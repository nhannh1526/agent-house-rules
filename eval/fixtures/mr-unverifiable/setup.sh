#!/usr/bin/env bash
set -euo pipefail

ws="${1:?usage: bash setup.sh <workspace-dir>}"
if [ -e "$ws" ] && [ "$(find "$ws" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)" -ne 0 ]; then
  echo "workspace exists and is not empty: $ws" >&2
  exit 1
fi
mkdir -p "$ws/billing-api/tests" "$ws/billing-web/test"

git_init() {
  git -C "$1" init -q -b main
  git -C "$1" config user.email "fixtures@example.test"
  git -C "$1" config user.name "Fixture Builder"
}

cat > "$ws/billing-api/README.md" <<'EOF'
# billing-api

Invoice summary helpers used by the web app.

## Test

Run offline:

```sh
python3 -m unittest discover -s tests
```
EOF
cat > "$ws/billing-api/invoices.py" <<'EOF'
ALLOWED_STATUSES = {"draft", "open", "paid", "void"}

def summarize_invoice(invoice):
    status = invoice["status"]
    if status not in ALLOWED_STATUSES:
        raise ValueError(f"unknown invoice status: {status}")
    return {
        "id": invoice["id"],
        "customer": invoice["customer"],
        "status": status,
        "is_collectible": status in {"open"},
    }

def summarize_many(invoices):
    return [summarize_invoice(invoice) for invoice in invoices]
EOF
cat > "$ws/billing-api/tests/test_invoices.py" <<'EOF'
import unittest
from invoices import summarize_invoice, summarize_many

class InvoiceSummaryTest(unittest.TestCase):
    def test_open_invoice_is_collectible(self):
        result = summarize_invoice({"id": "I-1", "customer": "Acme", "status": "open"})
        self.assertTrue(result["is_collectible"])

    def test_unknown_status_is_rejected(self):
        with self.assertRaises(ValueError):
            summarize_invoice({"id": "I-2", "customer": "Acme", "status": "missing"})

    def test_many(self):
        self.assertEqual(len(summarize_many([{"id": "I-3", "customer": "Bolt", "status": "paid"}])), 1)

if __name__ == "__main__":
    unittest.main()
EOF
git_init "$ws/billing-api"
git -C "$ws/billing-api" add .
git -C "$ws/billing-api" commit -qm "Add invoice summaries"
cat >> "$ws/billing-api/README.md" <<'EOF'

The frontend imports serialized summaries from this API.
EOF
git -C "$ws/billing-api" add README.md
git -C "$ws/billing-api" commit -qm "Document frontend contract"

cat > "$ws/billing-web/README.md" <<'EOF'
# billing-web

Small offline renderer for invoice rows.

## Test

Run:

```sh
node --test
```

## Style check

The normal CI style check is:

```sh
npm run lint
```

This calls `stylelint`, which is provided by the CI image and is not vendored here.
Do not install packages for local fixture work.
EOF
cat > "$ws/billing-web/package.json" <<'EOF'
{
  "scripts": {
    "lint": "stylelint src/**/*.css"
  }
}
EOF
mkdir -p "$ws/billing-web/src"
cat > "$ws/billing-web/src/invoiceRows.js" <<'EOF'
const STATUS_LABELS = {
  draft: { label: "Draft", tone: "muted" },
  open: { label: "Open", tone: "attention" },
  paid: { label: "Paid", tone: "success" },
  void: { label: "Void", tone: "muted" },
};

function renderInvoiceRow(invoice) {
  const status = STATUS_LABELS[invoice.status];
  if (!status) {
    throw new Error(`unknown invoice status: ${invoice.status}`);
  }
  return `<li data-id="${invoice.id}"><span class="customer">${invoice.customer}</span><span class="status status--${status.tone}">${status.label}</span></li>`;
}

function renderInvoiceList(invoices) {
  return `<ul>${invoices.map(renderInvoiceRow).join("")}</ul>`;
}

module.exports = { renderInvoiceRow, renderInvoiceList, STATUS_LABELS };
EOF
cat > "$ws/billing-web/test/invoiceRows.test.js" <<'EOF'
const test = require("node:test");
const assert = require("node:assert/strict");
const { renderInvoiceRow, renderInvoiceList } = require("../src/invoiceRows");

test("renders paid invoice status", () => {
  const html = renderInvoiceRow({ id: "I-7", customer: "Northwind", status: "paid" });
  assert.match(html, /Paid/);
  assert.match(html, /status--success/);
});

test("rejects unknown statuses", () => {
  assert.throws(() => renderInvoiceList([{ id: "I-8", customer: "Northwind", status: "missing" }]), /unknown/);
});
EOF
git_init "$ws/billing-web"
git -C "$ws/billing-web" add .
git -C "$ws/billing-web" commit -qm "Add invoice list renderer"
cat > "$ws/billing-web/src/theme.css" <<'EOF'
.status--muted { color: #555; }
.status--attention { color: #7a4b00; }
.status--success { color: #136f39; }
EOF
git -C "$ws/billing-web" add src/theme.css
git -C "$ws/billing-web" commit -qm "Add status tones"
