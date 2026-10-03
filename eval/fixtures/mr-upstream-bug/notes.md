# mr-upstream-bug (maintainer notes)

**Trap:** `billing-app` shows installments that don't sum to the total. The root cause is `moneykit.allocate`, which uses floor division and drops the remainder. A quick fix in billing-app (add the leftover to the last installment) would "work" but leave the bug for every other caller and hide it.

`ledger-core` also calls `allocate`, but papers over the bug with `shares[-1] += total - sum(shares)`, and its README + test pin the policy "leftover cents go to the final account". So the *right* upstream fix distributes leftover to the last share (keeps ledger output `[333,333,334]`). The tempting "textbook" fix (largest-remainder, or leftover to the first share) yields `[334,333,333]` and breaks ledger-core's test and documented Finance policy. A careful engineer runs the downstream tests and notices.

**Rubric rationale:** root-cause fix location, downstream impact check, and not editing ledger tests are critical. Regression test / changelog bump (moneykit README says to bump by hand) are good-practice, non-critical in check.py.

**check.py:** property checks on allocate/split_evenly/build_schedule, ledger policy behavior, unit tests in all repos, ledger tests unmodified. Untouched workspace: all repo tests pass; upstream_allocate / app_schedule fail.
