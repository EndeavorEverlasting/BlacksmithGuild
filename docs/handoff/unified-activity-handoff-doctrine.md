# Unified Activity Handoff Doctrine

## Scope

This doctrine defines how The Blacksmith Guild transfers responsibility between launcher, runtime readiness, authority, domain engines, tests, and terminal finalization.

It belongs on PR #27 because PR #27 is the active duration-governance guardrail. Duration policy is the pressure point where weak handoffs usually hide. A system that waits longer instead of transferring classified state is not handing off. It is stalling.

This document is doctrine and sprint routing. It does not implement runtime behavior, claim live proof, mutate saves, or authorize long certs.

## Problem

The repo now has strong partial doctrines:

```text
PR #25: launcher window context and post-handoff classification
PR #23: runtime engine authority
PR #27: bounded duration governance
recursive campaign assist doctrine: checkpoint discipline and terminal finalization
```

Those pieces still need one shared handoff contract.

Current failure shape:

```text
one system reaches a checkpoint
  -> the next system assumes responsibility without a record
  -> evidence is split across logs
  -> duration grows to cover uncertainty
  -> checkpoint starts wearing a PASS costume
```

No medal.

## Core rule

A handoff is a controlled transfer of authority, state, evidence, and next responsibility.

Every valid handoff must answer:

```text
Who owned the workflow before this point?
What state did that owner prove?
What evidence supports that state?
Who owns the next decision?
What authority mode applies?
What duration budget applies?
What happens if the next owner cannot proceed?
```

If those answers are missing, there is no handoff. There is only hope with a timeout.

## Handoff record

Future implementation should emit a machine-readable handoff record whenever responsibility crosses a major seam.

Suggested event name:

```text
handoff.recorded
```

Suggested JSON shape:

```json
{
  "schemaVersion": 1,
  "sessionId": "20260705-example",
  "handoffId": "launcher-to-runtime-readiness-001",
  "createdUtc": "2026-07-05T08:30:00Z",
  "fromOwner": "LauncherNavigation",
  "toOwner": "PostHandoffReadiness",
  "handoffKind": "launcher_to_runtime",
  "authorityMode": "Hybrid",
  "stateClassification": "game_spawned",
  "terminal": false,
  "checkpoint": true,
  "durationBudgetSec": 30,
  "durationProfile": "default",
  "evidenceFiles": [
    "BlacksmithGuild_Launch.log",
    "BlacksmithGuild_Status.json",
    "RuntimeLifecycle.json"
  ],
  "requiredNextQuestion": "Is the loaded session attachable and command-ready?",
  "nextOwnerAction": "classify_runtime_readiness",
  "blockedFallback": "operator_action_required",
  "reason": "Launcher phase observed forward progress and must stop clicking controls."
}
```

Field meanings:

| Field | Meaning |
|---|---|
| `fromOwner` | System that just reached a classified checkpoint or terminal state. |
| `toOwner` | System now responsible for the next decision. |
| `handoffKind` | Stable category of transfer, not a prose guess. |
| `authorityMode` | Current Manual, Hybrid, or Automation authority posture when known. |
| `stateClassification` | Named state proven by evidence. |
| `terminal` | True only when no next runtime owner should continue. |
| `checkpoint` | True when progress occurred but completion is not claimed. |
| `durationBudgetSec` | Budget used for this handoff observation. Defaults to 30 unless explicitly approved. |
| `durationProfile` | `default`, `explicit_long_run`, `live_certificate`, `manual_debug`, or similar approved profile. |
| `evidenceFiles` | Artifacts the next owner can read before guessing. |
| `requiredNextQuestion` | The next question that must be answered from fresh state. |
| `nextOwnerAction` | The next bounded action or classification step. |
| `blockedFallback` | Named blocked state if the next owner cannot proceed. |

## Canonical handoff kinds

The repo should converge on these handoff kinds before inventing new names.

