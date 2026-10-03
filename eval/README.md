# Eval harness

Measures whether `agent-house-rules` changes how Claude Code and Codex behave, mainly in sessions
that span several repos (backend + frontend, an app with local upstream packages, or both).

## Design

| Concern | How it is handled |
|---|---|
| Host leakage | Every run is a fresh container (`Dockerfile`); nothing from the host is mounted. Claude gets `CLAUDE_CODE_OAUTH_TOKEN` from the environment, Codex gets a copy of `auth.json` that is deleted when the agent finishes |
| Arms | `base-none`, `base-rules` (clean image, with or without this config), `machine-none`, `machine-rules` (Claude: superpowers, the codex plugin, ponytail, caveman; Codex: superpowers, ponytail) |
| Fixture bias | Fixtures are written by Claude and Codex in a container that holds only `author-brief.md` and a list of situations (`briefs/`), never this repo or its rules |
| Hidden answers | `setup.sh` builds the workspace and is deleted before the agent starts; `check.py` is copied in only after the agent finishes; the agent never sees `rubric.md` |
| Grader bias | Two graders (Claude and Codex, models pinned in `grade.py`) in clean containers grade each run against the rubric. Instruction-file mentions and plugin paths are redacted and grading order is shuffled; command names still reveal which tool ran, so grading is blind to the arm, not the tool |
| Agents that ask first | Every run gets the same second user turn: "if you were waiting on me, go ahead; otherwise reply done". Graders see both turns |
| Noise | Each cell runs several times (`reps`); results are reported as rates |

## Run

```bash
docker build -t ahr-eval:base --target base eval/
docker build -t ahr-eval:machine --target machine eval/
export CLAUDE_CODE_OAUTH_TOKEN=...          # from `claude setup-token`
bash eval/author.sh claude; bash eval/author.sh codex   # writes eval/fixtures/ (the 2026-10-03 set is committed)
bash eval/matrix.sh eval/results/<date> 3 4            # reps, parallel jobs
python3 eval/grade.py bundle eval/results/<date>
python3 eval/grade.py grade eval/results/<date> claude
python3 eval/grade.py grade eval/results/<date> codex
python3 eval/grade.py summary eval/results/<date>
```

A single run: `bash eval/run.sh <fixture> <claude|codex> <arm> <rep> <results-dir>`. Each run leaves
`transcript.jsonl`, `git-state.txt`, `diff.txt`, `check.json`, and later `bundle.md` and `grade-*.json`.

Runs use `--dangerously-skip-permissions` (Claude) and `--dangerously-bypass-approvals-and-sandbox` (Codex)
because the container is the sandbox; never point these scripts at a host directory. Models are pinned
in `run.sh` (`CLAUDE_MODEL`, `CODEX_MODEL`, `CODEX_EFFORT` override them).

The committed fixtures are the set used in [RESULTS.md](RESULTS.md). The rules were adjusted after seeing them, so write a fresh set with `author.sh` before trusting a new comparison.
