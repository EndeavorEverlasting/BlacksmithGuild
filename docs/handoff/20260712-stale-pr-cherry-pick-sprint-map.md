# 2026-07-12 Stale PR Cherry-Pick Sprint Map

## Repo

`EndeavorEverlasting/BlacksmithGuild`

Current verified remote base:

```text
main @ 590d08de32ec4a39970f2fc54f676e55ec7198bb
```

Planning branch:

```text
docs/stale-pr-cherry-pick-sprint-20260712
```

## PR / Sprint Context

This sprint converts the merged stale-PR recovery doctrine into a current-main execution map. The repository already owns:

```text
AGENTS.md
.tbg/skills/stale-pr-cherry-pick/SKILL.md
.tbg/workflows/stale-pr-cherry-pick.contract.json
.tbg/skills/compendium-preservation/SKILL.md
ForgeRepoHygiene.cmd
```

A detailed salvage ledger also exists on PR #43's branch. It is used as a provenance source, not as current-main authority, because its snapshot predates the current `main` and PR #43 remains an active divergent foundation.

## Lane

`coordinator / cleanup / selective replay planning`

## Scope

- verify remote PR, branch, stack, mergeability, dependency, and comment state;
- identify current-main recovery bases;
- preserve useful commits, paths, contracts, tests, evidence references, and review findings;
- define replay waves, validators, supersession gates, and safe parallel lanes;
- require local branch/worktree/conflict/artifact proof before execution.

## Forbidden Scope

- no feature implementation;
- no Bannerlord launch or runtime claims;
- no blind stale-head merge or squash;
- no broad refactor;
- no destructive PR, branch, worktree, or evidence cleanup;
- no use of stale PR heads as general sprint bases;
- no integration of PR #43/#52 from the coordinator branch.

## Verified Remote State

- `main` is current at `590d08de`.
- 18 PRs were open at the inventory snapshot.
- Active lane: #43 with nested repair #52.
- Stale/recovery set: #2, #5, #6, #8, #9, #20, #24, #28–#35, and #38.
- PR #43 and #52 both diverged heavily from the inspected current-main snapshot; whole-head replay is prohibited.
- PR #52 is based on PR #43 and belongs in that active branch stack.
- PR #8 and #20 contain unresolved review findings with reusable acceptance criteria.
- PR #24, #31, #33, #38, #5, and #6 had no unresolved review threads at this snapshot; comments must still be refreshed immediately before replay.

## PR Map

| PR | Classification | Recovery action | Gate |
|---:|---|---|---|
| #43 | Active route/harness foundation | Exclude from stale sprint; keep exact-head worktree. | Settle independently. |
| #52 | Active bounded repair stacked on #43 | Integrate into owning #43 lane after exact-head checks. | Never replay whole head to main. |
| #9 | Historical evidence | Preserve manifests/context and link maintained replacement. | No stale evidence as current PASS. |
| #34 | Superseded coordination map | Keep timeless worktree rules only. | Link current map before close. |
| #2 | Small independent replay | Selective path/hunk replay from current main. | Diff check and Debug build. |
| #8 | Superseded runner with valuable comments/history | Carry comments into current tests; preserve history. | Fail-closed/current-lineage verification. |
| #28–#31 | Feedback stack | Reconcile fields and pure behavior in dependency order. | Current schemas/reporting/done gate. |
| #32–#33 | Guardrail stack | Field-level guardrail merge and pure-tool adapters. | No stub can imply PASS. |
| #35 | Partial route utility replacement | Salvage detection/ownership only. | Blocked by #43/#52 disposition. |
| #20 | Governor handoff model | Reconstruct model/tests and review requirements. | Correct evidence ownership, branches, reasons, cycles. |
| #24 | Route/profile helper lane | Reconcile helper/wrapper value with current authority. | Blocked on current route-control comparison. |
| #38 | Conflicted broad guardrail stack | Reconstruct unique guardrails from current main. | One mapped decision per unique SHA/path. |
| #5–#6 | Legacy economic/runtime stack | Contract-first reconstruction; #6 follows #5. | Current build and fresh exact-head runtime proof. |

## Comment Map

PR #8 unresolved findings to preserve:

```text
fail-open F7 gate
parent bisect exit code not enforcing child failure
silent -SkipLaunch behavior
dot-sourced logger changing caller ErrorActionPreference
mutex timeout followed by unlocked write
grep verifier missing root wrappers
operator docs contradicting script entrypoint guidance
```

PR #20 unresolved findings to preserve:

```text
governor factory hardcoding runner-owned evidence paths
horse-acquisition missions mislabeled as Trade
blocked completion discarding richer detail
terminal reason recording next command instead of outcome
hardcoded cycleId = 1
```

These are replay requirements, not authority to copy the stale implementation.

## Worktree Map

Remote connectors cannot inspect the local Windows worktrees.

Expected primary checkout from prior repo evidence:

```text
%USERPROFILE%\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
```

Current local facts remain unverified:

```text
current branch
dirty/conflicted files
in-progress Git operation
attached worktrees
local-only commits
upstream-gone branches
ignored/generated evidence
```

