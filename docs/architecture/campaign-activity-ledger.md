# Campaign Activity Ledger

## Purpose

The Blacksmith Guild needs a repo-owned memory layer for meaningful player and automation activity.

The goal is not to create another giant log that agents struggle to interpret. The goal is to capture useful gameplay events, compare app plans against what the user actually does afterward, and turn repeated divergence into planner improvements.

## Core doctrine

```text
Append meaningful events.
Summarize old history.
Read only hot state during runtime.
Track both actions and rejected plans.
Compare proposed plans against what the user does next.
Write English reports that an agent can act on without asking the user to translate logs.
Emit feature signals when repeated divergence shows the app is making bad or unwanted plans.
```

## Problem this fixes

The app should not repeatedly ask the user or developer to explain what happened.

Bad loop:

```text
planner proposes action
user does something else
raw logs become large
agent cannot tell what happened
user explains the same behavior again
next patch starts from rediscovery
```

Correct loop:

```text
planner proposes action
listener records meaningful player actions
a compact comparison summarizes plan vs actual behavior
English report explains the contrast
a feature signal names the planner weakness
next patch starts from the signal, not from chat memory
```

## Non-goals

Do not log every campaign tick.

Do not parse a giant JSON document during normal planning.

Do not force the runtime planner to scan a week of history.

Do not require the user to translate raw event logs for the next agent.

## Event domains

The listener should record meaningful events across gameplay domains:

| Domain | Example events |
|---|---|
| Travel | route selected, travel command issued, route started, arrival observed, route blocked |
| Trade | market opened, item bought, item sold, price observed, profit/loss observed |
| Companions | companion inspected, companion hired, companion skipped |
| Recruits | troop recruits inspected, recruits hired, recruits skipped |
| Smithing | smithy opened, material refined, weapon crafted, stamina consumed, stamina recovered |
| Inventory | item gained, item consumed, item sold, capacity pressure observed |
| Gold | gold delta, purchase cost, sale revenue |
| Planning | plan proposed, plan accepted, plan rejected, plan ignored, manual override |
| Feature signals | repeated rejection, repeated manual override, planner/user mismatch |

## Storage model

Do not use one giant JSON array as the primary store.

Use layered artifacts:

```text
BlacksmithGuild_ActivityJournal.jsonl
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
BlacksmithGuild_PlanLedger.jsonl
BlacksmithGuild_PlanComparisons.jsonl
BlacksmithGuild_FeatureSignals.jsonl
BlacksmithGuild_ActivityReport.md
```

### ActivityJournal.jsonl

Append-only long-term event journal.

Each line is one JSON object. This allows cheap appends and tail reads without rewriting or reparsing the whole file.

Example:

```json
{"utc":"2026-07-06T19:10:00Z","type":"route_selected","targetSettlement":"Quyaz","reason":"engine_selected_destination"}
{"utc":"2026-07-06T19:10:04Z","type":"travel_command_issued","targetSettlement":"Quyaz","success":true}
{"utc":"2026-07-06T19:14:20Z","type":"arrival_observed","settlement":"Quyaz"}
```

### ActivityState.json

Small rolling state safe for runtime reads.

Example:

```json
{
  "schema": "TbgActivityState.v1",
  "lastUpdatedUtc": "2026-07-06T19:14:20Z",
  "recentSettlement": "Quyaz",
  "lastRouteTarget": "Quyaz",
  "lastRouteStarted": true,
  "recentFailures": [],
  "recentPlanFeedback": {
    "avoidRepeatedSuggestions": []
  }
}
```

### RecentActivity.json

Bounded hot window of recent useful events.

The live planner may read this during planning. It should not grow without bound.

Example:

```json
{
  "schema": "TbgRecentActivity.v1",
  "maxEvents": 50,
  "events": []
}
```

### PlanLedger.jsonl

Append-only record of proposed plans and plan outcomes.

Example:

```json
{"utc":"2026-07-06T19:10:00Z","type":"plan_proposed","planId":"plan-20260706-001","domain":"trade_route","proposal":"Travel to Quyaz to pursue a trade opportunity.","targetSettlement":"Quyaz","confidence":0.72}
{"utc":"2026-07-06T19:12:00Z","type":"plan_rejected_implicit","planId":"plan-20260706-001","reason":"user_chose_different_action","observedAction":"entered_market_at_Onira"}
```

### PlanComparisons.jsonl

Append-only comparison of proposed plan vs observed behavior after the plan.

Example:

