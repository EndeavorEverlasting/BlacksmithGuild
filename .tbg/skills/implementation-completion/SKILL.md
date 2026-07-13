---
name: implementation-completion
description: Complete bounded implementation across concurrent pushes with one lane per branch and worktree, exact-base decisions, validation, commit, push, PR, evidence retention, and safe release gates.
---

# Skill: implementation-completion

## Use when

- Turning an implemented change into a validated commit and pull request.
- Coordinating completion while other agents are pushing.
- Selecting a safe base and isolated worktree for an implementation lane.
- Archiving evidence and deciding whether a branch or worktree may be released.
- Running the first safe no-game test after clone.

## Do not use when

- Implementing unrelated product behavior under the guise of closeout.
- Deleting a branch, worktree, PR, or evidence because it looks stale.
- Using a stale PR head as a general base.
- Claiming runtime proof from a clean Git state, build, or CI.
- Closing a stale PR before its unique value is replayed, rejected, or superseded.

## Read first

1. `AGENTS.md`
2. `.tbg/skills/manifest.json`
3. `.tbg/workflows/implementation-completion-clean-branches.contract.json`
4. `docs/handoff/implementation-completion-clean-branches.md`
5. `docs/first-test-after-clone.md`
6. fresh repo-floor and PR state

## Completion sequence

```text
fetch -> prove floor -> choose exact base -> isolate lane -> validate -> inspect diff -> commit -> push -> PR -> archive evidence -> release decision
```

Use one active lane per branch and worktree. `origin/main` is the default base unless the sprint explicitly owns a current PR branch.

## Owned scope

- completion contract and closeout documentation
- branch, worktree, commit, push, and PR workflow for the owned lane
- validation and artifact accounting
- evidence archive manifests
- first-test-after-clone guidance
- safe release recommendations

## Forbidden scope

- unrelated feature work
- destructive cleanup without proof and operator authority
- force push or history rewrite unless an explicit workflow grants it
- stale evidence promoted to current proof
- branch or worktree release before evidence retention is settled

## Validation

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tbg/Test-TbgSkillRouting.ps1
git diff --check
git status --short
git diff --stat
git diff
```

Run targeted tests, relevant validators, build checks, and workflow-specific runtime checks before the commit claim that requires them.

## Done gate

- Repo, branch, sprint, scope, forbidden scope, and artifacts are named.
- The diff is bounded and reviewed.
- Practical validators have passed or exact skipped commands are recorded.
- Commit SHA and push/PR state are recorded.
- Evidence retention and branch/worktree release disposition are explicit.
- The final report names one exact next command.
