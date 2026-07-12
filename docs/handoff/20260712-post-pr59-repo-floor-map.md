# Post-PR #59 Repository Floor and Sprint Map

```text
[TBG | Repo Floor / Hygiene | post-PR #59 | remote evidence + local verification gate]
```

## Context

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Coordinator branch: `docs/post-pr59-repo-floor-map-20260712`
- Coordinator base: `main` at `75078deba98dd8d7133e175c9195e8aa94012c4c`
- Sprint: repo / PR / worktree hygiene and sprint map
- Lane: coordinator / cleanup
- Owned scope: repository, PR, branch, worktree, conflict, ignored-artifact, and safe-base classification
- Forbidden scope: feature implementation, Bannerlord runtime claims, broad refactors, destructive branch deletion, worktree removal, evidence deletion, reset, stash, clean, force operations, or blind stale-head integration

This map records remote GitHub state and the last retained local evidence. The coordinator environment cannot inspect the user's Windows filesystem. Current local status, conflicts, worktrees, ignored artifacts, and unique unpublished commits remain unverified until the local floor command completes.

## Current center of gravity

Current `main` contains:

1. exact-head PR lifecycle automation and reconciliation;
2. BlacksmithGuild-to-Continuum capability export;
3. the stale-PR recovery plan from PR #58;
4. the syntactic-English recovery renderer from PR #59.

The current default-branch head is:

```text
75078deba98dd8d7133e175c9195e8aa94012c4c
```

Independent work must start from current `origin/main` unless the sprint explicitly owns an existing PR branch.

## Coordinator decisions

1. Run local Wave 0 before deleting, cleaning, switching, rebasing, or assigning the primary checkout.
2. Treat PR #43 and PR #52 as one active nested launcher/route stack, not stale-recovery inputs.
3. Do not merge PR #43 wholesale. It is a selective-replay source for focused current-main launcher and product PRs.
4. Do not merge PR #52 to `main`. Its base is PR #43; first decide whether to merge it into that branch or replay its six-file repair with the focused launcher extraction.
5. Use PR #58's recovery manifest for old PRs. Do not create a competing stale-PR classification system.
6. Use one branch and sibling worktree per execution lane.
7. Preserve ignored runtime evidence until its owning branch, head, proof value, size, and retention decision are recorded.
8. No branch or worktree is proven disposable from remote GitHub state alone.

## Remote PR map

At this snapshot there are 18 known open PRs: the 17 repository-owner PRs returned by the open-PR inventory plus nested repair PR #52.