| Handoff kind | From | To | Required classification |
|---|---|---|---|
| `launcher_to_runtime` | Forge / launcher navigation | Post-handoff readiness watcher | `game_spawned`, `operator_or_external_handoff_detected`, `launcher_target_invalidated_after_handoff`, or `post_handoff_watch` |
| `runtime_to_readiness` | Runtime lifecycle/status probes | Assistive/readiness surface | `attach_ready`, `attach_blocked`, `hotkeys_ready`, `assistive_commands_ready`, `main_menu_ready`, `map_ready`, or `operator_action_required` |
| `readiness_to_authority` | Readiness surface | `EngineToggleAuthority` | Manual, Hybrid, or Automation mode resolved through authority, not raw booleans |
| `authority_to_engine` | `EngineToggleAuthority` | Governor, MapTrade, GuildLoop, Smithing, Companion, Assistive | Engine allowed, rejected, held, aborted, or observe-only |
| `engine_to_checkpoint` | Domain engine | Evidence writer / runner | Real delta, blocked reason, or observe-only classification |
| `checkpoint_to_next_branch` | Evidence writer / runner | Campaign planner | `nextActionRequired=true` with next branch, or terminal stop reason |
| `test_to_live_cert` | Offline verifier / harness | Live disposable-save cert | Verifier PASS plus explicit live-cert request and approved duration profile |
| `operator_to_system` | User click, hotkey, or file command | Current owning system | Operator action classified as evidence, hold, abort, or command intent |
| `system_to_terminal` | Any owner | Finalization writer | Exactly one terminal state and final evidence summary |

## Ownership boundaries

### Launcher owns only launch-adjacent behavior

Launcher automation may own:

```text
opening or reusing launcher
selecting launcher hwnd/pid
clicking PLAY or CONTINUE
classifying operator/external handoff
stopping launcher clicks after game handoff
```

Launcher automation must not claim:

```text
attach readiness
assistive command readiness
runtime control authority
gameplay deltas
campaign-loop completion
```

Correct handoff:

```text
game_spawned -> post_handoff_watch -> readiness classification
```

Wrong handoff:

```text
game_spawned -> PASS
```

### Runtime readiness owns actionability

Runtime readiness must classify whether the session can accept the next command.

Valid classifications include:

```text
map_ready
main_menu_ready
loading_still_in_progress
attach_ready
attach_blocked
hotkeys_ready
assistive_commands_ready
operator_action_required
post_handoff_idle_unactionable
```

A loaded game with no message, no command route, no activity, and no next owner is unfinished behavior.

### Engine authority owns permission

`EngineToggleAuthority` owns Manual, Hybrid, and Automation decisions.

Authority answers:

```text
May this class of engine proceed?
Is this explicit-command mode or autonomous mode?
Should active automation be held or aborted?
Is bounded execution allowed for this engine?
```

Authority does not prove that any mechanism worked.

```text
automation_allowed != runtime proof
```

### Domain engines own visible mechanisms and deltas

Domain engines own actual work:

```text
Governor
MapTrade
GuildLoop
Smithing
Companion
Assistive
```

They must prove their work with fresh evidence:

```text
command ack
visible mechanism
route set
time advanced
movement observed
inventory delta
gold delta
material delta
stamina delta
companion roster delta
blocked reason
```

A domain engine may return blocked or observe-only. That is a valid handoff if it is named and evidenced.

### Checkpoints own continuation, not completion

A checkpoint means the next branch must be recomputed from fresh state unless a real terminal stop condition exists.

```text
checkpoint != completion
cycle_completed != product complete
finalized_pass requires terminal evidence
```

## Duration rule for handoffs

PR #27 controls the budget posture for handoff observations.

Default rule:

```text
A handoff watch defaults to 30 seconds.
```

A handoff may use more than 30 seconds only when it is explicitly routed through an approved long-run profile:

```text
AllowLongRun
LongRunReason
live_certificate
operator_approved_long_cert
manual_debug
explicit long-run
full_runtime_soak
```

Forbidden pattern:

```text
handoff uncertain -> increase timeout -> call it stability
```

Correct pattern:

```text
handoff uncertain -> classify pending, blocked, or operator_action_required -> write evidence -> stop or transfer ownership
```

The inventory baseline is debt. It is not permission to add new long waits.

## Valid blocked handoffs

A blocked handoff is valid when the next owner is named and the block reason is useful.

Examples:

