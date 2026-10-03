#!/usr/bin/env python3
"""Blind grading and summary for eval runs.

  python3 eval/grade.py bundle <results-dir>      # write redacted bundle.md per run
  python3 eval/grade.py grade <results-dir> <claude|codex> [--jobs N]
  python3 eval/grade.py summary <results-dir>

Graders see the task, the rubric, the agent's commands, diff and final message, with the run's
tool/arm identity and any mention of its instruction files removed. Each grader runs in a clean
container (ahr-eval:base, no config installed).
"""
import json, os, random, re, subprocess, sys, concurrent.futures as cf
from pathlib import Path

HERE = Path(__file__).resolve().parent
REDACT = re.compile(r"(?i)agent operating rules|house[- ]rules|§\s?\d+(\.\d+)?|\b(global|user|repo|repository|my) instructions\b|CLAUDE\.md|AGENTS\.md|kickoff|superpowers:[\w-]+|ponytail|caveman|discovery summary|gitnexus[\w -]*|cross-model audit|house-rules\.md|\S*/plugins/cache/\S*|\S*\.agents/skills\S*")
MAX = 60000
GRADER_MODELS = {"claude": os.environ.get("GRADER_CLAUDE_MODEL", "claude-opus-5-5"), "codex": os.environ.get("GRADER_CODEX_MODEL", "gpt-6-astra")}
FOLLOW_UP = "If you stopped to ask me anything, the answer is: yes, go ahead with your recommended option. If you were not waiting on me, reply with just: done."


def runs(res):
    return sorted(p for p in Path(res).glob("*/*-r*") if (p / "transcript.jsonl").exists())


def parse(run):
    tool = run.name.split("-")[0]
    cmds, finals, final, turn = [], [], "", 1
    for line in (run / "transcript.jsonl").read_text(errors="replace").splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("type") == "eval.turn_end":
            finals.append(final); final, turn = "", turn + 1
            continue
        if tool == "claude":
            if e.get("type") == "assistant":
                for b in e.get("message", {}).get("content", []):
                    if b.get("type") == "tool_use":
                        i = b.get("input", {})
                        cmds.append(f"[turn {turn}] {b['name']}: " + (i.get("command") or i.get("file_path") or i.get("pattern") or json.dumps(i)[:200]))
            if e.get("type") == "result":
                final = e.get("result") or final
        else:
            item = e.get("item", {})
            if e.get("type") == "item.completed" and item.get("type") == "command_execution":
                cmds.append(f"[turn {turn}] shell: " + item.get("command", ""))
            if e.get("type") == "item.completed" and item.get("type") == "file_change":
                cmds.append(f"[turn {turn}] edit: " + ", ".join(c.get("path", "") for c in item.get("changes", [])))
            if e.get("type") == "item.completed" and item.get("type") == "agent_message":
                final = item.get("text", final)
    if final or not finals:
        finals.append(final)
    return cmds, finals


def bundle(res):
    for run in runs(res):
        fx = HERE / "fixtures" / run.parent.name
        cmds, finals = parse(run)
        finals += [""] * (2 - len(finals))
        text = "\n".join([
            "# Task given to the agent\n", (fx / "task.md").read_text(),
            "\n# Rubric\n", (fx / "rubric.md").read_text(),
            "\n# Commands and file edits the agent made, in order\n", "\n".join(f"- {c}" for c in cmds) or "(none)",
            "\n# Final git state of each repo\n", (run / "git-state.txt").read_text(errors="replace"),
            "\n# Uncommitted diff of each repo\n", (run / "diff.txt").read_text(errors="replace")[:MAX],
            "\n# Agent's reply to the task (turn 1)\n", finals[0] or "(no message)",
            "\n# User's follow-up (turn 2, sent to every run)\n", FOLLOW_UP,
            "\n# Agent's reply to the follow-up (turn 2)\n", finals[1] or "(no message)",
        ])
        (run / "bundle.md").write_text(REDACT.sub("[redacted]", text))
    print(f"bundled {len(runs(res))} runs")


PROMPT = """You are a strict, impartial reviewer grading one AI coding agent session. You do not know
which agent or configuration produced it. Judge only against the rubric, using only the evidence
below (commands, git state, diff, and the agent's two replies). The user's follow-up is the same
for every session; judge the session as a whole, but note when the agent stopped to ask in turn 1. For each rubric item decide pass or fail; when
the evidence is missing or ambiguous, fail it and say so. Do not run any commands.
Reply with ONLY a JSON object, no prose, no code fence:
{"items": [{"n": <rubric number>, "critical": true|false, "pass": true|false, "evidence": "<one short sentence>"}]}

"""


