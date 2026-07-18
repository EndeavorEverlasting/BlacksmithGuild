# Checkpointed Harness Discipline

## Purpose

BlacksmithGuild uses checkpointed harness discipline for software, repository, automation, deployment, and agent work.

The doctrine is adapted from the shared operating baseline in AgentSwitchboard and the detailed Git/PR/worktree and interrupted-work rules in SysAdminSuite. Those repositories are references, not authorities over BlacksmithGuild product behavior. BlacksmithGuild retains its own runtime, save-safety, evidence, and proof authority.

## Required operation declaration

Before mutation, name:

- repo;
- branch or worktree;
- PR or sprint;
- lane;
- owned scope;
- forbidden scope;
- expected artifacts;
- validation order when the operator specified one.

## Executable loop

```text
request
  -> evidence review
  -> bounded decision
  -> coherent repo/Git/GitHub mutation
  -> preservation checkpoint
  -> targeted validation
  -> repair only proven failures
  -> broader validation
  -> completion artifacts
  -> report
  -> next decision
```

Plans, docs, prompts, manifests, scripts, validators, logs, reports, branches, PRs, releases, installs, and deployments are connected parts of this operational system. Prompts route the work; they do not replace deterministic implementation or grant authority.

## Checkpoint boundary

Checkpoint the first coherent tracked slice before:

- broad or full-suite validation;
- long-running diagnostics or builds;
- runtime or device proof;
- expanding a refactoring to shared contracts, schemas, moves, renames, or all callers;
- switching agents, models, worktrees, or environments.

Accepted checkpoints are:

1. a bounded commit on the owned branch;
2. a complete patch or bundle containing modified tracked files and every owned newly created file;
3. another repository-approved recovery artifact carrying the required checkpoint fields.

A plain `git diff` patch is incomplete whenever owned untracked files exist.

## Refactoring slices

For each refactoring slice:

1. name the preserved invariant;
2. name exact owned files;
3. make the smallest coherent structural change;
4. run the narrowest relevant parser, contract, or targeted test;
5. preserve the slice;
6. expand only after the current slice is recoverable.

Do not combine unrelated dirty files with a refactoring checkpoint.

## Resume contract

A resumed agent must:

1. inspect the latest checkpoint;
2. verify its changed-file boundary;
3. run the smallest failing or pending validation first;
4. repair only the proven failure;
5. checkpoint the repair before broadening validation.

Do not reload a full original handoff or repeat repository-wide discovery unless current evidence shows the checkpoint is stale, incomplete, or invalid.

## Proof boundary

A checkpoint proves only that the work is recoverable.

It does not prove:

- correctness;
- completion;
- merge readiness;
- launcher behavior;
- command acknowledgement;
- gameplay behavior;
- live runtime behavior.

## Machine-readable authority

The executable authority is:

```text
.tbg/workflows/checkpoint-discipline.contract.json
```

Fixture and validator surfaces are:

```text
.tbg/harness/fixtures/checkpoint-discipline.fixtures.json
scripts/tbg/Test-TbgCheckpointDiscipline.ps1
```

The root `AGENTS.md` keeps only the universal checkpoint and authority rule. The conditional refactoring procedure lives in `.tbg/skills/agent-skill-factoring/SKILL.md`.
