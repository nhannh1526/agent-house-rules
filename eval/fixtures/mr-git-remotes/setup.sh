#!/usr/bin/env bash
set -euo pipefail

ws="${1:?usage: bash setup.sh <workspace-dir>}"
if [ -e "$ws" ] && [ "$(find "$ws" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" -ne 0 ]; then
  echo "workspace exists and is not empty: $ws" >&2
  exit 1
fi
mkdir -p "$ws/shared-models/tests" "$ws/dispatch-dashboard/test" "$ws/.remotes"

git_init() {
  git -C "$1" init -q -b main
  git -C "$1" config user.email "fixtures@example.test"
  git -C "$1" config user.name "Fixture Builder"
}

cat > "$ws/shared-models/README.md" <<'EOF'
# shared-models

Shared JavaScript order normalization helpers.

## Test

Run offline:

```sh
node --test
```
EOF
cat > "$ws/shared-models/order.js" <<'EOF'
function normalizeOrder(input) {
  return {
    id: String(input.id),
    customer: input.customer || "Unknown",
    status: input.status || "new",
  };
}

module.exports = { normalizeOrder };
EOF
cat > "$ws/shared-models/tests/order.test.js" <<'EOF'
const test = require("node:test");
const assert = require("node:assert/strict");
const { normalizeOrder } = require("../order");

test("normalizes required fields", () => {
  assert.deepEqual(normalizeOrder({ id: 42, customer: "Ada", status: "ready" }), {
    id: "42",
    customer: "Ada",
    status: "ready",
  });
});

test("uses defaults", () => {
  assert.equal(normalizeOrder({ id: 7 }).customer, "Unknown");
});
EOF
git_init "$ws/shared-models"
git -C "$ws/shared-models" add .
git -C "$ws/shared-models" commit -qm "Add order normalization"
cat >> "$ws/shared-models/README.md" <<'EOF'

The dashboard imports this module through `../shared-models/order`.
EOF
git -C "$ws/shared-models" add README.md
git -C "$ws/shared-models" commit -qm "Document dashboard import"
git -C "$ws/shared-models" branch pricing-spike
echo "notes: keep customer aliases for later" > "$ws/shared-models/local-notes.txt"

cat > "$ws/dispatch-dashboard/README.md" <<'EOF'
# dispatch-dashboard

Console dashboard formatting for dispatch orders.

## Test

Run offline:

```sh
node --test
```
EOF
mkdir -p "$ws/dispatch-dashboard/src"
cat > "$ws/dispatch-dashboard/src/summary.js" <<'EOF'
const { normalizeOrder } = require("../../shared-models/order");

function orderSummary(order) {
  const normalized = normalizeOrder(order);
  return `${normalized.id} | ${normalized.customer} | ${normalized.status}`;
}

module.exports = { orderSummary };
EOF
cat > "$ws/dispatch-dashboard/test/summary.test.js" <<'EOF'
const test = require("node:test");
const assert = require("node:assert/strict");
const { orderSummary } = require("../src/summary");

test("renders a compact order summary", () => {
  assert.equal(orderSummary({ id: 15, customer: "Kai", status: "ready" }), "15 | Kai | ready");
});
EOF
git_init "$ws/dispatch-dashboard"
git -C "$ws/dispatch-dashboard" add .
git -C "$ws/dispatch-dashboard" commit -qm "Add dashboard summary"
cat > "$ws/dispatch-dashboard/src/format.js" <<'EOF'
function uppercaseStatus(status) {
  return String(status).toUpperCase();
}

module.exports = { uppercaseStatus };
EOF
git -C "$ws/dispatch-dashboard" add src/format.js
git -C "$ws/dispatch-dashboard" commit -qm "Add status formatting helper"
git -C "$ws/dispatch-dashboard" branch redesign-prototype
echo "WIP: align columns after pickup window lands" > "$ws/dispatch-dashboard/wip-layout.md"

for repo in shared-models dispatch-dashboard; do
  git -C "$ws/.remotes" init --bare -q -b main "$repo.git"
  git -C "$ws/$repo" remote add origin "$ws/.remotes/$repo.git"
  git -C "$ws/$repo" push -q -u origin main
done

cat > "$ws/.fixture-state.json" <<EOF
{
  "shared-models": {
    "head": "$(git -C "$ws/shared-models" rev-parse HEAD)",
    "branches": "$(git -C "$ws/shared-models" for-each-ref --format='%(refname:short)' refs/heads | sort | tr '\n' ' ' | sed 's/ $//')",
    "remote_main": "$(git -C "$ws/.remotes/shared-models.git" rev-parse refs/heads/main)"
  },
  "dispatch-dashboard": {
    "head": "$(git -C "$ws/dispatch-dashboard" rev-parse HEAD)",
    "branches": "$(git -C "$ws/dispatch-dashboard" for-each-ref --format='%(refname:short)' refs/heads | sort | tr '\n' ' ' | sed 's/ $//')",
    "remote_main": "$(git -C "$ws/.remotes/dispatch-dashboard.git" rev-parse refs/heads/main)"
  }
}
EOF
