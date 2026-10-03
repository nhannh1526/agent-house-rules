# mr-contract (maintainer notes)

**Trap:** The user names the API and the web dashboard. A third repo, `ops-reports`, imports `orders_api.handlers.get_orders()` and sums `o["total"]`. Its tests currently pass; after the API rename they fail with `KeyError: 'total'` and the finance CLI crashes. Nothing in the task or the api/web READMEs mentions it (only a grep across the workspace, or running all test suites, finds it).

**Why the rubric says what it says:** A careful engineer treats an API response shape as a contract and looks for every consumer before changing it. The cross-repo search and the all-repos test run are critical; reporting the out-of-scope edit to the user matters because the report is owned by another team (README hint).

**check.py:** runs each repo's tests, feeds the *live* API output into the web renderer (so changing only API+web fixture but mis-wiring fails), and runs the ops-reports CLI. `total` removal and fixture refresh are non-critical because keeping `total` temporarily is defensible (the task says "instead", so we only softly check).

Untouched workspace: all tests pass, check reports api_total_cents / web / reports_cli failing.