Decision:

- primary worktree is **not proven safe**;
- sibling worktree is required when primary is dirty, conflicted, mid-operation, or owned by another lane;
- separate worktrees are required for Wave A and Wave B if run in parallel;
- PR #43/#52 worktrees remain isolated from stale recovery;
- no worktree removal is authorized by this sprint.

## Changed Files

```text
.tbg/plans/stale-pr-recovery-20260712/manifest.json
.tbg/plans/stale-pr-recovery-20260712/README.md
docs/handoff/20260712-stale-pr-cherry-pick-sprint-map.md
```

## Validation

Completed remotely:

```text
repository/default branch lookup: PASS
current main exact-SHA comparison: PASS
open PR inventory: PASS at snapshot
active versus stale lane classification: PASS
PR #43/#52 base and divergence inspection: PASS
existing doctrine/contract inspection: PASS
PR #43 salvage-ledger inspection: PASS as provenance source
review-thread harvest: PASS for selected high-value lanes
manifest JSON structure inspection: PASS
scope review: PASS, three planning files only
```

Not available in the connector environment:

```text
local git status/worktree/branch proof
ForgeRepoHygiene.cmd execution
PowerShell validators
dotnet build
git diff --check in the Windows checkout
runtime validation
```

## Gaps / Risks

- The primary checkout may contain local work, conflicts, attached recovery branches, or ignored evidence.
- Remote mergeability does not prove dependency completeness or local safety.
- The PR #43 salvage ledger is valuable but stale relative to current `main`; each entry must be refreshed before execution.
- PR #8 review threads are mostly outdated against their original diff, so every finding requires current-source verification.
- PR #20 review threads remain unresolved and non-outdated on that stale branch; the findings are strong acceptance candidates but still require reconstruction against current code.
- #28–#35 and #38 overlap current harness policies and must not be wholesale cherry-picked.
- #5/#6 cannot be closed or claimed complete without current runtime proof.
- No stale PR or branch was closed, deleted, or retargeted in this sprint.

## Exact Next Command

Run from the primary Windows checkout:

```powershell
git fetch origin --prune; .\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
```

Then read the generated report:

```powershell
Get-Content -LiteralPath .\artifacts\latest\repo-hygiene-report.md -Raw
```

## Copy-Paste Handoff Prompt

```text
EXECUTE THE REPO SPRINT. DO NOT REWRITE THIS PROMPT.

Repo:
EndeavorEverlasting/BlacksmithGuild

Branch / PR:
Create or use a clean sibling worktree from current origin/main.
Planning source: docs/stale-pr-cherry-pick-sprint-20260712
Plan paths:
- .tbg/plans/stale-pr-recovery-20260712/manifest.json
- .tbg/plans/stale-pr-recovery-20260712/README.md
- docs/handoff/20260712-stale-pr-cherry-pick-sprint-map.md

Sprint:
Wave 0 local floor proof, then Wave A preservation and Wave B independent replay

Lane:
coordinator / cleanup / selective replay

Owned scope:
- Run the merged read-only repo hygiene report.
- Verify current branch, HEAD, status, conflicts, in-progress operations, worktrees, local-only commits, upstream state, and ignored evidence.
- Preserve the primary checkout if it owns local work.
- Create separate sibling worktrees from current origin/main when isolation is required.
- Lane A: preserve and supersede PR #9 historical evidence and PR #34 timeless worktree rules.
- Lane B: replay only the still-missing PR #2 identity/disposition schema and exact role-doctrine wording.
- Preserve source PR/SHA/path/comment provenance.
- Run manifest-listed validators and git diff --check.
- Open bounded replacement PRs.
- Record old PR disposition, but do not close anything until replacement and retention gates pass.

Forbidden scope:
- Do not touch or base recovery work on PR #43 or PR #52.
- Do not implement unrelated features.
- Do not launch Bannerlord or claim runtime proof.
- Do not blind merge or squash stale PR heads.
- Do not broadly rewrite NEXT_STEPS.md or current runtime files.
- Do not close/delete PRs, branches, worktrees, or evidence without proof and explicit recorded rationale.
- Do not reuse historical evidence as current PASS.

Start exactly:
git fetch origin --prune
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list --porcelain
gh pr list --state open --limit 50
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
Get-Content -LiteralPath .\artifacts\latest\repo-hygiene-report.md -Raw
git branch -vv
git diff --name-only --diff-filter=U

If the primary checkout is not safe, preserve it and create sibling worktrees from origin/main.

Required proof:
- exact base SHA
- clean worktree evidence
- source PR/head/commit/path/comment classification
- changed-file list
- targeted validator output
- git diff --check
- replacement PR URL
- retained/rejected/superseded value list
- no destructive cleanup

Final response:
repo, branch, PR/sprint, lane, owned scope, forbidden scope, completed work, source PR classifications, changed files, artifacts, validation, skipped checks, gaps/risks, important paths, git state, exact next command, and a copy-paste prompt for the following wave.
```
