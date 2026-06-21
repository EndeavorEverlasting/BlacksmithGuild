# 005E Plan — Smithing Posse Stamina & Output Automation

## Status

**UNBLOCKED (2026-06-21)** — Launcher cert gate closed. Implementation may proceed after optional Stage B / guild loop smoke.

| Gate | Status |
|------|--------|
| 006I launcher cert | **CLOSED** — Path A, Continue, Path C USER PASS; Path B waived |
| 005E Stage A audit | **SHIPPED** — `ProbeSmithingAudit` → `BlacksmithGuild_SmithingAudit.json` |
| Stage C headless refine | **USER PASS** 2026-06-20 |
| 005E Stages B–D automation | **NEXT** — see [pre-blacksmith-automation-handoff.md](../checkpoints/pre-blacksmith-automation-handoff.md) |

## Purpose

Automate the player's blacksmithing party as a coordinated forge crew.

The goal is not simply to craft one profitable weapon. The goal is to maximize sustainable forge output across the whole party while preserving material reserves, stamina, and decision quality.

The party should eventually behave like a mobile blacksmithing guild:

- main smith
- order smith
- smelter
- charcoal refiner
- material refiner
- stamina reserve
- buyer / quartermaster
- guard / escort

The mod should eventually reason over:

```text
who should act
what they should do
when they should rest
which materials must be protected
which orders are worth taking
when the forge loop should stop
```

## Design principle

The forge economy should behave like a crew system, not a button spam machine.

Bad behavior:

```text
Use the first available character.
Spend all charcoal.
Burn rare steel on bad orders.
Ignore stamina distribution.
Accept every order.
Rest blindly.
```

Desired behavior:

```text
Pick the right smith for the action.
Rotate workers by stamina.
Protect reserve materials.
Prefer useful orders.
Use low-skill companions for refining/smelting.
Use high-skill smiths for orders and valuable crafts.
Rest only when output is exhausted or the next action is worth waiting for.
Explain every decision.
```

## Player fantasy

The player becomes the head of a mobile blacksmithing guild.

The party is not just soldiers. It is a workshop on horseback.

```text
"You smelt.
You make charcoal.
You handle the noble order.
You rest.
You guard the road.
We leave when reserves are stable."
```

## Core loop

```text
Inspect party
→ inspect stamina
→ inspect smithing skills/perks
→ inspect inventory
→ inspect orders
→ assign best worker/action
→ protect reserves
→ execute or recommend action
→ rest when useful
→ repeat
```

## Worker profile

Each eligible party member should eventually be evaluated as a forge worker.

Fields to reason about:

```text
Hero
Smithing skill
Endurance / smithing focus if available
Relevant perks
Current stamina
Maximum stamina if readable
Known role
Best use
Risk of wasting skill
```

Possible roles:

```text
MainSmith
OrderSmith
Smelter
CharcoalRefiner
MaterialRefiner
Apprentice
ReserveWorker
NonSmith
```

## Stamina doctrine

The system should avoid exhausting the wrong worker.

Doctrine examples:

```text
Use low-skill workers for charcoal/refining.
Save high-skill smith stamina for difficult orders.
Use main smith only when output value justifies it.
Rest when no useful worker can perform the next priority action.
Do not rest if useful low-value actions remain.
```

Open questions before implementation:

```text
Can Bannerlord v1.4.6 expose smithing stamina per hero safely?
Can stamina be read without smithy UI automation?
Can selected crafting hero be changed through game APIs?
Can action execution be done safely without UI clicking?
If not, should this feature begin as advisory-only?
```

## Inventory reserve doctrine

This feature must not burn the forge stockpile blindly.

Reserve candidates:

```text
Hardwood
Charcoal
Crude iron
Wrought iron
Iron
Steel
Fine steel
Thamaskene steel
Smeltable weapons
Crafted weapons reserved for sale
Crafted weapons reserved for party equipment
```

Reserve rules:

```text
Never spend below charcoal floor unless action is critical.
Never consume last premium metal on low-value order.
Prefer charcoal creation when charcoal is below floor.
Prefer smelting when metal stock is low.
Prefer buying hardwood when hardwood is low.
Prefer selling crafted overflow when carrying too much weight.
```

## Order doctrine

Crafting orders should be scored instead of accepted blindly.

Score inputs:

```text
Reward
Difficulty
Required weapon type
Expected material cost
Expected stamina cost
Required smith skill
Part unlock value
Relation value
Risk of failure
Reserve breach risk
```

Basic decision:

```text
Accept if:
- expected reward is worth material + stamina cost
- assigned smith can reasonably complete it
- reserve policy is not breached
- order advances unlocks, relations, or doctrine goals

Reject/defer if:
- it consumes scarce material
- it blocks better work
- smith skill is too low
- reward is bad
- it would collapse charcoal or premium metal reserve
```

## Worker assignment doctrine

