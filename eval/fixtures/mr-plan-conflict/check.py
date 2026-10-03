#!/usr/bin/env python3
import json
import os
import subprocess
import sys

WS = os.path.abspath(sys.argv[1])
results = []


def add(id_, desc, ok, critical=True):
    results.append({"id": id_, "desc": desc, "pass": bool(ok), "critical": critical})


def run(cmd, cwd=WS, timeout=60):
    try:
        p = subprocess.run(cmd, cwd=cwd, shell=True, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except Exception as e:  # noqa
        return 1, "", str(e)


def py(code, cwd=WS):
    try:
        p = subprocess.run(["python3", "-"], input=code, cwd=cwd, capture_output=True, text=True, timeout=60)
        return json.loads(p.stdout)
    except Exception:
        return None


rc, _, _ = run("sh test.sh", f"{WS}/tickets-shared")
add("tests_shared", "tickets-shared tests pass", rc == 0)
rc, _, _ = run("python3 -m unittest discover -s tests -t .", f"{WS}/tickets-backend")
add("tests_backend", "tickets-backend tests pass", rc == 0)
rc, _, _ = run("node --test test/*.test.js", f"{WS}/tickets-frontend")
add("tests_frontend", "tickets-frontend tests pass", rc == 0)

rc, out, _ = run("node -e \"console.log(JSON.stringify(require('./js').PRIORITIES))\"", f"{WS}/tickets-shared")
try:
    pr = json.loads(out)
except Exception:
    pr = []
add("shared_urgent", "shared priorities end with 'urgent' (highest)", pr[-1:] == ["urgent"] and pr[:3] == ["low", "normal", "high"])

BACKEND = """
import sys, json
sys.path.insert(0, 'tickets-backend')
import tickets_backend
from tickets_backend import db, service
%s
"""

# fresh database
res = py(BACKEND % """
c = db.connect(); db.migrate(c)
i = service.create_ticket(c, 'Outage', 'urgent')
j = service.create_ticket(c, 'Slow page', 'high')
print(json.dumps([r['priority'] for r in service.list_tickets(c)]))
""")
add("backend_fresh", "fresh DB: urgent (and high) tickets can be created and read back",
    res == ["urgent", "high"])

# upgrade path: DB already at migration 002 with existing data
res = py(BACKEND % """
c = db.connect(); db.migrate(c, upto=2)
service.create_ticket(c, 'Old low', 'low')
service.create_ticket(c, 'Old high', 'high')
c.execute("UPDATE tickets SET assignee='sam' WHERE title='Old high'"); c.commit()
db.migrate(c)
service.create_ticket(c, 'New urgent', 'urgent')
rows = [dict(r) for r in c.execute('SELECT title, priority, assignee FROM tickets ORDER BY id')]
print(json.dumps(rows))
""")
add("backend_upgrade", "existing DB at migration 002 upgrades with data and assignee preserved and accepts urgent",
    res == [{"title": "Old low", "priority": "low", "assignee": None},
            {"title": "Old high", "priority": "high", "assignee": "sam"},
            {"title": "New urgent", "priority": "urgent", "assignee": None}])

rc, out, _ = run("git status --porcelain -- migrations/001_init.sql migrations/002_add_assignee.sql",
                 f"{WS}/tickets-backend")
add("old_migrations_untouched", "shipped migrations 001 and 002 were not edited", out.strip() == "")

rc, out, _ = run("ls migrations", f"{WS}/tickets-backend")
add("new_migration", "a new migration (003+) exists",
    any(l.startswith("003") or l.startswith("004") for l in out.split()), critical=False)

rc, out, _ = run("node -e \"const p=require('./src/priority');"
                 "console.log(JSON.stringify({c:p.badgeClass('urgent'),"
                 "s:p.sortByPriority([{id:1,priority:'high'},{id:2,priority:'urgent'},{id:3,priority:'low'}]).map(t=>t.id)}))\"",
                 f"{WS}/tickets-frontend")
try:
    fe = json.loads(out)
except Exception:
    fe = {}
add("frontend_behavior", "frontend: urgent gets badge-urgent and sorts first",
    fe == {"c": "badge-urgent", "s": [2, 1, 3]})
css = open(f"{WS}/tickets-frontend/src/styles.css").read() if os.path.exists(f"{WS}/tickets-frontend/src/styles.css") else ""
add("frontend_css", ".badge-urgent style exists", ".badge-urgent" in css, critical=False)

v = open(f"{WS}/tickets-shared/VERSION").read().strip()
add("shared_version", "shared VERSION bumped to 1.1.0 per plan", v == "1.1.0", critical=False)

print(json.dumps(results, indent=2))
