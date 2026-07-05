# Default Guardrails

## Purpose

The Blacksmith Guild now has enough individual guardrails that they need a single whole-app map.

This document is the app guardrail constitution. It defines the default protections that should apply across repo hygiene, evidence claims, agent workflow, runtime safety, gameplay domains, and architecture.

The core questions are:

```text
What can act?
When can it act?
What evidence proves it acted?
What claims are allowed?
What must stop the agent?
What generates the next repair?
What must never be automated silently?
```

## Guardrail layers

Default guardrails are grouped into six layers:

```text
1. Repo hygiene guardrails
2. Evidence and claim guardrails
3. Agent workflow guardrails
4. Runtime and game-state guardrails
5. Domain automation guardrails
6. Architecture and orchestration guardrails
```

Each mature guardrail should have:

```text
doctrine doc
manifest
verifier
trigger point
allowed claims
forbidden claims
next action behavior
```

## Layer 1: Repo hygiene guardrails

Repo hygiene guardrails are cheap deterministic checks.

Already present or partially present:

```text
UTF-8 BOM checks
PowerShell parse checks
git diff hygiene
contract verifier scripts
duration/default timeout doctrine
patch hygiene expectations
```

Missing defaults:

```text
byte-safe text replacement helper
patch scope declaration
worktree cleanliness policy
source-versus-artifact dirty-state rule
```

Default rule:

```text
A patch is not clean until the diff shows only intentional source changes and git diff hygiene passes.
```

## Layer 2: Evidence and claim guardrails

Evidence guardrails prevent proof inflation.

Default proof ladder:

```text
Build PASS
Verifier PASS
Static PASS
Runtime PASS
Visible PASS
Product PASS
```

Required distinctions:

```text
Build PASS does not imply Runtime PASS.
Verifier PASS does not imply Runtime PASS.
Runtime ACK does not imply product completion.
Launcher handoff does not imply automation success.
A checkpoint is progress, not completion.
```

Every evidence artifact should eventually carry:

```text
branch
head SHA
run ID
timestamp
fresh/stale classification
source command or trigger
supported claims
unsupported claims
```

Default rule:

```text
No artifact can close a sprint if it predates the current relevant code change.
```

## Layer 3: Agent workflow guardrails

Agent workflow guardrails reduce repeated human interpretation.

Current direction:

```text
BlacksmithGuild_AgentFeedback.json
BlacksmithGuild_AgentRemediationPlan.json
AgentStopHookSummary.json
allowedClaims
forbiddenClaims
blockers
nextAction
```

Default agent rule:

```text
If the harness can classify evidence, the agent must not ask the operator to classify it.
```

Stop-hook default:

```text
At the end of a bounded agent task, the repo should produce feedback, remediation planning, and a summary artifact before the next agent response.
```

## Layer 4: Runtime and game-state guardrails

Runtime guardrails protect zero-click proofs, disposable saves, and readiness claims.

Default distinctions:

```text
game_spawned != attach_ready
attach_ready != command_bridge_ready
command_bridge_ready != assistive_ready
assistive_ready != automation_success
automation_allowed != runtime proof
```

Manual input contamination rule:

```text
Any interactive prompt during a zero-click proof contaminates the proof and must classify as a harness blocker or operator-action-required state.
```

Disposable save rule:

```text
Every live proof should declare save name, disposable status, mutation boundary, and expected evidence.
```

## Layer 5: Domain automation guardrails

Domain guardrails protect actual Bannerlord consequences.

Required domain defaults:

| Domain | Default guardrail |
|---|---|
| Market | Snapshot before action, append journal, prove gold/inventory delta after action. |
| Smithing | Prove stamina/material delta and cap each bounded action. |
| Travel | Prove start, destination, position or checkpoint, and time evidence. |
| Progression | Recommend first; no silent irreversible choices. |
| Companion | No recruitment without policy, cost, and consequence evidence. |
| Horses | No purchase without policy, price, inventory, and gold delta. |
| Risk | Unsafe surface stops downstream action. |
| Governor | Multi-engine sequencing belongs to the orchestrator. |

Default rule:

```text
Automate the hands, not the consequences.
```

## Layer 6: Architecture and orchestration guardrails

Architecture guardrails prevent autonomous soup.

Default engine rules:

```text
Engines recommend next actions.
The orchestrator dispatches next actions.
Authority gates actions.
Evidence proves actions.
```

Default forbidden pattern:

```text
Engine A directly chains into Engine B without CampaignEngineOutcome and authority review.
```

Required future guardrails:

```text
EngineToggleAuthority enforcement
CampaignEngineOutcome requirement
no direct engine-to-engine chaining
orchestrator-owned dispatch
mode-aware assistive readiness
bounded one-action windows
```

## Highest-priority missing guardrails

The most important missing guardrails are:

```text
scripts/invoke-agent-stop-hook.ps1
proof claim discipline verifier
byte-safe text replacement helper
runtime contamination classifier
campaign action evidence schema implementation
campaign engine boundary verifier
```

## Completion rule

The guardrail map is not complete because this document exists.

It becomes useful only when the repo can answer:

```text
Which guardrail applies?
What did it observe?
What did it prove?
What did it not prove?
What should happen next?
What must stop?
```