```json
{"type":"plan_behavior_comparison","planId":"plan-20260706-001","plannedBehavior":"travel_to_Quyaz","observedBehavior":["bought_hardwood_at_Onira","refined_charcoal","remained_near_Onira"],"comparison":"user_preferred_local_smithing_loop_over_long_distance_trade_route","featureSignal":"planner_should_weight_smithing_supply_and_distance_more_heavily"}
```

### FeatureSignals.jsonl

Append-only backlog hints emitted from repeated behavior patterns.

Example:

```json
{"type":"feature_signal","source":"plan_feedback","domain":"trade","signal":"user_repeatedly_rejects_high_profit_trade_routes","hypothesis":"Planner is optimizing profit while user may prefer smithing materials, nearby towns, safety, or novelty.","nextPatchHint":"Add planner preference weights for profit, distance, safety, smithing supply, and user blacklist."}
```

### ActivityReport.md

Human- and agent-readable English report.

This is not a raw log. It should explain what happened and why it matters.

Example:

```markdown
## Recent Player Pattern

The app suggested travel to Quyaz.
The player did not go there.
Over the next observed actions, the player stayed near Onira, bought hardwood, and used smithing.

Interpretation:
The planner may be overvaluing long-distance trade and undervaluing local smithing supply, travel distance, or player preference.

Recommended next patch:
Add planner preference weights for smithing supply, travel distance, repeated rejection, and route novelty.
```

## Runtime read rule

The game runtime should usually read only:

```text
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
last N lines of JSONL when explicitly needed
```

The runtime planner must not scan a week of full history during normal campaign ticks.

Long history belongs to summarizers, reports, and development workflows.

## Write rule

The event listener should write only meaningful events.

Allowed examples:

```text
campaign ready
map ready
settlement entered
route selected
travel command issued
route started
arrival observed
route blocked
market opened
item bought
item sold
companion hired
companion skipped
recruits hired
recruits skipped
smithing action
stamina delta
gold delta
inventory delta
plan proposed
plan accepted
plan rejected
manual override
feature signal emitted
```

Forbidden default behavior:

```text
write every tick
rewrite full history on every event
scan full journal in campaign tick
emit raw logs without English interpretation
```

## Comparative behavior window

After a plan is proposed, the ledger should watch what the player does next.

Comparison windows may be based on:

```text
next N meaningful events
next in-game day
next session
next real-world day
next several in-game days for longer trade/route plans
```

The comparison should answer:

```text
What did the app propose?
What did the user do instead?
Was the plan accepted, ignored, rejected, or overridden?
What pattern emerged?
What feature or planner rule should change?
```

## Plan rejection and divergence

One rejection is a choice.

Repeated rejection is a product signal.

If the app keeps proposing a plan and the user repeatedly declines, ignores, reverses, or chooses a different pattern, the ledger should emit a feature signal.

Examples:

```text
user repeatedly rejects routes to Quyaz
user repeatedly chooses smithing supply over long-distance trade
user repeatedly avoids hiring recruits of a suggested type
user repeatedly ignores companion suggestions
user repeatedly sells items the planner wanted to keep
```

## English-first reporting doctrine

Every activity report should be readable by a developer or future agent without requiring the user to explain it.

Bad:

```text
[RouteBrain] branch=travel safe=true next=Quyaz ack=false activeReport=null
```

Good:

```text
The route planner selected Quyaz and the campaign map was safe for travel, but no route started because the runtime did not issue a travel command from campaign tick.
```

Better:

```text
The app wanted to send the player to Quyaz. The player did not go there. Over the next three observed actions, the player stayed near Onira, bought hardwood, and used smithing. This suggests the planner may be overvaluing long-distance trade and undervaluing smithing materials or travel distance.
```

## Acceptance for implementation PR

The first implementation PR should add:

```text
Activity event schema
append-only JSONL writer
bounded RecentActivity writer
compact ActivityState writer
PlanLedger event writer
PlanComparison writer
FeatureSignal writer
English ActivityReport writer
runtime read boundary tests
```

Minimum implementation acceptance:

```json
{
  "activity": {
    "journalAppendOnly": true,
    "recentWindowBounded": true,
    "runtimeReadsBoundedState": true,
    "planComparisonsWritten": true,
    "englishReportWritten": true,
    "featureSignalsWritten": true
  }
}
```

## Working principle

The app should not only ask:

```text
Did the user obey the plan?
```

It should ask:

```text
What did the user do instead, what does that teach the planner, and how do we make the next plan less annoying?
```
