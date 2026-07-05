# Progression Policy Doctrine

## Purpose

Skill upgrades and perk choices are campaign consequences.

The mod must not silently spend skill choices just because automation is running.

This document defines how future progression automation should recommend, stage, and eventually apply skill upgrades.

This is doctrine only. It does not implement perk selection and does not claim runtime proof.

## Core rule

Progression decisions must be policy-driven.

Default behavior:

```text
Manual    = recommend only
Hybrid    = recommend by default, apply only by explicit command
Automation = apply only if a whitelist policy exists and the choice is evidence-backed
```

No mode should silently guess irreversible perk choices.

## Output surfaces

Planned policy file:

```text
BlacksmithGuild_ProgressionPolicy.json
```

Planned recommendation file:

```text
BlacksmithGuild_ProgressionRecommendations.json
```

Planned outcome file:

```text
BlacksmithGuild_CampaignOutcome.json
```

## Policy shape

Minimum policy shape:

```json
{
  "schema": "TbgProgressionPolicy.v1",
  "mode": "Hybrid",
  "defaultBehavior": "recommend_only",
  "skills": {
    "Smithing": {
      "autoApply": false,
      "preferredPerks": [
        "EfficientCharcoalMaker",
        "SteelMaker"
      ],
      "fallback": "operator_action_required"
    },
    "Trade": {
      "autoApply": false,
      "preferredPerks": [
        "Appraiser",
        "WholeSeller"
      ],
      "fallback": "operator_action_required"
    },
    "Riding": {
      "autoApply": false,
      "preferredPerks": [],
      "fallback": "recommend_only"
    }
  }
}
```

Perk identifiers above are examples. Implementation must use actual game identifiers discovered from runtime or safe metadata.

Do not hardcode guessed identifiers as proof.

## Recommendation shape

Minimum recommendation shape:

```json
{
  "schema": "TbgProgressionRecommendation.v1",
  "generatedUtc": "2026-07-05T09:30:05Z",
  "campaignReady": true,
  "hero": {
    "name": "",
    "isMainHero": true
  },
  "pendingChoices": [
    {
      "skill": "Smithing",
      "level": 25,
      "choices": [
        {
          "perk": "EfficientCharcoalMaker",
          "rank": 1,
          "reason": "Supports charcoal production and smithing economy."
        },
        {
          "perk": "CuriousSmelter",
          "rank": 2,
          "reason": "Alternative unlock path, lower priority for current trade-smith loop."
        }
      ],
      "recommendedPerk": "EfficientCharcoalMaker",
      "policyAction": "recommend_only",
      "requiresOperator": true
    }
  ]
}
```

## Authority behavior

### Manual

Manual mode must never apply a progression choice.

Allowed:

```text
probe available choices
write recommendations
show operator message
write CampaignEngineOutcome status=operator_action_required
```

Forbidden:

```text
apply perk
spend focus point
spend attribute point
change build path
```

### Hybrid

Hybrid mode may apply a progression choice only through an explicit command.

Allowed command shape:

```text
ApplyProgressionPolicyNow
```

Required evidence:

```text
policy loaded
pending choice found
chosen perk matches policy
command ack written
post-action recommendation no longer lists the same pending choice
CampaignEngineOutcome written
```

### Automation

Automation mode may eventually apply a progression choice only when:

```text
policy autoApply=true for that skill
chosen perk is explicitly whitelisted
choice is reversible or accepted as policy consequence
fresh pending-choice evidence exists
post-action evidence confirms result
```

If any of those are missing, Automation still degrades to recommendation.

## Progression engine role

The Progression engine should run early in the orchestrator candidate order.

Reason:

```text
perk choices may change trade, smithing, riding, and survival strategy
```

But running early does not mean applying choices early.

Initial behavior should be:

```text
observe pending choices
write recommendation
write outcome
hand off or stop
```

## First implementation slice

Recommended first implementation:

```text
1. Probe available perk / skill upgrade choices.
2. Write BlacksmithGuild_ProgressionRecommendations.json.
3. Write CampaignEngineOutcome.
4. In Manual and Hybrid, stop with operator_action_required if a pending irreversible choice exists.
5. Do not implement auto-apply in the first slice.
```

This creates visibility without spending consequences.

## Future commands

Planned command names:

```text
ProbeProgressionChoices
RecommendProgressionPolicy
ApplyProgressionPolicyNow
```

`ApplyProgressionPolicyNow` must require explicit policy and explicit authority allowance.

## Evidence requirements

A progression PASS requires:

```text
fresh pre-action pending-choice evidence
policy file or default recommend-only behavior
command ack if an action was requested
fresh post-action evidence
CampaignEngineOutcome with status and nextAction
```

A recommendation PASS is not an application PASS.

An application PASS is not a build-quality PASS.

An automation permission PASS is not a visible runtime PASS.

## Relationship to market and smithing

Progression policy may influence future choices, for example:

```text
Smithing perk preference changes charcoal/refining priorities
Trade perk preference changes buy/sell evaluation
Riding perk preference changes horse acquisition priority
Steward or Charm choices may change companion or party policy
```

But progression must not directly call those engines.

It should return a `CampaignEngineOutcome` with a nextAction recommendation.

## Safety boundary

Skill and perk choices are player-agency decisions.

The default doctrine is recommendation first.

Auto-apply belongs in a later branch only after:

```text
policy format exists
recommendations are proven
operator can inspect choices
authority gating is wired
evidence proves post-action state
```

No silent build doctor. No mystery perk goblin.
