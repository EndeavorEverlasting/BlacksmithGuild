# Harness Doctrine

**Authority:** repository-wide agent execution contract for `EndeavorEverlasting/BlacksmithGuild`  
**Enforcement:** `.tbg/harness/policies/harness-doctrine.policy.json`, `scripts/tbg/Test-TbgHarnessDoctrine.ps1`, and `AGENTS.md`

## Harness, not prompt

A prompt is one artifact inside the harness. The harness is the tracked operational surface that lets a fresh agent enter the repository, select the correct lane and workflow, avoid known traps, mutate only authorized surfaces, validate the result, preserve evidence, and hand off cleanly.

| Component | Canonical surface |
|---|---|
| Repo agent rules | `AGENTS.md`, `CLAUDE.md` |
| Codebase map | `CODEBASE_MAP.md` |
| Workflow specifications | `.tbg/workflows/*.contract.json` |
| Run context | current chat packets, sprint capsules, runtime-context capsules |
| Artifact registry | `.tbg/harness/e2e-artifact-types.registry.json`, consumer handoffs |
| Validators | `scripts/tbg/Test-*.ps1` and focused contract tests |
| Local hooks and guardrails | repository-owned guardrail or hook surfaces when useful |
| Scoped skills | `.tbg/skills/manifest.json`, `.tbg/skills/*/SKILL.md` |
| Read-only code intelligence | repository-registered code-intelligence workflow |
| English operator reports | `docs/handoff/**`, certification and evidence reports |
| Final handoff compression | `.tbg/workflows/tbg-sprint-capsule.contract.json` |

Do not invent a parallel authority surface when one of these already owns the concern.

## Required identity

Every serious writing or mutation sprint must name:

- repo;
- branch or worktree;
- PR or sprint;
- lane;
- owned scope;
- forbidden scope;
- expected artifacts;
- validation order when specified.

The narrowest task-specific execution contract overrides generic closeout behavior. Mutable runtime, PR, and worktree facts belong in current-state artifacts, not in this stable doctrine.

## Executable loop

```text
request
  -> evidence review
  -> bounded decision
  -> repo or Git or GitHub mutation
  -> artifacts
  -> validation
  -> report
  -> next decision
```

Rules:

1. **Evidence before confidence.** Inspect repository state, contracts, helpers, artifacts, and relevant logs before concluding.
2. **Existing contracts before invention.** Reuse current workflows, validators, registries, schemas, and helpers.
3. **Preservation before cleanup.** Preserve dirty, unpublished, ignored-evidence, and sibling-worktree state; checkpoint coherent owned work before broad or risky operations.
4. **Bounded mutation before completion.** Requested repository work is not replaced by an acknowledgment, plan, rewritten prompt, summary, or handoff.
5. **Artifacts before claims.** Name paths, freshness, exact head when relevant, and the highest proof level actually reached.
6. **Validation in declared order.** Run targeted contracts first, then relevant harness checks, broader safe checks, and final Git review.
7. **Report one next decision.** Close with exact Git or PR state, gaps, and one exact next command.

## Action-commitment rule

A task that claims it will **install, set up, build, execute, repair, configure, upgrade, deploy, merge, or release** something must require the corresponding mutation and proof.

Valid no-mutation completion exists only when mutation is genuinely blocked. That report must state the exact blocker, provide the smallest useful patch or file content, and give one safest next command.

Invalid closeouts include:

- acknowledgment only;
- summary only;
- rewritten prompt only;
- plan only;
- handoff only;
- preflight only;
- asking for permission when a bounded safe mutation is already authorized.

## Proof ladder

```text
contract -> harness -> static test -> build -> launcher -> command ACK -> behavior observed -> live runtime
```

Proof levels do not collapse. Parser success, a checkpoint, process presence, command ACK, launcher handoff, or a sanitized evidence capsule does not prove product behavior or live runtime completion.

## Runtime-context specialization

`.tbg/workflows/runtime-context-continuity.contract.json` specializes this doctrine for parallel agents, launchers, scripts, and engine handoffs around an already-running Bannerlord session.

Before launch, stop, build, install, cleanup, global input injection, or other runtime mutation:

- classify the current canonical Bannerlord processes and session ownership;
- treat PID deltas as secondary correlation, not primary identity;
- fail closed for active human, foreign, or ambiguous sessions;
- preserve the current and intended engine handoff before mutation;
- keep raw logs, saves, crash dumps, credentials, and private machine data local and ignored;
- publish only a schema-valid bounded sanitized capsule when remote diagnosis is needed.

## Completion contract

Every serious completion report names:

- completed work;
- exact files changed;
- generated artifacts;
- validation commands and results;
- skipped checks and reasons;
- blockers and risks;
- important paths;
- branch, commit SHA, push, and PR state;
- one exact next command.

Interrupted or resumed work additionally names the checkpoint SHA or artifact, preserved and excluded files, last completed validation, first pending validation, and exact resume command.

## Scope lock

This doctrine grants no gameplay, launcher, save-mutation, deployment, process-termination, merge, or release authority by itself. Those permissions must come from the active narrow workflow and task contract.
