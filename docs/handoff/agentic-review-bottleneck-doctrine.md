# Agentic Review Bottleneck Doctrine

## Purpose

AI can generate code faster than a human can review it. If the repo keeps using the human operator as the primary interpreter for every log, JSON artifact, verifier result, and proof bundle, the bottleneck simply moves from coding to review.

This document defines how The Blacksmith Guild should move review pressure out of the human loop and into the harness.

This is doctrine only. It does not implement stop hooks, Semgrep rules, architectural tests, or live runtime automation.

## Core thesis

The primary bottleneck is not raw code generation.

The primary bottleneck is interpretation and review:

```text
agent writes code
  -> repo emits logs and verifier output
  -> human interprets what the evidence means
  -> human tells agent what to do next
```

That loop does not scale.

The target loop is:

```text
agent writes code
  -> stop hook runs deterministic guardrails
  -> harness summarizes evidence into AgentFeedback
  -> agent self-corrects or proposes the next bounded sprint
  -> human reviews architecture and product intent
```

The human stays responsible for direction, architecture, and quality. The human should not be forced to repeatedly translate evidence the repo already produced.

## Harness over model

Model choice matters, but the harness matters more.

The harness gives the model:

```text
memory
constraints
feedback loops
allowed claims
forbidden claims
validation commands
next sprint shape
```

Without that, even a strong model asks the operator to explain logs that already contain the answer.

## Engineer the environment

The repo should not rely on a human to manually notice every recurring problem.

The environment should provide feedback directly to the agent through deterministic artifacts:

```text
contract verifiers
PowerShell parse checks
UTF-8 BOM checks
git diff --check
git status --short
launcher doctrine checks
duration doctrine checks
engine authority checks
agent feedback harness checks
future architectural tests
future static-analysis rules
```

The goal is not to remove human judgment. The goal is to stop spending human judgment on machine-checkable facts.

## Cheap wins

The first guardrails should be cheap, fast, and deterministic.

### Static analysis rules

Use Semgrep-style rules or equivalent lightweight static checks for recurring code patterns.

Examples:

```text
forbid unbounded Start-Sleep defaults
forbid new TimeoutSec defaults above the doctrine budget without AllowLongRun / LongRunReason
forbid direct raw config toggles when EngineToggleAuthority should be used
forbid launcher heuristic reselection after frozen target selection
forbid runtime PASS claims from launcher-only evidence
```

The repo already does some of this through custom PowerShell verifiers. Future work may add Semgrep if it improves coverage without adding tool friction.

### Architectural unit tests

Architectural constraints should be executable.

Examples:

```text
UI or launcher scripts must not claim gameplay runtime proof
Market engine must not directly call Smithing engine
Progression engine must not silently apply perks
Campaign engines must write CampaignEngineOutcome before handoff
AgentFeedback writer must emit allowedClaims and forbiddenClaims
```

These are not gameplay tests. They are design-boundary tests.

### Stop hooks

A stop hook should run when an agent finishes a task.

Minimum stop-hook behavior:

```text
run relevant contract verifiers
run parse checks
run git diff --check
capture git status --short
summarize failures and passes into BlacksmithGuild_AgentFeedback.json
print next bounded action or stop reason
```

The stop hook should not ask the human what the logs mean. It should classify them.

## Behavioral specifications

High-level prose is not enough.

Future implementation sprints should define behavior before code:

```text
Given fresh CommandAck Success
When SmithingAudit refreshes after the command
Then AgentFeedback classification is checkpoint_reached
And allowedClaims include command bridge proof
And forbiddenClaims include smithing automation completion
```

Behavioral specs become the executable guardrails that let the agent self-correct.

## Data mining sessions

Repeated operator corrections are data.

When the operator repeatedly tells the agent the same thing, convert that correction into a guardrail.

Examples:

| Repeated correction | New guardrail |
|---|---|
| Do not claim launch success proves automation. | Verifier checks launcher docs and feedback forbiddenClaims. |
| Do not ask me to interpret fresh ACK + refreshed audit. | AgentFeedback writer classifies command bridge checkpoint. |
| Do not add long waits to hide uncertainty. | Duration inventory guard blocks casual long defaults. |
| Do not mix campaign engine handoff with repo sprint feedback. | Doctrine distinguishes CampaignOrchestrator from AgentFeedbackHarness. |
| Do not silently choose perks. | Progression policy doctrine requires recommend-first behavior. |

Operator frustration should become repo memory.

## Human responsibility

The human does not disappear.

The human remains responsible for:

```text
product direction
architecture
safety boundaries
what consequences are acceptable
which automation should exist
what tradeoffs are worth making
```

The harness should reduce cognitive debt, not create cognitive surrender.

## Blacksmith Guild guardrail map

Existing guardrail families:

```text
PowerShell UTF-8 BOM contract
bounded test-duration doctrine
launcher window context doctrine
launcher Safe Mode doctrine
post-attach actionability doctrine
engine toggle authority doctrine
agent feedback harness doctrine
```

Near-future guardrail families:

```text
agent stop-hook runner
agent feedback writer
architectural boundary verifier
market journal / outcome verifier
progression policy verifier
campaign engine outcome verifier
Semgrep-style static rules for recurring code smells
```

## First implementation slice

After PR #28 lands, the first implementation branch should add:

```text
scripts/write-agent-feedback-summary.ps1
```

Minimum behavior:

```text
read git branch and status
read selected logs and JSON artifacts if present
read latest verifier output if supplied or rerun cheap verifiers
classify state
emit allowedClaims and forbiddenClaims
emit blockers
emit nextSprint
emit validation commands
write BlacksmithGuild_AgentFeedback.json
```

Second implementation branch may add:

```text
scripts/invoke-agent-stop-hook.ps1
```

Minimum behavior:

```text
run cheap verifiers
call write-agent-feedback-summary.ps1
print summary for the agent
exit nonzero when blocking guardrails fail
```

Do not start with a giant autonomous review bot.

Build the narrow loop first.

## Review replacement boundary

This harness does not eliminate review.

It eliminates avoidable review bottlenecks:

```text
formatting errors
stale evidence
known doctrine violations
unsupported claims
wrong branch validation
missing next action
repeated operator corrections
```

Human review should focus on:

```text
Is this the right product direction?
Is the architecture coherent?
Are the safety boundaries acceptable?
Is the next sprint worth doing?
```

## Safety boundary

The harness may cause an agent to self-correct or propose a bounded sprint.

It must not silently:

```text
merge PRs
run live certs
mutate saves
choose perks
buy or sell market goods
travel on the campaign map
claim runtime proof from static checks
claim product completion from a checkpoint
```

Guardrails are not permission slips.
