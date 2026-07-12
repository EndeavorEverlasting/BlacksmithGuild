# 2026-07-12 Repo Floor Sprint Map

## Repo

`EndeavorEverlasting/BlacksmithGuild`

Default branch: `main`

Current remote `main` head observed during this sprint:

```text
5efa144b82f703094d41600ce2e4cedc12583dbb Merge pull request #49 from EndeavorEverlasting/feat/repo-hygiene-report
```

This map is based on live GitHub metadata plus the repo-owned hygiene tooling merged by PR #49. The coordinator environment did not have a mounted local checkout, `gh` executable, or working outbound DNS for `git clone`, so local dirty state, conflicts, ignored artifacts, and worktrees remain explicitly unverified.

## Branch

Sprint-map branch:

```text
docs/repo-floor-sprint-map-20260712
```

Safe base used:

```text
main @ 5efa144b82f703094d41600ce2e4cedc12583dbb
```

## PR / Sprint Context

PR #49 is merged and provides executable repo hygiene reporting through:

```text
ForgeRepoHygiene.cmd
scripts/tbg/Get-TbgRepoHygieneReport.ps1
scripts/tbg/Test-TbgRepoHygieneReport.ps1
.github/workflows/repo-hygiene-report.yml
```

PR #44 remains open and non-mergeable with an older 2026-07-11 map. This sprint creates a fresh replacement from current `main`; it does not close, retarget, or delete PR #44 or its branch.

## Lane

`coordinator / cleanup / repo-floor / sprint map`

## Scope

- Verify remote repository, PR, branch-stack, and mergeability state.
- Record the local evidence still required for dirty/conflict/worktree decisions.
- Classify stale generated artifacts as retain, inspect, or safe candidate without deleting them.
- Identify safe bases for the next bounded sprints.
- Preserve feature/runtime lanes from coordinator edits.

## Forbidden Scope

- No feature implementation.
- No runtime claims.
- No Bannerlord launch.
- No ForgeReboot.
- No command inbox or save mutation.
- No unrelated code changes or broad refactors.
- No branch, worktree, PR, or evidence deletion without proof.

## Remote PR Map

There are 18 open PRs in the current remote inventory.

| PR | Head -> Base | Draft | Mergeable | Floor classification | Recommended action |
| --- | --- | --- | --- | --- | --- |
| #43 | `agent/route-automation-operator-plan` -> `main` | yes | yes | Active route/harness lane | Keep isolated. Continue only from the exact PR head in a sibling worktree. Fresh Windows/Bannerlord proof remains outside this sprint. |
| #44 | `docs/repo-floor-sprint-map-20260711` -> `main` | no | no | Stale coordinator map | Treat this 2026-07-12 map as the replacement candidate. Do not repair #44 in the primary worktree. |
| #38 | `docs-worktree-stop-guardrails` -> `docs/agent-workflow-contracts` | no | no | Stale stacked guardrail lane | Compare unique value against current `main`, then selectively replay from a fresh recovery branch. |
| #35 | `feat/harness-focused-route-proof` -> `agent-default-guardrail-map` | yes | yes | Old stacked runtime-harness lane | Do not use as a generic base. Reconcile against #43 before any continuation. |
| #34 | `docs-concurrent-sprint-map` -> `agent-default-guardrail-implementation` | yes | yes | Old coordination stack | Likely superseded by newer repo-floor and agentic-operations maps; inspect before closure. |
| #33 | `agent-default-guardrail-implementation` -> `agent-default-guardrail-map` | yes | yes | Old guardrail implementation stack | Selective-replay candidate, not direct merge candidate. |
| #32 | `agent-default-guardrail-map` -> `agent-feedback-stop-hook` | yes | yes | Old guardrail doctrine stack | Review unique doctrine against merged contracts before replay. |
| #31 | `agent-feedback-stop-hook` -> `agent-feedback-remediation-planner` | yes | yes | Old feedback stack | Preserve executable stop-hook value; replay only after dependency review. |
| #30 | `agent-feedback-remediation-planner` -> `agent-feedback-writer` | yes | yes | Old feedback stack | Preserve planner value; do not merge independently from its stack. |
| #29 | `agent-feedback-writer` -> `agent-feedback-harness` | yes | yes | Old feedback stack | Preserve writer value; do not merge independently from #28. |
| #28 | `agent-feedback-harness` -> `main` | yes | no | Conflicted stack root | Start any recovery from current `main`; classify and selectively replay #28 through #35 in dependency order. |
| #24 | `feat/shared-route-profile-contracts` -> `main` | yes | no | Stale route/profile contract lane | Compare against #43 and current main before replay. Do not use as a fresh sprint base. |
| #20 | `sprint/governor-activity-contract` -> `main` | no | no | Stale mixed contract/data lane | Inspect unique contract value and generated JSON implications before selective replay. |
| #9 | `codex/update-pr-with-bisect-session-details` -> `main` | no | no | Historical evidence lane | Preserve evidence and summaries before any closure or branch cleanup. |
| #8 | `codex/stabilize-f7-launch-tooling-and-open-pr` -> `fix/f7-gate-stability` | no | no | Historical tooling/evidence stack | Treat as evidence source, not a base. Replay only verified tooling still absent from main. |
| #6 | `feat/006c-4b-second-leg-travel` -> `feat/006c-4-sell-loop` | yes | yes | Legacy sell-loop stack child | Do not continue until #5 value and current #43 overlap are classified. |
| #5 | `feat/006c-4-sell-loop` -> `main` | yes | no | Legacy runtime stack root | Do not merge or delete without current build/runtime and evidence-preservation review. |
| #2 | `codex/design-identity-and-behavior-schema` -> `main` | no | no | Independent stale mixed docs/code PR | Small selective-replay candidate after checking whether the docs and wording already exist on main. |

