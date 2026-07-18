# Skill: agent-skill-factoring

Use this skill when changing agent rules, skill files, skill manifests, client adapters, refactoring plans, or documentation that tells future agents how to orient themselves in this repository.

## Use when

- Editing `AGENTS.md`, `CLAUDE.md`, `.tbg/skills/**`, or agent-facing prompt surfaces.
- Deciding what belongs in root agent rules versus a targeted brush-up file.
- Planning a refactoring that changes shared contracts, schemas, paths, callers, or agent/harness structure.
- Preventing policy prose drift between docs, skills, workflow contracts, and harness reports.

## Do not use when

- Patching runtime C# behavior.
- Launching Bannerlord or running live proof.
- Writing command inbox files.
- Resolving route, trade, save, launcher, or evidence behavior directly.

## Read first

1. `AGENTS.md`
2. `CLAUDE.md`
3. `.tbg/skills/manifest.json`
4. `.tbg/harness/manifest.json`
5. `.tbg/workflows/checkpoint-discipline.contract.json`
6. `docs/architecture/checkpointed-harness-discipline.md`
7. `docs/architecture/local-agent-harness.md`
8. `docs/architecture/effective-policy-english-reports.md`

## Doctrine

`AGENTS.md` is the common denominator. It must stay small enough for every agent to read at entry.

A skill is conditional lane knowledge. It may summarize context, but it must point to executable contracts, policies, manifests, scripts, or current docs as the authority. Skills explain executable truth; they do not replace it.

`CLAUDE.md` is an adapter for one client. It may remind Claude how to behave, but it must not duplicate the whole repo constitution.

A trigger, prompt, installed tool, or external coordinator may select a lane. It does not grant mutation, deployment, merge, runtime, secret, or live-target authority.

## Planning a refactoring

Plan refactoring as recoverable slices, not one uninterrupted rewrite.

For each slice:

1. name the invariant being preserved and the exact owned files;
2. make the smallest coherent structural change;
3. run the narrowest relevant parser, contract, or targeted test;
4. preserve the slice before broad validation or expanding to more callers;
5. record the checkpoint SHA or approved recovery artifact;
6. expand only after the current slice is recoverable.

A checkpoint is required before renaming or moving multiple files, changing shared schemas or contracts, updating all callers, running a full suite, beginning runtime proof, or switching agents, models, worktrees, or environments.

A patch is valid recovery evidence only when it includes modified tracked files and every owned untracked file. A plain `git diff` patch does not preserve newly created files.

When resuming interrupted work, inspect the latest checkpoint, verify its file boundary, run the smallest failing or pending validation first, repair only the proven failure, and checkpoint again before broader validation. Do not reload or regenerate completed work without evidence that the checkpoint is incomplete.

A checkpoint proves preservation only. It does not prove correctness, completion, merge readiness, launcher behavior, or runtime behavior.

## Owned scope

- Root agent coordination language.
- Skill registry and skill docs.
- Harness manifest entries that locate skills.
- Checkpoint and refactoring workflow contracts and fixtures.
- Architecture docs explaining agent/skill factoring.

## Forbidden scope

- Product runtime behavior.
- Runtime proof claims.
- Launcher automation.
- Route or trade source edits.
- Save mutation.
- Branch, worktree, or evidence deletion.

## Done gate

A factoring change is done only when:

1. root rules identify the authority chain and checkpoint boundary;
2. skills are registered in `.tbg/skills/manifest.json` when a new skill is added;
3. each skill has use/do-not-use/read-first/owned/forbidden/done-gate sections;
4. policy statements point to executable contracts or current repo docs;
5. checkpoint fixtures prove that owned untracked files cannot be omitted;
6. resumed-work fixtures require the smallest failing or pending validation first;
7. no stale PR, runtime proof, or launcher claim is introduced by prose alone;
8. JSON files parse;
9. `scripts/tbg/Test-TbgCheckpointDiscipline.ps1` passes;
10. `scripts/tbg/Test-TbgSkillRouting.ps1` passes;
11. `git diff --check` passes.

## Common traps

- Copying a whole sprint handoff into `AGENTS.md`.
- Letting `CLAUDE.md` become a second constitution.
- Creating a skill that repeats policy but does not name its executable source.
- Loading every skill instead of the narrowest matching skill.
- Treating a skill as permission to cross its forbidden scope.
- Treating a WIP commit as validated completion.
- Saving only `git diff` while leaving new owned files untracked.
- Repeating repository-wide discovery after a valid checkpoint already exists.
