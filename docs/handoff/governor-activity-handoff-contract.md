# Governor Activity Handoff Contract

**Date:** 2026-06-26  
**Scope:** recursive campaign assist, autonomous guild loop, engine-to-engine activity routing  
**Status:** implementation contract and sprint doctrine

## Purpose

The recursive campaign assist loop now has multiple engines that can observe or act:

- market intel
- map trade
- visible movement
- horse and capacity analysis
- smithing prep
- tavern hero intel and recruitment
- cohesion and threat scanning
- runner/finalization

The gap was not that these engines were absent. The gap was that their activity could be interpreted locally, then lost or over-claimed by the next engine. This contract codifies how each engine passes actionable behavior forward and how the governor observes, recommends, dictates, blocks, or finalizes activity.

## Core rule

```text
An engine may prove a local checkpoint.
Only the governor may decide what that checkpoint means for the recursive campaign cycle.
```

A movement engine can prove arrival. It cannot prove economic progress.

A trade engine can prove a buy delta. It cannot prove that food attrition, capacity, or smithing needs are now healthy unless those branches have fresh evidence.

A smithing engine can prove a refine or smelt checkpoint. It cannot prove full crafting unless the craft API and material/stamina deltas are proven.

A tavern engine can prove candidates or recruitment. It cannot silently replace trade, food, capacity, or threat decisions.

## Authority modes

| Mode | Meaning | Allowed claim |
|---|---|---|
| `ObservedOnly` | Engine reported fresh state or verified a delta | checkpoint only |
| `Recommended` | Engine suggests a branch, but governor has not dispatched it | advisory only |
| `Dictated` | Governor selected a branch and handed action to an engine | branch execution authorized |
| `Blocked` | Branch could not safely prove its required evidence | choose another branch or finalize blocked |
| `Terminal` | Runner finalized a declared stop condition | final run result only |

## Activity phases

| Phase | Meaning |
|---|---|
| `Observe` | read state, produce evidence |
| `Decide` | compare branch choices |
| `Dispatch` | send selected activity to target engine |
| `Execute` | target engine attempts bounded in-game action |
| `Verify` | before/after state proves or rejects action |
| `Block` | action cannot safely continue |
| `Finalize` | terminal evidence written exactly once |

## Branch vocabulary

| Branch | Required proof |
|---|---|
| `Travel` | source settlement, target settlement, movement command, arrival checkpoint |
| `Trade` | gold before/after, inventory before/after, non-fake trade iteration row |
| `Provision` | food variety, days remaining, projected weight, buy delta if executed |
| `HorseAcquisition` | capacity buffer before/after, pack-animal classification, gold/inventory delta |
| `SmithingPrep` | material before/after, stamina before/after, safe action or blocked reason |
| `TavernScan` | candidate list, companion capacity, safe gold reserve |
| `RecruitCompanion` | roster before/after, gold before/after, direct injection false |
| `ThreatAvoidance` | scan radius, hostile count, nearest hostile, selected fallback |
| `ObserveOnly` | state observed but no mutation allowed or no safe branch exists |
| `Stop` | terminal state, reason, final evidence, no next action required |

## Handoff object

The autonomous guild loop writes `governorActivityHandoffs` inside `BlacksmithGuild_AutonomousGuildLoop.json`.

Each row represents one passed activity:

```json
{
  "generatedUtc": "2026-06-26T00:00:00.0000000Z",
  "cycleId": 1,
  "sourceEngine": "Governor",
  "targetEngine": "MapTradeVisibleMovementDriver",
  "branch": "Travel",
  "phase": "Dispatch",
  "authority": "Dictated",
  "actionName": "TravelToTown",
  "observationSummary": "target=Ortysia",
  "gateVerdict": "governor_dispatch",
  "proofRequired": "source settlement, target settlement, movement command, arrival checkpoint",
  "evidenceFile": "BlacksmithGuild_AutonomousGuildLoop.json",
  "nextEngineHint": "wait for arrival then verify target state",
  "isCheckpoint": true,
  "isTerminal": false
}
```

## Passing activity from engine to engine

### Market to governor

Market intel observes towns, goods, prices, inventory, and smithing material shortfalls. It should hand observations to the governor, not dictate execution by itself.

The governor uses market evidence to choose among trade, provision, horse acquisition, smithing prep, tavern scan, threat avoidance, or observe-only.

### Governor to movement

The governor may dictate travel only after branch selection. Movement proof ends at arrival.

Arrival is a checkpoint. It is not economic completion.

### Governor to map trade

Map trade may execute a buy only when the branch proof requires a gold and inventory delta. A trade branch is not proven by travel, market scan, or visible UI traversal.

### Governor to horse/capacity

Horse acquisition is a distinct branch. It is selected when capacity buffer is below target or projected trade/provision weight would damage movement viability.

Pack animal purchase proof must include classification plus before/after gold and inventory delta. Future hardening should also compare capacity buffer before and after.

### Governor to smithing prep

Smithing prep may refine or smelt when material/stamina gates are satisfied. Full crafting remains manual until craft execution is proven by the same before/after discipline.

### Governor to tavern engines

Tavern scan is read-only. Recruitment is mutating and must prove roster and gold deltas, with direct injection false.

### Threat engines to governor

Threat scanning is radius-filtered game state, not a formal fog-of-war model. Unknown threat state must never be converted to safe. It should block, hold, duck to town, or observe-only according to policy.

## Anti-collapse rules

The governor contract prevents these bad renditions:

| Bad rendition | Required correction |
|---|---|
| Travel completed, therefore economy passed | classify as `Travel` checkpoint only |
| Trade driver probed, therefore trade passed | require gold and inventory delta |
| Pack animal recommended, therefore capacity improved | require pack-animal buy delta and projected capacity proof |
| Smithing candidate exists, therefore smithing done | require refine/smelt/craft delta by action type |
| Tavern candidate found, therefore companion acquired | require roster and gold delta |
| Hostiles not displayed, therefore route safe | require scan policy and radius evidence |
| Any checkpoint produced final PASS | reject as checkpoint-only pass attempt |

## Current implementation hook

`src/BlacksmithGuild/GuildLoop/GovernorActivityHandoff.cs` defines the shared C# contract.

`AutonomousGuildLoopService` appends `governorActivityHandoffs` while it moves through:

1. preflight
2. faction/threat posture
3. market scan
4. mission selection
5. cohesion check
6. travel dispatch
7. arrival checkpoint
8. trade or pack-animal buy verification/block
9. smithing prep handoff
10. finalization

This does not claim a full economic pass. It gives the next cert runner the machine-readable chain needed to decide whether the loop actually proved actionable behavior.

## Next required hardening

1. Add `ProvisionIntelService` and first-class `Provision` branch proof.
2. Add capacity snapshot before/after trade and food purchases.
3. Promote horse acquisition from advisory/probe into a required branch boundary.
4. Add branch consideration JSONL so blocked alternatives are visible.
5. Extend the economic-loop certifier to reject `TravelOnlyCert` as economic completion unless a proven trade iteration also exists.
6. Add local tests once a Bannerlord-mounted worktree is available.
