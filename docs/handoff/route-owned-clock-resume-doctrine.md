# Route-Owned Clock Resume Doctrine

## Scope

This doctrine captures the successor lesson from PR #25 and routes the next implementation work after the launcher bridge.

PR #25 proved that the launcher can get the system across the launch river. The next bottleneck is not more launcher navigation. The next bottleneck is route-owned campaign clock control.

This document is doctrine and sprint routing. It does not implement gameplay behavior, mutate saves, claim movement proof, or authorize autonomous loops.

## Core lesson

Launcher handoff success is a bridge crossing, not the destination.

Correct chain:

```text
launcher handoff proved
  -> runtime bridge proved with a safe command ACK
  -> next owner must prove route execution from fresh campaign state
```

Forbidden regression:

```text
route assigned
  -> assume travel happened
  -> call it movement proof
```

Correct conclusion:

```text
route assigned is an intent checkpoint.
Movement proof requires clock ownership plus observable route progress or a useful blocked classification.
```

## Problem statement

The current route gap is this:

```text
AutoTravelToRecommended can ACK Success and assign a route while campaign time remains stopped.
```

That result is not useless. It is a checkpoint.

But it is not movement proof.

The owner that accepts a travel route must also own the next clock decision. It may resume the campaign clock, prove that the clock is already running, or emit a blocked/action-required state. It may not silently pass responsibility to the user without a named handoff.

## Route ownership rule

Any command or engine that accepts a travel target becomes the route owner until one of these terminal handoffs occurs:

```text
route_started
route_blocked
route_cancelled
route_arrived
route_replanned
operator_action_required
```

A route owner must answer:

```text
Was a target selected?
Was movement intent recorded?
Was the campaign clock running or resumed?
Was party position observed after the route assignment?
Was distance-to-target observed after the route assignment?
Was arrival, blockage, cancellation, or replanning observed?
Who owns the next checkpoint?
```

If these are unanswered, the route is pending, not complete.

## Clock responsibility

Route-owned clock resume means:

```text
The same layer that records travel intent must either ensure campaign time can advance or declare why it cannot.
```

Valid clock outcomes:

| Outcome | Meaning | Next owner |
|---|---|---|
| `clock_already_running` | Route accepted and time was already advancing. | Movement observer |
| `clock_resumed_by_route_owner` | Route owner explicitly resumed time after route assignment. | Movement observer |
| `clock_resume_rejected_by_authority` | Engine authority denied resume. | Authority / operator |
| `clock_resume_blocked_by_surface` | Runtime surface cannot accept clock control. | Readiness watcher |
| `clock_resume_operator_required` | Manual input is required. | Operator |
| `clock_resume_not_attempted` | Route owner did not own the clock decision. | Bug / doctrine failure |

`clock_resume_not_attempted` should be treated as a sprint failure unless the command is intentionally observe-only and says so in the evidence.

## What must not happen

Do not solve this by widening launcher waits.

Do not solve this by adding a global unpause daemon.

Do not solve this by treating a route ACK as movement.

Do not solve this by trusting `partyMovedDistance == 0` as proof that movement did not happen.

Do not solve this by mutating gold, inventory, stamina, or position to manufacture progress.

The correct seam is route-owned clock and movement observation.

## Evidence required

A route-owned movement attempt needs at least these evidence fields:

```text
commandName
commandAckObserved
routeTargetName
routeTargetId when available
routeIntentSet
clockStateBefore
clockResumeAttempted
clockResumeResult
clockStateAfter
partyPositionBefore when available
partyPositionAfter when available
distanceToTargetBefore when available
distanceToTargetAfter when available
settlementBefore when available
settlementAfter when available
movementCheckpointObserved
arrivalObserved
blockedReason
nextOwner
```

Useful files to read before creating new ones:

```text
BlacksmithGuild_CommandAck.json
BlacksmithGuild_RuntimeLifecycle.json
BlacksmithGuild_RuntimeRegent.json
BlacksmithGuild_RouteCouncil.json
BlacksmithGuild_MovementProof.json
BlacksmithGuild_AssistiveTravelExecution.json
BlacksmithGuild_Status.json
BlacksmithGuild_Phase1.log
```

Future event stream target:

```text
BlacksmithGuild_HandoffEvents.jsonl
```

Minimum handoff events for this lane:

```text
route.intent_recorded
route.clock_resume_attempted
route.clock_resume_blocked
route.movement_checkpoint_observed
route.arrival_observed
route.handoff_recorded
```

## Relationship to EngineToggleAuthority

Route clock control must obey runtime authority.

Manual mode:

```text
Route owner may record intent and recommend the next action, but must not resume the clock autonomously.
```

Hybrid mode:

