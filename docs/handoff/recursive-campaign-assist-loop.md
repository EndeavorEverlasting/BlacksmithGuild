# Recursive Campaign Assist Loop Doctrine

**Date:** 2026-06-26  
**Scope:** The Blacksmith Guild autonomous assist / campaign-loop planning doctrine  
**Status:** Product direction and test-routing doctrine

## Core principle

The campaign assist system must not treat a single successful test checkpoint as the end of the product path.

A live cert can prove that one action worked, but the product goal is a logically recursive campaign loop:

```text
observe state
choose the next safe profitable action
act in-game
log the checkpoint
finalize only when a terminal stop condition occurs
resume from the next observed state on the next cycle
```

A checkpoint is progress. It is not completion.

Completion only means the current automation run reached a terminal stop condition and wrote final evidence. It does not mean the campaign plan is finished.

## Strategic product loop

The high-level campaign loop is:

1. Travel from one town to another.
2. Evaluate market, smithing, stamina, party, threat, and companion state.
3. Trade when profitable and safe.
4. Smith or refine when materials, stamina, location, and opportunity make sense.
5. Avoid threats when risk exceeds the current party/economic plan.
6. Visit taverns when companion capacity, role gaps, or quality upgrades justify it.
7. Recruit useful companions when they improve the party/clan plan.
8. Shed poor-fit companions when clan capacity is capped and better options are available.
9. Recompute the next town/action from fresh state.
10. Continue recursively until the user stops the run, an unsafe condition appears, the game exits, or a configured terminal objective is reached.

The system must therefore plan for the next safe campaign action after every successful checkpoint.

## Non-goals

The recursive loop must not become a cheat path.

Do not add free gold, free resources, fake XP, fake movement, fake inventory deltas, or fake companion progress.

The doctrine remains:

```text
Automate the hands, not the consequences.
```

## Checkpoint versus terminal state

Tests and runners must distinguish these clearly:

| Event | Meaning | What happens next |
|---|---|---|
| `checkpoint_reached` | A step succeeded | Continue planning from fresh state |
| `checkpoint_blocked` | A step could not safely proceed | Pick another safe branch or stop with reason |
| `cycle_completed` | One logical campaign cycle ended | Start next cycle unless terminal stop exists |
| `stop_requested` | User or policy requested stop | Finalize evidence and stop automation |
| `unsafe_surface` | Current state is not safe for automation | Stop or observe-only according to policy |
| `finalized_pass` | Current run completed its declared terminal objective | Write summary and stop this run only |
| `finalized_fail` | Current run failed its declared terminal objective | Write reason and stop this run only |
| `finalized_abort` | Game/process/user/policy interrupted the run | Write reason and stop this run only |

A test must not report final completion merely because a travel checkpoint, trade checkpoint, smithing checkpoint, or companion checkpoint succeeded.

## Recursive campaign cycle schema

Every cycle should produce machine-readable evidence like:

```json
{
  "sessionId": "20260626-example",
  "cycleId": 7,
  "phase": "campaign_loop",
  "currentTown": "Ortysia",
  "nextPlannedTown": "Danustica",
  "selectedAction": "travel_trade_smith",
  "checkpointName": "party_movement_observed",
  "checkpointReached": true,
  "terminal": false,
  "nextActionRequired": true,
  "nextActionReason": "arrive_then_recompute_market_smithing_companion_state"
}
```

Terminal evidence should be explicit:

```json
{
  "sessionId": "20260626-example",
  "cycleId": 7,
  "phase": "finalization",
  "terminal": true,
  "terminalState": "finalized_pass",
  "passFail": "PASS",
  "reason": "configured_objective_met_and_summary_written",
  "nextActionRequired": false
}
```

## Required live feedback

When the game is alive, important checkpoints and terminal states must be written to both:

1. JSON/evidence logs.
2. The in-game bottom-left message log.

Examples:

```text
BlacksmithGuild: checkpoint - arrived at Ortysia.
BlacksmithGuild: checkpoint - market evaluated; next action selected.
BlacksmithGuild: checkpoint - smithing/refine action completed.
BlacksmithGuild: checkpoint - tavern companion scan completed.
BlacksmithGuild: checkpoint - companion roster decision recorded.
BlacksmithGuild: cycle complete - recomputing next town/action.
BlacksmithGuild: automation stopping - user toggle received.
BlacksmithGuild: automation finalized - summary evidence written.
```

