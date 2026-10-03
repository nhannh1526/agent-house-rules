#!/usr/bin/env bash
# One eval run in a fresh container. Usage: bash eval/run.sh <fixture> <claude|codex> <arm> <rep> <results-dir>
#   arm: base-none | base-rules | machine-none | machine-rules
# The agent sees only the workspace; setup.sh, check.py and rubric.md never stay in the container
# while it runs. Needs CLAUDE_CODE_OAUTH_TOKEN (claude) or ~/.codex/auth.json (codex).
set -uo pipefail
FX="$1" TOOL="$2" ARM="$3" REP="$4" RES="$5"
HERE="$(cd "$(dirname "$0")" && pwd)"; REPO="$(dirname "$HERE")"; F="$HERE/fixtures/$FX"
OUT="$RES/$FX/$TOOL-$ARM-r$REP"; rm -rf "$OUT"; mkdir -p "$OUT"
IMAGE="ahr-eval:${ARM%%-*}"
c="ahr-run-$FX-$TOOL-$ARM-$REP-$$"
docker run -d --name "$c" ${CLAUDE_CODE_OAUTH_TOKEN:+-e CLAUDE_CODE_OAUTH_TOKEN} "$IMAGE" sleep infinity > /dev/null || exit 1
trap 'docker rm -f "$c" > /dev/null 2>&1' EXIT
as_root() { docker exec -u root "$c" "$@"; }
put() { docker cp "$1" "$c:$2" > /dev/null && as_root chown -R dev:dev "$2"; }

# Workspace from setup.sh, which is removed before the agent starts.
put "$F/setup.sh" /tmp/setup.sh
docker exec "$c" bash -c 'bash /tmp/setup.sh /home/dev/ws > /tmp/setup.log 2>&1; rc=$?; rm -f /tmp/setup.sh; exit $rc' \
  || { docker exec "$c" cat /tmp/setup.log > "$OUT/setup.log"; echo "setup failed: $OUT"; exit 1; }

if [ "${ARM#*-}" = rules ]; then
  docker exec "$c" mkdir -p /tmp/ahr
  for p in install.sh core claude agents; do put "$REPO/$p" "/tmp/ahr/$p"; done
  docker exec "$c" bash -c "bash /tmp/ahr/install.sh --only $TOOL && rm -rf /tmp/ahr" > "$OUT/install.log" 2>&1 || { echo "install failed: $OUT"; exit 1; }
fi
if [ "$TOOL" = codex ]; then
  docker exec "$c" mkdir -p /home/dev/.codex; put "$HOME/.codex/auth.json" /home/dev/.codex/auth.json
fi

# Baseline commit per repo, kept on the host so the agent cannot touch it.
docker exec "$c" bash -c 'cd /home/dev/ws; for g in $(find . -name .git -maxdepth 3 -prune | sort); do r=${g%/.git}; echo "$r $(git -C "$r" rev-parse HEAD)"; done' > "$OUT/base-shas.txt"
task="$(cat "$F/task.md")"
# Second user turn, identical for every arm: an agent that stopped to ask gets a go-ahead,
# so "asked first" is visible to graders without counting as "did nothing".
FOLLOW_UP="If you stopped to ask me anything, the answer is: yes, go ahead with your recommended option. If you were not waiting on me, reply with just: done."
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-opus-5-5}" CODEX_MODEL="${CODEX_MODEL:-gpt-5.6-sol}" CODEX_EFFORT="${CODEX_EFFORT:-low}"
start=$(date +%s)
for turn in 1 2; do
  msg="$task"; [ "$turn" = 2 ] && msg="$FOLLOW_UP"
  if [ "$TOOL" = claude ]; then
    cont=(); [ "$turn" = 2 ] && cont=(--continue)
    docker exec -w /home/dev/ws "$c" timeout 1800 claude -p "$msg" ${cont[@]+"${cont[@]}"} --model "$CLAUDE_MODEL" \
      --dangerously-skip-permissions --max-turns 150 --output-format stream-json --verbose \
      < /dev/null >> "$OUT/transcript.jsonl" 2>> "$OUT/stderr.log"
  else
    sub=(exec); [ "$turn" = 2 ] && sub=(exec resume --last)
    docker exec -w /home/dev/ws "$c" timeout 1800 codex "${sub[@]}" --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox \
      -m "$CODEX_MODEL" -c "model_reasoning_effort=\"$CODEX_EFFORT\"" --json "$msg" \
      < /dev/null >> "$OUT/transcript.jsonl" 2>> "$OUT/stderr.log"
  fi
  echo "turn$turn exit=$? seconds=$(( $(date +%s) - start ))" >> "$OUT/agent.status"
  echo '{"type":"eval.turn_end","turn":'"$turn"'}' >> "$OUT/transcript.jsonl"
done
as_root rm -f /home/dev/.codex/auth.json

# Evidence: per-repo git state, then the hidden checks.
docker exec "$c" bash -c 'cd /home/dev/ws; for g in $(find . -name .git -maxdepth 3 -prune | sort); do r=${g%/.git}; echo "=== $r"; git -C "$r" status --short --branch; git -C "$r" branch -a --format="%(refname:short) %(objectname:short)"; git -C "$r" log --oneline -5 --all; git -C "$r" stash list; git -C "$r" diff HEAD --stat; done' > "$OUT/git-state.txt" 2>&1
# Full change since baseline: commits, uncommitted edits and new files (intent-to-add only inside the throwaway container).
docker cp "$OUT/base-shas.txt" "$c:/tmp/base-shas.txt" > /dev/null
docker exec "$c" bash -c 'cd /home/dev/ws; while read -r r sha; do git -C "$r" add -A -N . 2>/dev/null; git -C "$r" diff "$sha" | sed "s|^|$r: |"; done < /tmp/base-shas.txt' > "$OUT/diff.txt" 2>&1
put "$F/check.py" /tmp/check.py
if docker exec "$c" timeout 300 python3 /tmp/check.py /home/dev/ws > "$OUT/check.json" 2> "$OUT/check.err" && python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert isinstance(d, list) and d and all("pass" in c for c in d)' "$OUT/check.json" 2>> "$OUT/check.err"; then
  echo "$OUT $(tr '\n' ' ' < "$OUT/agent.status")"
else
  rm -f "$OUT/check.json"; echo "check failed: $OUT"; exit 1   # no check.json, so matrix.sh retries the run
fi
