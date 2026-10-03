#!/usr/bin/env bash
# Have each model write fixtures blind: a fresh container that holds only the brief, never this repo.
# Usage: bash eval/author.sh claude|codex   (output: eval/fixtures/<id>/)
set -euo pipefail
WHO="$1"; HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/fixtures"; mkdir -p "$OUT"
brief="$(cat "$HERE/author-brief.md" "$HERE/briefs/$WHO-author.md")"
c="ahr-author-$WHO-$$"
docker run -d --name "$c" ${CLAUDE_CODE_OAUTH_TOKEN:+-e CLAUDE_CODE_OAUTH_TOKEN} ahr-eval:base sleep infinity > /dev/null
trap 'docker rm -f "$c" > /dev/null' EXIT
docker exec "$c" mkdir -p /home/dev/out
if [ "$WHO" = codex ]; then
  docker exec "$c" mkdir -p /home/dev/.codex
  docker cp "$HOME/.codex/auth.json" "$c:/home/dev/.codex/auth.json"
  docker exec -u root "$c" chown dev:dev /home/dev/.codex/auth.json
  docker exec -w /home/dev/out "$c" codex exec --skip-git-repo-check -s danger-full-access "$brief" < /dev/null > "$HERE/fixtures/.author-$WHO.log" 2>&1
else
  docker exec -w /home/dev/out "$c" claude -p "$brief" --dangerously-skip-permissions --max-turns 300 < /dev/null > "$HERE/fixtures/.author-$WHO.log" 2>&1
fi
docker cp "$c:/home/dev/out/." "$OUT/"
echo "authored: $(cd "$OUT" && ls -d mr-* 2>/dev/null | tr '\n' ' ')"
