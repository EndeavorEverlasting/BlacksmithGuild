# Skill: repo-floor-hygiene

Use this skill when the sprint is a coordinator or cleanup lane that must map repo state before feature work.

## Use when

- Verifying repo path, branch, PRs, worktrees, dirty state, conflicts, stale artifacts, or safe bases.
- Preparing a sprint map.
- Deciding whether a sibling worktree is required.
- Identifying cleanup candidates without deleting them.

## Do not use when

- Implementing feature behavior.
- Claiming runtime proof.
- Launching Bannerlord.
- Running ForgeReboot or command inbox workflows.
- Deleting branches, worktrees, or runtime evidence without explicit proof and operator approval.

## Read first

1. `AGENTS.md`
2. `.tbg/harness/manifest.json`
3. `.tbg/skills/manifest.json`
4. `docs/handoff/post-pr41-repo-hygiene-map.md`
5. Current `gh pr list` and `git worktree list` output.

## Required preflight

```powershell
git fetch origin
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20
```

## Owned scope

- Repo and PR maps.
- Worktree maps.
- Dirty/conflict inventory.
- Stale generated artifact inventory.
- Safe base recommendations.
- Cleanup candidate ledger.

## Forbidden scope

- Feature implementation.
- Runtime source edits.
- Runtime proof claims.
- Broad refactors.
- Destructive cleanup without proof.

## Done gate

A repo-floor hygiene pass is complete only when it names:

- repo and branch;
- PR/sprint context;
- open PR map;
- dirty/conflicted state;
- worktree map;
- changed files;
- validation output;
- gaps/risks;
- one exact next command.

## Common traps

- Treating a clean worktree as proof that ignored runtime evidence can be deleted.
- Treating a merged PR as proof that all related local branches are disposable.
- Treating an open stale PR as a safe base.
- Repairing a conflict in a coordinator sprint when the route/runtime owner owns that lane.
