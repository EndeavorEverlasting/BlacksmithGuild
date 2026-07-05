# Agent Feedback Schema

## Purpose

This document defines the schema that turns repo evidence into sprint-ready feedback for LLM coding agents.

The schema is intentionally close to plain English, because the consumer is usually an LLM. It is also structured JSON, because agents need stable keys and not vibes.

This is doctrine and schema planning only. It does not implement the writer.

## Planned file

```text
BlacksmithGuild_AgentFeedback.json
```

This file should be generated from logs, JSON artifacts, verifier output, and worktree state.

## Minimum schema

```json
{
  "schema": "TbgAgentFeedback.v1",
  "generatedUtc": "2026-07-05T18:15:00Z",
  "source": {
    "kind": "repo_artifact_analysis",
    "tool": "write-agent-feedback-summary.ps1"
  },
  "repoState": {
    "branch": "feat/example",
    "headSha": "abcdef0",
    "statusShort": "clean",
    "untrackedPolicy": "ignored_artifacts_allowed"
  },
  "runtimeState": {
    "known": true,
    "campaignReady": true,
    "hotkeysReady": true,
    "commandBridgeReady": true
  },
  "classification": {
    "state": "checkpoint_reached",
    "confidence": "high",
    "reason": "Fresh command ACK and refreshed SmithingAudit were observed."
  },
  "evidence": [],
  "allowedClaims": [],
  "forbiddenClaims": [],
  "blockers": [],
  "nextSprint": {},
  "validation": []
}
```

## Evidence item schema

```json
{
  "path": "BlacksmithGuild_CommandAck.json",
  "kind": "runtime_ack",
  "fresh": true,
  "observedUtc": "2026-07-05T09:11:17Z",
  "summary": "ProbeSmithingAudit returned Success with fresh sequence.",
  "supports": [
    "command_bridge_checkpoint"
  ],
  "doesNotSupport": [
    "autonomous_campaign_completion",
    "smithing_resource_mutation"
  ]
}
```

## Artifact kinds

Allowed initial artifact kinds:

```text
launch_log
forge_log
phase1_log
status_json
runtime_lifecycle_json
command_ack
command_inbox
market_intel
market_journal
smithing_audit
campaign_outcome
contract_verifier
powershell_parse_check
git_status
git_diff_check
proof_bundle
```

## Claim fields

The schema must include both:

```text
allowedClaims
forbiddenClaims
```

Reason: agents overclaim when only success evidence is presented.

Allowed claim example:

```text
Fresh ProbeSmithingAudit ACK proves read-only command bridge execution.
```

Forbidden claim example:

```text
This does not prove autonomous smithing or campaign loop completion.
```

## Blocker schema

```json
{
  "kind": "runtime_blocked",
  "severity": "blocking",
  "summary": "Safe Mode modal detected and not declined.",
  "evidencePath": "BlacksmithGuild_Launch.log",
  "recommendedFix": "Decline Safe Mode modal during frozen navigation, then watch for game_spawned."
}
```

Allowed blocker severities:

```text
info
warning
blocking
unsafe
```

## Next sprint schema

```json
{
  "title": "Add MarketJournal append from MarketIntel",
  "branchHint": "feat/market-journal-outcome",
  "problem": "MarketIntel overwrites latest state but does not preserve historical observations.",
  "scope": "Read-only market memory and engine outcome handoff.",
  "nonGoals": [
    "automatic buying",
    "automatic selling",
    "travel automation"
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

## Confidence values

Allowed confidence values:

```text
low
medium
high
```

Confidence should be high only when the evidence is fresh and directly supports the classification.

## Freshness doctrine

Evidence should be marked stale when:

```text
timestamp predates current run
branch/headSha does not match current worktree
a proof bundle is older than the latest relevant code change
runtime file exists but was not updated during the current proof
```

A stale artifact can inform the next sprint, but it cannot close one.

## Validation field

Validation commands should be copy-ready and branch-specific.

Do not emit validation that belongs to another PR unless explicitly marked as integration validation.

## Non-goals

The schema does not replace logs.

It summarizes logs into LLM-usable feedback.

Raw evidence should remain available for audit.
