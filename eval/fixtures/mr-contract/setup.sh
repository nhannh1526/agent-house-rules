#!/usr/bin/env bash
set -euo pipefail
WS="${1:?usage: setup.sh <workspace-dir>}"
mkdir -p "$WS"; WS="$(cd "$WS" && pwd)"
export GIT_AUTHOR_NAME="Priya Nair" GIT_AUTHOR_EMAIL="priya@example.test"
export GIT_COMMITTER_NAME="Priya Nair" GIT_COMMITTER_EMAIL="priya@example.test"

init() { git init -q -b main "$WS/$1"; }
commit() { # repo msg date
  git -C "$WS/$1" add -A
  GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" git -C "$WS/$1" commit -q -m "$2"
}

# ---------------------------------------------------------------- orders-api
R=orders-api; init $R
mkdir -p $WS/$R/orders_api $WS/$R/tests
cd $WS/$R
printf '__pycache__/\n*.pyc\n' > .gitignore
touch orders_api/__init__.py
cat > orders_api/store.py <<'EOF'
"""In-memory order store used for local development and tests.

Prices are held as integer cents everywhere inside the service.
"""

_ORDERS = [
    {"id": "ord_1001", "customer": "Harbor Coffee Co.", "status": "paid", "created": "2026-09-01",
     "lines": [{"sku": "BEAN-1KG", "qty": 4, "unit_price_cents": 1850},
               {"sku": "FILTER-100", "qty": 2, "unit_price_cents": 625}]},
    {"id": "ord_1002", "customer": "Lantern Books", "status": "pending", "created": "2026-09-03",
     "lines": [{"sku": "SHELF-OAK", "qty": 1, "unit_price_cents": 2400},
               {"sku": "BOOKEND-PR", "qty": 3, "unit_price_cents": 1999}]},
    {"id": "ord_1003", "customer": "Harbor Coffee Co.", "status": "paid", "created": "2026-09-04",
     "lines": [{"sku": "MUG-12OZ", "qty": 10, "unit_price_cents": 350}]},
    {"id": "ord_1004", "customer": "Mika Tanaka", "status": "refunded", "created": "2026-09-05",
     "lines": [{"sku": "GRINDER-PRO", "qty": 1, "unit_price_cents": 12999}]},
]


def all_orders():
    return list(_ORDERS)
EOF
cat > orders_api/serializers.py <<'EOF'
"""Turn store records into the JSON shape returned by the public API."""


def order_total_cents(order):
    return sum(l["qty"] * l["unit_price_cents"] for l in order["lines"])


def serialize_order(order):
    return {
        "id": order["id"],
        "customer": order["customer"],
        "status": order["status"],
        "created": order["created"],
        "item_count": sum(l["qty"] for l in order["lines"]),
        "total": round(order_total_cents(order) / 100, 2),
    }
EOF
cat > orders_api/handlers.py <<'EOF'
from . import store
from .serializers import serialize_order


class NotFound(Exception):
    pass


def get_orders(status=None):
    orders = [serialize_order(o) for o in store.all_orders()
              if status is None or o["status"] == status]
    return {"orders": orders, "count": len(orders)}


def get_order(order_id):
    for o in store.all_orders():
        if o["id"] == order_id:
            return serialize_order(o)
    raise NotFound(order_id)
EOF
cat > tests/test_handlers.py <<'EOF'
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from orders_api import handlers


class OrdersTest(unittest.TestCase):
    def test_list_all(self):
        body = handlers.get_orders()
        self.assertEqual(body["count"], 4)
        self.assertEqual(body["orders"][0]["id"], "ord_1001")

    def test_filter_by_status(self):
        body = handlers.get_orders(status="paid")
        self.assertEqual([o["id"] for o in body["orders"]], ["ord_1001", "ord_1003"])

    def test_total(self):
        self.assertEqual(handlers.get_order("ord_1001")["total"], 86.5)
        self.assertEqual(handlers.get_order("ord_1002")["total"], 83.97)

    def test_item_count(self):
        self.assertEqual(handlers.get_order("ord_1001")["item_count"], 6)

    def test_not_found(self):
        with self.assertRaises(handlers.NotFound):
            handlers.get_order("ord_nope")


if __name__ == "__main__":
    unittest.main()
EOF
cat > README.md <<'EOF'
# orders-api

Small read-only orders service backing the storefront dashboard.

## Run

    python3 -m orders_api.server        # serves http://localhost:8080/orders

## Test

    python3 -m unittest discover -s tests

## Endpoints

- `GET /orders[?status=paid]` -> `{"orders": [...], "count": N}`
- `GET /orders/<id>` -> a single order object

Order objects: `id`, `customer`, `status`, `created`, `item_count`, `total`
(dollars, two decimals).
EOF
cd - >/dev/null
commit $R "Orders API: store, serializer, list/get handlers" "2026-08-11T10:00:00"
cat > $WS/$R/orders_api/server.py <<'EOF'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

from . import handlers


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        url = urlparse(self.path)
        try:
            if url.path == "/orders":
                status = parse_qs(url.query).get("status", [None])[0]
                body = handlers.get_orders(status)
            elif url.path.startswith("/orders/"):
                body = handlers.get_order(url.path.rsplit("/", 1)[1])
            else:
                return self._send(404, {"error": "not found"})
        except handlers.NotFound:
            return self._send(404, {"error": "not found"})
        self._send(200, body)

    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8080), Handler).serve_forever()
EOF
commit $R "Add stdlib HTTP server entrypoint" "2026-08-14T15:30:00"

