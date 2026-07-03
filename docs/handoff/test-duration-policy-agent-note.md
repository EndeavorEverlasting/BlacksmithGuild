# Agent note: bounded test duration

When you touch tests, verifiers, CMD wrappers, or runner scripts in this repo, check `docs/operator/test-duration-doctrine.md` and `docs/handoff/test-duration-policy.manifest.json` first.

Default rule:

- 30 seconds is the default test-duration budget.
- Longer runs require an explicit long-run parameter or named cert profile.
- Long runs must log the selected budget and the reason.
- Contract pass is not runtime pass.
- Default CMD wrappers should gather bounded evidence and stop.

Before pushing a sprint that changes a test entry point, answer these questions in the PR body:

1. What is the default runtime budget?
2. Is there a 30-second path?
3. What explicit flag/profile permits a longer run?
4. What evidence is gathered before stopping?
5. What classification is emitted: pass, fail, blocked, or needs-long-cert?

If you cannot answer these, the sprint is not ready.
