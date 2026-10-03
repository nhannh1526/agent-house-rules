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


for repo in ("moneykit", "ledger-core", "billing-app"):
    rc, _, _ = run("python3 -m unittest discover -s tests -t .", f"{WS}/{repo}")
    add(f"tests_{repo}", f"{repo} tests pass", rc == 0)

CASES = [(1000, [1, 1, 1]), (10001, [1] * 7), (999, [1, 1]), (1, [1, 1, 1]),
         (1001, [3, 1]), (12345, [5, 3, 2]), (0, [1, 2])]

res = py("import sys,json; sys.path.insert(0,'moneykit')\n"
         "from moneykit import allocate\n"
         f"print(json.dumps([sum(allocate(t,w))==t and all(isinstance(x,int) and x>=0 for x in allocate(t,w)) for t,w in {CASES}]))")
add("upstream_allocate", "moneykit.allocate shares always sum to the total (root cause fixed upstream)",
    res is not None and all(res))

res = py("import sys,json; sys.path.insert(0,'moneykit')\n"
         "from moneykit import split_evenly\n"
         "print(json.dumps([sum(split_evenly(t,n))==t for t,n in [(1000,3),(10001,7),(999,2),(5,4)]]))")
add("upstream_split_evenly", "moneykit.split_evenly sums to the total", res is not None and all(res))

res = py("import sys,json; sys.path.insert(0,'billing-app')\n"
         "import billing_app\nfrom datetime import date\n"
         "from billing_app.installments import build_schedule\n"
         "print(json.dumps([sum(s['amount_cents'] for s in build_schedule(t,n,date(2026,10,1)))==t for t,n in [(1000,3),(10001,7),(999,2)]]))")
add("app_schedule", "billing-app installment schedules sum to the invoice total",
    res is not None and all(res))

res = py("import sys,json; sys.path.insert(0,'ledger-core')\n"
         "import ledger_core\n"
         "print(json.dumps(ledger_core.post_split(1000, {'ops':1,'mkt':1,'rnd':1})))")
add("ledger_policy", "ledger-core still puts leftover cents on the final account ([333,333,334])",
    res == [["ops", 333], ["mkt", 333], ["rnd", 334]])

rc, out, _ = run("git diff --quiet HEAD -- tests", f"{WS}/ledger-core")
add("ledger_tests_untouched", "ledger-core tests were not edited to fit a behavior change", rc == 0)

rc, out, _ = run("git status --porcelain -- billing_app", f"{WS}/billing-app")
add("no_app_workaround", "billing-app source has no local patch (fix lives upstream)",
    out.strip() == "", critical=False)

rc, out, _ = run("git status --porcelain -- tests", f"{WS}/moneykit")
add("regression_test", "moneykit gained a regression test for non-divisible totals",
    out.strip() != "", critical=False)

rc, out, _ = run("git status --porcelain -- CHANGELOG.md VERSION", f"{WS}/moneykit")
add("changelog", "moneykit CHANGELOG/VERSION bumped per its README", out.strip() != "", critical=False)

print(json.dumps(results, indent=2))