```text
Route owner may resume the clock only for an explicit user-issued command that requested travel execution.
```

Automation mode:

```text
Route owner may resume the clock inside bounded automation, but must emit handoff evidence and checkpoint classification.
```

Authority failure must be explicit:

```text
authority_manual_hold
authority_hybrid_requires_explicit_command
authority_automation_not_enabled
```

Do not read raw config booleans as permission. Route engines request mode through the authority surface.

## Relationship to PR #27 duration governance

Route-owned clock resume is exactly where casual long waits will try to creep back in.

Forbidden pattern:

```text
route did not obviously move
  -> wait longer
  -> call it stable
```

Correct pattern:

```text
route did not obviously move within the default budget
  -> classify clock state
  -> classify movement observation state
  -> write blocked or pending evidence
  -> hand off to the next owner
```

Default route observation should stay inside the 30-second doctrine unless the run is explicitly marked as a live certificate, manual debug run, or approved long-run soak.

A long route run must have a named reason. A long route run without a named reason is not patience. It is hidden uncertainty.

## Movement observation rule

Movement in Bannerlord may be discrete or checkpoint-based. Therefore:

```text
partyMovedDistance == 0 alone is not proof that movement did not occur.
```

Movement observation should compare multiple signals:

```text
party position delta
distance-to-target delta
settlement departure
settlement arrival
route target change
campaign time delta
movement intent state
clock state
```

If the signals disagree, emit:

```text
movement_metric_disagreement
```

If the observation window is insufficient, emit:

```text
movement_observation_indeterminate
```

Both are better than fake certainty.

## Definition of done for the next implementation sprint

A route-owned clock resume sprint is done only when a disposable-save proof can show:

```text
1. A safe travel command was issued.
2. Command ACK was fresh.
3. Route target was recorded.
4. Route owner attempted or verified campaign clock resume under authority.
5. Movement observation was sampled after route assignment.
6. The result was classified as movement checkpoint, arrival, blocked, cancelled, or indeterminate.
7. The checkpoint was not treated as terminal completion.
8. Next owner was recorded.
9. Default durations stayed bounded unless explicitly approved.
```

Recommended first command target:

```text
AutoTravelToRecommended
```

Recommended first proof target:

```text
route accepted
clock resumed or blocked with reason
movement observation classified
handoff to next branch recorded
```

## Minimal verifier targets

Add or extend offline verifiers to reject:

```text
route ACK without clock decision
clock resume without authority classification
movement proof based only on partyMovedDistance
route checkpoint recorded as terminal completion
undocumented route waits above default duration
missing nextOwner after route assignment
missing blockedReason when clock resume fails
```

Suggested verifier name:

```text
scripts/verify-route-owned-clock-resume-contract.ps1
```

Suggested future runtime artifact:

```text
BlacksmithGuild_RouteClockResume.json
```

Suggested future movement artifact:

```text
BlacksmithGuild_MovementProof.json
```

Use existing artifacts before inventing new ones. Add new files only when the current ones cannot express ownership, clock decision, and movement observation clearly.

## Anti-rework guidance

Do not reopen launcher work to solve route movement.

Do not rebuild the whole autonomous loop before proving one route-owned clock resume.

Do not introduce background automation as a substitute for a bounded route owner.

Do not claim that visible arrival proves the route engine was correct unless the evidence links command, route, clock, movement observation, and arrival.

Do not bury uncertainty in logs only. Write a durable JSON artifact or handoff event.

## Sprint route

Recommended route from here:

```text
1. Push and close PR #25 launcher proof.
2. Keep PR #27 scoped to duration and doctrine guardrails.
3. Add route-owned clock resume contract verifier.
4. Wire AutoTravelToRecommended to record route clock decision.
5. Add bounded movement observation after route assignment.
6. Run one disposable-save proof.
7. Only then re-enter broader recursive campaign automation.
```

## Closing doctrine

The launcher bridge is crossed. The next honest question is no longer, "Did the game spawn?"

The next honest question is:

```text
When a route is accepted, who owns the campaign clock, and what evidence proves the route became motion or a named blocked state?
```

That question is the next sprint seam.
## Required route-owned clock evidence fields

Future route-clock implementation must emit an evidence record that distinguishes command acknowledgement from route assignment and movement proof.

Required fields:

commandAck
routeTarget
routeIntent
routeOwner
clockStateBefore
clockResumeAttempted
clockResumeResult
authorityMode
movementObservation
arrivalBlockedIndeterminate
nextOwner
runtimeProofClaim

Default proof posture:

runtimeProofClaim=false unless movement is actually observed

A route command may ACK success and assign a route without claiming runtime movement proof. The route owner must then attempt clock resume, classify the clock result, observe movement under the bounded duration doctrine, and emit the next owner.