| PR | State | Current disposition |
|---:|---|---|
| #43 | Open, non-draft, non-mergeable; `agent/route-automation-operator-plan` at `2fd964a`; 110 commits ahead and 24 behind current `main` | Active broad source lane. Keep isolated. Decompose into focused current-main launcher and minimal visible-trade PRs. Do not merge or rebase wholesale. |
| #52 | Open, non-draft, mergeable; `fix/launcher-supervisor-empty-list` at `2bb7077`; base is PR #43 | Active bounded nested repair. Required checks passed. Merge into PR #43 only if that branch remains the test source, or replay the six-file repair with launcher extraction. Never target `main` directly without current-main reconstruction. |
| #38 | Open, non-draft, non-mergeable; broad guardrail/worktree stack | Reconstruct still-useful current-main contracts under PR #58 Wave E. Not a base. |
| #35 | Draft, mergeable; focused route proof stacked on old guardrail base | Blocked on PR #43/#52 disposition. Salvage process/focus ownership ideas only after launcher decomposition. |
| #34 | Draft, mergeable; stale concurrent-sprint map | Preserve timeless worktree rules and supersede stale topology under PR #58 Wave A. |
| #33 | Draft, mergeable; guardrail utility scripts | Reconcile after feedback stack; do not merge independently from its old base. |
| #32 | Draft, mergeable; default guardrail doctrine | Selective current-main replay after PRs #28-#31 reconciliation. |
| #31 | Draft, mergeable; agent stop hook | Reconcile with current lifecycle, policy reporting, and artifact contracts. |
| #30 | Draft, mergeable; remediation planner | Selective replay after current feedback schema exists. |
| #29 | Draft, mergeable; feedback writer | Selective replay after current run/artifact context is chosen. |
| #28 | Draft, mergeable; feedback doctrine | Root of old agent-feedback stack. Reconcile, do not use as a base. |
| #24 | Draft, mergeable; route/profile command contracts | Reconstruct selected command contracts on current main. High semantic collision with runtime work. |
| #20 | Open, non-draft, mergeable; governor activity handoff | Reconstruct on current run/artifact context. Preserve review requirements, not stale implementation. |
| #9 | Open, non-draft, non-mergeable; historical F7 evidence | Preserve as historical evidence or supersession record. Never use old runtime evidence as current proof. |
| #8 | Open, non-draft, non-mergeable; F7 tooling/history | Harvest review requirements into current tests. Avoid wholesale runner replay. |
| #6 | Draft, mergeable; second-leg sell travel | Runtime reconstruction only after PR #5-equivalent first-leg behavior and fresh proof. |
| #5 | Draft, mergeable; sell loop | Reconstruct only after the current minimal legitimate buy cycle. Do not rebase and merge blindly. |
| #2 | Open, non-draft, mergeable; identity/disposition schema | First small independent replay candidate after local floor proof. |

## Active PR #43 / #52 stack

### PR #43

- Head: `2fd964ac679b4eb0e7403f6948bf4cf96ae7b484`
- Base: `main`
- Divergence: 110 ahead / 24 behind current `main`
- Required workflows at the head: Governor Contracts, Harness Policy Reports, and Hostile Escape Contracts passed
- Proof reached: contract, static, and branch-local harness proof
- Proof not reached: current-main integration, fresh exact-head launcher handoff, campaign readiness, movement, arrival, visible trade, or live runtime proof

The PR body says the PR remains draft, but GitHub reports `draft: false`. Treat the GitHub state as authoritative and the body wording as stale.

### PR #52

- Head: `2bb70775c65c3595c9d966fce8d86ae389eb727e`
- Base: `agent/route-automation-operator-plan`
- Changed files: six launcher/workhorse/CI regression files
- Required workflows passed
- Proof reached: Windows PowerShell 5.1 `current_synced`, validation-only workhorse completion, and dirty-source `isolated_remote` harness behavior
- Proof not reached: launcher, campaign, command ACK, movement, trade, or runtime proof

Safe decision sequence:

```text
local floor proof
-> preserve PR #43 worktree and evidence
-> decide whether PR #52 merges into PR #43 for branch-local proof
-> extract launcher workhorse + PR #52 repairs onto current main
-> extract minimal visible-trade product slice separately
-> supersede or close PR #43 only after value accounting
```

## Worktree map

### Current proof

The exact local worktree list is unavailable in this coordinator environment.

The last retained local evidence established:

