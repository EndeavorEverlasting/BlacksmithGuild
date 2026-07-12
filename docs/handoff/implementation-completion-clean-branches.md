# Implementation Completion With Clean Branches

```text
[TBG | Implementation Completion + Clean Branches | coordinator/harness docs | branch: docs/implementation-completion-worktree-first-test]
```

## Purpose

This plan turns the current parallel-agent workflow into a clean completion path: finish active implementation, keep branches clean despite concurrent pushes, preserve useful stale work, and give new users a first test they can run after cloning `main`.

The governing contract is:

```text
.tbg/workflows/implementation-completion-clean-branches.contract.json
```

## Non-negotiable operating model

```text
origin/main
  -> clean base for new work

one lane
  -> one branch
  -> one worktree
  -> one proof/merge/cleanup disposition
```

Do not use a stale merged branch as a base. Do not reuse one checkout for docs, runtime proof, stale PR replay, and artifact cleanup. Do not close PRs just because they are old. Replay or reject their value first.

## Concurrent-push discipline

Before any implementation, merge, replay, cleanup, or PR state change:

```powershell
git fetch origin --prune
git status --short
git branch --show-current
git log --oneline --decorate -5
git worktree list
gh pr list --state open --limit 20
```

If another agent pushed while this work was in progress, refresh the branch view before making a decision:

```powershell
git fetch origin --prune
gh pr view <number> --json number,title,state,isDraft,baseRefName,headRefName,mergeable,commits,changedFiles,url
gh pr checks <number> --repo EndeavorEverlasting/BlacksmithGuild
```

## Worktree allocation

Use explicit sibling worktrees so concurrent lanes do not step on each other.

| Lane | Worktree example | Base | Owns | Release condition |
|---|---|---|---|---|
| Main sync | `BlacksmithGuild-main-sync` | `origin/main` | fetch/status/first-test checks | always clean or discarded |
| Docs/contracts | `BlacksmithGuild-docs-contracts` | `origin/main` | docs, `.tbg` contracts, skills | PR merged/closed and branch deleted after proof |
| Route runtime proof | `BlacksmithGuild-pr43-proof` | PR #43 head | exact-head route/operator proof | proof merged or branch replaced with rationale |
| Stale PR replay | `BlacksmithGuild-stale-replay` | `origin/main` | replay PR #5-#38 value | each replay PR merged or closed with rationale |
| Artifact retention | `BlacksmithGuild-artifact-retention` | `origin/main` | archive manifests and evidence cleanup | archive verified before removal |

Template commands:

```powershell
Set-Location "<parent-dev-directory>"
git -C .\BlacksmithGuild fetch origin --prune

git -C .\BlacksmithGuild worktree add `
  .\BlacksmithGuild-docs-contracts `
  -b docs/<lane-name> origin/main
```

For an existing PR lane:

```powershell
Set-Location "<path-to-worktree>"
gh pr checkout 43 --repo EndeavorEverlasting/BlacksmithGuild
```

## Completion sequence

### 1. Start from current main or an owned PR branch

Do not start new runtime proof work from an old pre-doctrine branch. Start from current `origin/main` unless the sprint explicitly owns an open PR branch.

### 2. Finish PR #43 with agent-verifiable proof

PR #43 remains the active route/operator-control lane until current state says otherwise.

Runtime completion means exact-head evidence, not a chat assertion and not a green static check. The proof command should collect at least:

- clean preflight;
- head SHA;
- built DLL hash;
- installed DLL hash;
- loaded runtime assembly identity if available;
- mode/authority state;
- route start or command correlation;
- numeric movement evidence if movement is claimed;
- post-run cleanup to Manual/hold or a clearly reported blocked state;
- one compact packet or PR comment.

### 3. Preserve, replay, then close stale PRs

Use `stale-pr-cherry-pick` rules:

1. Map the PR stack and changed paths.
2. Classify each value as keep, replay, superseded, reject, or needs-owner-review.
3. Replay selected commits/hunks/tests/docs onto current `origin/main` or an explicit current foundation branch.
4. Validate.
5. Close the old PR only after the replacement or rejection rationale is recorded.

Recommended order after PR #43 is settled:

1. PR #20 worker/governor activity handoff.
2. PR #28-#33 agent feedback and guardrail stack.
3. PR #24 route/profile command contracts.
4. PR #8/#9 F7 and Unicode/log-pattern tooling.
5. PR #5/#6 sell/travel runtime stack.

### 4. Archive evidence before cleanup

Large ignored evidence lanes are not permanent live worktrees, but they are not disposable either.

Before removal, write an archive manifest that records:

- source worktree or branch;
- detached/head commit or PR identity;
- artifact count and byte size;
- archive path;
- manifest path;
- restore instructions;
- reason the evidence is no longer needed in a live worktree.

### 5. Keep first-user testing boring and safe

A user cloning `main` should not need to understand every PR lane. Their first test is documented in:

```text
docs/first-test-after-clone.md
```

That first test has two tiers:

1. no-game repo sanity checks;
2. optional Bannerlord-backed checks only after prerequisites are installed.

## Merge policy

| Work type | Ready to merge when |
|---|---|
| Docs/contracts/skills | JSON parses, diff check passes, PR checks pass, no personal paths/logs committed |
| Worktree/branch cleanup | branch merged or superseded, no worktree-local uncommitted work, evidence archived if needed |
| Static harness validators | targeted validator passes, no runtime claims made |
| Runtime route/operator proof | exact-head local proof artifact exists and matches claimed proof level |
| Stale PR replacement | replayed value is validated on current base and old PR closure rationale is recorded |

## First command for a coordinator

```powershell
Set-Location "<path-to-BlacksmithGuild>"; git fetch origin --prune; .\ForgeAgentStatus.cmd -PrNumber 43; git status --short --ignored; git worktree list; gh pr list --state open --limit 20
```