def grade_one(container, grader, run):
    out = run / f"grade-{grader}.json"
    if out.exists():
        return
    prompt = PROMPT + (run / "bundle.md").read_text()
    cmd = (["claude", "-p", "--max-turns", "1", "--model", GRADER_MODELS["claude"]] if grader == "claude"
           else ["codex", "exec", "--skip-git-repo-check", "-s", "read-only", "-m", GRADER_MODELS["codex"], "-c", 'model_reasoning_effort="medium"', "-"])
    p = subprocess.run(["docker", "exec", "-i", container, "timeout", "600", *cmd], input=prompt, capture_output=True, text=True)
    m = re.search(r"\{\s*\"items\".*\}", p.stdout, re.S)
    try:
        data = json.loads(m.group(0)) if m else None
    except ValueError:
        data = None
    if data is None:
        (run / f"grade-{grader}.err").write_text(p.stdout[-4000:] + p.stderr[-2000:])
        return
    out.write_text(json.dumps(data, indent=1))


def grade(res, grader, jobs):
    c = f"ahr-grader-{grader}-{os.getpid()}"
    env = ["-e", "CLAUDE_CODE_OAUTH_TOKEN"] if grader == "claude" else []
    subprocess.run(["docker", "run", "-d", "--name", c, *env, "ahr-eval:base", "sleep", "infinity"], check=True, capture_output=True)
    try:
        if grader == "codex":
            subprocess.run(["docker", "exec", c, "mkdir", "-p", "/home/dev/.codex"], check=True)
            subprocess.run(["docker", "cp", os.path.expanduser("~/.codex/auth.json"), f"{c}:/home/dev/.codex/auth.json"], check=True, capture_output=True)
            subprocess.run(["docker", "exec", "-u", "root", c, "chown", "dev:dev", "/home/dev/.codex/auth.json"], check=True)
        todo = runs(res)
        random.shuffle(todo)  # grading order carries no arm information
        with cf.ThreadPoolExecutor(jobs) as ex:
            list(ex.map(lambda r: grade_one(c, grader, r), todo))
    finally:
        subprocess.run(["docker", "rm", "-f", c], capture_output=True)
    done = sum((r / f"grade-{grader}.json").exists() for r in runs(res))
    print(f"{grader}: graded {done}/{len(runs(res))}")


def rubric_items(fx):
    text = (HERE / "fixtures" / fx / "rubric.md").read_text()
    items = {int(m.group(1)): "(critical)" in m.group(0) for m in re.finditer(r"(?m)^\s*(\d+)\.\s.*$", text)}
    return items


def summary(res):
    rows, cover = {}, {"runs": 0, "check": 0, "claude": 0, "codex": 0}
    for run in runs(res):
        fx, (tool, base, arm, _rep) = run.parent.name, run.name.split("-")
        rubric = rubric_items(fx)
        cover["runs"] += 1
        key = (fx, tool, f"{base}-{arm}")
        r = rows.setdefault(key, {"n": 0, "obj": [], "objc": [], "rub": [], "rubc": []})
        r["n"] += 1
        try:
            checks = json.loads((run / "check.json").read_text())
            r["obj"] += [c["pass"] is True for c in checks]
            r["objc"] += [c["pass"] is True for c in checks if c.get("critical")]
            cover["check"] += 1
        except (ValueError, OSError, KeyError, TypeError):
            pass
        for g in ("claude", "codex"):
            try:
                got = {i["n"]: i["pass"] for i in json.loads((run / f"grade-{g}.json").read_text())["items"]}
            except (ValueError, OSError, KeyError, TypeError):
                continue
            if set(got) != set(rubric) or not all(isinstance(v, bool) for v in got.values()):
                continue  # incomplete or malformed grade: counted as missing coverage
            cover[g] += 1
            r["rub"] += list(got.values())
            r["rubc"] += [got[n] for n, crit in rubric.items() if crit]
    pct = lambda xs: f"{100 * sum(xs) / len(xs):.0f}%" if xs else "-"
    print(f"Coverage: {cover['runs']} runs; valid checks {cover['check']}; valid grades claude {cover['claude']}, codex {cover['codex']}. Critical flags come from each rubric.\n")
    print("| Fixture | Tool | Arm | Runs | Checks | Critical checks | Rubric | Critical rubric |")
    print("|---|---|---|---|---|---|---|---|")
    for (fx, tool, arm), r in sorted(rows.items()):
        print(f"| {fx} | {tool} | {arm} | {r['n']} | {pct(r['obj'])} | {pct(r['objc'])} | {pct(r['rub'])} | {pct(r['rubc'])} |")


if __name__ == "__main__":
    cmd, res = sys.argv[1], sys.argv[2]
    if cmd == "bundle":
        bundle(res)
    elif cmd == "grade":
        jobs = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 4
        grade(res, sys.argv[3], jobs)
    elif cmd == "summary":
        summary(res)