- primary path: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`;
- a dedicated PR #43 route worktree existed and was clean at exact head `2fd964a` at that snapshot;
- the primary checkout still required explicit ancestry, dirty-state, and artifact comparison;
- additional historical worktrees and multi-gigabyte ignored evidence existed and were not proven disposable.

These are historical facts, not assertions about the current filesystem.

### Required current classification

For every worktree, record:

- path;
- branch or detached head;
- exact SHA;
- upstream;
- ahead/behind current `origin/main` and its PR head;
- dirty, conflicted, or interrupted-operation state;
- ignored artifact count and size;
- owning PR/sprint;
- retain, reuse, archive, or release decision.

### Primary worktree safety

The primary worktree is **not proven safe for new work** until local Wave 0 returns a clean, non-conflicted, non-interrupted result or identifies the exact owning lane.

Use sibling worktrees for all independent work until then.

## Generated and ignored artifacts

No generated artifact cleanup was performed.

Do not delete `artifacts/**`, game logs, runtime proof, or conflict-preservation copies merely because they are ignored. First classify:

```text
owner
branch
head SHA
proof level
freshness
size
replacement or archive
safe deletion gate
```

Obvious temporary output may be removed only when it was created by the current coordinator run and is not referenced by a retained result or handoff.

## Safe next sprint bases

| Lane | Safe base |
|---|---|
| Independent BlacksmithGuild work | current `origin/main` at or after `75078de` |
| PR #43 branch-local proof | exact PR #43 head only, in its dedicated worktree |
| PR #52 nested repair | exact PR #52 head, with base relationship to PR #43 preserved |
| Stale PR replay | fresh branch/worktree from current `origin/main`, following PR #58 manifest |
| Continuum consumer work | current `EndeavorEverlasting/Continuum` main; no BlacksmithGuild mutation |
| Minimal visible-trade replacement | fresh current-main branch after launcher/run-context ownership is settled |

Unsafe bases:

- PR #43 for unrelated work;
- PR #52 for anything outside its six-file repair;
- PRs #28-#38 stacked heads as general bases;
- PR #24, #20, #8, #9, #5, #6, or #2 heads for new development;
- any local branch with unknown unpublished commits or ignored evidence.

## Safe parallel lanes after local Wave 0

Low collision:

1. PR #2 identity-schema replay from current main.
2. PR #9/#34 preservation and supersession documentation.
3. Continuum read-only capability consumer in the Continuum repo.
4. Read-only source inspection for launcher extraction.

Must remain serial or explicitly partitioned:

1. PR #43 and PR #52 launcher scripts.
2. `.github/workflows/governor-contracts.yml`.
3. `.tbg/harness/manifest.json` and shared run/artifact schemas.
4. `src/BlacksmithGuild/MapTrade/**`.
5. `src/BlacksmithGuild/DevTools/**` save, command, runtime, and engine-authority surfaces.
6. stale-recovery manifest and ledger.

## Validation performed in this coordinator sprint

Remote evidence:

- current `main` resolved to `75078deba98dd8d7133e175c9195e8aa94012c4c`;
- recent center of gravity inspected through PR #59;
- open PR inventory inspected;
- PR #43 compared against current main: diverged, 110 ahead / 24 behind;
- PR #43 required workflows inspected: passed;
- PR #52 metadata and base relationship inspected;
- PR #52 required workflows inspected: passed;
- PR #58 recovery plan and PR #59 renderer inspected;
- coordinator branch created from current main;
- this map committed as documentation only.

Not performed:

- local `git fetch`, status, branch, log, worktree, conflict, or ignored-artifact commands;
- local `git diff --check`;
- local PowerShell verifier execution;
- branch/worktree/artifact deletion;
- PR closure or retargeting;
- Bannerlord, build, launcher, or runtime validation.

## Exact local Wave 0

Run from the primary Windows checkout:

```powershell
git fetch origin --prune
git status --short --ignored
git branch --show-current
git rev-parse HEAD
git log --oneline --decorate -8
git worktree list --porcelain
git diff --name-only --diff-filter=U
gh pr list --state open --limit 50
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
.\ForgeStalePrRecovery.cmd -Wave 0
```

Then inspect:

```powershell
Get-Content -LiteralPath .\artifacts\latest\repo-hygiene-report.md -Raw
Get-Content -LiteralPath .\artifacts\latest\stale-pr-recovery\stale-pr-recovery.report.md -Raw
git branch -vv
```

## Next decision

Do not start feature work in the primary checkout until the local packet proves it is safe.

After local proof:

1. preserve or assign every existing worktree;
2. settle PR #52's nested relationship to PR #43;
3. launch PR #2 replay and PR #9/#34 preservation in separate sibling worktrees;
4. create a focused current-main launcher extraction lane;
5. create the minimal visible-trade replacement only after launcher and shared artifact ownership are clear.
