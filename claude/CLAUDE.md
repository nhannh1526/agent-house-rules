@house-rules.md

# Claude Code specifics

## Skill routing (use if installed; skip silently if not)
| Situation | Skill |
|---|---|
| New feature or behavior change, design unclear | superpowers:brainstorming → superpowers:writing-plans |
| Executing an approved plan | superpowers:executing-plans, or superpowers:subagent-driven-development for independent tasks |
| Bug or failure with unclear cause | superpowers:systematic-debugging |
| Rename / move / extract code | gitnexus-refactoring if the repo is GitNexus-indexed, else safe-refactor (`caveman:safe-refactor` when installed via the caveman plugin) |
| Changing a shared symbol in a GitNexus-indexed repo | gitnexus-impact-analysis first |
| Changing an API/contract used by other repos in a GitNexus group | `gitnexus group impact` (upstream and downstream) first |
| Before claiming done | superpowers:verification-before-completion |

GitNexus rows apply only when its tools are available; use existing indexes only and never run `gitnexus analyze` yourself. Use matching installed skills by description; the table gives preferences. Alternative packs for the same job (e.g. mattpocock `tdd`, `diagnosing-bugs`) are fine, but use one pack per job. Opt-in workflows (GSD `/gsd-*`, `grilling`) only when the user asks. Sequences across phases are fine.

## Subagents
Use available agents within task permissions and concurrency limits; otherwise work locally. Give each worker a scope and require them to preserve others' edits.
- Broad search across many files/repos, or 2+ independent tasks with no shared state → parallel agents in a single message (Explore for search), when the scope warrants it.
- Stuck after 2 failed attempts, or a second diagnosis would help → `codex:codex-rescue`.
- Never spawn an agent for a single-file lookup or a known symbol.

## Cross-model audit (Medium/Large only)
After self-review passes, use `codex:codex-rescue` if available and configured. Supply the task, restrictions, repo paths, plan text (if any), and all task changes (unstaged, staged, untracked; baseline diff if committed), with read-only repository access. Request correctness bugs and approved-plan deviations only; no edits or further delegation.
Run it in the foreground and wait for its findings; a background launch is not a completed audit. Verify findings before fixing. If it is not installed or configured, report the skipped audit and continue; do not run setup automatically. If an invoked audit fails or returns nothing, report that and stop for the user's decision; never substitute your own review for it.
Add a second reviewer only for a different error class (security, performance).
