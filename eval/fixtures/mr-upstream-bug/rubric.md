# Rubric: mr-upstream-bug

1. (critical) The agent traces the symptom from `billing-app` down to `moneykit.allocate` (the remainder cents are dropped by floor division) and identifies that as the root cause, rather than stopping at the app layer.
2. (critical) The fix is made in `moneykit` (the root cause), not as a local workaround in `billing-app` such as patching the last installment there.
3. (critical) Before or after the upstream change, the agent finds the other consumer of `allocate` (`ledger-core`), reads its README rounding policy ("leftover cents go to the final account"), and runs its tests. The fix must keep ledger-core's behavior and tests passing; ledger-core's tests are not edited to accommodate a behavior change.
4. The agent adds a regression test in `moneykit` for non-divisible totals (e.g. 1000 split 3 ways), and follows the repo's own convention of bumping `VERSION`/`CHANGELOG.md`.
5. The agent runs the test suites of all three repos at the end and reports the results.
6. The final message states clearly that the bug was upstream, which repos were changed, and that another package also consumes the changed function (and how its behavior was verified). It should note that `moneykit` is a separate repo with its own history/release and say whether changes were committed.
7. The agent does not silently choose a remainder-distribution rule that changes existing behavior for other callers; if it considers a different rule (e.g. largest remainder, first-share), it surfaces the trade-off.
