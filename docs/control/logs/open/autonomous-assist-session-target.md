# Autonomous Assist Session Target

This document codifies the current user-facing product goal.

## Target

- Run one command
- game opens automatically
- Continue selected automatically
- campaign loads
- assist loop starts automatically
- avatar visibly trains / moves / acts on campaign map
- logs document every step
- user can toggle off
- runner stops cleanly
- summary evidence written
- terminal finalization recorded

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
