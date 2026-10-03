---
name: kickoff
description: Start a work session - capture task, plan, and repositories from the user's message, then run discovery per AGENTS.md. Use only when the user explicitly asks to kick off a session.
---

Session kickoff. Invoke as `$kickoff <task> [--plan <path>] [--repo <path>]...`; take input from the user's message, not `$ARGUMENTS` substitution.

1. Take the task, optional `--plan <path>` (default: none), and repeated `--repo <path>` (default: current directory), or equivalent prose. Honor quoted paths; resolve relative paths from the session's starting directory using its OS conventions.
   If the task is missing, ask the user for task, plan path, and repo paths. Stop until answered.
2. Check repo paths are directories and readable; read applicable AGENTS.md files in each repo. Report unavailable paths/access and pause dependent work. Listing a repo does not grant write access; if needed, restart with `codex -C <primary-repo> --add-dir <other-repo>` within user authorization.
3. Read any supplied plan; pause dependent work if missing/unreadable. A plan path alone is not execution approval: follow the user's requested scope and established approval (Agent Operating Rules §2).
4. Classify Tiny / Small / Medium / Large (Agent Operating Rules §1). Use a matching installed skill if one fits (design unclear → brainstorming; bug with unclear cause → systematic-debugging). GitNexus: use an existing index only; never run `gitnexus analyze` yourself.
   Large, or Medium across several repos: if the session may be running at low effort, suggest the user raise it (`/model` with a higher reasoning level); do not wait for it.
5. Briefly state task, plan/approval status, and resolved repo paths; Medium+: include the Discovery Summary. Continue within the requested scope unless an unknown blocks correctness.
6. Before declaring done: verify and report per Agent Operating Rules §5 and §7.
