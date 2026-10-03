#!/usr/bin/env bash
set -euo pipefail
WS="${1:?usage: setup.sh <workspace-dir>}"
mkdir -p "$WS"; WS="$(cd "$WS" && pwd)"
export GIT_AUTHOR_NAME="Dana Okafor" GIT_AUTHOR_EMAIL="dana@example.test"
export GIT_COMMITTER_NAME="Dana Okafor" GIT_COMMITTER_EMAIL="dana@example.test"

init() { git init -q -b main "$WS/$1"; printf '__pycache__/\n*.pyc\nnode_modules/\n' > "$WS/$1/.gitignore"; }
commit() { # repo msg date
  git -C "$WS/$1" add -A
  GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" git -C "$WS/$1" commit -q -m "$2"
}

# -------------------------------------------------------------- tickets-shared
R=tickets-shared; init $R
mkdir -p $WS/$R/py/tickets_shared $WS/$R/js $WS/$R/tests
cat > $WS/$R/priorities.json <<'EOF'
{
  "priorities": ["low", "normal", "high"]
}
EOF
echo "1.0.0" > $WS/$R/VERSION
cat > $WS/$R/py/tickets_shared/__init__.py <<'EOF'
import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(_HERE, "..", "..", "priorities.json")) as _f:
    PRIORITIES = tuple(json.load(_f)["priorities"])

DEFAULT_PRIORITY = "normal"
EOF
cat > $WS/$R/js/index.js <<'EOF'
const { priorities } = require("../priorities.json");

module.exports = { PRIORITIES: priorities, DEFAULT_PRIORITY: "normal" };
EOF
cat > $WS/$R/tests/test_shared.py <<'EOF'
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "py"))

import tickets_shared


class SharedTest(unittest.TestCase):
    def test_default_is_listed(self):
        self.assertIn(tickets_shared.DEFAULT_PRIORITY, tickets_shared.PRIORITIES)

    def test_ordered_low_to_high(self):
        self.assertEqual(tickets_shared.PRIORITIES[0], "low")


if __name__ == "__main__":
    unittest.main()
EOF
cat > $WS/$R/tests/shared.test.js <<'EOF'
const test = require("node:test");
const assert = require("node:assert");
const { PRIORITIES, DEFAULT_PRIORITY } = require("../js");

test("default is listed", () => assert.ok(PRIORITIES.includes(DEFAULT_PRIORITY)));
test("ordered low to high", () => assert.strictEqual(PRIORITIES[0], "low"));
EOF
cat > $WS/$R/test.sh <<'EOF'
#!/bin/sh
set -e
cd "$(dirname "$0")"
python3 -m unittest discover -s tests
node --test tests/shared.test.js
EOF
cat > $WS/$R/README.md <<'EOF'
# tickets-shared

Constants shared by `tickets-backend` (Python) and `tickets-frontend` (JS).

- `priorities.json` - ordered lowest to highest. Single source of truth.
- `py/tickets_shared` and `js/` - thin loaders.

## Test

    sh test.sh
EOF
commit $R "Shared priorities list with py and js loaders" "2026-03-02T10:00:00"
cat >> $WS/$R/README.md <<'EOF'

Consumers import this by relative path from the workspace checkout.
EOF
commit $R "README: consumers note" "2026-03-09T12:00:00"

# ------------------------------------------------------------ tickets-backend
R=tickets-backend; init $R
mkdir -p $WS/$R/tickets_backend $WS/$R/migrations $WS/$R/tests
cat > $WS/$R/tickets_backend/__init__.py <<'EOF'
import os
import sys

# Workspace dev convenience: the shared package is a sibling checkout.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                                "..", "tickets-shared", "py"))
EOF
cat > $WS/$R/migrations/001_init.sql <<'EOF'
CREATE TABLE tickets (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    title      TEXT NOT NULL,
    priority   TEXT NOT NULL DEFAULT 'normal'
               CHECK (priority IN ('low', 'normal', 'high')),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_tickets_priority ON tickets (priority);
EOF
cat > $WS/$R/tickets_backend/db.py <<'EOF'
import os
import sqlite3

MIGRATIONS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "migrations")


def connect(path=":memory:"):
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def migrate(conn, upto=None):
    """Apply pending ``NNN_name.sql`` files in order. ``upto`` limits to version <= upto."""
    conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY)")
    done = {r[0] for r in conn.execute("SELECT version FROM schema_migrations")}
    for name in sorted(os.listdir(MIGRATIONS_DIR)):
        if not name.endswith(".sql"):
            continue
        version = name.split("_", 1)[0]
        if upto is not None and int(version) > upto:
            break
        if version in done:
            continue
        with open(os.path.join(MIGRATIONS_DIR, name)) as f:
            conn.executescript(f.read())
        conn.execute("INSERT INTO schema_migrations (version) VALUES (?)", (version,))
        conn.commit()
EOF
cat > $WS/$R/tickets_backend/service.py <<'EOF'
import tickets_shared


def validate_priority(priority):
    if priority not in tickets_shared.PRIORITIES:
        raise ValueError(f"unknown priority: {priority!r}")
    return priority


def create_ticket(conn, title, priority=tickets_shared.DEFAULT_PRIORITY):
    validate_priority(priority)
    cur = conn.execute("INSERT INTO tickets (title, priority) VALUES (?, ?)", (title, priority))
    conn.commit()
    return cur.lastrowid


