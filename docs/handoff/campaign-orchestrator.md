# Campaign Orchestrator Doctrine

## Purpose

The launcher can get the mod to a live runtime, and the engine authority can govern Manual / Hybrid / Automation mode. The missing layer is a campaign orchestrator that decides which engine should act next.

This doctrine defines that layer.

The orchestrator is the campaign operating loop. It coordinates bounded work across travel, market, smithing, companion, horse acquisition, progression, risk checks, and future engines.

This document is doctrine only. It does not implement automation and does not claim runtime proof.

## Product target

The product path is:

```text
observe
  -> decide
  -> act once
  -> record evidence
  -> write outcome
  -> choose next engine
  -> stop or hand off
```

The product path is not:

```text
click around until something useful happens
```

That is haunted spaghetti. Do not build haunted spaghetti.

## Core principle

One engine may perform one bounded action window, then it must yield.

The orchestrator owns sequencing.

Engines own domain work.

Authority owns whether action is allowed.

Evidence owns proof.

## Initial engines

Initial orchestrated engine set:

```text
Risk
Progression
Market
Smithing
Travel
HorseMarket
Companion
GuildLoop
Governor
Assistive
```

A future implementation may add or remove engines, but engine names must stay aligned with `EngineToggleAuthority` and the campaign outcome schema.

## Responsibilities

### Orchestrator

The orchestrator must:

```text
read current campaign state
read latest status and evidence
read engine authority mode
ask candidate engines for eligibility
choose one bounded next action
write CampaignRunState
invoke or recommend the action
record the outcome
stop or hand off
```

### Engine

Each engine must:

```text
inspect only its domain
refuse unsafe or unauthorized work
perform at most one bounded action window
write fresh evidence
return CampaignEngineOutcome
recommend, not command, the next engine
```

### Authority

Engine authority must decide whether the recommended action is allowed:

```text
Manual    = recommend only
Hybrid    = explicit-command action allowed
Automation = bounded higher-order action allowed
```

No engine may bypass authority because its action seems harmless.

## Run state

The orchestrator should maintain:

```text
BlacksmithGuild_CampaignRunState.json
```

Minimum shape:

```json
{
  "schema": "TbgCampaignRunState.v1",
  "runId": "campaign-20260705-053000",
  "mode": "Hybrid",
  "sequence": 12,
  "lastEngine": "Market",
  "lastCheckpoint": "market_snapshot_written",
  "lastOutcomeStatus": "checkpoint_completed",
  "nextEngine": "Smithing",
  "nextReason": "Hardwood available and charcoal shortfall detected.",
  "terminal": false,
  "nextActionRequired": true,
  "updatedUtc": "2026-07-05T09:30:05Z"
}
```

## Candidate order

Default candidate order should be conservative:

```text
1. Risk
2. Progression
3. Market
4. Smithing
5. Travel
6. HorseMarket
7. Companion
8. GuildLoop
```

Reasoning:

- Risk runs first because unsafe surfaces should stop the loop.
- Progression runs early because pending skill upgrades may alter what is efficient or possible.
- Market runs before smithing because smithing depends on material availability and price.
- Smithing runs before travel when local profitable or preparatory work exists.
- Travel runs when local action is exhausted or another location has better opportunity.
- Horse and companion engines are opportunistic, not default drivers.
- GuildLoop remains a higher-level planner, not a free pass around bounded engine outcomes.

## First implementation slice

The first useful slice should be small:

```text
MarketIntel
  -> MarketJournal append
  -> CampaignEngineOutcome
  -> CampaignRunState update
  -> nextAction recommendation
```

Do not begin by trying to automate every engine.

The first slice should prove that the mod can remember market state and produce a clean handoff recommendation.

## Handoff examples

### Market to smithing

```json
{
  "engine": "Market",
  "status": "checkpoint_completed",
  "action": {
    "name": "market_snapshot",
    "stateChanged": false
  },
  "nextAction": {
    "engine": "Smithing",
    "reason": "Hardwood is available and charcoal reserve is below target.",
    "priority": 70,
    "requiresOperator": false
  }
}
```

### Smithing to travel

```json
{
  "engine": "Smithing",
  "status": "checkpoint_blocked",
  "action": {
    "name": "refine_charcoal",
    "stateChanged": false
  },
  "blocker": {
    "reason": "No hardwood available in party inventory."
  },
  "nextAction": {
    "engine": "Travel",
    "reason": "Nearest town with affordable hardwood should be selected.",
    "priority": 65,
    "requiresOperator": false
  }
}
```

### Progression to operator recommendation

```json
{
  "engine": "Progression",
  "status": "operator_action_required",
  "action": {
    "name": "recommend_skill_upgrade",
    "stateChanged": false
  },
  "nextAction": {
    "engine": "Progression",
    "reason": "Perk choices are irreversible and current policy is recommend-only.",
    "priority": 90,
    "requiresOperator": true
  }
}
```

## Stop conditions

The orchestrator must stop when:

```text
authority mode is Manual and action would mutate state
risk engine reports unsafe_surface
required evidence is stale or missing
operator approval is required
terminal objective is reached
runtime readiness is lost
save mutation boundary is uncertain
```

## Non-goals

Do not use this doctrine to smuggle in:

```text
free gold
free resources
fake XP
silent perk selection
unbounded travel
unbounded trade loops
unbounded smithing loops
save mutation without evidence
runtime PASS claims from launcher evidence
```

Automate the hands, not the consequences.

## Validation targets

Future verifier should check:

```text
docs/handoff/campaign-orchestrator.md exists
docs/handoff/campaign-engine-outcome-schema.md exists
CampaignRunState schema text exists
Manual / Hybrid / Automation handoff rules exist
checkpoint != completion doctrine exists
engine direct-call prohibition exists
first implementation slice is MarketIntel -> MarketJournal -> Outcome -> RunState
```

Suggested future script:

```text
scripts/verify-campaign-orchestrator-doctrine.ps1
```

## Relationship to PR #23

PR #23 defines shared engine authority.

This doctrine defines the future orchestration layer that must obey that authority.

It belongs with PR #23 as planning doctrine, but implementation should happen in a later branch after PR #23 and PR #25 are stable.

## Canonical campaign loop

observe -> decide -> act once -> record evidence -> write outcome -> choose next engine -> stop or hand off

This loop is intentionally one-action-at-a-time. A route owner may not treat command ACK or route assignment as completion. It must write an outcome before the next engine acts.