| Blocked state | Meaning | Next owner |
|---|---|---|
| `launcher_target_invalidated_after_handoff` | Launcher target disappeared because workflow moved forward | Post-handoff readiness |
| `loading_still_in_progress` | Runtime exists but cannot yet accept commands | Readiness watcher or operator |
| `attach_blocked` | Game exists but attach path cannot act | Operator or recovery runner |
| `assistive_commands_not_ready` | Runtime is alive but action commands are not available | Assistive readiness |
| `authority_manual_hold` | Operator/manual mode blocks automation | Operator or authority surface |
| `engine_rejected_by_authority` | Engine wanted work but authority denied it | Engine caller |
| `state_ambiguous_observe_only` | Evidence is insufficient for action | Observation loop |
| `terminal_stop_requested` | User, process, policy, or objective ended the run | Finalization writer |

Blocked is not failure by default. Silent blocked state is failure. Vague blocked state is failure wearing a hat.

## Evidence streams

Future handoff implementation should prefer these evidence files before creating new ones:

```text
BlacksmithGuild_Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
RuntimeLifecycle.json
ForgeStatus.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_CommandInbox.json
ExternalStateTimeline.json
BlacksmithGuild_AutomationEvents.jsonl
BlacksmithGuild_BoundaryEvents.jsonl
checkpoint-events.jsonl
campaign-loop-summary.json
```

A future dedicated stream is acceptable:

```text
BlacksmithGuild_HandoffEvents.jsonl
```

If added, it should contain `handoff.recorded`, `handoff.blocked`, and `handoff.terminal` events with the record shape above.

## Forbidden conclusions

Do not allow these claims in docs, PR bodies, runners, or cert summaries:

```text
game_spawned means attach_ready
continue_clicked means map_ready
hotkeys_ready means assistive_commands_ready
automation_allowed means runtime proof
raw config boolean means authority
checkpoint means final PASS
cycle_completed means product complete
long timeout means stability
baseline debt means approval for new debt
operator click means automation failure
```

## Sprint placement

### PR #25

PR #25 owns the launcher side of the first handoff.

It should finish with:

```text
launcher_to_runtime handoff classified
launcher click loop stopped after handoff
post_handoff_watch emitted
no runtime PASS claimed from launcher progress
```

### PR #23

PR #23 owns authority posture after readiness.

It should finish with:

```text
Manual, Hybrid, Automation modes present
higher-order engines routed through EngineToggleAuthority where in scope
Manual treated as stop/hold posture
Automation treated as permission, not proof
```

### PR #27

PR #27 owns the duration guard that keeps future handoffs honest.

It should finish with:

```text
bounded duration doctrine enforced
long-wait inventory documented as debt
new handoff doctrine attached to PR #27
future handoff watches blocked from casual long defaults
```

PR #27 does not need to implement `BlacksmithGuild_HandoffEvents.jsonl`. It does need to leave the doctrine visible enough that the next implementation sprint cannot pretend the handoff concept is still vibes and fog.

## Minimum implementation sequence after PR #27

1. Add `BlacksmithGuild_HandoffEvents.jsonl` or equivalent handoff event emission.
2. Emit `launcher_to_runtime` from launcher/post-handoff paths.
3. Emit `runtime_to_readiness` when status/lifecycle classifies actionability.
4. Route readiness into `EngineToggleAuthority` before domain engines act.
5. Emit `authority_to_engine` before Governor, MapTrade, GuildLoop, Smithing, Companion, or Assistive action.
6. Emit `engine_to_checkpoint` with real delta or blocked reason.
7. Emit `checkpoint_to_next_branch` with fresh recomputation requirement.
8. Emit exactly one `system_to_terminal` event when stopping.
9. Add an offline verifier that rejects missing `toOwner`, missing evidence, checkpoint-as-terminal collapse, and undocumented long handoff waits.

## Definition of done for this doctrine

The doctrine is satisfied when future agents can inspect a run and answer:

```text
What system had authority before the handoff?
What system has authority after it?
What evidence was transferred?
What state was classified?
What budget was used?
What authority mode governed the next action?
What branch came next?
Was finalization explicit if the run stopped?
```

That is the handoff system. Everything else is baton-dropping in ceremonial uniform.
