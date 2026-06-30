# Travel Logistics Circuit Doctrine

## Purpose

Travel is the spine of the automation. Food, horses, trade, smithing, town use, and route selection only become reliable after movement, interruption recovery, arrival detection, and town transition behavior are reliable.

This doctrine prevents future sprints from treating trade, food, horses, and route optimization as independent features. They are linked currencies in one circuit.

## Correct development order

1. Travel must work.
2. Travel must resume after manual intervention.
3. Arrival must be detected.
4. Town mechanics must run before leaving.
5. Food must be checked before route commitment.
6. Horses and capacity must be checked before trade commitment.
7. Trade should run only when the logistics circuit supports it.
8. Route selection should optimize after the loop is reliable.

## Core rule

Do not optimize trade before travel works.

Do not optimize route selection before the party can reliably leave, move, resume, arrive, use the town, and decide whether it is safe and profitable to leave again.

## Circuit of currencies

The campaign loop is a movement economy. Each branch consumes or enables another branch.

- Travel consumes time, food, and safety margin.
- Food requires buying, looting, or other acquisition.
- Buying requires gold.
- Gold comes from trade, smithing, loot, quests, or other lawful gameplay mechanics.
- Trade requires cargo capacity and a route worth taking.
- Cargo capacity requires horses or pack animals.
- Horses require gold, availability, and sometimes route risk.
- Speed determines whether travel is safe enough to continue or escape.
- Town utility determines whether the party should leave or exhaust local mechanics first.
- Inventory pressure determines whether to sell, buy, smelt, refine, dump, rest, or move.

## Intended branch order

The governor and assistive runner should reason in this order:

1. If the current state is unsafe or non-actionable, classify the state.
2. If the game requires human input, suspend into `manual_intervention_pending` with resume criteria.
3. If the party is on the campaign map and travel-safe, continue movement toward the current target.
4. If arrival is detected, stop treating the job as travel.
5. If in town, exhaust town mechanics before choosing the next route.
6. If food is low, prioritize food acquisition before route commitment.
7. If horses or cargo capacity are insufficient, account for that before buying trade goods.
8. Sell profitable goods or reduce inventory pressure before buying more.
9. Buy trade goods only when food, gold, cargo capacity, route risk, and destination logic support it.
10. Run smithing, refining, smelting, or rest only when mechanically legal and useful.
11. Only after town utility is exhausted should the governor select or commit to the next travel target.

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

Town utility should include, in this order:

1. Food check
2. Horse and capacity check
3. Sell or dump inventory pressure
4. Buy trade goods only when supported by the circuit
5. Smith, refine, smelt, or rest when useful and legal
6. Decide next route only after local utility is exhausted

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

## What remains blocked until travel works

The following work should remain downstream until travel, resume, and arrival are reliable:

- food automation
- horse buying and pack capacity decisions
- trade buying and selling loops
- route profit optimization
- town exhaustion optimization
- multi-town economic loops

## Product principle

Local harnesses should iterate and generate context. AI should patch named gaps, not babysit repeated retries.

Travel must become reliable enough that higher-level logistics can depend on it.
