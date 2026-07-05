# Agent Feedback Harness Doctrine

## Purpose

The repo already produces many useful logs, JSON files, contract verifiers, and proof artifacts. The missing layer is not more raw logging. The missing layer is a harness that turns those artifacts into a clear sprint instruction an LLM can follow without asking the operator to interpret every line.

This doctrine defines that harness.

The goal is to make repo feedback legible to agents:

```text
artifact evidence
  -> normalized interpretation
  -> blocker or checkpoint classification
  -> next sprint instruction
  -> bounded validation command list
```

This is doctrine and harness-planning only. It does not claim runtime proof, does not mutate saves, and does not authorize autonomous gameplay.

## Core problem

Current repo feedback is rich, but scattered:

```text
Launch.log
Forge.log
Phase1.log
Status.json
RuntimeLifecycle.json
CommandAck.json
CommandInbox.json
MarketIntel.json
SmithingAudit.json
contract verifier output
PowerShell parse checks
git diff --check
git status --short
proof artifact folders
```

Agents can read these, but often fail to convert them into the next correct sprint. The human operator should not have to explain the meaning of every proof artifact after the repo already produced it.

## Harness definition

The feedback harness is a repo-specific interpretation layer around the agent.

It is not a generic agent brain.

It is the app-specific body that tells the agent:

```text
which artifacts matter
how to classify them
which claims are allowed
which claims are forbidden
what next action is implied
what validation must run before closure
```

The agent can reason in English, but the repo must supply disciplined English-shaped evidence. That is the bridge.

## Required output surface

The harness should eventually produce:

```text
BlacksmithGuild_AgentFeedback.json
```

Minimum shape:

```json
{
  "schema": "TbgAgentFeedback.v1",
  "generatedUtc": "2026-07-05T18:15:00Z",
  "repoState": {
    "branch": "feat/example",
    "headSha": "abcdef0",
    "statusShort": "clean"
  },
  "classification": {
    "state": "checkpoint_reached",
    "confidence": "high",
    "reason": "Fresh command ACK and refreshed audit were observed."
  },
  "evidence": [
    {
      "path": "BlacksmithGuild_CommandAck.json",
      "kind": "runtime_ack",
      "fresh": true,
      "summary": "ProbeSmithingAudit succeeded."
    }
  ],
  "allowedClaims": [
    "runtime command bridge accepted ProbeSmithingAudit",
    "SmithingAudit refreshed after command ACK"
  ],
  "forbiddenClaims": [
    "autonomous campaign loop complete",
    "smithing automation proven",
    "save mutation proven"
  ],
  "nextSprint": {
    "title": "Add MarketJournal append from MarketIntel",
    "branchHint": "feat/market-journal-outcome",
    "scope": "read-only market memory and engine outcome handoff",
    "firstFiles": [
      "docs/handoff/market-journal-doctrine.md",
      "src/BlacksmithGuild/Market/MarketJournalService.cs"
    ]
  },
  "validation": [
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\verify-agent-feedback-harness-contract.ps1",
    "git diff --check",
    "git status --short"
  ]
}
```

## Classification states

Allowed high-level states:

```text
checkpoint_reached
checkpoint_blocked
contract_pass
contract_fail
runtime_ready
runtime_blocked
operator_action_required
unsafe_surface
stale_evidence
unclassified
```

Meaning:

| State | Meaning |
|---|---|
| `checkpoint_reached` | A bounded proof point completed, but product completion is not claimed. |
| `checkpoint_blocked` | A bounded proof point failed or stopped with a clear blocker. |
| `contract_pass` | Static/verifier contract passed. No runtime proof implied. |
| `contract_fail` | Static/verifier contract failed and needs repair. |
| `runtime_ready` | Runtime surface is actionable for a bounded command. |
| `runtime_blocked` | Runtime surface exists but cannot accept the intended command. |
| `operator_action_required` | Human action or approval is required. |
| `unsafe_surface` | Automation should stop for safety. |
| `stale_evidence` | Evidence exists but is too old or mismatched to support a claim. |
| `unclassified` | Harness cannot safely interpret the artifacts yet. |

## Claim discipline

The harness must separate:

```text
what happened
what that proves
what it does not prove
what should happen next
```

Example:

```text
Fresh ProbeSmithingAudit ACK proves the command bridge accepted and completed that read-only command.
It does not prove smithing automation, resource mutation, market action, travel, or campaign loop completion.
```

No sprint output may claim more than the evidence supports.

## Input artifact families

The harness should know these artifact families:

```text
launcher
runtime readiness
command bridge
market
smithing
campaign outcome
verifier
git/worktree
proof bundle
```

Each family needs a small interpretation rule.

Example:

```text
CommandAck.json with a fresh sequence and result=Success supports command_bridge_checkpoint.
CommandInbox.json missing after ACK is not a blocker if the command was consumed and ACK is fresh.
```

## Sprint instruction rule

The harness should produce a next sprint instruction that is:

```text
bounded
branchable
file-aware
validation-aware
claim-aware
```

Minimum sprint instruction fields:

```json
{
  "title": "Add MarketJournal append from MarketIntel",
  "branchHint": "feat/market-journal-outcome",
  "problem": "MarketIntel overwrites latest state but does not preserve historical observations.",
  "scope": "read-only market journal and outcome handoff only",
  "nonGoals": [
    "automatic buying",
    "automatic selling",
    "travel automation",
    "save mutation"
  ],
  "firstFiles": [
    "docs/handoff/market-journal-doctrine.md",
    "src/BlacksmithGuild/Market/MarketJournalService.cs"
  ],
  "validation": [
    "dotnet build src\\BlacksmithGuild\\BlacksmithGuild.csproj -c Release",
    "git diff --check",
    "git status --short"
  ]
}
```

## Agent behavior contract

Future agents must do this before proposing code:

```text
1. Read the latest harness feedback if present.
2. Read the referenced evidence artifacts.
3. State allowed claims and forbidden claims.
4. Choose one bounded next sprint.
5. Name the target branch or worktree.
6. Name validation commands.
7. Avoid asking the operator to reinterpret evidence already classified by the harness.
```

## Relationship to campaign orchestration

Campaign orchestration decides which gameplay engine should act next.

Agent feedback harness decides which development sprint should happen next.

They are related but not identical:

```text
CampaignOrchestrator = in-game engine handoff
AgentFeedbackHarness = repo feedback to next coding sprint
```

Do not collapse them into one system.

## First implementation slice

Recommended first implementation slice:

```text
1. Codify this doctrine.
2. Add the feedback classification schema.
3. Add a verifier that checks doctrine anchors.
4. Add a future sprint target for a script that summarizes known logs into BlacksmithGuild_AgentFeedback.json.
```

Do not start with full log parsing.

First build the shape, then automate extraction.

## Future implementation targets

Suggested future files:

```text
scripts/write-agent-feedback-summary.ps1
scripts/verify-agent-feedback-harness-contract.ps1
src/BlacksmithGuild/DevTools/AgentFeedback/AgentFeedbackSnapshot.cs
src/BlacksmithGuild/DevTools/AgentFeedback/AgentFeedbackWriter.cs
```

The first script can be PowerShell and repo-side. Runtime C# can come later if needed.

## Safety boundary

The harness may recommend a sprint. It must not silently merge PRs, mutate saves, run live certs, or claim gameplay automation completion.

It exists to reduce operator interpretation burden, not to remove evidence discipline.
