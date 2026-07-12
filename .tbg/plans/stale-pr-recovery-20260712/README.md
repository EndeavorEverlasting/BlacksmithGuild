# Stale PR Recovery Sprint — 2026-07-12

## Context

```text
Repo: EndeavorEverlasting/BlacksmithGuild
Branch: docs/stale-pr-cherry-pick-sprint-20260712
Sprint: stale PR, branch, and comment recovery
Lane: coordinator / cleanup / selective replay
Base: main @ 590d08de32ec4a39970f2fc54f676e55ec7198bb
```

This directory implements the current-main recovery plan for stale feature branches, stacked PRs, historical evidence, and useful review comments. It does not merge feature work. It turns the existing stale-PR doctrine into an executable sprint queue with exact source SHAs, replay methods, validators, and disposition gates.

Authority:

1. `AGENTS.md`
2. `.tbg/skills/stale-pr-cherry-pick/SKILL.md`
3. `.tbg/workflows/stale-pr-cherry-pick.contract.json`
4. `manifest.json`
5. Current source, PR metadata, comments, and checks

## Scope

Owned:

- local repo-floor proof;
- PR and dependency classification;
- unique commit/path/hunk/comment extraction;
- current-main recovery branches;
- targeted validation;
- replacement PR provenance;
- non-destructive supersession decisions.

Forbidden:

- blind merge or squash of stale PR heads;
- feature implementation in the coordinator branch;
- runtime claims from historical artifacts;
- stale branch heads as generic bases;
- deleting PRs, branches, worktrees, or evidence without the manifest done gate;
- touching PR #43 or #52 from a stale-recovery worktree.

## Start exactly

Run in the primary Windows checkout:

```powershell
git fetch origin --prune
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list --porcelain
gh pr list --state open --limit 50
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
```

Then inspect:

```powershell
Get-Content -LiteralPath .\artifacts\latest\repo-hygiene-report.md -Raw
git branch -vv
git diff --name-only --diff-filter=U
```

Do not proceed in the primary checkout when it is dirty, conflicted, mid-merge/rebase/cherry-pick/revert/bisect, attached to another sprint, or contains unclassified ignored evidence.

Create an isolated recovery worktree when required:

```powershell
git fetch origin --prune
git worktree add ..\BlacksmithGuild-stale-pr-recovery -b sprint/stale-pr-recovery-20260712 origin/main
Set-Location ..\BlacksmithGuild-stale-pr-recovery
git status --short
git branch --show-current
git rev-parse HEAD
```

Expected clean recovery base:

```text
branch: sprint/stale-pr-recovery-20260712
HEAD: current origin/main
status: clean
```

## Active lane exclusion

PR #43 and PR #52 are current route/harness work, not stale-replay inputs.

```text
#43 agent/route-automation-operator-plan
#52 fix/launcher-supervisor-empty-list -> #43
```

Do not cherry-pick either whole head to `main`. PR #52 is a bounded repair owned by PR #43. Settle that stack in its dedicated worktree and preserve its proof boundary separately.

## Sprint waves

| Wave | Targets | Operation | Parallel rule |
|---|---:|---|---|
| 0 | local floor | Verify branch, worktrees, conflicts, generated artifacts, and safe base. | Serial gate. |
| A | #9, #34 | Preserve historical evidence and timeless worktree rules; prepare supersession notes. | Safe beside Wave B with separate worktrees. |
| B | #2 | Replay the isolated schema doc and wording only after current-source comparison. | Safe beside Wave A. |
| C | #8 | Harvest unresolved comments as current tests/acceptance rules; avoid wholesale runner replay. | Serial due launcher-script churn. |
| D1 | #28–#31 | Reconcile feedback doctrine, writer, planner, and trigger fields into current schemas. | Dependency order required. |
| D2 | #32–#33 | Reconcile guardrail fields and pure tools; prove stubs cannot imply PASS. | Dependency order required. |
| D3 | #35 | Salvage process-detection and ownership ideas only after #43/#52 disposition. | Blocked by active route lane. |
| E | #20, #24, #38 | One bounded current-main replacement PR per source lane. | Serial unless changed-path proof shows no overlap. |
| F | #5, #6 | Reconstruct economic/sell behavior under current contracts and fresh runtime proof. | Runtime lane; #6 follows #5. |

## Replay procedure for every source PR

### 1. Map current source

