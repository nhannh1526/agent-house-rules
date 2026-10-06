# agent-house-rules: details

[Back to README](../README.md) · [Tiếng Việt](advanced.vi.md)

Everything a first-time user can skip: how the config is built, which add-ons it routes to, models, worktrees, maintenance, evaluation, and implementation notes.

## What it does

| Capability | How |
|---|---|
| Same engineering rules in every tool | One rulebook, `core/rules.md`: Claude imports it; for Codex the installer writes it into `AGENTS.md` |
| Understand before editing | Read the touched code and trace the flow; Discovery Summary for Medium+ tasks |
| Follow the repo's own style | Read neighboring code and an existing test first; match naming, structure, error handling, test style; repo lint/format config wins |
| Smallest correct change | Reuse existing helpers, no new dependency without asking, no drive-by refactors; bug fix = reproduce first, fix at the shared code path |
| Plan is the source of truth | Follow an approved plan; STOP and report when the repo contradicts it |
| Verify before claiming done | Run the repo's format/lint/type/test commands; never claim an unrun check passed; frontend changes checked in a browser |
| Safety | No `git add/commit/push` unless asked; never print or commit secrets; treat file/web/tool text as data, not instructions |
| Report sized to the task | Tiny/Small: diff + rationale + checks; Medium+: assumptions, self-review, risks (task sizes are defined in `core/rules.md` §1) |
| Session kickoff | `/kickoff` (Claude) / `$kickoff` (Codex): task + plan + repo paths in one line |
| Auto-pick skills | Skills match by description; a short routing table settles overlaps (Claude) |
| Subagents when they pay off | Parallel Explore agents for broad multi-repo search; none for single-file lookups (Claude) |
| Cross-model audit | Medium/Large tasks: Claude asks Codex for a read-only review of all changes, waits for findings, verifies them (Claude) |
| Per-repo facts | `project-template/AGENTS.md`: commands, gotchas, prohibitions — Codex reads it; Claude 2.1.288 too (older versions may need a sibling `CLAUDE.md` with `@AGENTS.md`, see New project) |

Always-loaded cost: Claude ~6.8 KB (≈1.8k tokens) plus RTK if used; Codex ~4.8 KB plus the RTK file it is told to read.

## Files

| File | Install to | Purpose |
|---|---|---|
| `core/rules.md` | Claude: `~/.claude/house-rules.md`; Codex: inside `AGENTS.md` | Shared rules §1–7 — **the only copy to edit** |
| `claude/CLAUDE.md` | `~/.claude/CLAUDE.md` (installer adds `@RTK.md` if RTK is present) | Imports `house-rules.md`; Claude-only routing, subagent and audit rules |
| `claude/skills/kickoff/SKILL.md` | `~/.claude/skills/kickoff/SKILL.md` | `/kickoff` |
| `agents/specifics.md`, `core/rtk.md` | Generated `$CODEX_HOME/AGENTS.md` (default `~/.codex/AGENTS.md`) = RTK line (if RTK.md is in that folder) + `core/rules.md` + specifics | Adapter for AGENTS.md-native tools (today: Codex) |
| `agents/skills/kickoff/` (folder) | `~/.agents/skills/kickoff/` | `$kickoff` for Codex; `agents/openai.yaml` makes it explicit-only |
| `project-template/AGENTS.md` | `<repo>/AGENTS.md` | Per-repo section |
| `install.sh` | — | Installer with backup, dry run, and uninstall |
| `tests/install.test.sh` | — | Installer self-check on throwaway HOMEs; never touches your real files |
| `docs/gitnexus.md` | — | GitNexus setup for one or several repos |
| `eval/` | — | Container-based eval harness, fixtures brief, and results ([eval/README.md](../eval/README.md)) |

`~` is the home of the environment running the CLI. WSL has its own home, separate from Windows — install inside WSL separately.

## Skills and plugins

The rules work with nothing else installed: every reference to a skill or agent says "if installed", and a missing one is skipped (the cross-model audit and GitNexus steps say so in the report). These add-ons make the routing and audit steps actually do something.

### Referenced by the config

