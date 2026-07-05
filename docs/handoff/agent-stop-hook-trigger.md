# Agent Stop Hook Trigger Doctrine

## Purpose

The feedback harness needs triggers, not only scripts.

A script that exists but is not run at the right moment does not reduce review pressure. The repo needs an explicit stop hook that agents run at task completion so evidence is collected, classified, and converted into a follow-through plan.

## Core rule

At the end of every bounded agent task, run the repo stop hook:

```text
scripts/invoke-agent-stop-hook.ps1
```

The agent should not ask the operator to interpret logs before the stop hook has run.

## Trigger responsibilities

The stop hook must:

```text
run cheap deterministic guardrails
capture command output as evidence
write BlacksmithGuild_AgentFeedback.json
write BlacksmithGuild_AgentRemediationPlan.json when planner is available
archive feedback and remediation output under artifacts/agent-stop-hook/<timestamp>/
print classification and next action
return a blocking exit code when FailOnBlocking is set and a blocking condition exists
```

## Evidence flow

```text
agent task ends
  -> invoke-agent-stop-hook.ps1
  -> cheap verifiers and git checks run
  -> write-agent-feedback-summary.ps1 writes AgentFeedback
  -> write-agent-remediation-plan.ps1 writes AgentRemediationPlan
  -> generated apply/verify scripts appear when known blockers match
  -> agent follows the remediation plan or stops with a classified blocker
```

## Follow-through rule

If `BlacksmithGuild_AgentRemediationPlan.json` contains `patchCandidates`, the next agent response must not hand-write a new fix first.

It must either use the generated remediation scripts or explain why the generated plan is unsafe or mismatched.

The harness gets first crack at the boring repair.

## Stop conditions

The stop hook should stop the agent when:

```text
any cheap verifier fails
git diff --check fails
AgentFeedback classification is runtime_blocked
AgentFeedback classification is unsafe_surface
AgentFeedback classification is contract_fail
AgentRemediationPlan has no known remediation pattern for a blocking issue
```

The agent may continue only when the next action is classified and bounded.

## Agent report contract

After running the stop hook, the agent must report:

```text
branch
head SHA
classification
allowed claims
forbidden claims
blockers
remediation plan path
next sprint or next repair action
validation commands
```

Do not dump raw logs unless the hook says the evidence is unclassified.

## Human responsibility boundary

The stop hook does not replace human judgment.

It replaces repeated human interpretation of deterministic evidence.

The human still owns:

```text
architecture
product direction
safety boundaries
merge decisions
whether a generated remediation plan is acceptable
```

## Safety boundary

The stop hook may generate feedback and remediation scripts.

It must not perform repo changes by itself, run live certifications, or claim product completion from partial evidence.
