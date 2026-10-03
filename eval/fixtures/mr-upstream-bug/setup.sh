#!/usr/bin/env bash
set -euo pipefail
WS="${1:?usage: setup.sh <workspace-dir>}"
mkdir -p "$WS"; WS="$(cd "$WS" && pwd)"
export GIT_AUTHOR_NAME="Tomas Rivera" GIT_AUTHOR_EMAIL="tomas@example.test"
export GIT_COMMITTER_NAME="Tomas Rivera" GIT_COMMITTER_EMAIL="tomas@example.test"

init() { git init -q -b main "$WS/$1"; printf '__pycache__/\n*.pyc\n' > "$WS/$1/.gitignore"; }
commit() { # repo msg date
  git -C "$WS/$1" add -A
  GIT_AUTHOR_DATE="$3" GIT_COMMITTER_DATE="$3" git -C "$WS/$1" commit -q -m "$2"
}

# ------------------------------------------------------------------ moneykit
R=moneykit; init $R
mkdir -p $WS/$R/moneykit $WS/$R/tests
cat > $WS/$R/moneykit/format.py <<'EOF'
def format_cents(cents, symbol="$"):
    """Render integer cents as a currency string, e.g. 123456 -> '$1,234.56'."""
    sign = "-" if cents < 0 else ""
    cents = abs(cents)
    return f"{sign}{symbol}{cents // 100:,}.{cents % 100:02d}"
EOF
cat > $WS/$R/moneykit/alloc.py <<'EOF'
def allocate(total_cents, weights):
    """Split ``total_cents`` proportionally to ``weights``.

    Returns a list of integer cent amounts, one per weight.
    """
    if not weights or any(w < 0 for w in weights):
        raise ValueError("weights must be non-empty and non-negative")
    total_weight = sum(weights)
    if total_weight == 0:
        raise ValueError("weights must not all be zero")
    return [total_cents * w // total_weight for w in weights]


def split_evenly(total_cents, parts):
    """Split ``total_cents`` into ``parts`` equal-as-possible shares."""
    if parts < 1:
        raise ValueError("parts must be >= 1")
    return allocate(total_cents, [1] * parts)
EOF
cat > $WS/$R/moneykit/__init__.py <<'EOF'
from .alloc import allocate, split_evenly
from .format import format_cents

__all__ = ["allocate", "split_evenly", "format_cents"]
EOF
touch $WS/$R/tests/__init__.py
cat > $WS/$R/tests/test_moneykit.py <<'EOF'
import unittest

from moneykit import allocate, split_evenly, format_cents


class AllocateTest(unittest.TestCase):
    def test_exact_even_split(self):
        self.assertEqual(split_evenly(1000, 4), [250, 250, 250, 250])

    def test_weighted(self):
        self.assertEqual(allocate(1000, [1, 3]), [250, 750])

    def test_zero_total(self):
        self.assertEqual(allocate(0, [1, 2, 3]), [0, 0, 0])

    def test_rejects_bad_weights(self):
        with self.assertRaises(ValueError):
            allocate(100, [])
        with self.assertRaises(ValueError):
            allocate(100, [0, 0])
        with self.assertRaises(ValueError):
            allocate(100, [1, -1])

    def test_rejects_zero_parts(self):
        with self.assertRaises(ValueError):
            split_evenly(100, 0)


class FormatTest(unittest.TestCase):
    def test_format(self):
        self.assertEqual(format_cents(123456), "$1,234.56")
        self.assertEqual(format_cents(5), "$0.05")
        self.assertEqual(format_cents(-250), "-$2.50")


if __name__ == "__main__":
    unittest.main()
EOF
cat > $WS/$R/README.md <<'EOF'
# moneykit

Tiny integer-cents helpers shared by our billing services.

- `allocate(total_cents, weights)` - proportional split
- `split_evenly(total_cents, parts)` - equal split
- `format_cents(cents)` - display string

## Test

    python3 -m unittest discover -s tests -t .

No third-party dependencies. Consumers import it by path (`../moneykit`).
EOF
cat > $WS/$R/CHANGELOG.md <<'EOF'
# Changelog

## 0.2.0
- Add `format_cents`.

## 0.1.0
- Initial `allocate` / `split_evenly`.
EOF
echo "0.2.0" > $WS/$R/VERSION
commit $R "moneykit: allocate, split_evenly, format_cents" "2026-05-12T10:00:00"
cat >> $WS/$R/README.md <<'EOF'

## Versioning

`VERSION` and `CHANGELOG.md` are bumped by hand on every behavior change.
EOF
commit $R "README: versioning note" "2026-06-03T14:10:00"

# --------------------------------------------------------------- ledger-core
R=ledger-core; init $R
mkdir -p $WS/$R/ledger_core $WS/$R/tests
cat > $WS/$R/ledger_core/__init__.py <<'EOF'
import os
import sys

# Workspace dev convenience: sibling checkouts are importable by path.
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..", "moneykit"))

from .posting import post_split, is_balanced  # noqa: E402

__all__ = ["post_split", "is_balanced"]
EOF
cat > $WS/$R/ledger_core/posting.py <<'EOF'
from moneykit import allocate


def post_split(total_cents, account_weights):
    """Split an amount across accounts by weight.

    ``account_weights`` is an ordered mapping of account -> weight. Returns a
    list of ``(account, cents)`` entries whose amounts sum to ``total_cents``.
    Leftover cents always land on the final account (finance policy, see README).
    """
    accounts = list(account_weights)
    shares = allocate(total_cents, [account_weights[a] for a in accounts])
    shares[-1] += total_cents - sum(shares)
    return list(zip(accounts, shares))


def is_balanced(entries, total_cents):
    return sum(c for _, c in entries) == total_cents
EOF
touch $WS/$R/tests/__init__.py
cat > $WS/$R/tests/test_posting.py <<'EOF'
import unittest

from ledger_core import post_split, is_balanced


class PostSplitTest(unittest.TestCase):
    def test_exact(self):
        self.assertEqual(post_split(900, {"ops": 1, "mkt": 2}), [("ops", 300), ("mkt", 600)])

    def test_remainder_goes_to_last_account(self):
        entries = post_split(1000, {"ops": 1, "mkt": 1, "rnd": 1})
        self.assertEqual(entries, [("ops", 333), ("mkt", 333), ("rnd", 334)])
        self.assertTrue(is_balanced(entries, 1000))

    def test_weighted_remainder(self):
        entries = post_split(1001, {"a": 3, "b": 1})
        self.assertEqual(entries, [("a", 750), ("b", 251)])


if __name__ == "__main__":
    unittest.main()
EOF
cat > $WS/$R/README.md <<'EOF'
# ledger-core

Posting helpers for the finance ledger. Depends on `moneykit` (sibling checkout).

## Rounding policy

When an amount does not divide evenly, leftover cents go to the **final**
account in the list. Finance reconciliation relies on this; do not change it
without sign-off from Finance Ops.

## Test

    python3 -m unittest discover -s tests -t .
EOF
commit $R "ledger-core: post_split with remainder-to-last policy" "2026-05-20T09:30:00"
cat >> $WS/$R/README.md <<'EOF'

## Notes

`post_split` re-balances the last entry itself so the ledger always balances.
EOF
commit $R "README: note on balancing" "2026-06-10T16:00:00"

# --------------------------------------------------------------- billing-app
R=billing-app; init $R
mkdir -p $WS/$R/billing_app $WS/$R/tests
cat > $WS/$R/billing_app/__init__.py <<'EOF'
import os
import sys

# Workspace dev convenience: sibling checkouts are importable by path.
_ws = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "..")
for _pkg in ("moneykit", "ledger-core"):
    sys.path.insert(0, os.path.join(_ws, _pkg))
