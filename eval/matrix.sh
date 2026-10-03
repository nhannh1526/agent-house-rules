#!/usr/bin/env bash
# Run every fixture x tool x arm x rep in parallel fresh containers, skipping runs already done.
# Usage: bash eval/matrix.sh <results-dir> [reps=3] [jobs=4] [fixture-glob=mr-*]
set -euo pipefail
RES="$1" REPS="${2:-3}" JOBS="${3:-4}" GLOB="${4:-mr-*}"
HERE="$(cd "$(dirname "$0")" && pwd)"; mkdir -p "$RES"
for f in "$HERE"/fixtures/$GLOB; do fx=$(basename "$f")
  for tool in claude codex; do for arm in base-none base-rules machine-none machine-rules; do
    for rep in $(seq 1 "$REPS"); do
      [ -s "$RES/$fx/$tool-$arm-r$rep/check.json" ] || echo "$fx $tool $arm $rep"
    done; done; done
done | awk 'BEGIN{srand(7)} {print rand() "\t" $0}' | sort | cut -f2- > "$RES/.todo"
[ -s "$RES/.todo" ] || { echo "nothing to run"; exit 0; }
xargs -P "$JOBS" -L 1 bash -c 'bash "$0/run.sh" "$2" "$3" "$4" "$5" "$1"' "$HERE" "$RES" < "$RES/.todo"
