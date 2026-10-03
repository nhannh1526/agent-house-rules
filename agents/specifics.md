# AGENTS.md tool specifics
- Use matching installed skills by description; prefer superpowers when applicable. When GitNexus tools are available and the repo is indexed, run impact analysis before changing a shared symbol (across repos in a GitNexus group: `gitnexus group impact`); if they are not, say so. Never run `gitnexus analyze` yourself. Opt-in workflows (GSD) only when the user asks. Avoid overlapping workflows; user scope and permissions govern skill actions.
- When asked to review another agent's work: review only, never edit files; report findings as file:line, severity, fix.
