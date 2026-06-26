# Ortysia Live Cert Landmark

**Date:** 2026-06-25 / 2026-06-26 UTC  
**Merged PR:** [#14](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/14)  
**Main merge commit:** `85f2f33`  
**Cert branch head:** `0ead00d`  
**Live evidence:** `docs/evidence/live-cert/20260625-235004-pr11-launch-attach-execute/cycle-result.json`

## Landmark

The unattended PR11 live cert reached the real product milestone: **Quyaz -> Ortysia travel execute passed with real movement observed**.

The successful run launched Bannerlord, attached to a loaded campaign at the Quyaz settlement menu, passed the state-machine travel gate, sent the advisory probe, sent `AssistiveLeaveTownAndTravel -Execute -TargetSettlement Ortysia`, left town, reached the campaign map, and observed live party movement.

Key proof from `cycle-result.json`:

```text
passFail=PASS
attachResult=attach_ready
probeOk=true
executeOk=true
travelGateAllowed=true
travelGateReason=state_machine_travel_ready
runtimeLifecycleConsumed=true
stateMachineConsumed=true
executeChecks.partyMoved=true
executeChecks.actualExecutionObserved=true
executeChecks.fakeGameplayDelta=true
```

Live execution proof from `BlacksmithGuild_AssistiveTravelExecution.json` during the run:

```text
currentSettlement=Quyaz
targetSettlement=Ortysia
leaveTownSucceeded=true
mapTravelAttempted=true
travelApiCallSucceeded=true
movementIntentSet=true
actualExecutionObserved=true
partyMovedDistance=0.324
travelClockRunning=true
fakeGameplayDelta=false
```

## What Failed Before

Two defects made earlier runs look worse than they were:

1. **Attach freshness was always stale on non-UTC machines.** `ConvertFrom-Json` coerced `stateMachine.updatedAtUtc` from an ISO `...Z` string into a `[datetime]` and later re-stringified it without the `Z`. The old parser treated that UTC wall-clock as local time, shifted it into the future, and made `statusFresh=false`. The runner never attached, never sent the travel command, and the party stayed at Quyaz.
2. **Window authority drifted away from PID before/after selection.** The classifier used process-snapshot deltas and logged `new_pid_after_baseline`, but launcher UIA still relied on process-name matching (`Bannerlord`) and coordinate/title fallback. On this Steam setup the game is hosted under `TaleWorlds.MountAndBlade.Launcher`, so name-only game detection missed the real game-host PID.

## Non-Regression Rules

These are product invariants, not preferences:

1. **One PID/window authority.** Bannerlord launch, attach, and UIA targeting must prefer the session before/after process-set diff. Process name, title, and coordinate picks are fallbacks only when the diff yields no usable candidates.
2. **No silent coordinate fallback.** If `new_pid_after_baseline` or equivalent before/after candidates exist, launcher code must not silently fall back to title or coordinate selection. Logs must state which PID was selected and why.
3. **UTC-by-contract fields stay UTC.** Fields named `*Utc` from JSON must be treated as UTC even when `ConvertFrom-Json` has already coerced them to `[datetime]` with `Kind=Unspecified`.
4. **Movement evidence must be physical.** A passing execute cert requires real party movement (`partyMovedDistance > 0`) and a running travel clock. Route intent alone is not enough.
5. **State surfaces must be checked in both locations.** Live status may be written under the Steam Bannerlord root while Documents copies are rotated to `.bak`. A stale Documents file is not proof that state logging stopped.
6. **A checkpoint is not completion.** `checkpoint_reached` events show progress only. Completion requires a terminal `finalized_pass`, `finalized_fail`, or `finalized_abort` event in `checkpoint-events.jsonl`, linked to the run summary.

## Checkpoint vs Finalization

Every cert runner that claims a terminal result must write `checkpoint-events.jsonl`.

Required execute PASS evidence now includes:

```text
checkpoint-events.jsonl contains finalized_pass
attach_ready checkpoint reached
state_machine_consumed checkpoint reached
runtime_lifecycle_consumed checkpoint reached
probe_ack checkpoint reached
execute_ack checkpoint reached
party_movement_observed checkpoint reached
summary_written checkpoint reached
```

Reaching any checkpoint alone cannot set `passFail=PASS`. The runner must start finalization, evaluate criteria, emit `finalized_pass`, and only then write the summary/termination linkage.

## Required Validation Before Touching This Lane

Run the full offline contract after launcher, lifecycle, readiness, or assistive-travel changes:

```powershell
pwsh -NoProfile -File scripts\verify-f7-runner-contract.ps1
```

The contract must include these regression guards:

```text
test-pr11-utc-freshness.ps1
test-launcher-pid-baseline-diff.ps1
test-pr11-execute-cert-parser.ps1
test-faction-posture-scan-guard.ps1
test-automation-checkpoint-finalization.ps1
test-runtime-user-message-events.ps1
```

For any future live re-cert, use an early-kill rule: if state classification repeats the same ready state while no command is issued and the attach gate does not transition, stop the run, capture evidence, and diagnose the gate. Do not burn the full timeout on a dead run.

## Forward Path

Next work should harden the milestone rather than re-prove it from scratch:

1. Unify the launcher UIA baseline with `TbgProcessLifecycle.preExistingProcesses` so there is a single lifecycle authority instead of parallel baselines.
2. Strengthen `test-launcher-pid-baseline-diff.ps1` from an anchor test into a behavioral fixture: when a new post-baseline PID exists, coordinate/title fallback must be rejected.
3. Keep `ConvertTo-Pr11Utc` as the only freshness converter for UTC-by-contract fields.
4. Preserve the execute PASS contract: attach ready, probe ACK, execute ACK, `partyMovedDistance > 0`, `travelClockRunning=true`, `fakeGameplayDelta=false`.
5. Treat the Ortysia run as the known-good landmark for PR11 unattended execute behavior.