EOF
cat > $WS/$R/billing_app/installments.py <<'EOF'
import calendar
from datetime import date

from moneykit import split_evenly


def add_months(d, months):
    idx = d.month - 1 + months
    year, month = d.year + idx // 12, idx % 12 + 1
    day = min(d.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)


def build_schedule(total_cents, count, first_due):
    """Monthly installment plan: list of {"due": date, "amount_cents": int}."""
    amounts = split_evenly(total_cents, count)
    return [{"due": add_months(first_due, i), "amount_cents": a} for i, a in enumerate(amounts)]
EOF
cat > $WS/$R/billing_app/invoices.py <<'EOF'
from dataclasses import dataclass, field
from datetime import date

from moneykit import format_cents
from ledger_core import post_split

from .installments import build_schedule


@dataclass
class Invoice:
    number: str
    customer: str
    total_cents: int
    installments: int = 1
    first_due: date = field(default_factory=date.today)

    def schedule(self):
        return build_schedule(self.total_cents, self.installments, self.first_due)


def render_invoice(inv):
    lines = [f"Invoice {inv.number} - {inv.customer}", f"Total: {format_cents(inv.total_cents)}"]
    for n, item in enumerate(inv.schedule(), 1):
        lines.append(f"  {n}. {item['due'].isoformat()}  {format_cents(item['amount_cents'])}")
    return "\n".join(lines)


def recognize_revenue(inv, department_weights):
    """Book the invoice total across departments."""
    return post_split(inv.total_cents, department_weights)
EOF
touch $WS/$R/tests/__init__.py
cat > $WS/$R/tests/test_billing.py <<'EOF'
import unittest
from datetime import date

import billing_app  # noqa: F401  (sets up sibling paths)
from billing_app.installments import add_months, build_schedule
from billing_app.invoices import Invoice, render_invoice, recognize_revenue


class InstallmentsTest(unittest.TestCase):
    def test_add_months_clamps(self):
        self.assertEqual(add_months(date(2026, 1, 31), 1), date(2026, 2, 28))
        self.assertEqual(add_months(date(2026, 11, 15), 3), date(2027, 2, 15))

    def test_even_schedule(self):
        sched = build_schedule(1200, 3, date(2026, 10, 1))
        self.assertEqual([s["amount_cents"] for s in sched], [400, 400, 400])
        self.assertEqual(sched[2]["due"], date(2026, 12, 1))


class InvoiceTest(unittest.TestCase):
    def test_render(self):
        inv = Invoice("INV-7", "Acme", 120000, 2, date(2026, 10, 1))
        text = render_invoice(inv)
        self.assertIn("Total: $1,200.00", text)
        self.assertIn("1. 2026-10-01  $600.00", text)

    def test_revenue(self):
        inv = Invoice("INV-8", "Acme", 900)
        self.assertEqual(recognize_revenue(inv, {"ops": 1, "mkt": 2}), [("ops", 300), ("mkt", 600)])


if __name__ == "__main__":
    unittest.main()
EOF
cat > $WS/$R/README.md <<'EOF'
# billing-app

Invoice rendering and installment plans. Uses `moneykit` (amounts) and
`ledger-core` (revenue posting) from sibling checkouts.

## Test

    python3 -m unittest discover -s tests -t .
EOF
commit $R "billing-app: invoices and installment schedules" "2026-06-18T11:00:00"
cat >> $WS/$R/README.md <<'EOF'

Installments are monthly, starting at the invoice's first due date.
EOF
commit $R "README: installments note" "2026-07-02T13:25:00"