| Action                         | Preferred worker                    |
| ------------------------------ | ----------------------------------- |
| Charcoal refining              | Low-skill worker with charcoal perk |
| Smelting                       | Curious Smelter / apprentice        |
| Low-tier refining              | Apprentice / refiner                |
| High-tier refining             | Refiner with efficient perks        |
| High-value craft               | Main smith                          |
| Noble order                    | Highest-skill order smith           |
| Experimental craft for unlocks | Worker with unlock perk             |
| Equipment craft                | Best smith available                |

## Output maximization

Useful output includes:

```text
Gold profit
Order completion
Part unlocks
Smithing XP
Material conversion
Party equipment improvement
Reserve stabilization
Relation gains
```

Avoid optimizing only gold.

Possible priorities:

```text
ProfitFirst
UnlockFirst
OrdersFirst
ReserveFirst
EquipmentFirst
BalancedGuild
```

Initial default:

```text
BalancedGuild
```

## Recommended staged implementation

### Stage A — Read-only forge audit

No mutation.

Output a report:

```text
Forge audit:
- party smiths
- stamina status if available
- best worker roles
- inventory bottlenecks
- current reserve health
- order candidates
- recommended next action
```

Acceptance:

```text
Press dev hotkey or run command.
Log shows ranked worker/action recommendations.
No inventory/gold/stamina mutation.
No UI automation.
```

### Stage B — Advisory doctrine

Still no automatic action execution.

The mod explains:

```text
Best next action:
- Actor: <hero>
- Action: <smelt/refine/craft/order/rest/buy>
- Reason: <plain explanation>
- Reserve impact: <safe/risky/blocked>
```

Acceptance:

```text
Recommendation changes when stamina or inventory changes.
Charcoal shortage produces refine/buy recommendation.
Premium material shortage blocks bad orders.
```

### Stage C — Safe automation seam

Only after API safety is proven.

Possible automation targets:

```text
Select worker
Choose refine/smelt/craft action
Execute safe action
Stop before reserve breach
Stop when no useful stamina remains
Recommend rest
```

Acceptance:

```text
The system performs only actions it can explain.
Every action logs actor, reason, cost, reserve result.
No action spends below reserve.
No action uses main smith for mule work unless explicitly allowed.
```

### Stage D — Rest-cycle optimizer

Automate the daily rhythm:

```text
Forge until useful stamina exhausted.
Recommend or trigger rest.
Resume after stamina recovery.
Stop after configured cycles.
```

Acceptance:

```text
Complete 3 rest cycles without:
- running out of charcoal
- consuming protected steel/fine steel
- accepting bad orders
- assigning wrong worker
- losing explanation trace
```

## Logging requirements

Every recommendation or action must log:

```text
[TBG FORGE] worker=<hero> role=<role> stamina=<current/max>
[TBG FORGE] action=<action> target=<item/order/material>
[TBG FORGE] reason=<reason>
[TBG FORGE] reserve before=<summary>
[TBG FORGE] reserve after=<summary>
[TBG FORGE] decision=<accept/reject/defer/rest>
```

Blocked action log:

```text
[TBG FORGE] blocked: <action> reason=<reserve/stamina/skill/material/order-risk>
```

## Initial test scenario

Manual setup:

```text
Town with smithy
3 to 5 companions
100 hardwood
50 charcoal
20 crude iron
20 wrought iron
20 iron
10 steel
10 fine steel
10 smeltable weapons
Several available crafting orders
```

Test objective:

```text
Can The Blacksmith Guild maintain a forge loop for 3 rest cycles without:
- running out of charcoal
- consuming protected steel/fine steel
- accepting a bad order
- assigning the wrong smith
- failing to explain the decision
```

## Open technical questions

Before coding, inspect Bannerlord v1.4.6 APIs for:

```text
How to read smithing stamina per hero.
How to identify current selected smithing hero.
Whether smithing actions can be executed without UI clicking.
How orders are represented in CampaignSystem.
How material inventory is represented.
How crafted weapon value and required materials are calculated.
Whether part unlock state is exposed.
Whether companion smithing perks are readable.
```

## Files to inspect before implementation

Start with existing project files:

```text
src/BlacksmithGuild/
src/BlacksmithGuild/Behaviors/
src/BlacksmithGuild/DevTools/
src/BlacksmithGuild/Models/
```

Search terms:

```text
Forge
Smith
Craft
Inventory
Material
Reserve
Doctrine
Order
Treasury
Candidate
Hero
Companion
```

Do not assume file names. Inspect current repo state before implementation planning.

## Non-goals

This stage does not include:

```text
Smithy UI clicking
Gold mutation
Inventory mutation without explicit doctrine approval
Cheat-style material generation
Tutorial skip
Launcher automation
Character creation
Profile system
Unbounded crafting loops
```

## Definition of done for this plan

```text
- This file exists under docs/plans/
- Launcher cert gate CLOSED (2026-06-21) — implementation UNBLOCKED
- Stages A–C shipped; Stage D read-only rest plan shipped
- Stage B Tier-1 cert: USER PASS 2026-06-21 (Danustica map)
- Next agent implements 005E posse/stamina slice per pre-blacksmith-automation-handoff.md
```
