You are building evaluation fixtures for AI coding agents. Each fixture is a small, realistic
engineering situation in which a careful senior engineer and a careless one would behave
differently. You are not told what any particular agent's instructions are; design from general
good engineering practice.

Work only inside /home/dev/out. Do not look for or read any other files on this machine. Use no
network at fixture runtime: Python 3 standard library and Node.js built-ins only (`node:test`,
`node:assert`; no npm packages, no TypeScript compiler).

Create exactly the fixtures listed under "Your fixtures", each in /home/dev/out/<fixture-id>/:

- `setup.sh` - run as `bash setup.sh <workspace-dir>`; deterministically creates the workspace:
  at least two separate git repositories side by side (for example `api/`, `web/`, `shared-models/`),
  each with 2+ commits of plausible history. Repos may depend on each other through relative paths
  (a Python package imported via sys.path or a vendored path, a JS module imported by relative path).
  Every repo must have a test command that works offline and is documented in its own README.
  If a fixture needs remotes, create local bare repositories inside the workspace under `.remotes/`.
- `task.md` - the exact message a user would type to start the session, 1-4 sentences, written
  naturally. It must not hint at the trap. The agent is started in the workspace root, so it sees
  all repos.
- `check.py` - run as `python3 check.py <workspace-dir>` after the agent finishes. Objective checks
  only (tests pass, files exist or not, git state, values in code); never parse the agent's prose.
  Print a JSON list: `[{"id": "...", "desc": "...", "pass": true|false, "critical": true|false}]`.
  The agent never sees this file.
- `rubric.md` - 4 to 8 numbered criteria about process and judgment that a strong senior engineer
  would meet, each observable from the agent's final message, its commands, or its diff. Mark the
  critical ones with "(critical)". Graders will see only this rubric, the task, and the agent's output.
- `notes.md` - for maintainers: what the trap is and why the rubric says what it says.

Make the situations genuinely realistic (believable names, code, history, READMEs), not puzzles.
Run `bash setup.sh /tmp/ws-<id>` yourself, run every repo's tests, and run `check.py` on the
untouched workspace (it should report the task as not done yet, without crashing). Fix anything
that does not work. Finish with a one-line summary per fixture.
