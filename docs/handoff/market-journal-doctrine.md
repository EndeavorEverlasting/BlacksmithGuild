# Market Journal Doctrine

## Purpose

Market intel should not only overwrite the latest snapshot. It should also build a durable history of observed market changes.

The mod needs long-term market memory for:

```text
price trends
stock volatility
best hardwood towns
best sell routes
market recovery timing
profit memory
route planning
future data analysis
```

This document defines the market journal doctrine.

This is doctrine only. It does not implement market purchase, sale, travel, or save mutation.

## Core rule

Every meaningful market observation should write two surfaces:

```text
latest snapshot
append-only journal
```

Latest snapshot answers:

```text
What is true now?
```

Journal answers:

```text
What changed over time?
```

## Output surfaces

Existing or planned latest snapshot:

```text
BlacksmithGuild_MarketIntel.json
```

Planned append-only journal:

```text
BlacksmithGuild_MarketJournal.jsonl
```

Optional future derived summary:

```text
BlacksmithGuild_MarketInsights.json
```

## JSONL row shape

Each observed item should append one JSON object per line:

```json
{
  "schema": "TbgMarketJournalRow.v1",
  "runId": "campaign-20260705-053000",
  "sequence": 12,
  "generatedUtc": "2026-07-05T09:30:05Z",
  "settlement": "Onira",
  "item": "Hardwood",
  "stock": 13,
  "price": 26,
  "source": "market_intel_snapshot",
  "phase": "pre_action",
  "engine": "Market"
}
```

If a prior row exists for the same settlement and item, a future implementation may add deltas:

```json
{
  "schema": "TbgMarketJournalRow.v1",
  "runId": "campaign-20260705-053000",
  "sequence": 13,
  "generatedUtc": "2026-07-05T09:40:22Z",
  "settlement": "Onira",
  "item": "Hardwood",
  "stock": 9,
  "price": 31,
  "source": "post_trade_snapshot",
  "phase": "post_action",
  "engine": "Market",
  "deltaStock": -4,
  "deltaPrice": 5,
  "previousObservedUtc": "2026-07-05T09:30:05Z"
}
```

## Observation phases

Allowed initial phases:

```text
pre_action
post_action
passive_observation
startup_snapshot
operator_probe
```

Meaning:

| Phase | Meaning |
|---|---|
| `pre_action` | Market state before a trade, smithing, or travel decision. |
| `post_action` | Market state after an action that could affect stock or price. |
| `passive_observation` | Read-only market observation. |
| `startup_snapshot` | Market state captured during startup or readiness check. |
| `operator_probe` | Market state captured by explicit operator command. |

## Append-only rule

`BlacksmithGuild_MarketJournal.jsonl` should be append-only during normal operation.

Do not rewrite old rows during gameplay.

Do not compact the journal inside live campaign action code.

Future offline tools may create derived summaries, but they should preserve raw observations.

## Freshness rule

A market journal row should be considered fresh only if:

```text
campaignReady=true
settlement is known
item identity is known
stock or price is known
row timestamp is current to the observation
```

Rows with incomplete data may be written only if marked:

```text
partial=true
reason=<clear reason>
```

## Engine outcome relationship

The Market engine should write an outcome after journaling:

```text
MarketIntel snapshot written
MarketJournal rows appended
CampaignEngineOutcome written
CampaignRunState updated
```

The Market engine may recommend next actions such as:

```text
Smithing, if local materials enable refining or crafting
Travel, if another town has better stock or price
HorseMarket, if animals are available and policy allows inspection
operator_action_required, if trade would mutate state under Manual mode
```

## First implementation slice

Recommended first implementation:

```text
1. Keep existing BlacksmithGuild_MarketIntel.json behavior.
2. Add MarketJournalService.
3. Append JSONL rows from the same data used by MarketIntel.
4. Add simple deltas when previous same settlement/item row is available.
5. Write CampaignEngineOutcome with nextAction recommendation.
```

Do not implement automatic buying in the same first slice.

Memory before mutation.

## Data analysis use cases

Future offline analysis can answer:

```text
Which towns usually stock hardwood?
Which towns have stable low prices?
How quickly does stock recover after purchase?
Which routes repeatedly produce profitable spreads?
Which items should never be bought at current location?
Which observations are stale?
```

## Safety boundary

Market journaling is read-only unless attached to a separately authorized trade action.

Writing a journal row does not prove a trade happened.

A trade requires separate action evidence:

```text
command ack
pre-action market snapshot
post-action market snapshot
inventory or gold delta
CampaignEngineOutcome status=state_changed
```

## File-size boundary

The journal may grow. That is acceptable in the short term.

Future derived tools may roll summaries into:

```text
BlacksmithGuild_MarketInsights.json
```

But live action code should prefer appending raw facts over replacing history.

## Relationship to engine authority

Manual mode:

```text
journal and recommend only
```

Hybrid mode:

```text
journal automatically, trade only by explicit command
```

Automation mode:

```text
journal automatically, bounded trade may be allowed if future policy and evidence permit
```

Automation permission is not proof of profitable or safe trade.
