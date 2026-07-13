# Active PR Stack Summary

## Purpose

This file gives agents a quick way to understand which PRs are stacked, parallel, stale, or risky before starting another sprint.

## Current guardrail stack

```text
#28 docs(agent): add feedback harness doctrine
  base: main
  head: agent-feedback-harness

#29 feat(agent): add feedback summary writer
  base: agent-feedback-harness
  head: agent-feedback-writer

#30 feat(agent): add remediation planner
  base: agent-feedback-writer
  head: agent-feedback-remediation-planner

#31 feat(agent): add stop hook trigger contract
  base: agent-feedback-remediation-planner
  head: agent-feedback-stop-hook

#32 docs(guardrails): add default app guardrail map
  base: agent-feedback-stop-hook
  head: agent-default-guardrail-map

#33 feat(guardrails): add default guardrail implementation scripts
  base: agent-default-guardrail-map
  head: agent-default-guardrail-implementation

#34 docs(concurrent): add PR-numbered sprint map
  base: agent-default-guardrail-implementation
  head: docs-concurrent-sprint-map
```

## Stack rule

A stacked branch may validate its own files, but it cannot be considered independently merge-ready until its base stack is resolved or rebased.

## Local checkout collision rule

A stacked branch must not be validated by switching the protected local main checkout to that branch.

Use PR-specific worktrees under the same parent instead:

```text
BlacksmithGuild-pr31-agent-stop-hook
BlacksmithGuild-pr33-default-guardrail-implementation
BlacksmithGuild-pr34-concurrent-sprint-map
```

The protected local main checkout remains:

```text
BlacksmithGuild
```

## Older open lanes observed

The repo also has older open PRs and branches that represent real concurrent history:

```text
#24 feat: add shared route/profile mode command contracts
#23 feat(engine): add shared toggle authority
#20 Codify governor activity handoff contract
#19 feat(governor): add campaign runtime decision spine
#18 feat(cert): economic_loop trade-driving loop policy
#17 feat(cert): wire runtime emitters into gameplay for economic-loop cert
#16 feat(cert): economic-loop certification foundation
#9 docs(f7): add continue-gate bisect evidence and coordination log
#8 F7: Add Continue bisect tooling, em-dash grep safeguards, and agent handoff docs
#6 feat(006c-4b): second-leg auto-travel to sell town
#5 feat(006c-4): vanilla sell driver + multi-cycle guild loop
```

## Risk notes

### Mergeability is not proof

A mergeable PR is not validated runtime behavior.

### Draft means intentional uncertainty

Draft PRs should not be interpreted as abandoned. They often represent lanes waiting for local validation, runtime proof, or lower-stack closure.

### Older branches may contain stale proof language

Older proof artifacts and PR bodies can guide history, but they should not close new guardrail or runtime claims without fresh branch/head evidence.

### Wrong checkout can contaminate concurrent work

Commands that mutate branches, files, generated artifacts, or validation output must be aimed at the intended PR worktree.

Do not assume that a folder named only `BlacksmithGuild` is safe for side work.

## Agent instruction

Before starting side work, an agent should identify:

```text
which lane it is extending
which PR it is stacked on
which files are safe to touch
which validation belongs to this lane
which claims are forbidden from this lane
which local worktree owns the commands
whether the protected local main checkout is untouched
```
