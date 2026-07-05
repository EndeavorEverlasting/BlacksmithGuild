# Agent Evidence Follow-Through Runbook

## Purpose

The feedback harness is not useful unless agents follow through with the evidence it generates.

This runbook defines what an agent should do after the stop-hook trigger produces feedback, remediation plans, and archived evidence.

## Required first read

After a stop-hook run, read these in order:

```text
1. artifacts/agent-stop-hook/<timestamp>/AgentStopHookSummary.json
2. BlacksmithGuild_AgentFeedback.json
3. BlacksmithGuild_AgentRemediationPlan.json, if present
4. step logs only if the summary is blocking or unclassified
```

## Report format

The next agent response must include:

```text
branch
head SHA
classification
blocking yes/no
allowed claims
forbidden claims
blockers
remediation plan path
next action
validation commands
```

Do not ask the operator what the logs mean until the generated feedback and remediation plan have been read.

## If classification is checkpoint_reached

Allowed:

```text
state the bounded checkpoint reached
state what it proves
state what it does not prove
continue to the next bounded sprint only if nextAction is clear
```

Forbidden:

```text
claim product completion
claim live runtime proof beyond the evidence
skip validation commands
```

## If classification is runtime_blocked

Required:

```text
read blockers
read remediation plan
if patchCandidates exist, inspect generated remediation scripts
state the exact blocker and the exact target seam
```

Allowed next action:

```text
use the generated remediation workflow
or explain why the generated plan is mismatched
```

Forbidden:

```text
start a broad refactor
change unrelated gameplay logic
claim route proof
ask the operator to restate the blocker already captured by the harness
```

## If classification is contract_fail

Required:

```text
read failedSteps
open the failed step log
fix only the relevant contract issue
rerun the stop hook or at least the failed verifier
```

Forbidden:

```text
move to runtime proof
claim the branch is ready
ignore failed deterministic guardrails
```

## If classification is stale_evidence

Required:

```text
identify which evidence is stale
rerun the bounded proof or regenerate feedback from fresh artifacts
```

Forbidden:

```text
close the sprint from stale files
copy old proof into a new claim
```

## If classification is unclassified

Required:

```text
add one narrow interpretation rule
or document why the available evidence cannot be classified
```

Forbidden:

```text
invent confidence
ask for broad human interpretation before checking artifacts
build a giant generalized parser
```

## Remediation plan rule

When `BlacksmithGuild_AgentRemediationPlan.json` contains patch candidates, the generated plan gets priority over hand-written patch instructions.

Agents may reject the generated plan only when they can name a concrete mismatch:

```text
wrong branch
wrong target file
oldText match count is not one
evidence no longer matches the blocker
scope is unsafe
```

## Evidence discipline

Every next action must name:

```text
evidence path
classification
allowed claim
forbidden claim
validation command
```

If any of those are missing, the agent has not completed the follow-through step.