## PR Stack Map

```text
Current active lane
  #43 route automation / launcher-validation workhorse

Coordinator replacement
  #44 old map -> this 2026-07-12 replacement map

Guardrail / feedback dependency chain
  #28 -> #29 -> #30 -> #31 -> #32 -> #33 -> #34
                                 \-> #35

Separate stale guardrail stack
  former #36 base -> #38

Legacy route/profile and governor lanes
  #24
  #20

Historical evidence lanes
  #8 -> #9 context

Legacy sell-loop stack
  #5 -> #6

Independent stale item
  #2
```

## Branch Map

Remote PR metadata confirms the head and base names above. This environment could not safely prove which remote heads have been auto-deleted after merge or which local tracking branches remain.

Merged branch cleanup candidate:

```text
feat/repo-hygiene-report
```

It is only a local deletion candidate after all of these are true:

```text
not attached to a worktree
no unique local commits
reachable from origin/main
no active PR reference requiring preservation
```

No branch was deleted in this sprint.

## Worktree Map

Local worktrees are unavailable from GitHub metadata. Therefore:

| Worktree question | Decision |
| --- | --- |
| Primary worktree path | Expected from prior handoffs at `%USERPROFILE%\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`; not verified here. |
| Primary dirty/conflicted state | Unknown. |
| Primary safe for new work | No safety claim until the repo hygiene command runs locally. |
| Sibling worktrees present | Unknown. |
| Sibling required | Yes for PR #43, PR #38 recovery, stale-stack replay, or any work when primary is dirty/conflicted. |
| Detached or evidence worktrees | Preserve until `git worktree list --porcelain` and artifact-retention review prove disposal is safe. |

## Dirty / Conflict Decision

Remote mergeability does not identify local conflict files. If the local report detects an in-progress merge, rebase, cherry-pick, revert, or bisect:

1. Do not reset, clean, abort, or overwrite.
2. Record the current branch and HEAD.
3. Record `git status --short --branch`.
4. Record `git diff --name-only --diff-filter=U`.
5. Preserve local commits and uncommitted changes.
6. Use a sibling worktree for unrelated sprint work.

## Generated and Ignored Artifact Map

Known generated surfaces to inspect locally include:

```text
artifacts/latest/repo-hygiene-report.md
artifacts/latest/repo-hygiene-report.json
artifacts/latest/launcher-validation-workhorse/**
artifacts/latest/launcher-validation-workhorse.progress.log
artifacts/latest/launcher-validation-workhorse.handoff.md
artifacts/latest/launcher-validation-workhorse.result.json
artifacts/agent-stop-hook/**
artifacts/agent-remediation/**
BlacksmithGuild_AgentFeedback.json
BlacksmithGuild_AgentRemediationPlan.json
BlacksmithGuild_RuntimeContamination.json
BlacksmithGuild_CampaignActionEvidence.json
```

Classification rules:

- Runtime, crash, launcher, and operator evidence: retain until explicitly superseded and archived.
- Reproducible latest-status packets: inspect producer and retention contract before cleanup.
- Accidental temp files: remove only after content inspection proves no unique work.
- Ignored status alone is not deletion proof.

No artifact was deleted in this sprint.

## Safe Base Branches for Next Sprints

