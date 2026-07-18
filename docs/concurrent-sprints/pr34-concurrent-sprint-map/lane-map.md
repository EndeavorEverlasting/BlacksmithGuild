# Active Lane Map

## Purpose

This file maps active or recently active lanes so agents can pick a safe concurrent sprint without confusing branches, proof types, validation gates, or local checkout paths.

## Lane A: Agent feedback and guardrail stack

Current stack:

```text
PR #28 agent-feedback-harness
  -> doctrine, schema, review bottleneck, gap register

PR #29 agent-feedback-writer
  -> BlacksmithGuild_AgentFeedback.json writer

PR #30 agent-feedback-remediation-planner
  -> BlacksmithGuild_AgentRemediationPlan.json writer

PR #31 agent-feedback-stop-hook
  -> trigger contract, output schema, follow-through runbook

PR #32 agent-default-guardrail-map
  -> whole-app default guardrail map

PR #33 agent-default-guardrail-implementation
  -> first implementation scripts and stubs
```

Safe concurrent work:

```text
contract verifiers
repo-local helper scripts
docs that improve agent follow-through
schema stubs that do not claim runtime proof
```

Avoid:

```text
runtime gameplay mutation
live cert claims
merge-ready claims before local validation
branch switching inside the protected local main checkout
```

## Lane B: Launcher / route-owned clock / runtime proof

Known related work:

```text
PR #25 launcher window context helper
PR #27 duration inventory guard and route-clock doctrine
feat/route-owned-clock-resume branch work
```

Safe concurrent work:

```text
proof classification
runtime contamination detection
launcher handoff evidence capture
byte-safe replacement helpers
```

Avoid:

```text
route logic changes while fixing launcher handoff seams
movement proof claims from launcher-only evidence
manual input contamination during zero-click proof
branch switching inside the protected local main checkout
```

## Lane C: Governor / campaign handoff

Known related work:

```text
PR #19 campaign runtime decision spine
PR #20 governor activity handoff contract
PR #23 engine toggle authority and campaign orchestration doctrine
```

Safe concurrent work:

```text
CampaignEngineOutcome docs
CampaignActionEvidence schema
engine boundary verifiers
orchestrator-owned handoff doctrine
```

Avoid:

```text
direct engine-to-engine chaining
authority bypass
silent irreversible gameplay choices
branch switching inside the protected local main checkout
```

## Lane D: Route/profile command contracts

Known related work:

```text
PR #24 shared route/profile mode command contracts
```

Safe concurrent work:

```text
mode command docs
command-state validation
profile/route manifest cleanup
```

Avoid:

```text
mixing route/profile config success with runtime route proof
branch switching inside the protected local main checkout
```

## Lane E: Economic loop / sell loop legacy branches

Known related work:

```text
PR #16 economic-loop certification foundation
PR #17 runtime emitters into gameplay
PR #18 economic-loop trade-driving loop policy
PR #5 vanilla sell driver
PR #6 second-leg auto-travel to sell town
```

Safe concurrent work:

```text
historical reconciliation docs
proof artifact classification
schema compatibility checks
```

Avoid:

```text
pulling old stale proof into current guardrail claims
reviving legacy runtime claims without fresh branch/head validation
branch switching inside the protected local main checkout
```

## Default concurrent sprint rule

When in doubt, a concurrent sprint should prefer:

```text
docs
verifiers
schema stubs
classification helpers
artifact summarizers
```

and avoid:

```text
live runtime mutation
save mutation
automation claims
cross-engine behavioral changes
branch switching inside the protected local main checkout
```

## Local worktree rule

Every lane must be executed from a lane-specific worktree unless the operator explicitly says otherwise.

```text
BlacksmithGuild = protected local main checkout
BlacksmithGuild-prNN-short-description = PR/lane worktree
```

Validation commands and generated helper runs belong in the PR/lane worktree.