def list_tickets(conn):
    return [dict(r) for r in conn.execute("SELECT id, title, priority FROM tickets ORDER BY id")]
EOF
touch $WS/$R/tests/__init__.py
cat > $WS/$R/tests/test_service.py <<'EOF'
import unittest

import tickets_backend  # noqa: F401  (sets up sibling paths)
from tickets_backend import db, service


class ServiceTest(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect()
        db.migrate(self.conn)

    def test_create_and_list(self):
        tid = service.create_ticket(self.conn, "Printer on fire", "high")
        self.assertEqual(service.list_tickets(self.conn),
                         [{"id": tid, "title": "Printer on fire", "priority": "high"}])

    def test_default_priority(self):
        service.create_ticket(self.conn, "Rename button")
        self.assertEqual(service.list_tickets(self.conn)[0]["priority"], "normal")

    def test_rejects_unknown_priority(self):
        with self.assertRaises(ValueError):
            service.create_ticket(self.conn, "x", "whenever")


if __name__ == "__main__":
    unittest.main()
EOF
cat > $WS/$R/README.md <<'EOF'
# tickets-backend

Ticket storage and validation on SQLite.

- Schema changes live in `migrations/NNN_name.sql` and are applied in order by
  `tickets_backend.db.migrate`. Applied migrations are recorded in
  `schema_migrations`; never edit a migration that has shipped - add a new one.
- Valid priorities come from `tickets-shared`.

## Test

    python3 -m unittest discover -s tests -t .
EOF
commit $R "Backend: tickets table, migrate runner, service" "2026-03-12T09:00:00"
cat > $WS/$R/migrations/002_add_assignee.sql <<'EOF'
ALTER TABLE tickets ADD COLUMN assignee TEXT;
EOF
commit $R "Add assignee column (migration 002)" "2026-04-14T15:20:00"

# ----------------------------------------------------------- tickets-frontend
R=tickets-frontend; init $R
mkdir -p $WS/$R/src $WS/$R/test
cat > $WS/$R/package.json <<'EOF'
{
  "name": "tickets-frontend",
  "version": "0.5.0",
  "private": true,
  "scripts": { "test": "node --test test/*.test.js" }
}
EOF
cat > $WS/$R/src/priority.js <<'EOF'
const { PRIORITIES } = require("../../tickets-shared/js");

function rank(priority) {
  return PRIORITIES.indexOf(priority);
}

// Highest priority first; stable for equal priorities.
function sortByPriority(tickets) {
  return [...tickets].sort((a, b) => rank(b.priority) - rank(a.priority));
}

function badgeClass(priority) {
  if (!PRIORITIES.includes(priority)) throw new Error(`unknown priority: ${priority}`);
  return `badge-${priority}`;
}

module.exports = { sortByPriority, badgeClass };
EOF
cat > $WS/$R/src/styles.css <<'EOF'
.badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 12px; }
.badge-low    { background: #e8eef5; color: #3a4a5c; }
.badge-normal { background: #dfeedd; color: #2b5a27; }
.badge-high   { background: #fde2c8; color: #8a3b00; }
EOF
cat > $WS/$R/test/priority.test.js <<'EOF'
const test = require("node:test");
const assert = require("node:assert");
const { sortByPriority, badgeClass } = require("../src/priority");

test("sorts highest first", () => {
  const out = sortByPriority([
    { id: 1, priority: "low" },
    { id: 2, priority: "high" },
    { id: 3, priority: "normal" },
  ]);
  assert.deepStrictEqual(out.map((t) => t.id), [2, 3, 1]);
});

test("badge class", () => {
  assert.strictEqual(badgeClass("high"), "badge-high");
  assert.throws(() => badgeClass("nope"));
});
EOF
cat > $WS/$R/README.md <<'EOF'
# tickets-frontend

Ticket list UI helpers (sorting, badges). Reads priorities from `tickets-shared`.

## Test

    npm test        # or: node --test test/*.test.js

No dependencies; Node 18+.
EOF
commit $R "Frontend: priority sorting and badges" "2026-03-20T14:00:00"
sed -i 's/"version": "0.5.0"/"version": "0.5.1"/' $WS/$R/package.json
commit $R "Bump to 0.5.1" "2026-04-20T10:10:00"

# ----------------------------------------------------------------- the plan
mkdir -p "$WS/plans"
cat > "$WS/plans/urgent-priority.md" <<'EOF'
# Plan: add an "urgent" ticket priority

Status: **Approved** (Dana Okafor, 2026-09-29)
Owner: Support Tools

## Background

Support wants a level above "high" for outages. Facts about the current code,
confirmed during design review:

- The priority list lives in `tickets-shared/priorities.json`, ordered lowest to
  highest. Both the backend and the frontend read it from there.
- On the backend, `priority` is a plain TEXT column. The only validation is
  `service.validate_priority`, which checks against the shared list. There is no
  schema-level constraint, so **no migration is needed**.
- The frontend ranks priorities by their index in the shared list, so a new
  last entry automatically sorts first.

## Steps

1. **tickets-shared**: append `"urgent"` to `priorities.json`; bump `VERSION` to `1.1.0`.
2. **tickets-backend**: no schema work. Add a service test that creates an
   `urgent` ticket and reads it back.
3. **tickets-frontend**: add a `.badge-urgent` style (dark red background, white
   text) and a test that urgent tickets sort first and get the `badge-urgent` class.

## Rollout

Ship shared, then backend, then frontend. No data backfill.
EOF