If the game is gone, the runner must write terminal JSON immediately. On next mod load, the mod should show a previous-run terminal notice in the bottom-left message log.

## Agent test ownership

### Agent A - Evidence / PR / Git judgment

Agent A must prove the run did not fake completion.

Agent A checks:

- checkpoint events are not mislabeled as terminal completion
- terminal state exists before any PASS/FAIL claim
- summary evidence names the next logical action or the terminal stop reason
- real movement/trade/smithing/companion deltas are not inferred from stale artifacts
- evidence is runner-captured, not manually harvested

### Agent B - Runtime / gameplay state truth

Agent B owns the gameplay truth that feeds recursion.

Agent B checks:

- current town/settlement
- campaign surface
- party movement state
- smithing stamina/material state
- trade inventory/price state
- companion capacity and roster state
- tavern candidate state when available
- threat/unsafe surface state
- fresh `Status.json.stateMachine` and `RuntimeLifecycle`

Agent B must return enough state for the next cycle to choose a safe branch.

### Agent C - Launcher / runner / lifecycle / command execution

Agent C owns the loop runner mechanics.

Agent C checks:

- one command starts or resumes the run
- PID/window authority follows before/after process-set diff
- checkpoints are emitted when actions occur
- the runner does not call a checkpoint a final completion
- stop/finalization states are emitted exactly once
- user toggle and cancel files stop the loop cleanly
- JSON and in-game messages agree when the game is alive

### Agent D - Docs / atlas / routing board

Agent D keeps the recursive doctrine visible.

Agent D checks:

- docs do not describe one-town travel as the final product goal
- docs route trading, smithing, threats, and companions as recursive loop work
- future sprints preserve the distinction between checkpoint, cycle completion, and terminal finalization
- stale F7 or single-cert language is marked historical or subordinated

## Recursive action branches

The loop should choose among these branches after each cycle:

| Branch | Trigger | Required evidence |
|---|---|---|
| Travel | Better next town exists and travel is safe | source town, target town, route intent, movement observed |
| Trade | Profitable buy/sell exists and inventory/gold allow it | prices, inventory before/after, gold delta |
| Smith/refine | Materials/stamina/opportunity allow it | materials before/after, stamina before/after, recipe/action result |
| Rest/wait | Stamina or time gating blocks productive action | wait reason, time advanced, stamina refreshed if applicable |
| Tavern scan | Town has tavern and companion decision is useful | candidates, traits, cost, role fit |
| Recruit companion | Candidate improves roster and capacity allows | roster before/after, cost, role reason |
| Dismiss companion | Clan capacity capped and candidate quality improves roster | roster before/after, dismissal reason, replacement reason |
| Avoid threat | Risk exceeds safety threshold | threat reason, avoided action, fallback route/action |
| Observe only | State is ambiguous but not terminal | observed state and next poll condition |
| Stop | User toggle, unsafe surface, crash, timeout, or configured objective | terminal reason and final evidence |

## Test shape for recursive sprints

Future tests should have this form:

```text
Arrange known state
Run one campaign-loop cycle
Assert checkpoint events
Assert no terminal completion unless stop condition exists
Assert nextActionRequired=true
Assert next branch is documented
Assert evidence and in-game message contract are satisfied
```

For terminal tests:

```text
Arrange terminal stop condition
Run finalization path
Assert terminal event exactly once
Assert nextActionRequired=false
Assert summary evidence exists
Assert in-game message shown when game alive, or previous-run notice queued when game gone
```

## Required future hardening

1. Add `checkpoint-events.jsonl` if not already present.
2. Add `campaign-loop-summary.json` with `nextActionRequired` and `nextPlannedBranch`.
3. Add tests that fail if a checkpoint is treated as terminal completion.
4. Add tests that fail if a run ends without a terminal reason.
5. Add tests that fail if a cycle completes without a next planned branch or explicit stop reason.
6. Add in-game bottom-left messages for checkpoint and terminal states.
7. Add companion/tavern state probes before implementing companion recruitment or dismissal automation.
8. Add threat/risk state probes before implementing avoidance automation.

## Definition of done for this doctrine

The recursive campaign assist system is not done when it reaches one town.

It is only behaving correctly when each cycle can answer:

```text
Where am I?
What changed?
What checkpoint did I reach?
Am I terminally stopping?
If not stopping, what is the next safe branch and why?
Was that written to evidence?
Was the player shown the important state in-game when possible?
```

That is the loop. Preserve it.