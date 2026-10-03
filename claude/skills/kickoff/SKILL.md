---
name: kickoff
description: Start a work session - capture task, plan, and repositories, then run discovery and route to the right skills and agents.
argument-hint: "<task> [--plan <path>] [--repo <path>]..."
disable-model-invocation: true
---

Session kickoff. Input: $ARGUMENTS

1. Parse the task text, optional `--plan <path>` (default: none), and repeated `--repo <path>` (default: current directory). Honor quoted paths; resolve relative paths from the session's starting directory using its OS conventions.
   If the task text is empty, ask the user for: task, plan path (or "none"), repo paths. Stop until answered.
2. Check repo paths are directories and readable; read applicable repo instructions, including those in additional repos. If needed access is denied, report the exact path and permission; `/add-dir <path>` adds workspace access, not a missing file. Pause dependent work.
3. Read any supplied plan; pause dependent work if missing/unreadable. A plan path alone is not execution approval: follow the user's requested scope and established approval (Agent Operating Rules §2).
4. Classify Tiny / Small / Medium / Large (Agent Operating Rules §1). Route using available skills/agents and the CLAUDE.md routing table:
   - design unclear → superpowers:brainstorming, then superpowers:writing-plans
   - approved plan to execute → superpowers:executing-plans, or superpowers:subagent-driven-development for independent tasks
   - bug with unclear cause → superpowers:systematic-debugging (obvious local bug: reproduce, fix, verify)
   - several repos needing independent investigation → Explore agents in parallel (skip for small or obvious scope)
   - GitNexus: use an existing index only (MCP `list_repos` / `gitnexus list`) — impact analysis before changing shared symbols, `group impact` for API/contract changes across a group. Never run `gitnexus analyze` yourself; if a repo is not indexed, mention `npx gitnexus analyze --index-only <repo>` once and continue.
   Large, or Medium across several repos: if the session may be running at low effort, suggest the user raise it (`/effort high`); do not wait for it.
5. Briefly state task, plan/approval status, and resolved repo paths; Medium+: include the Discovery Summary. Continue within the requested scope unless an unknown blocks correctness.
6. Before declaring done: verify per Agent Operating Rules §5; Medium+: apply CLAUDE.md's Cross-model audit once; report per §7.
