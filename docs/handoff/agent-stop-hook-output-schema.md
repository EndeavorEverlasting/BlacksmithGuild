# Agent Stop Hook Output Schema

## Purpose

The stop hook must produce a small, stable summary that agents can read before asking the operator for interpretation.

This document defines the planned output shape for:

```text
AgentStopHookSummary.json
```

The summary is archived under:

```text
artifacts/agent-stop-hook/<timestamp>/AgentStopHookSummary.json
```

## Minimum schema

```json
{
  "schema": "TbgAgentStopHookSummary.v1",
  "generatedUtc": "2026-07-05T21:30:00Z",
  "artifactDir": "artifacts/agent-stop-hook/20260705-213000",
  "classification": {
    "state": "checkpoint_reached",
    "confidence": "high",
    "reason": "Fresh command ACK was observed."
  },
  "blocking": false,
  "failedSteps": [],
  "feedbackPath": "BlacksmithGuild_AgentFeedback.json",
  "remediationPlanPath": "BlacksmithGuild_AgentRemediationPlan.json",
  "patchCandidateCount": 0,
  "nextAction": "Add agent stop hook runner",
  "requiredAgentReport": [
    "branch",
    "head SHA",
    "classification",
    "allowed claims",
    "forbidden claims",
    "blockers",
    "remediation plan path",
    "next action",
    "validation commands"
  ]
}
```

## Blocking rule

`blocking` must be true when any of the following is true:

```text
cheap guardrail failed
classification is runtime_blocked
classification is unsafe_surface
classification is contract_fail
```

## Patch candidate rule

If `patchCandidateCount` is greater than zero, the agent must not invent a separate repair first.

It must inspect the generated remediation plan and either use it or explain why it does not match the current evidence.

## Archive rule

The stop hook archive directory should contain:

```text
AgentStopHookSummary.json
BlacksmithGuild_AgentFeedback.json
BlacksmithGuild_AgentRemediationPlan.json, when planner output exists
one log per guardrail or generator step
```

## Report rule

The agent response after a hook run should be short and structured:

```text
branch/head
classification
blocking yes/no
allowed claims
forbidden claims
blockers
remediation plan
next action
validation
```

Raw logs are fallback evidence, not the default response.
