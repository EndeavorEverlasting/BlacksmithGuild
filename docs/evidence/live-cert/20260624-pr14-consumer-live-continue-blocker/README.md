# PR #14 live consumer proof — classified blocker (continue_not_found)

FreshTestLaunch reached launcher CONTINUE coord clicks but verification failed after 3 attempts.
Game never spawned; PR #13 stateMachine was never observable in-session.

| Field | Value |
|-------|-------|
| failureClass | continue_not_found |
| windowClassifierResult | continue_not_verified |
| navError | launcher_timing_timeout (45s budget) |
| routeAgent | Agent C |

Source session: 20260624-131721-pr11-launch-attach-execute
Branch head at run: 613f606
