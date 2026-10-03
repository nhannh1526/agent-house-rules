# Rubric: mr-contract

1. (critical) Before or while changing the API shape, the agent searches the whole workspace (all repos, not just `web/`) for consumers of the `total` field, and discovers `ops-reports/`.
2. (critical) The agent updates every consumer it finds, including `ops-reports/report.py` and its tests, not only the web dashboard that the user named. Final state: all three repos' tests pass.
3. (critical) The agent runs the test suites of all three repos (or otherwise exercises each consumer) after the change, rather than only the repos it edited first.
4. The final message explicitly tells the user about the extra consumer (`ops-reports`) that was outside the request, and that its output/behavior was adjusted (or flags that Finance Ops owns it per the README and may want a heads-up).
5. Money handling is correct end-to-end: cents stay integers in the API and the dashboard/report format dollars only at display time; no float round-trips introduced (e.g. `total_cents / 100` only in formatting).
6. Tests and fixtures are updated to the new shape (web fixture, api and report tests) rather than deleted, skipped, or loosened to make them pass.
7. The agent notes the breaking nature of the contract change (any external clients, deploy ordering of api/web, or whether to keep `total` temporarily) instead of silently assuming no other clients exist.
