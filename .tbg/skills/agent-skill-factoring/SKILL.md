# Skill: agent-skill-factoring

Use this skill when changing agent rules, skill files, skill manifests, client adapters, or documentation that tells future agents how to orient themselves in this repository.

## Use when

- Editing `AGENTS.md`, `CLAUDE.md`, `.tbg/skills/**`, or agent-facing prompt surfaces.
- Deciding what belongs in root agent rules versus a targeted brush-up file.
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
5. `docs/architecture/local-agent-harness.md`
6. `docs/architecture/effective-policy-english-reports.md`

## Doctrine

`AGENTS.md` is the common denominator. It must stay small enough for every agent to read at entry.

A skill is conditional lane knowledge. It may summarize context, but it must point to executable contracts, policies, manifests, scripts, or current docs as the authority. Skills explain executable truth; they do not replace it.

`CLAUDE.md` is an adapter for one client. It may remind Claude how to behave, but it must not duplicate the whole repo constitution.

## Owned scope

- Root agent coordination language.
- Skill registry and skill docs.
- Harness manifest entries that locate skills.
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

1. root rules identify the authority chain;
2. skills are registered in `.tbg/skills/manifest.json`;
3. each skill has use/do-not-use/read-first/owned/forbidden/done-gate sections;
4. policy statements point to executable contracts or current repo docs;
5. no stale PR, runtime proof, or launcher claim is introduced by prose alone;
6. JSON files parse;
7. `git diff --check` passes.

## Common traps

- Copying a whole sprint handoff into `AGENTS.md`.
- Letting `CLAUDE.md` become a second constitution.
- Creating a skill that repeats policy but does not name its executable source.
- Loading every skill instead of the narrowest matching skill.
- Treating a skill as permission to cross its forbidden scope.