```powershell
gh pr view <PR> --json number,title,state,isDraft,mergeable,baseRefName,headRefName,headRefOid,commits,files,reviews,comments
gh pr diff <PR> --name-only
gh api repos/EndeavorEverlasting/BlacksmithGuild/pulls/<PR>/comments --paginate
```

Record unresolved review threads before changing code. Bot summaries are context, not proof.

### 2. Create one bounded branch

```powershell
git fetch origin --prune
git switch --create replay/pr-<PR>-<short-name> origin/main
```

Use a sibling worktree instead when another branch owns the checkout.

### 3. Compare before replay

```powershell
git log --oneline --reverse origin/main..<SOURCE_HEAD>
git diff --stat origin/main...<SOURCE_HEAD>
git diff --name-status origin/main...<SOURCE_HEAD>
```

Classify each useful SHA/path/comment:

```text
keep
superseded
reject
needs-owner-review
needs-runtime-proof
```

### 4. Replay narrowly

Use a whole commit only when it remains coherent:

```powershell
git cherry-pick -x <SOURCE_SHA>
```

When a commit mixes current and obsolete work, do not cherry-pick it. Restore only an isolated path or apply a reviewed hunk:

```powershell
git restore --source=<SOURCE_SHA> -- <PATH>
git add <PATH>
git commit -m "docs(replay): preserve PR #<PR> <value>"
```

For high-churn runtime files, reconstruct against current source rather than restoring stale files.

### 5. Validate current context

Always:

```powershell
git diff --check
git status --short
```

Run every validator listed for the PR in `manifest.json`. For PowerShell changes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tools\Add-Utf8Bom.ps1 -Fix
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
```

A skipped build or runtime gate must be named with the exact later command. A stale artifact cannot satisfy the check.

### 6. Open a replacement PR with provenance

Use this body shape:

```text
Source PRs:
- #<number> <title>

Selected value replayed:
- commit <sha>
- path or hunk <path>: <summary>
- review comment requirement: <summary>

Rejected or superseded value:
- <item>: <reason>

Base:
- current main @ <sha>

Validation:
- <commands and results>
- git diff --check

Proof reached:
- <contract/static/build/etc.>

Proof not reached:
- <explicitly named levels>

Old PR disposition:
- keep open / close after replacement merge / retain evidence / owner review
```

### 7. Close or retain deliberately

Do not close a source PR until:

- every useful SHA/path/comment has a replacement, rejection, or historical-retention record;
- the replacement is reachable from `main` or the explicit blocker is recorded;
- current validators pass;
- evidence is clearly historical;
- no attached worktree or unique local commit is being abandoned.

Do not delete a remote branch until the source head remains reachable from its PR or a named archive ref and worktree/evidence retention is settled.

## Useful comment carry-forward

### PR #8

Current replay tests must prove:

- the F7 gate cannot return success without executing its gate and writing evidence;
- parent bisect exit status reflects failed child masks;
- `-SkipLaunch` is never a silent default for a self-contained bisect;
- dot-sourced logging preserves caller error behavior;
- a failed mutex acquisition prevents the write;
- ready-line validation includes root wrappers;
- docs and scripts agree on the supported entrypoint.

### PR #20

Current model/tests must prove:

- runner-owned orchestration selects evidence artifacts;
- horse/capacity missions remain `HorseAcquisition`, including fallbacks and successful execution;
- terminal and blocked reasons preserve actual outcomes;
- cycle IDs correlate distinct runs/cycles.

Review comments are requirements to verify, not patches to copy.

## First two safe execution lanes

### Lane A — preservation

Owned:

```text
PR #9 historical evidence
PR #34 timeless worktree/protected-checkout rules
docs/evidence/**
current-main preservation or supersession docs
```

Forbidden:

```text
src/**
launcher/runtime scripts
PR #43/#52 branches
```

### Lane B — independent schema replay

Owned:

```text
PR #2
docs/identity-disposition-schema.md
the exact role-doctrine wording, if still missing
a minimal current doc-index link
```

Forbidden:

```text
broad NEXT_STEPS rewrite
unrelated AutoCharacterBuild changes
runtime claims
```

Collision risk between Lane A and Lane B is low when they use separate worktrees and PRs.

## Exact next decision

After local floor proof, execute Wave A and Wave B in separate sibling worktrees. Do not begin the feedback/guardrail stack or runtime lanes until those two replacements prove the replay process and establish clean closeout patterns.
