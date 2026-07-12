# Agent Skill Factoring and Stale PR Cherry-Pick Doctrine

```text
[TBG | Agent Skills + Stale PR Cherry-Pick | coordinator/architecture | branch: docs/agent-skills-stale-pr-cherry-pick]
```

## Purpose

This document codifies how The Blacksmith Guild keeps agent onboarding small while preserving useful work from stale PRs.

The repo should not solve agent drift by making `AGENTS.md` enormous. It should keep root rules compact, then route conditional knowledge through targeted skills backed by executable contracts and current repo evidence.

The repo should also not clean old PRs by blind deletion or blind squash. Stale PRs often contain salvageable tests, docs, contracts, or small source deltas. Those pieces should be classified and replayed onto a safe current base.

## Authority model

| Surface | Role |
|---|---|
| `AGENTS.md` | Common denominator for every agent and client. |
| `CLAUDE.md` | Claude-specific adapter that defers to `AGENTS.md` and skills. |
| `.tbg/skills/manifest.json` | Registry that tells agents which targeted skill to load. |
| `.tbg/skills/<skill-id>/SKILL.md` | Conditional brush-up card for a narrow lane. |
| `.tbg/workflows/*.contract.json` | Executable workflow contract and done-gate source. |
| `.tbg/harness/manifest.json` | Harness registry, protected path, policy paths, skill path, and doctrine. |
| Current source/scripts/docs | Truth for implemented behavior. |

If these disagree, executable contracts and current source win. The doc or skill must be corrected.

## Skill factoring rule

`AGENTS.md` keeps only durable root rules:

- agent identity and ownership;
- hard routing boundaries;
- proof/evidence discipline;
- encoding rules;
- where to find skills and executable contracts;
- harness maturity boundary;
- stale PR preservation policy.

A skill owns conditional lane knowledge:

- when to use it;
- when not to use it;
- what to read first;
- owned paths and forbidden paths;
- validation and done gates;
- common traps.

Agents should load `AGENTS.md`, then the narrowest matching skill. They should not load every skill or paste full historical handoffs into every prompt.

## Initial skill set

| Skill | Use |
|---|---|
| `repo-floor-hygiene` | PR/worktree/branch/conflict/artifact/safe-base maps. |
| `agent-skill-factoring` | Edits to root rules, Claude adapter rules, skill registry, and skill docs. |
| `harness-maturity` | Decisions about harness plumbing versus narrow skill/domain behavior. |
| `stale-pr-cherry-pick` | Selective replay from stale PRs without blind merge, blind squash, or blind deletion. |

Future skills should be added only when a recurring lane needs a compact brush-up. Good candidates include route runtime proof, operator control surface, launcher lifecycle, visible trade cycle, effective-policy reporting, MCP/LSP code intelligence, and PowerShell BOM hygiene.

## Harness maturity doctrine

A harness-heavy architecture is useful for low-trust automation because the plumbing must own policy, evidence, permissions, rollback, reporting, adapters, retries, and validation. It is not useful when it moves game behavior into vague infrastructure just to make the harness look larger.

Use `.tbg/skills/harness-maturity/SKILL.md` and `.tbg/workflows/harness-skill-maturity.contract.json` before refactors that claim to make the app more harness-driven.

Default decision:

1. Move cross-cutting safety, evidence, routing, reporting, schema, and adapter concerns toward harness.
2. Keep stateless calculations and game/economy/route/smithing behavior in skill or domain modules.
3. Reject refactors whose only clear benefit is an improved harness percentage.

The architecture note at `docs/architecture/harness-skill-maturity.md` records the full decision test and migration pattern.

## Stale PR doctrine

A stale PR is not useless merely because it is old, conflicted, behind, or superseded in part.

A stale PR is also not safe merely because GitHub says it is clean or mergeable. It may omit commits from its own base, depend on superseded contracts, include stale evidence, or touch high-churn runtime surfaces.

The default operation is **selective replay**, not deletion.

## Cherry-pick workflow

1. **Map the source PR.** Record number, title, base, head SHA, commits, changed files, checks, conflict state, and current semantic overlap.
2. **Classify every unit of value.** Mark commits, hunks, docs, tests, contracts, and evidence references as keep, superseded, reject, or needs-owner-review.
3. **Choose a safe base.** Prefer current `origin/main`. Use another base only when a current workflow contract explicitly requires a foundation branch.
4. **Replay narrowly.** Use `git cherry-pick -x <sha>` only for clean coherent commits. Use hunk/path replay when a stale commit mixes valid and obsolete work.
5. **Preserve provenance.** Replacement PRs must cite the stale PR and source commit or path that contributed value.
6. **Validate in current context.** Run targeted validators and `git diff --check`; run build/runtime checks only when the lane permits them and prerequisites are safe.
7. **Supersede deliberately.** Close or archive the old PR only after replacement, rejection, or retention rationale is recorded.

## Forbidden shortcuts

- Do not use stale PR heads as general bases.
- Do not blind squash stale stacks.
- Do not delete stale branches, worktrees, artifacts, or PRs as cleanup theater.
- Do not claim runtime proof from stale evidence.
- Do not collapse command ACK, route start, movement, arrival, trade delta, or visible UI proof levels.
- Do not reintroduce stale docs as current truth without updating their authority chain.

## Replacement PR body checklist

A replacement PR that salvages stale work should include:

```text
Source PRs:
- #<number> <title>

Selected value replayed:
- commit <sha> / path <path> / hunk summary

Rejected or superseded value:
- reason

Base:
- current main or explicit foundation branch

Validation:
- targeted checks
- git diff --check
- build/runtime checks or exact reason skipped

Old PR disposition:
- keep open / close after merge / archive evidence / needs owner review
```

## Done gate

The agent/skill factoring sprint is done when:

- `AGENTS.md` states the common-denominator and skill-selection rule;
- `CLAUDE.md` defers to `AGENTS.md` and targeted skills;
- `.tbg/harness/manifest.json` locates `.tbg/skills`;
- `.tbg/skills/manifest.json` registers initial skills;
- `.tbg/workflows/harness-skill-maturity.contract.json` defines harness versus skill/domain classification;
- `.tbg/workflows/stale-pr-cherry-pick.contract.json` defines the stale PR replay workflow;
- each initial skill has a `SKILL.md` with use/do-not-use/read-first/owned/forbidden/done-gate sections;
- JSON files parse;
- `git diff --check` passes.
