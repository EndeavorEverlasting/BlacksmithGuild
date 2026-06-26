# Autonomous Assist Session Target

This document codifies the current user-facing product goal.

## Target

- Run one command that starts a **recursive campaign assist session** (not a one-shot cert finish line)
- game opens automatically
- Continue selected automatically
- campaign loads
- assist loop starts automatically
- each cycle: observe state, choose next safe branch, act when allowed, log checkpoints
- avatar visibly trains / moves / acts on campaign map when travel/training branches run
- logs document every step
- user can toggle off
- runner stops cleanly with terminal finalization
- `assist-loop-summary.json` and `campaign-loop-summary.json` written

Doctrine: [`docs/handoff/recursive-campaign-assist-loop.md`](../../handoff/recursive-campaign-assist-loop.md)

## Explicit non-goals

- manual log harvesting
- manual hotkey ceremony
- old F7 ritual
- manual Bannerlord open
- fake travel/gold/inventory/XP

The preferred path requires no hotkey; the autonomous assist loop starts after the runner reaches campaign attach and consumes runtime state.

A checkpoint is not completion. `checkpoint_reached` events document progress; completion requires `finalization_started` and a terminal `finalized_pass`, `finalized_fail`, or `finalized_abort` event in `checkpoint-events.jsonl`.

## Required assist loop files

- `session-manifest.json`
- `assist-loop-timeline.json`
- `assist-loop-summary.json`
- `campaign-loop-summary.json`
- `state-snapshots.jsonl`
- `command-timeline.jsonl`
- `toggle-events.jsonl`
- `safety-decisions.jsonl`
- `travel-decisions.jsonl`
- `training-decisions.jsonl`
- `checkpoint-events.jsonl`
- `process-lifecycle.json`
- `runtime-lifecycle.json`
- `BlacksmithGuild_Status.json`
- `BlacksmithGuild_RuntimeLifecycle.json`
- `cert-run-output.txt`
- `termination-detection.json`
- `safe-mode-detection.json` if present
- `BlacksmithGuild_AssistiveTravelExecution.json` if travel executes

## PASS Gate

`assist-loop-summary.json.passFail=PASS` is valid only when `checkpoint-events.jsonl` contains `finalized_pass` and the required checkpoints for the run:

- `attach_ready`
- `state_machine_consumed`
- `runtime_lifecycle_consumed`
- `assist_loop_started`
- `summary_written`

Travel execution additionally requires `probe_ack`, `execute_ack`, `party_movement_observed`, `partyMovedDistance > 0`, `travelClockRunning=true`, and `fakeGameplayDelta=false`.

## Toggle mechanism

- `BlacksmithGuild_AssistToggle.json` = stops assist loop
- `BlacksmithGuild_CancelRun.json` = cancels entire runner

## Economic-loop cert profile

The `economic_loop` cert profile extends the assist session with a recursive trade objective. It is offline-proven (boundary contract + economic-loop cert test); a live cert run is planned but not executed by the current foundation.

Planned live command (do not run without authorization):

```powershell
pwsh -NoProfile -File scripts/run-autonomous-assist-session.ps1 `
  -CertProfile economic_loop -TradeIterationTarget 10 -RequireExecuteMovement
```

Additional EvidenceDir artifacts written under this profile:

- `BlacksmithGuild_BoundaryEvents.jsonl` — section boundary lifecycle (status, failureClass, evidenceFiles)
- `BlacksmithGuild_TradeIterations.jsonl` — proven buy/sell iterations with gold/inventory deltas
- `BlacksmithGuild_AutomationEvents.jsonl` — dotted runtime events (evidence, not proof)
- `economic-loop-summary.json` — tradeIterationCount / tradeIterationTarget / branchConsiderationLog / lastFailureClass
- `economic-loop-cert.json` — offline `Test-AutomationEconomicLoopPassCriteria` verdict
- domain JSON copied when present: `BlacksmithGuild_MapTradeCert.json`, `BlacksmithGuild_HorseMarketIntel.json`, `BlacksmithGuild_SmithingSafeAction.json`

### Economic-loop PASS gate (in addition to the base PASS gate)

`economic-loop-cert.json.pass=true` requires:

- 10 proven trade iterations (real gold AND inventory delta, `fakeGameplayDelta=false`) and `tradeIterationTarget == 10`
- at least one non-trade branch executed or blocked (multi-branch; no trade-only / observe-only PASS)
- all started boundaries closed; no orphan `command.started`; exactly one terminal `finalized_pass`

Full failure map and section/failure-class vocabulary: [`docs/handoff/recursive-campaign-assist-loop.md`](../../../handoff/recursive-campaign-assist-loop.md#economic-loop-certification-foundation).
