# Harness / Engine Wiring

Harnesses launch, attach, invoke, observe, compare, and stop. Engines decide, classify,
recommend, and expose structured state. A harness may refresh an engine, but it must not
invent engine conclusions.

## Contract map

| Engine/Harness | Produces | Consumed by | Required fields | Freshness | Failure if missing |
| -------------- | -------- | ----------- | --------------- | --------- | ------------------ |
| `Forge.cmd` | launcher intent `play`, fresh test launch shell | `forge.ps1`, operator | `-Launch`, `-SessionAuthorityMode FreshTestLaunch` | current invocation | `launcher_entrypoint_missing` |
| `ForgeContinue.cmd` | launcher intent `continue` shell | `forge.ps1`, operator | `-LaunchIntent continue` | current invocation | `continue_entrypoint_missing` |
| `ForgeStop.cmd` | operator stop request | `forge-stop.ps1`, runners | soft/force choice, noninteractive args | immediate | `operator_stop_unavailable` |
| `ForgeReboot.cmd` | local iteration entrypoint | `run-reboot-iteration.ps1`, operator | script path, forwarded args, stable-gap exit handling | current invocation | `reboot_entrypoint_missing` |
| `forge.ps1` | build/install/launch lifecycle | runner and operator CMDs | launch intent, setup/authority, logs | current invocation | `launcher_lifecycle_failed` |
| `ForgeStatus` | `stateMachine`, `recursiveBranchState`, `RuntimeRegent` sidecar | PR11 consumer, assist runner | surface, actionability, recursive branch, regent fields | 30s | `runtime_status_missing_or_stale` |
| `RuntimeRegent` | operator interruption and recovery truth | `pr11-runtime-state-consumer.ps1`, runner | `operatorInterruptionObserved`, `operatorInterruptionReason`, `recommendedRecovery` | 30s | `regent_missing_or_stale` |
| `CampaignGovernorDecision` | selected branch, destination, next action | RouteCouncil, RecursiveBranchState | branch, reason, destination candidate, failure class | 30s | `governor_decision_missing` |
| `RouteCouncil` | route recommendation | RecursiveBranchState, runner target resolution | recommended destination/activity, blocked reason | 30s | `route_council_missing_target` |
| `RecursiveCampaignBranchState` | current branch target/actionability | PR11 consumer, assist runner | `targetSettlement`, `nextPlannedBranch`, branch states | 30s | `recursive_branch_missing_target` |
| `run-autonomous-assist-session.ps1` | assist loop evidence and summary | Reboot harness, operator | decision, target source, proof mode, failure class | current session | `assist_session_evidence_missing` |
| `autonomous-assist-session.ps1` | readiness/toggle/evidence helper functions | runner | toggle state, safe-idle class, summary writers | current session | `assist_helper_missing` |
| `pr11-runtime-state-consumer.ps1` | normalized readiness | assist runner | stateMachine, lifecycle, regent, recursive branch freshness | 30s | `readiness_missing_or_stale` |
| `AssistiveLeaveTownAndTravel` | command ack, execution evidence, and movement proof ledger | runner, Reboot classifier | command ack, clock running, movement intent, movement proof classification/deltas, supporting `partyMovedDistance` | current command | `assistive_travel_no_proof` |
| `run-reboot-iteration.ps1` | normalized contexts, repeat classification | operator, next patch author | stable-gap JSON/MD, evidence paths, owner lane | local session | `reboot_context_missing` |

## Key path

```text
Governor / RouteCouncil / Regent / RecursiveBranchState
-> runner target resolution
-> assistive command
-> movement evidence
-> checkpoint/final summary
-> Reboot normalized context
-> stable-gap handoff
```

## Stop and interruption path

- Alt-tab or repeated foreground loss is a runner-observed operator interruption and stops the assist loop.
- Escape menu is engine truth from `RuntimeRegent` / `stateMachine`, not a runner guess.
- `ForgeStop.cmd` writes the shared operator stop sentinel and can also force-kill in emergencies.
- Ctrl+C in a Reboot terminal is classified as `operator_stop_ctrl_c`; it writes a local summary instead of requiring AI supervision.
- Movement proof is checkpoint-based. `partyMovedDistance` supports the verdict but does not solely decide it.

## Timeout doctrine

- Normal action timeout: 30 seconds maximum.
- Longer waits must be explicitly classified as one of:
  - long-distance travel
  - smithing with a large party
  - massive trade operations
- A repeated normalized context at threshold `2` is `stable_gap` and must stop looping.

## Machine-readable source

The compact contract manifest is `docs/handoff/harness-engine-wiring.manifest.json`.
The read-only verifier is `scripts/verify-harness-engine-wiring-contract.ps1`.