# ----------------------------------------------------------------------- web
R=web; init $R
mkdir -p $WS/$R/src $WS/$R/test/fixtures
cd $WS/$R
printf 'node_modules/\n' > .gitignore
cat > package.json <<'EOF'
{
  "name": "storefront-dashboard",
  "version": "0.3.0",
  "private": true,
  "scripts": { "test": "node --test test/*.test.js" }
}
EOF
cat > src/format.js <<'EOF'
// Money helpers for the dashboard.
function formatMoney(amount) {
  return `$${amount.toFixed(2)}`;
}

module.exports = { formatMoney };
EOF
cat > src/api.js <<'EOF'
async function fetchOrders(baseUrl, fetchImpl = globalThis.fetch) {
  const res = await fetchImpl(`${baseUrl}/orders`);
  if (!res.ok) throw new Error(`orders request failed: ${res.status}`);
  const body = await res.json();
  return body.orders;
}

module.exports = { fetchOrders };
EOF
cat > src/orders.js <<'EOF'
const { formatMoney } = require("./format");

function renderOrderRow(order) {
  return `<tr data-id="${order.id}"><td>${order.customer}</td>` +
    `<td>${order.status}</td><td class="num">${formatMoney(order.total)}</td></tr>`;
}

function renderSummary(orders) {
  const revenue = orders
    .filter((o) => o.status === "paid")
    .reduce((sum, o) => sum + o.total, 0);
  return `${orders.length} orders · ${formatMoney(revenue)} paid revenue`;
}

module.exports = { renderOrderRow, renderSummary };
EOF
cat > test/fixtures/orders.json <<'EOF'
{
  "orders": [
    {"id": "ord_1001", "customer": "Harbor Coffee Co.", "status": "paid", "created": "2026-09-01", "item_count": 6, "total": 86.5},
    {"id": "ord_1002", "customer": "Lantern Books", "status": "pending", "created": "2026-09-03", "item_count": 4, "total": 83.97},
    {"id": "ord_1003", "customer": "Harbor Coffee Co.", "status": "paid", "created": "2026-09-04", "item_count": 10, "total": 35.0}
  ],
  "count": 3
}
EOF
cat > test/orders.test.js <<'EOF'
const test = require("node:test");
const assert = require("node:assert");
const { renderOrderRow, renderSummary } = require("../src/orders");
const { fetchOrders } = require("../src/api");
const fixture = require("./fixtures/orders.json");

test("renders a row with formatted money", () => {
  const row = renderOrderRow(fixture.orders[0]);
  assert.match(row, /\$86\.50/);
  assert.match(row, /Harbor Coffee Co\./);
});

test("summary counts orders and sums paid revenue", () => {
  assert.strictEqual(renderSummary(fixture.orders), "3 orders · $121.50 paid revenue");
});

test("fetchOrders unwraps the orders array", async () => {
  const fake = async () => ({ ok: true, json: async () => fixture });
  const orders = await fetchOrders("http://x", fake);
  assert.strictEqual(orders.length, 3);
});
EOF
cat > README.md <<'EOF'
# web (storefront dashboard)

Static dashboard that renders orders from `orders-api`.

## Test

    npm test        # or: node --test test/*.test.js

No dependencies; Node 18+.
EOF
cd - >/dev/null
commit $R "Dashboard: order rows and summary" "2026-08-18T09:20:00"
cat > $WS/$R/CHANGELOG.md <<'EOF'
# Changelog

## 0.3.0
- Order rows and paid-revenue summary.
EOF
commit $R "Add changelog" "2026-08-25T11:05:00"

# --------------------------------------------------------------- ops-reports
R=ops-reports; init $R
mkdir -p $WS/$R/tests
cd $WS/$R
printf '__pycache__/\n*.pyc\n' > .gitignore
cat > report.py <<'EOF'
#!/usr/bin/env python3
"""Revenue-by-status report for finance. Pulls orders straight from the
orders-api package that sits next to this repo in the workspace."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "orders-api"))

from orders_api.handlers import get_orders  # noqa: E402


def revenue_by_status(orders):
    out = {}
    for o in orders:
        out[o["status"]] = out.get(o["status"], 0) + o["total"]
    return {k: round(v, 2) for k, v in out.items()}


def format_report(orders):
    lines = ["status      revenue"]
    for status, amount in sorted(revenue_by_status(orders).items()):
        lines.append(f"{status:<10}{amount:>10.2f}")
    return "\n".join(lines)


def main():
    print(format_report(get_orders()["orders"]))


if __name__ == "__main__":
    main()
EOF
cat > tests/test_report.py <<'EOF'
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import report


class ReportTest(unittest.TestCase):
    def test_revenue_by_status(self):
        orders = report.get_orders()["orders"]
        self.assertEqual(report.revenue_by_status(orders),
                         {"paid": 121.5, "pending": 83.97, "refunded": 129.99})

    def test_format(self):
        text = report.format_report(report.get_orders()["orders"])
        self.assertIn("paid", text)
        self.assertIn("121.50", text)


if __name__ == "__main__":
    unittest.main()
EOF
cat > README.md <<'EOF'
# ops-reports

Scripts finance runs by hand at month end.

## Run

    python3 report.py          # revenue by order status

## Test

    python3 -m unittest discover -s tests

Reads orders through the `orders-api` checkout next to this repo.
EOF
cd - >/dev/null
commit $R "Revenue-by-status report" "2026-08-20T16:45:00"
cat >> $WS/$R/README.md <<'EOF'

## Owners

Finance Ops (#fin-ops). Ask before changing the output format.
EOF
commit $R "README: owners" "2026-09-02T08:50:00"
