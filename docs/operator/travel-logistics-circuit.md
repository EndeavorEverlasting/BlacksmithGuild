# Travel Logistics Circuit Doctrine

## Purpose

Travel is the spine of the automation. Food, horses, trade, companion recruitment, smithing, town use, and route selection only become reliable after movement, interruption recovery, arrival detection, and town transition behavior are reliable.

This doctrine prevents future sprints from treating trade, food, horses, companions, smithing, and route optimization as independent features. They are linked currencies in one circuit.

## Correct development order

1. Travel must work.
2. Travel must resume after manual intervention.
3. Arrival must be detected.
4. Town mechanics must run before leaving.
5. Market trade must run before logistics checks.
6. Food must be checked after the market pass and before departure.
7. Horses and capacity must be checked after food and before route commitment.
8. Tavern companion recruitment must run before smithing when useful, legal, and affordable.
9. Smithing should use available companion stamina before the town is considered exhausted.
10. Route selection should choose the next town that maximizes profit after town utility is exhausted.

## Core rule

Do not optimize routes before travel works.

Do not treat smithing as ready until the town hierarchy has checked trade, food, horses, tavern recruitment, and companion stamina.

Do not select the next destination before the current town has been exhausted in the correct order.

## Circuit of currencies

The campaign loop is a movement economy. Each branch consumes or enables another branch.

- Travel consumes time, food, and safety margin.
- Trade converts inventory into gold and gold into profitable goods.
- Food is checked after the market pass so departure readiness is based on the post-trade inventory and gold state.
- Horses and pack animals are checked after food so capacity and route speed are based on the post-trade, food-secured party state.
- Tavern companions are checked before smithing because companions add stamina pools and early earning power.
- Smithing consumes stamina and materials, and may create gold through legal in-game outputs.
- Cargo capacity determines whether the next trade route is worth taking.
- Speed determines whether travel is safe enough to continue or escape.
- Town utility determines whether the party should leave or exhaust local mechanics first.
- Inventory pressure determines whether to sell, buy, smelt, refine, dump, rest, or move.

## Intended branch order

The governor and assistive runner should reason in this order:

1. If the current state is unsafe or non-actionable, classify the state.
2. If the game requires human input, suspend into `manual_intervention_pending` with resume criteria.
3. If the party is on the campaign map and travel-safe, continue movement toward the current target.
4. If arrival is detected, stop treating the job as travel.
5. If in town, execute the town utility hierarchy before choosing the next route.
6. Sell profitable or pressure-inducing goods.
7. Buy profitable trade goods when the market pass supports it.
8. Check food after the trade pass.
9. Check horses and carrying capacity after food.
10. Visit the tavern when companion recruitment is useful, legal, and affordable.
11. Recruit the companion when the decision is favorable and the cost can be paid.
12. Refresh the smithing stamina picture after recruitment.
13. Use available player and companion stamina for smithing.
14. Smith, refine, and smelt when mechanically legal and useful.
15. Only after town utility is exhausted should the governor select the next town that maximizes profit.

## Manual intervention resume

Manual intervention is not automatically a terminal failure. Encounters, looters, hostile parties, modal prompts, or user-directed movement can create a recoverable pause.

The expected recoverable state is:

```text
manual_intervention_pending
```

A recoverable manual-intervention handoff should include:

- reason
- current surface
- last planned branch
- target settlement, if any
- user action needed
- resume allowed when
- resume command or future command
- evidence path
- next owner

The desired behavior is:

```text
AI controls travel
-> encounter or manual-risk state appears
-> automation suspends with a classified handoff
-> user resolves the immediate danger or prompt
-> automation reacquires campaign state
-> automation resumes the previous branch or selects the next legal branch
```

## Arrival before town mechanics

Arrival is a branch transition. Once arrival is detected, the system should stop proving travel and begin town utility evaluation.

Town utility must run in this order:

1. Trade sell
2. Trade buy
3. Food check
4. Horse and capacity check
5. Tavern visit
6. Companion recruitment
7. Smithing stamina refresh
8. Use companion stamina for smithing
9. Smith, refine, and smelt
10. Select the next town that maximizes profit

## Companion recruitment before smithing

Companion recruitment belongs before smithing in the town hierarchy.

A companion recruitment pass should:

1. Visit the tavern when the town is safe and the party can afford a useful recruit.
2. Identify the recruitable hero.
3. Skip or shorten conversation flow where the game allows it.
4. Pay the real recruitment cost.
5. Verify the companion joined the party.
6. Refresh smithing stamina and party capability.
7. Use companion stamina for smithing only after the companion exists in the party.

No implementation may fake a companion, bypass the cost, invent stamina, or mutate the party outside legal game mechanics.

## What counts as travel proof

Travel proof should not rely on one metric alone.

Useful evidence may include:

- movement command acknowledged
- campaign clock running
- movement intent set
- party position delta
- distance-to-target delta
- settlement departure
- settlement arrival
- route target change
- movement checkpoint observed
- movement metric disagreement classified as useful proof

`partyMovedDistance == 0` alone is not proof that movement did not occur. Movement may be discrete, checkpoint-based, reset between samples, or sampled too early/late.

## What remains blocked until travel and town hierarchy work

The following work should remain downstream until travel, resume, arrival, and ordered town utility are reliable:

- food automation beyond the post-trade check
- horse buying and pack capacity decisions beyond the post-food check
- tavern companion recruitment execution
- companion stamina allocation
- trade buying and selling loops beyond first safe market pass
- route profit optimization
- town exhaustion optimization
- multi-town economic loops

## Product principle

Local harnesses should iterate and generate context. AI should patch named gaps, not babysit repeated retries.

Travel must become reliable enough that higher-level logistics can depend on it, and town utility must exhaust the current town before the next route is selected.
