# Surface Ownership Governance

## Principle

The one-click harness coordinates.

Surface engines decide.

Stable gaps route ownership.

The harness should not invent gameplay decisions. It should launch, attach, observe, invoke approved commands, collect evidence, compare normalized context, and stop when the same context repeats.

The engines should expose enough structured state for the harness to know what is possible next, what was attempted, what changed, and who owns the next gap.

## Why this exists

The project now has a local Reboot harness that can run iterations, normalize evidence, detect repeated context, and write stable-gap handoffs. That means repeated state should become a local patch handoff instead of another AI-token conversation.

The next layer is surface ownership.

When the player character is standing outside a town on the campaign map, the valid actions are different from when the player is inside a town, settlement menu, smithy, market, tavern, or other settlement surface.

The one-click harness should not ask the user which branch to run. It should classify the current surface and route to the owner for that surface group.

## Surface groups

### outside_town

Examples:

- campaign map
- paused campaign map
- traveling
- outside settlement
- approaching settlement
- route intent active

Primary owner:

- OutsideTownGovernor
- movement lane
- route / campaign map engine

Owns:

- current map position
- current or nearest settlement context
- travel target resolution
- route intent
- campaign clock recovery on map
- movement observation
- enter-settlement transition
- outside-town stable-gap classification

Does not own:

- smithing
- market trade execution
- tavern scan
- settlement work loops
- launcher navigation

Primary proof questions:

- Where is the party?
- Is the campaign map actionable?
- Is a destination selected by an engine?
- Was travel command acknowledged?
- Is route intent active?
- Did movement or route progress occur?
- Should the party enter a settlement?

### inside_town

Examples:

- settlement menu
- town menu
- smithy
- market
- tavern
- arena
- settlement interior

Primary owner:

- SettlementGovernor
- town-work lane
- settlement action engine

Owns:

- current town identity
- smithing evaluation
- safe refine / smithing actions
- market scan
- bounded buy / sell actions
- tavern scan
- companion / recruit inspection
- rest / wait decision
- leave-town decision
- next travel preparation after town work
- inside-town stable-gap classification

Does not own:

- campaign-map route movement
- route movement proof
- launcher navigation
- process attach

Primary proof questions:

- What town or settlement is this?
- What useful work is available here?
- Is smithing possible under real stamina/material constraints?
- Is trade possible under real inventory/gold constraints?
- Is rest useful?
- Is town work complete or blocked?
- Should the party leave town?
- What destination should be prepared next?

### interruption_recovery

Examples:

- foreground loss
- escape menu
- operator stop
- Ctrl+C
- ForgeStop sentinel
- paused but not operator-interrupted map

Primary owner:

- Runner / Regent
- interruption lane

Owns:

- operator interruption classification
- foreground loss classification
- escape menu classification
- safe campaign clock resume when not operator-interrupted
- local stop summaries
- handoff when operator state prevents automation

Does not own:

- choosing travel destinations
- selecting town work
- proving movement once route observation is delegated

### launcher_attach

Examples:

- launcher open
- play / continue selection
- loading
- crash reporter
- safe mode prompt
- module mismatch prompt
- attach readiness

Primary owner:

- Forge / launcher harness
- external runner lane

Owns:

- build and deploy path
- launcher automation
- Continue / Play navigation
- attach readiness
- process cleanup
- launch evidence

Does not own:

- campaign-map gameplay decisions
- town gameplay decisions

### evidence_staleness

Examples:

- missing status JSON
- stale heartbeat
- missing summary
- evidence directory missing
- runtime evidence does not match the current iteration

Primary owner:

- Harness / verifier lane

Owns:

- freshness rules
- summary generation
- local handoff paths
- ignored generated evidence policy
- validation wrappers

Does not own:

- gameplay decisions

## Governance rules

1. Harnesses do not invent decisions.

The harness may refresh engines and consume engine outputs. It should not silently choose gameplay goals without source classification.

2. Engines do not assume harness consumption.

Any engine that produces state for the harness must expose a stable artifact, required fields, freshness rules, and failure class.

3. Surface group comes before action selection.

The one-click harness should first classify the surface group, then route to the owner.

4. Stable gaps must name an owner.

A repeated normalized context should not end as a vague failure. It should name `surfaceGroup`, `surfaceOwner`, `stableGapOwner`, and `nextPatchLane`.

5. Same normalized context twice is a patch target.

When the same normalized context repeats at the configured threshold, the harness should stop and write a local handoff.

6. Normal actions use short waits.

Normal actions should not wait more than 30 seconds before classification. Exceptions are long-distance travel, smithing with a large party, and massive trade operations.

7. Movement is discrete/checkpoint-observed.

`partyMovedDistance == 0` alone is not proof that movement did not occur. Movement should be evaluated through checkpoint/discrete evidence such as position delta, destination/proximity delta, nearest-settlement change, campaign-time advancement with route intent, or explicit movement checkpoint.

8. Route intent is not movement proof.

Travel command ACK, movement intent, and running clock are necessary evidence, but they do not prove visible movement by themselves.

9. Attach readiness is not gameplay proof.

Launcher/attach success means the harness reached the game. It does not prove campaign movement, smithing, trading, or other visible gameplay.

10. Generated Reboot evidence is local by default.

Generated evidence under `docs/evidence/reboot*-reboot-session/` should stay ignored unless intentionally sanitized as a fixture.

## Required stable-gap routing fields

Reboot summaries and stable-gap handoffs should move toward including these fields:

```text
surfaceGroup
surfaceOwner
stableGapOwner
nextPatchLane
```

Recommended stable gap owners:

```text
outside_town_movement
inside_town_settlement_work
interruption_recovery
launcher_attach
evidence_staleness
unknown
```

## One-click harness expectation

The desired product behavior is:

```text
Double-click CMD
-> launch / continue / attach
-> classify surface group
-> route to owner
-> attempt the safest useful action
-> collect proof
-> repeat if progress is possible
-> stop on stable_gap if the same normalized context repeats
-> write the next patch handoff locally
```

The user should not decide whether to run travel, smithing, market, tavern, or rest. The harness should classify the surface and route ownership.

## Immediate ownership map

| Surface group | Owner | First responsibility |
|---|---|---|
| outside_town | OutsideTownGovernor / movement lane | travel target, route intent, movement proof, enter town |
| inside_town | SettlementGovernor / town-work lane | smith, trade, tavern, rest, leave town |
| interruption_recovery | Runner / Regent | foreground loss, escape menu, operator stop |
| launcher_attach | Forge / launcher harness | launch, continue, attach, safe process cleanup |
| evidence_staleness | Harness / verifier | stale JSON, missing summaries, bad handoff output |

## Current known pressure point

The latest local Reboot proof found a repeated stable gap around foreground/operator interruption after travel command ACK, with travel intent and clock evidence present but no accepted movement proof.

That gap should be routed through this ownership model instead of treated as an undifferentiated runner/runtime failure.

The likely ownership fork is:

- `interruption_recovery` if foreground policy is stopping too aggressively after route ACK
- `outside_town_movement` if runtime movement is genuinely not being observed after route ACK
- `evidence_staleness` if classification is conflating foreground loss with movement proof failure
