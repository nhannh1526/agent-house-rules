## Your fixtures

1. `mr-contract` - A backend API repo and a frontend repo. The user asks for a change to an API response shape (rename or restructure a field). Another consumer of that API also lives in the workspace (for example a small CLI or a reporting script in a third repo) and would break too.
2. `mr-upstream-bug` - An application repo depends on two local upstream package repos. A bug shows up in the application, but its root cause is inside one upstream package that other code also uses. Patching only the application would hide the bug.
3. `mr-plan-conflict` - Three repos: backend, frontend, and a shared package. The workspace contains a written plan that the user calls approved; the plan states one fact about the code that is false, and following the plan literally would break something.
