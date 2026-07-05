# Campaign Action Evidence Schema

## Purpose

Gameplay automation needs a standard way to prove actual campaign actions.

AgentFeedback proves repo and agent workflow state. CampaignActionEvidence proves in-game action state.

Do not collapse them.

## Planned output

```text
BlacksmithGuild_CampaignActionEvidence.json
```

## Minimum schema

```json
{
  "schema": "TbgCampaignActionEvidence.v1",
  "generatedUtc": "2026-07-05T22:00:00Z",
  "runId": "campaign-20260705-220000",
  "branch": "feat/example",
  "headSha": "abcdef0",
  "engine": "Market",
  "action": "market_snapshot",
  "mode": "Hybrid",
  "authorityAllowed": true,
  "preState": {},
  "actionRequested": {},
  "actionResult": {},
  "postState": {},
  "delta": {},
  "evidenceFiles": [],
  "allowedClaims": [],
  "forbiddenClaims": [],
  "nextAction": {},
  "terminal": false
}
```

## Required fields

Every action evidence file must include:

```text
schema
generatedUtc
runId
engine
action
mode
authorityAllowed
preState
actionRequested
actionResult
postState
delta
evidenceFiles
allowedClaims
forbiddenClaims
nextAction
terminal
```

## Domain-specific evidence

### Market

Required evidence:

```text
settlement
item
pre stock
pre price
post stock when action mutates market
post price when action mutates market
gold delta when buy or sell happens
inventory delta when buy or sell happens
journal row appended
```

### Smithing

Required evidence:

```text
hero
stamina before
stamina after
material inventory before
material inventory after
smithing action requested
smithing action result
one-action cap honored
```

### Travel

Required evidence:

```text
start settlement or position
destination
map time before
map time after
position or checkpoint delta
route intent
route status
```

### Progression

Required evidence:

```text
hero
pending choice before
policy decision
choice applied or recommendation only
pending choice after when applied
operator requirement when irreversible
```

### Companion

Required evidence:

```text
candidate
location
cost or condition
policy allowance
party state before
party state after
```

### Horse market

Required evidence:

```text
animal
price
inventory before
inventory after
gold before
gold after
policy allowance
```

## Claim rules

CampaignActionEvidence must always say:

```text
what this action proves
what this action does not prove
what evidence is required next
```

Example:

```text
A market snapshot proves market observation.
It does not prove buying, selling, travel, or smithing.
```

## Relationship to CampaignEngineOutcome

CampaignActionEvidence is action-level proof.

CampaignEngineOutcome is engine-level handoff.

Correct flow:

```text
CampaignActionEvidence
  -> CampaignEngineOutcome
  -> CampaignRunState
  -> next engine recommendation
```

## Safety boundary

A domain action is not proven by intent, config, or command request alone.

A domain action requires fresh pre/post evidence or a clear non-mutating action classification.
