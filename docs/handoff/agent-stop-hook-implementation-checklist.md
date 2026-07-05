# Agent Stop Hook Implementation Checklist

## Purpose

This checklist describes the remaining executable trigger work without pretending the trigger is complete.

The contract already names the required script:

```text
scripts/invoke-agent-stop-hook.ps1
```

Until that file exists and passes the verifier, PR #31 must remain draft.

## Required behavior

The stop hook must:

```text
create artifacts/agent-stop-hook/<timestamp>/
run cheap repo guardrails
capture each step result as a log
run the feedback writer
run the remediation planner when available
copy generated JSON outputs into the archive folder
write AgentStopHookSummary.json
print a short summary
return a blocking status when strict mode is requested and blocking evidence exists
```

## Required inputs

The hook should support:

```text
FailOnBlocking
SkipPlanner
NoPlannerScripts
ArtifactRoot override
```

## Required outputs

The hook should write or archive:

```text
BlacksmithGuild_AgentFeedback.json
BlacksmithGuild_AgentRemediationPlan.json, when planner is available
AgentStopHookSummary.json
step logs for each cheap guardrail
```

## Cheap guardrails

Initial cheap guardrails:

```text
verify-agent-feedback-harness-contract
verify-agent-feedback-writer-contract
verify-agent-remediation-planner-contract
UTF-8 BOM contract
git diff check
git status short
```

## Blocking classifications

The hook must treat these classifications as blocking:

```text
runtime_blocked
unsafe_surface
contract_fail
```

## First local implementation strategy

Recommended local implementation sequence:

```text
1. Create scripts/invoke-agent-stop-hook.ps1 with only repo-local script calls.
2. Archive step outputs under artifacts/agent-stop-hook/<timestamp>/.
3. Call write-agent-feedback-summary.ps1.
4. Call write-agent-remediation-plan.ps1 when available.
5. Write AgentStopHookSummary.json.
6. Run verify-agent-stop-hook-contract.ps1.
7. Run the stacked verifier chain.
```

## Non-goals for first implementation

Do not include:

```text
network calls
background execution
live runtime certification
repo mutation
merge behavior
large log parsing framework
Semgrep integration
```

## Completion rule

This slice is complete only when:

```text
scripts/invoke-agent-stop-hook.ps1 exists
verify-agent-stop-hook-contract passes
stop hook creates AgentStopHookSummary.json in an artifact directory
feedback JSON is archived
remediation JSON is archived when planner exists
blocking status is represented honestly
```