| Next sprint | Safe base |
| --- | --- |
| New repo-floor, documentation, contract, or toolchain work | Fresh branch from current `origin/main` at or after `5efa144b82f703094d41600ce2e4cedc12583dbb`. |
| PR #43 continuation | Exact #43 head `agent/route-automation-operator-plan` in a dedicated sibling worktree. |
| PR #38 recovery | Fresh recovery branch from current `main`; selectively replay verified unique #38 commits. |
| #28-#35 recovery | Fresh recovery branch from current `main`; replay one dependency slice at a time starting with #28 value classification. |
| #24 or #20 recovery | Fresh branch from current `main`; selective replay only. |
| #8/#9 preservation | Read-only inspection of their exact heads, with evidence copied to a current-main preservation branch if still unique. |
| #5/#6 review | Read-only comparison first; any implementation continuation requires a separate runtime lane and current proof plan. |
| #2 recovery | Fresh current-main branch with only still-missing docs/wording replayed. |

## Work Completed

- Resolved the placeholder repo from established sprint context.
- Verified repository metadata and default branch.
- Verified PR #49 merged into `main` at `5efa144b82f703094d41600ce2e4cedc12583dbb`.
- Retrieved the 18-open-PR inventory.
- Verified current mergeability, draft state, head, and base for each open PR.
- Classified active, conflicted, stacked, historical-evidence, and legacy lanes.
- Created this fresh map from current `main` instead of modifying non-mergeable PR #44.
- Performed no feature, runtime, cleanup, deletion, retarget, or PR-close action.

## Changed Files

```text
docs/handoff/20260712-repo-floor-sprint-map.md
```

## Validation Output

Remote validation completed:

```text
repository metadata: PASS
main head lookup: PASS
PR #49 merged-state check: PASS
open PR inventory: PASS (18)
per-PR head/base/draft/mergeability classification: PASS
branch created from current main: PASS
scope review: one docs-only handoff file
```

Local validation unavailable in this coordinator environment:

```text
git fetch origin
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20
ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
git diff --check
```

## Gaps / Risks

- Primary worktree safety remains unknown until the merged repo hygiene command runs locally.
- Local branches, tracking refs, and worktree leases remain unknown.
- PR #43 is mergeable but still draft and runtime-gated; mergeability is not proof completion.
- PR #44, #38, #28, #24, #20, #9, #8, #5, and #2 are currently non-mergeable.
- PR #28 through #35 must be treated as a dependency stack even where individual PRs report mergeable.
- Generated artifacts may contain unique runtime or operator evidence and must not be cleaned by pattern alone.
- A clean primary worktree would not prove sibling worktrees are clean or disposable.

## Exact Next Command

Run from the primary Windows checkout:

```powershell
git fetch origin --prune; .\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
```

## Copy-Paste Handoff Prompt for Next Sprint

```text
You are continuing the BlacksmithGuild repo-floor hygiene pass.

Repo:
EndeavorEverlasting/BlacksmithGuild

Sprint:
Local worktree and branch verification after the 2026-07-12 remote sprint map

Lane:
coordinator / cleanup / local evidence

Owned scope:
- Run the merged repo hygiene command in the primary Windows checkout.
- Verify current branch, HEAD, dirty/conflicted state, in-progress Git operations, local branches, upstream-gone branches, and all worktrees.
- Inspect generated and ignored artifacts without deleting evidence.
- Confirm whether the primary worktree is safe for new work.
- Create sibling worktrees for PR #43 or recovery lanes when isolation is required.
- Identify deletion candidates only with worktree, reachability, upstream, and unique-commit proof.

Forbidden scope:
- No feature implementation.
- No Bannerlord launch.
- No ForgeReboot.
- No command inbox or save mutation.
- No runtime or gameplay claims.
- No broad refactors.
- No branch, worktree, PR, or artifact deletion without explicit proof.

Start exactly:
git fetch origin --prune
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
Get-Content -LiteralPath .\artifacts\latest\repo-hygiene-report.md -Raw
git worktree list --porcelain
git branch -vv

Use these remote facts:
- current main includes merged PR #49 at 5efa144b82f703094d41600ce2e4cedc12583dbb
- PR #43 is the active mergeable draft route/harness lane
- PR #44 is a non-mergeable stale map replaced by docs/handoff/20260712-repo-floor-sprint-map.md
- PR #38 is a non-mergeable stale guardrail stack
- PR #28-#35 are a dependency chain requiring selective replay from current main
- PR #8/#9 are historical evidence lanes
- PR #5/#6 are legacy runtime lanes

Final response must include:
repo, branch, PR/sprint context, lane, scope, forbidden scope, work completed, PR map, worktree map, changed files, validation output, gaps/risks, exact next command, and a copy-paste handoff prompt for the following sprint.
```