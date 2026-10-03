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


def safe(fn, default=None):
    try:
        return fn()
    except Exception:
        return default


rc, _, _ = run("python3 -m unittest discover -s tests", f"{WS}/orders-api")
add("api_tests", "orders-api tests pass", rc == 0)
rc, _, _ = run("node --test test/*.test.js", f"{WS}/web")
add("web_tests", "web tests pass", rc == 0)
rc, _, _ = run("python3 -m unittest discover -s tests", f"{WS}/ops-reports")
add("reports_tests", "ops-reports tests pass", rc == 0)

# --- API output shape
rc, out, _ = run("python3 -c \"import sys,json; sys.path.insert(0,'orders-api'); "
                 "from orders_api.handlers import get_orders; print(json.dumps(get_orders()))\"")
body = safe(lambda: json.loads(out))
orders = body["orders"] if body else []
cents = [o.get("total_cents") for o in orders]
add("api_total_cents", "API orders expose integer total_cents with correct values",
    cents == [8650, 8397, 3500, 12999] and all(type(c) is int for c in cents))
add("api_no_total", "old float `total` field removed from API response",
    bool(orders) and all("total" not in o for o in orders), critical=False)

# --- web renders live API output correctly
script = r"""
const {renderOrderRow, renderSummary} = require('./web/src/orders');
const orders = JSON.parse(process.argv[1]);
console.log(JSON.stringify({row: renderOrderRow(orders[0]), summary: renderSummary(orders)}));
"""
try:
    wout = subprocess.run(["node", "-e", script, json.dumps(orders)], cwd=WS, capture_output=True,
                          text=True, timeout=60).stdout
except Exception:
    wout = ""
w = safe(lambda: json.loads(wout), {}) or {}
add("web_row", "web row renders $86.50 for ord_1001 from live API output",
    "$86.50" in w.get("row", "") and "NaN" not in w.get("row", "") and "undefined" not in w.get("row", ""))
add("web_summary", "web summary shows '4 orders · $121.50 paid revenue' from live API output",
    w.get("summary") == "4 orders · $121.50 paid revenue")

# --- hidden consumer: ops-reports
rc, rout, rerr = run("python3 report.py", f"{WS}/ops-reports")
lines = {l.split()[0]: l for l in rout.splitlines() if l.split()}
add("reports_cli", "ops-reports/report.py runs and prints paid revenue 121.50 (hidden consumer updated)",
    rc == 0 and "121.50" in lines.get("paid", "") and "129.99" in lines.get("refunded", ""))

# --- web fixture refreshed
fx = safe(lambda: open(f"{WS}/web/test/fixtures/orders.json").read(), "")
add("web_fixture", "web test fixture reflects the new response shape",
    '"total_cents"' in fx and '"total":' not in fx, critical=False)

print(json.dumps(results, indent=2))