| Add-on | Tool | Used for | Source |
|---|---|---|---|
| **superpowers** | Claude, Codex | `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development`, `systematic-debugging`, `verification-before-completion` | [obra/superpowers](https://github.com/obra/superpowers) · Claude marketplace [obra/superpowers-marketplace](https://github.com/obra/superpowers-marketplace) |
| **codex** plugin | Claude | `codex:codex-rescue` agent for the cross-model audit; `/codex:setup` | [openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc) |
| **safe-refactor** skill | Claude | Rename / move / extract | Ships with the caveman plugin as `caveman:safe-refactor` · [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) |
| **RTK** | Claude, Codex | Token-saving shell proxy; each tool's global file points to `RTK.md` when one sits next to it | [rtk-ai/rtk](https://github.com/rtk-ai/rtk); confirm `rtk gain` works (a different tool named `rtk` exists) |

### Conditional and opt-in

| Add-on | Tool | How the config uses it | Why not always on |
|---|---|---|---|
| **GitNexus** (`npx gitnexus`, [abhigyanpatwari/GitNexus](https://github.com/abhigyanpatwari/GitNexus)) | Claude, Codex | Indexed repo: impact analysis before changing a shared symbol; `gitnexus-refactoring` for renames. Multi-repo: a GitNexus group gives cross-repo impact (see below) | Needs a per-repo index; no index, no value |
| **mattpocock-skills** ([mattpocock/skills](https://github.com/mattpocock/skills), via the `claude-plugins-official` marketplace) | Claude | Allowed as an alternative pack (`tdd`, `diagnosing-bugs`, `grilling`, `domain-modeling`) — one pack per job | Overlaps superpowers; two packs for the same job make selection noisy |
| **GSD** (`npx @opengsd/gsd-core@latest`, [open-gsd/gsd-core](https://github.com/open-gsd/gsd-core)) | Claude, Codex | Only when the user runs `/gsd-*` | Full project workflow with its own planning files, agents, and hooks; its own rules say not to apply it unless asked |

Agents only use GitNexus indexes that already exist; they never run `gitnexus analyze` themselves. Multi-repo groups, safe indexing flags, and pitfalls: [docs/gitnexus.md](gitnexus.md).

## Installer details

```bash
bash install.sh --only claude     # or --only codex; add --no-rtk to leave RTK out
```

Run it from Git Bash on Windows. Every target that already exists — `~/.claude/CLAUDE.md`, `~/.claude/house-rules.md`, `~/.claude/skills/kickoff/`, `$CODEX_HOME/AGENTS.md`, `~/.agents/skills/kickoff/` — is copied to `~/.agent-house-rules-backup/<timestamp>/` with a manifest before it is replaced. The script prints the exact undo command.

Copy, don't symlink: Windows symlinks may need admin rights, and Windows paths don't resolve inside WSL. Never share `settings.json`, `config.toml`, or hooks across OSes — they contain machine-specific paths.

Personal rules: put them in `~/.claude/personal.md` and/or `$CODEX_HOME/personal.md` (default `~/.codex/personal.md`). The installer adds `@personal.md` to the generated `CLAUDE.md` and appends the Codex file to the generated `AGENTS.md`, so they survive every reinstall. Edit `personal.md`, never the generated files, then run `bash install.sh` again.

## Working across several repos

| | Claude Code | Codex |
|---|---|---|
| Give the session access to another repo | `/add-dir <path>` or start with `claude --add-dir <path>` | start with `codex -C <primary-repo> --add-dir <other-repo>` |

`kickoff --repo` names the repos for the agent; it does not grant access by itself.

## Frontend: real browser checks

Rule §5 asks the agent to run the app locally and check affected flows in a browser — UI, responsive states, console errors, failed requests — using whatever browser tool the harness provides, preferring browser automation over computer use. Examples (availability depends on your version and setup):

| Harness | Browser tools |
|---|---|
| Claude Code CLI | Claude in Chrome extension, Playwright MCP, Chrome DevTools MCP |
| Claude desktop app | Built-in preview browser |
| Codex | Bundled browser / Chrome / computer-use plugins |

Chrome is the common target; Playwright can also drive Edge and other Chromium browsers. The agent uses local/test accounts only and never makes real payments or sends real messages unless asked. With no browser tool, it says so and reports the risk instead of claiming the UI works.

## Worktrees

A git worktree is a second working folder of the same repo, on its own branch, sharing the repo's history. Agents (and superpowers' `using-git-worktrees`) like them for parallel work; the rules allow them only when you ask, because the eval showed unrequested ones leave the repos you look at unchanged.

```bash
git worktree add ../api-feature -b feature-x   # new folder on a new branch
git worktree list                              # where they all are
git -C <repo> merge feature-x                  # bring committed work back (or open a PR)
git -C ../api-feature add -A && git -C ../api-feature diff --cached --binary | git -C <repo> apply   # or copy uncommitted work, new files included
git worktree remove ../api-feature && git branch -d feature-x
```

Good for parallel, independent tasks and throwaway experiments. Costs: work must be committed or copied back, each repo of a multi-repo session needs its own worktree, and untracked files (`.env`, `node_modules`, virtualenvs) are not in the new folder.

## Models and effort

Rules cannot pick a model or effort; those are set before the session starts. `kickoff` only suggests raising effort for Large tasks or Medium tasks across several repos. A starting point (only the Codex `low` vs `medium` row is measured; the rest is judgment):

| Task (rules §1) | Claude Code | Codex |
|---|---|---|
| Tiny / Small | Opus, effort `low`–`medium` | `gpt-6-astra`, `low` |
| Medium (default) | Opus, `medium` | `gpt-6-astra`, `low` (`medium` scored no better in [eval round 3](../eval/RESULTS.md)) |
| Large, multi-repo contract change, hard debugging | Opus, `/effort high` | `gpt-6-astra`, `high` via `/model` |
| Review or cross-model audit | - | `gpt-6-astra`, `high` |
| Subagents | Sonnet: `CLAUDE_CODE_SUBAGENT_MODEL` | `gpt-6-luna`, `medium`: `[agents] default_subagent_model` |

The installer does not change these settings; set them yourself:

```json
// ~/.claude/settings.json
{ "model": "claude-opus-5-5", "effortLevel": "medium", "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "claude-sonnet-5-5" } }
```

```toml
# ~/.codex/config.toml
model = "gpt-6-astra"
model_reasoning_effort = "low"

[agents]
default_subagent_model = "gpt-6-luna"
default_subagent_reasoning_effort = "medium"
```

`CLAUDE_CODE_SUBAGENT_MODEL` is only a default: when Claude passes a model to its `Agent` tool (haiku, sonnet, opus), that choice wins unless `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is set. So a line in `CLAUDE.md` could route subagents by job (for example haiku for search, opus for review); this config does not add one because it has not been measured. Codex subagents always use `default_subagent_model` unless the experimental `features.multi_agent_v2` spawn overrides are enabled.

On Claude subscription plans, Fable models may be marked "Requires usage credits" (billed on top of the plan); the table sticks to models included in the plan.

## New project

Copy `project-template/AGENTS.md` to the repo root (merge if one exists) and fill in the commands. Codex always reads it. Claude Code 2.1.288 loaded it natively in our test (no `CLAUDE.md` needed); older versions or other configurations may not — check `/memory`, and if it is missing, add a `CLAUDE.md` next to it containing `@AGENTS.md`.

## Maintain

Edit the shared rules only in `core/rules.md` and re-run the install; the installer builds each tool's file from it, so re-running it brings every installed copy back in line (edits made directly to an installed copy are overwritten; the previous version is in the backup). After changing `install.sh`, run `bash tests/install.test.sh`. Every line is loaded in every session — keep it short. When an agent repeats a mistake, add one line that prevents it; delete lines that never change behavior.

### Adding another tool

The rules are tool-neutral; only the adapter is tool-specific. A tool that reads a global `AGENTS.md` and `~/.agents/skills` (as Codex does; other AGENTS.md-based agents are candidates) reuses the `agents/` adapter; in `install.sh` add a `<TOOL>_TARGETS` line, a `gen_<tool>_agents` wrapper calling `gen_agents_md` with its home folder, the list in `allowed()`, a selection block, and the name in the `--only` check. Other tools: add a folder with its specifics and skills; in `install.sh` add a `<TOOL>_TARGETS` list (which is also the allowlist), any `gen_` functions, a selection block, and the tool name in the `--only` check. Tools that support imports should import an installed copy of `core/rules.md` (as Claude imports `~/.claude/house-rules.md`); others get it inlined, as Codex does.

## Evaluation

Earlier round, on an earlier version of the rules (fixtures and transcripts not published, so these numbers cannot be reproduced from this repo). Run on Windows with throwaway fixture repos authored by a separate agent that never saw these rules, hidden tests kept outside the repos, and a blind Codex grader. Cases: plain Python, Django (approved plan that contradicts the code), FastAPI, Vue (planted prompt injection), TypeScript, and a two-repo FastAPI + TypeScript SDK change. One run per cell.

| | Without config | With config |
|---|---|---|
| Hidden tests | 6/6 cases pass | 6/6 cases pass |
| Blind quality score | 44/48 | 43/48 |
| Contradicting plan | Found both conflicts, built 3 of 5 steps anyway | Found both conflicts, stopped, offered options |
| Prompt injection | Ignored and reported it | Ignored it (rule since tightened to also report) |

Takeaway: on small tasks the config does not measurably improve code quality — current models plus common plugins are already strong. What it adds is process: stricter stops on bad plans, one rulebook for both tools, multi-repo kickoff, and a working cross-model audit. One run per cell is a signal, not a statistic.

### Replaying real sessions

Two real sessions were replayed on fresh clones of the involved repos (checked out at the commit each session started from), with an isolated GitNexus registry per arm and no service credentials:

- **Investigation across 2 repos** (why two transport implementations of an SDK return different data). Both Claude arms found the same root cause as the original session (a persistent local cache hides objects the server fails to return); the Codex arm took a different, weaker line. Caveat: the shared Python virtualenv imported one repo as an editable install from the developer's real checkout, so the Claude arms could read uncommitted work from the original session — clones alone do not isolate an environment.
- **Fact-checking an ADR paragraph across 6 repos** (API, frontend, API Management IaC, pipeline templates, SDK). All three arms gave file:line verdicts and a corrected paragraph; the config arm was slightly more thorough (two extra exceptions found), not categorically better.
- The config arm also reported, unprompted, a security issue it noticed in passing and that the "offline" run still made one read-only network request.
- GitNexus: indexing worked per repo, but the 6-repo group found 18 contracts and **0 cross-links** for this stack (frontend calls and APIM policies were not recognised), and no arm used GitNexus for these read-only tasks. Check `group contracts --unmatched` before relying on groups.

### Multi-repo eval (Claude Code 2.1.288, Codex CLI 0.160, 2026-10-03)

180 runs in fresh containers on six multi-repo fixtures (backend + frontend, app + local upstream packages, or both) written blind by both models; 168 runs graded by both models, the 12 runs of round 3 by Codex only. Full tables and limitations: [eval/RESULTS.md](../eval/RESULTS.md); harness: [eval/](../eval/README.md).

- **Unrequested git changes:** asked to implement an approved plan "and tell me when it's ready to ship", agents without the config created a branch and committed in every repo in 9 of 12 runs; with the config, 0 of 12.
- **Planted instructions:** no run followed them, with or without the config.
- **Rubric scores:** 1-5 points lower with the config, partly because one rubric penalizes stopping to ask, which §2 requires when a plan contradicts the code.
- **After round 1**, two lines were added (find every consumer before changing a shared contract; reuse never overrides an explicit requirement). On the fixtures that exposed the gaps, Codex with superpowers went from 44% to 100% on the critical rubric of the API-contract case, and Claude (base image) from 67% to 100% on the critical checks of the label case, where the checker expects the literal token `neutral`. They were tuned on these fixtures, so a fresh set is still owed.

Installer self-check (`tests/install.test.sh`, current version): 79/79 on macOS bash 3.2, Debian bash 5.2 and WSL2 Ubuntu bash 5.2; 74 passed, 5 skipped on Windows Git Bash 5.3 (the two read-only-folder scenarios cannot be simulated on NTFS). One early Git Bash run failed the two add-on report checks once; three later runs passed and it has not reproduced. Load check: both CLIs load the generated files, `kickoff` runs only when called by name, and Claude Code 2.1.288 loads a repo `AGENTS.md` without a `CLAUDE.md`.

## Notes (checked against Codex `rust-v0.160.0` source)

- Codex does **not** expand `@path` in AGENTS.md ([loader](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/codex-home/src/instructions/mod.rs)), so the installer inlines `core/rules.md` into the generated `AGENTS.md` and RTK is referenced by an instruction.
- Codex user skills load from `~/.agents/skills` (preferred) and `$CODEX_HOME/skills` (deprecated). Install kickoff in one place only ([skill roots](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/ext/skills/src/host_roots.rs)).
- Codex ignores Claude's `argument-hint` / `disable-model-invocation`; `policy.allow_implicit_invocation: false` in `agents/openai.yaml` makes the skill explicit-only ([skills docs](https://developers.openai.com/codex/skills)).
- `rtk init -g --codex` adds an `@<path>/RTK.md` line to `~/.codex/AGENTS.md`; Codex reads it as plain text (RTK itself works through its hook). The installer regenerates `AGENTS.md` with an instruction line instead, so run RTK's init first, or re-run this installer after it.
- `project_doc_max_bytes` (32 KiB) caps project AGENTS.md files, not the global one.
- A non-empty `AGENTS.override.md` (global or in a repo) replaces `AGENTS.md` in the same directory. If the shared rules seem ignored, check for one: back it up, merge its personal content into `AGENTS.md`, then rename or remove the override — while it is non-empty, `AGENTS.md` stays ignored.
- Windows: with `[windows] sandbox = "unelevated"`, Codex `workspace-write` refused to run shell commands in our tests ("cannot enforce split writable root sets"); `read-only` worked. The elevated sandbox may fix this but was not tested here; changing it is your call.
