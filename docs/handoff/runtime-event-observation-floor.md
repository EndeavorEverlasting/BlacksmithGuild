# Runtime Event Observation Floor

```text
[TBG | Sprint 1 | Runtime Observer Floor | Wave 0 | repo-floor/research]
```

## Context

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Branch: `sprint/runtime-observer-floor`
- Worktree: `C:/Users/Cheex/Desktop/dev/Mods/Bannerlord/BlacksmithGuild-runtime-observer-floor`
- Floor: `origin/main` at `7800cb7a6bafdeac76c2ad723f756f86739429e2`
- Lane: repo-floor / research-design
- Owned scope: floor ledger, ownership ledger, this report
- Forbidden scope: `src/**`, `Module/**`, observer implementation, shared schemas, runtime launch, destructive cleanup, wholesale cherry-pick from PRs #101/#102/#20

Machine-readable companions:

- `.tbg/plans/runtime-event-observation/floor.json`
- `.tbg/plans/runtime-event-observation/ownership.json`

Mutable PR checks, mergeability, and sibling dirt are snapshots. Refresh before reuse.

## Verified floor

Current `origin/main` matches the pack expected SHA:

```text
7800cb7a6bafdeac76c2ad723f756f86739429e2
feat(harness): install crash observability and negative evidence doctrine (#108)
```

The primary local checkout at `BlacksmithGuild` remains on `main` at `6b618771e55969d579d9928ca5743a057dfff0b8` (13 commits behind). It was clean and was preserved. All Sprint 1 mutations happened in the isolated worktree above.

## Collision PRs

| PR | Head | Role | Verdict |
|---:|---|---|---|
| #101 | `38d0223` on `cert/2026-07-18-full-campaign-handoff-live` | collision/reference | Conflicting; failing harness checks. Overlaps governor/map-trade/cleanup. Do not base or wholesale cherry-pick. |
| #102 | `fed8bda` on `feat/harness-doctrine-installation` | collision/reference | Conflicting; failing harness checks. Heartbeat/crash-export scripts conflict with current crash doctrine on main. Do not base or import those scripts unchanged. |
| #20 | `2839b37` on `sprint/governor-activity-contract` | collision/reference | Mergeable but product/runtime. Separate review. Not an observer base. |

PR #102 anti-patterns to keep out of this program:

1. Stale `Phase1.log` treated as likely crash without external terminal evidence.
2. Process checks limited to `Bannerlord*` instead of the canonical four process names.
3. Unmatched `[TBG ENGINE START]` treated as crash without WER/TaleWorlds/correlated exit evidence.

## Canonical existing surfaces

Already on the floor and must be consumed, not reinvented:

1. **Window polling watcher** — `Invoke-TbgWindowIntelligence.ps1` defaults to 100 ms polling, publishes lifecycle events, and reduces them through the window-lifecycle spine (`Invoke-TbgWindowLifecycleRuntime.ps1`, window-lifecycle schemas, `.local/tbg-window-lifecycle/`).
2. **Runtime context continuity** — contract + `TbgRuntimeContextCapsule.v1` + crash-observability / negative-evidence doctrine already on main via #103–#108.
3. **In-process emitter** — `AutomationRuntimeEventEmitter` appends free-form `AutomationEvents.jsonl` runtime events. Useful seam for Sprint 5 spans; not yet a correlated span envelope.
4. **Capabilities** — operations expose E2E and window-lifecycle actions only. No external game-runtime observer or incident assembler operations yet.
5. **Artifact engine** — has `window-lifecycle-boundary` and `runtime-proof-boundary`; lacks observer/incident triggers.

## Missing surfaces Sprint 2+ must create

Shared spine (Sprint 2 only): observer run-context, event envelope, artifact registry, incident timeline schemas, focused validator, workflow contract, fixtures, CI.

Parallel Group Alpha after Sprint 2 is green:

- Sprint 3 — event-first window listener + polling reconciliation
- Sprint 4 — external process/WER/TaleWorlds/heartbeat observer
- Sprint 5 — correlated in-process spans around governor/map-trade boundaries

Then Sprint 6 assembler, Sprint 7 skills/capabilities/triggers, Sprint 8 live certification.

## Ownership summary

| Category | Owner |
|---|---|
| Floor / collision ledger | Sprint 1 |
| Shared event / run-context / artifact schemas | Sprint 2 |
| Window listener implementation | Sprint 3 |
| External game observer | Sprint 4 |
| In-process span implementation | Sprint 5 |
| Incident correlation | Sprint 6 |
| Skills / capabilities / triggers | Sprint 7 |
| Live evidence and final reporting | Sprint 8 |

Parallel Group Alpha branches from the Sprint 2 floor only. No stacking on another Alpha branch.

## Proof ceiling

Reached: contract / static inspection.

Not claimed: observer implementation, build, launcher, behavior, live runtime, native crash confirmation, or operator acceptance.

## Sprint 2 unlock

Base on exact floor SHA `7800cb7a6bafdeac76c2ad723f756f86739429e2`, or on the main commit that contains the merged Sprint 1 floor after this PR is green and merged.

Do not start Sprint 2 from PR #101, #102, or #20.

## Exact next command

```powershell
gh pr checks --watch
```
