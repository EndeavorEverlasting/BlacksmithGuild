# Agent Feedback Harness Gap Register

## Purpose

This register lists the known gaps, risks, and execution order for turning the Agent Feedback Harness from doctrine into a working repo loop.

It is intentionally blunt. The harness should reduce the operator's interpretation burden, not create a new pile of vague framework words.

## Current checkpoint

PR #28 currently provides:

```text
agent feedback doctrine
agent feedback schema
review bottleneck doctrine
manifest
contract verifier
```

That is enough to define the body.

It is not enough to make the body move.

## Known gaps

### G1. No feedback writer yet

Missing:

```text
scripts/write-agent-feedback-summary.ps1
```

Impact:

```text
BlacksmithGuild_AgentFeedback.json is planned but not generated.
Agents still need the operator to summarize logs unless a human runs the interpretation manually.
```

Next step:

```text
Implement a read-only writer that inspects git state, known logs, known JSON artifacts, and cheap verifier results, then writes BlacksmithGuild_AgentFeedback.json.
```

### G2. No stop hook yet

Missing:

```text
scripts/invoke-agent-stop-hook.ps1
```

Impact:

```text
Agents do not automatically receive deterministic feedback when they finish a task.
The review bottleneck remains partially human-routed.
```

Next step:

```text
Add a stop hook that runs cheap verifiers, calls write-agent-feedback-summary.ps1, prints the summary, and exits nonzero for blocking failures.
```

### G3. No artifact interpretation table

Missing:

```text
machine-readable mapping from artifact patterns to classifications
```

Impact:

```text
The schema says classification exists, but the repo does not yet encode enough concrete classification rules.
```

Next step:

```text
Start with a small internal ruleset in write-agent-feedback-summary.ps1, then promote it to a manifest if it grows.
```

Initial rules should include:

```text
fresh CommandAck Success -> checkpoint_reached / command bridge proof
missing CommandInbox after fresh ACK -> not a blocker
Safe Mode detected without decline -> runtime_blocked
contract verifier failure -> contract_fail
old proof bundle against newer head -> stale_evidence
git diff --check failure -> contract_fail
```

### G4. No automated claim discipline enforcement

Missing:

```text
writer-generated allowedClaims and forbiddenClaims based on evidence
```

Impact:

```text
Agents can still overclaim from partial evidence.
```

Next step:

```text
Make every classification emit allowedClaims and forbiddenClaims.
```

### G5. No branch/worktree awareness beyond planned schema

Missing:

```text
actual git branch / head / status capture
```

Impact:

```text
Agents may tell the user to run validation from the wrong branch or worktree.
```

Next step:

```text
Writer must capture git rev-parse --abbrev-ref HEAD, git rev-parse HEAD, git status --short, and include branch-specific validation.
```

### G6. No data-mining loop for repeated corrections

Missing:

```text
process for turning repeated operator corrections into new guardrails
```

Impact:

```text
Operator frustration can repeat instead of becoming repo memory.
```

Next step:

```text
Add a correction-mining section to AgentFeedback or create a future corrections ledger.
```

Potential future file:

```text
docs/handoff/operator-correction-guardrail-ledger.md
```

### G7. No architectural boundary tests yet

Missing:

```text
fast tests/verifiers for agent-review boundaries
```

Impact:

```text
Architecture remains partly human-reviewed instead of environment-enforced.
```

Next step:

```text
Add cheap verifier checks before heavier tooling.
```

Candidate checks:

```text
AgentFeedback writer must include allowedClaims and forbiddenClaims.
Campaign engines must not directly call each other once outcome interfaces exist.
Progression code must not apply perks without policy.
Market journaling must not buy/sell goods.
```

### G8. No Semgrep integration yet

Missing:

```text
.semgrep.yml or equivalent static rules
```

Impact:

```text
Some recurring code smells remain custom-verifier-only or manual.
```

Next step:

```text
Do not add Semgrep until the first PowerShell writer and stop hook prove useful. Avoid tool sprawl before loop value is proven.
```

### G9. No local validation evidence for PR #28 after latest doctrine expansion

Missing:

```text
local verifier output from the latest PR #28 head
```

Impact:

```text
PR #28 should remain draft until local gates pass.
```

Next step:

```text
Run verify-agent-feedback-harness-contract.ps1, UTF-8 BOM, git diff --check, and git status --short locally.
```

## Known risks

### R1. Framework bloat

Risk:

```text
The harness becomes a large meta-system before it provides value.
```

Mitigation:

```text
Implement the smallest writer first. Read a few artifacts, classify them, write JSON, stop.
```

### R2. False confidence

Risk:

```text
AgentFeedback.json could look authoritative while summarizing stale or incomplete evidence.
```

Mitigation:

```text
Every evidence item must carry fresh=true/false, and stale evidence must not close a sprint.
```

### R3. Overclaiming

Risk:

```text
The harness could accidentally make unsupported claims easier to repeat.
```

Mitigation:

```text
Every classification must emit forbiddenClaims, not just allowedClaims.
```

### R4. Wrong branch validation

Risk:

```text
The harness could tell the operator to validate the wrong worktree.
```

Mitigation:

```text
Always capture branch, head SHA, and status. Prefer branch-specific validation commands.
```

### R5. Stop hook annoyance

Risk:

```text
Stop hooks become noisy and agents ignore them.
```

Mitigation:

```text
Stop hook output must be short, classified, and action-oriented. Do not dump raw logs.
```

### R6. Human responsibility erosion

Risk:

```text
The harness creates cognitive surrender instead of cognitive relief.
```

Mitigation:

```text
Harness recommends bounded sprints. Human retains architecture, product, safety, and merge judgment.
```

### R7. Tooling sprawl

Risk:

```text
Adding Semgrep, test harnesses, stop hooks, and JSON writers all at once creates maintenance debt.
```

Mitigation:

```text
PowerShell writer first. Stop hook second. Static-analysis integrations later.
```

## Execution order

### Step 1. Close doctrine gap

Add this gap register and keep PR #28 draft until local checks pass.

### Step 2. Implement writer

Create a stacked implementation PR:

```text
base: agent-feedback-harness
branch: agent-feedback-writer
```

Add:

```text
scripts/write-agent-feedback-summary.ps1
```

Minimum behavior:

```text
read git branch/head/status
read known repo/root artifacts if present
classify fresh command ACK if present
classify contract verifier failures if provided
write BlacksmithGuild_AgentFeedback.json
print concise summary
```

### Step 3. Add writer verifier

Add:

```text
scripts/verify-agent-feedback-writer-contract.ps1
```

It should verify:

```text
writer exists
writer names BlacksmithGuild_AgentFeedback.json
writer emits schema TbgAgentFeedback.v1
writer emits repoState
writer emits evidence
writer emits allowedClaims
writer emits forbiddenClaims
writer emits nextSprint
writer emits validation
```

### Step 4. Add stop hook

Create later branch:

```text
agent-feedback-stop-hook
```

Add:

```text
scripts/invoke-agent-stop-hook.ps1
```

Minimum behavior:

```text
run cheap verifiers
call writer
print classification, blocker summary, next sprint, validation
exit nonzero on blocking failure
```

### Step 5. Mine corrections

Add a correction-to-guardrail ledger only after the writer and stop hook are useful.

## Immediate next action

Build Step 2 now.

Do not wait for Semgrep.

Do not wait for perfect architecture tests.

Do not build a giant review bot.

Make the first feedback JSON real.
