# GitNexus with agent-house-rules

[Back to README](../README.md)

## GitNexus across several repos

For backend + frontend, or a downstream repo with one or more upstream repos, index each repo, then put them in a group so GitNexus links their contracts (checked against GitNexus 1.6.12 CLI help):

```bash
# once per repo; --index-only keeps GitNexus from editing AGENTS.md / CLAUDE.md / skills in the repo
npx gitnexus analyze --index-only ../api-service
npx gitnexus analyze --index-only ../web-client

npx gitnexus group create shop                     # writes a template group.yaml
npx gitnexus group add shop shop/backend api-service   # <groupPath> <registryName from 'gitnexus list'>
npx gitnexus group add shop shop/frontend web-client
npx gitnexus group sync shop                       # extract contracts, build cross-repo links

npx gitnexus group status shop                     # stale indexes?
npx gitnexus group contracts shop --unmatched      # contracts GitNexus could not link
npx gitnexus group impact shop --repo shop/backend --target ProjectOut --direction upstream
```

- `--direction upstream` = who depends on this (downstream consumers); `downstream` = what this depends on.
- Keep indexes fresh (`analyze --index-only --watch`, or re-run `analyze --index-only` + `group sync` after pulls); a stale group gives stale answers.
- Without `--index-only`, `analyze` adds a GitNexus section to the repo's `AGENTS.md` / `CLAUDE.md` and installs skills into `.claude/skills` / `.agents/skills` — unwanted in shared team repos.
- Keep the `.gitnexus/` index folder out of git (`.gitignore` or `.git/info/exclude`).
- Cross-links are only as good as contract detection for your stack; check `group contracts --unmatched` before trusting an empty impact result.
