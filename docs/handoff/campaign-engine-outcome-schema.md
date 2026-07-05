# Campaign Engine Outcome Schema

## Purpose

Every campaign engine must report its result in the same shape before another engine is allowed to act.

The project now has multiple engine families:

```text
Travel
Market
Smithing
Companion
HorseMarket
Progression
Risk
Governor
GuildLoop
Assistive
```

Without a shared outcome shape, each engine invents its own meaning for success, blocked state, evidence, and next action. That makes handoff brittle and lets agents confuse a checkpoint with product completion.

This document defines the shared outcome contract future implementation should use.

This is doctrine and schema planning only. It does not claim runtime proof.

## Core rule

Each engine gets one bounded action window.

After that action window, it must write an outcome that says:

```text
what engine ran
what it observed
what it changed
what evidence it wrote
what should run next
whether the run may continue
```

No engine should directly chain into another engine without writing an outcome first.

## Required outcome fields

Minimum JSON shape:

```json
{
  "schema": "TbgCampaignEngineOutcome.v1",
  "runId": "campaign-20260705-053000",
  "sequence": 12,
  "engine": "Market",
  "mode": "Hybrid",
  "startedUtc": "2026-07-05T09:30:00Z",
  "completedUtc": "2026-07-05T09:30:05Z",
  "status": "checkpoint_completed",
  "campaignReady": true,
  "location": {
    "settlement": "Onira",
    "isTown": true
  },
  "action": {
    "name": "market_snapshot",
    "stateChanged": false,
    "description": "Captured market state and appended journal rows."
  },
  "evidence": {
    "files": [
      "BlacksmithGuild_MarketIntel.json",
      "BlacksmithGuild_MarketJournal.jsonl"
    ],
    "freshUtc": "2026-07-05T09:30:05Z"
  },
  "nextAction": {
    "engine": "Smithing",
    "reason": "Hardwood available and charcoal shortfall detected.",
    "priority": 70,
    "requiresOperator": false
  },
  "terminal": false,
  "nextActionRequired": true
}
```

## Status values

Allowed statuses:

```text
checkpoint_completed
checkpoint_blocked
action_taken
state_changed
unsafe_surface
operator_action_required
terminal_stop
```

Meaning:

| Status | Meaning |
|---|---|
| `checkpoint_completed` | The engine completed a non-mutating observation or bounded checkpoint. |
| `checkpoint_blocked` | The engine could not run, but it produced a clear reason and evidence. |
| `action_taken` | The engine performed a bounded action. State may or may not have changed. |
| `state_changed` | The engine performed a bounded action and confirmed fresh state change evidence. |
| `unsafe_surface` | The current surface is unsafe for automation. Stop or ask operator. |
| `operator_action_required` | The next step requires user action or explicit approval. |
| `terminal_stop` | The run intentionally ended. No next action should be taken. |

## Engine names

Initial engine keys:

```text
Governor
Travel
Market
Smithing
Companion
HorseMarket
Progression
Risk
GuildLoop
Assistive
```

These names should align with `EngineToggleAuthority` where possible.

If an engine is not represented in authority yet, add it deliberately. Do not invent shadow names in runtime JSON.

## Handoff rule

Only the orchestrator chooses the next engine.

Engines may recommend next actions, but they do not own the campaign loop.

Correct:

```text
MarketEngine writes nextAction=Smithing
CampaignOrchestrator reads outcome
CampaignOrchestrator checks authority and readiness
CampaignOrchestrator dispatches SmithingEngine if allowed
```

Incorrect:

```text
MarketEngine directly calls SmithingEngine
SmithingEngine directly calls TravelEngine
TravelEngine directly calls CompanionEngine
```

That creates autonomous soup. No soup.

## Completion rule

A checkpoint is not completion.

`checkpoint_completed` means progress. It does not mean the product path has succeeded.

A run is complete only when:

```text
terminal=true
status=terminal_stop
nextActionRequired=false
```

or when an explicit failure or operator-required state stops the run.

## Evidence rule

Every outcome must reference fresh evidence.

Examples:

```text
BlacksmithGuild_CommandAck.json
BlacksmithGuild_Status.json
BlacksmithGuild_MarketIntel.json
BlacksmithGuild_MarketJournal.jsonl
BlacksmithGuild_SmithingAudit.json
BlacksmithGuild_CampaignRunState.json
BlacksmithGuild_CampaignOutcome.json
```

An outcome without fresh evidence is only a claim.

## Authority rule

The orchestrator must check authority before acting on `nextAction`.

Mode meaning:

```text
Manual    = recommend only, no autonomous act
Hybrid    = explicit-command actions allowed
Automation = bounded higher-order actions allowed
```

Automation permission is not runtime proof.

## Future implementation targets

Recommended file targets:

```text
src/BlacksmithGuild/Campaign/CampaignEngineOutcome.cs
src/BlacksmithGuild/Campaign/CampaignEngineStatus.cs
src/BlacksmithGuild/Campaign/CampaignNextAction.cs
src/BlacksmithGuild/Campaign/CampaignRunStateService.cs
scripts/verify-campaign-engine-outcome-contract.ps1
```

Do not implement full autonomous behavior in the first schema sprint.

First useful implementation slice:

```text
MarketIntel
  -> MarketJournal append
  -> CampaignEngineOutcome
  -> nextAction recommendation
```

## Safety boundary

This schema does not authorize save mutation, perk selection, market purchase, travel, smithing, or companion recruitment by itself.

It defines the reporting contract those systems must use before future automation is allowed to coordinate them.
