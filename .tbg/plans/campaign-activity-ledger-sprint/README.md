# Campaign Activity Ledger Sprint Plan

## Goal

Add a lightweight activity ledger that lets the mod remember meaningful player behavior without making runtime planning slow.

The listener should observe travel, trade, companions, recruits, smithing, inventory, gold, and planning choices. It should record both what happened and how that differed from app-generated plans.

## Product objective

The app should be able to answer in plain English:

```text
The app suggested X.
The user did Y instead.
This happened repeatedly.
The planner should change Z.
```

## Files this sprint should eventually implement

Runtime outputs:

```text
BlacksmithGuild_ActivityJournal.jsonl
BlacksmithGuild_ActivityState.json
BlacksmithGuild_RecentActivity.json
BlacksmithGuild_PlanLedger.jsonl
BlacksmithGuild_PlanComparisons.jsonl
BlacksmithGuild_FeatureSignals.jsonl
BlacksmithGuild_ActivityReport.md
```

Repo contracts:

```text
docs/architecture/campaign-activity-ledger.md
.tbg/workflows/campaign-activity-ledger.contract.json
.tbg/plans/campaign-activity-ledger-sprint/README.md
```

## Implementation sequence

1. Define C# event models.
2. Add append-only JSONL writer.
3. Add bounded recent activity writer.
4. Add compact rolling activity state writer.
5. Add plan ledger writer.
6. Add plan comparison writer.
7. Add feature signal writer.
8. Add English markdown report writer.
9. Wire meaningful events from travel/trade/smithing/recruitment/companion seams.
10. Add workflow summarizer that reads compact outputs, not huge logs.

## Runtime performance rule

Normal campaign tick should read only:

```text
ActivityState.json
RecentActivity.json
```

Do not scan full `ActivityJournal.jsonl` during normal planning.

## Initial meaningful event targets

Start narrow:

```text
plan_proposed
travel_command_issued
route_started
arrival_observed
market_purchase
market_sale
smithing_action
companion_hired
recruits_hired
manual_override
plan_rejected_implicit
plan_behavior_comparison
feature_signal
```

Do not log every tick.

## Comparative behavior examples

### Route plan rejected by behavior

```text
Plan: travel to Quyaz.
Observed afterward: user stayed near Onira, bought hardwood, and refined charcoal.
Interpretation: user may prefer local smithing loop over long-distance trade.
Feature signal: add planner weights for smithing supply, distance, and route novelty.
```

### Recruit plan rejected by behavior

```text
Plan: recruit available troops.
Observed afterward: user skipped recruitment across several settlements.
Interpretation: user may be preserving wages or avoiding low-tier troops.
Feature signal: add wage pressure and troop-quality filters.
```

### Companion plan rejected by behavior

```text
Plan: hire companion.
Observed afterward: user inspected but did not hire companions with certain skills or costs.
Interpretation: planner lacks companion value/cost preference model.
Feature signal: add companion role, wage, culture, and skill preference filters.
```

## English report requirement

Every report should answer:

```text
What did the app propose?
What did the user do afterward?
Was the plan accepted, rejected, ignored, or overridden?
What pattern appeared?
What should the next patch change?
```

## Acceptance artifact

Future workflow should emit:

```text
artifacts/latest/campaign-activity-ledger.result.json
```

Minimum PASS target:

```json
{
  "verdict": "PASS",
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

## Stop rule

Static contract work does not require stopping Bannerlord.

Runtime implementation or live validation does require the stop guardrail:

```powershell
$env:FORGE_NO_PAUSE = '1'
.\ForgeStop.cmd soft
```

## Next patch hint

The first code PR should probably add `CampaignActivityLedger` under a runtime-safe services namespace, with append-only writers and bounded recent/state outputs before wiring all gameplay domains.
