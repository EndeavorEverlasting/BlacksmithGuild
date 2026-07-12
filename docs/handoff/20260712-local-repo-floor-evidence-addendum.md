# 2026-07-12 Local Repo-Floor Evidence Addendum

## Purpose

This addendum updates `docs/handoff/20260712-repo-floor-sprint-map.md` with evidence captured from the Windows checkout after PR #50 was opened. It does not repair launcher behavior. It records the actual local worktree state, the first local execution of PR #43 head `2fd964ac679b4eb0e7403f6948bf4cf96ae7b484`, and the smallest safe follow-up lane.

## Repo / Branch / Sprint

- **Repository:** `EndeavorEverlasting/BlacksmithGuild`
- **Coordinator branch:** `docs/repo-floor-sprint-map-20260712`
- **Coordinator PR:** #50
- **Active launcher lane:** PR #43, `agent/route-automation-operator-plan`
- **Lane:** coordinator / cleanup / local evidence

## Scope

- Record local branches and worktrees supplied by the operator.
- Classify primary and sibling worktree safety without deleting or rewriting anything.
- Record the supervisor failure as a runtime-proof gap rather than a generic launcher failure.
- Identify the exact follow-up repair lane and collision boundary.

## Forbidden Scope

- No launcher implementation changes in this coordinator branch.
- No Bannerlord launch or gameplay claim.
- No save, branch, worktree, PR, or artifact deletion.
- No reset, clean, stash, force push, merge, or unrelated refactor.

## Local Branch Evidence

The primary checkout reported:

```text
Path:   C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Branch: main
HEAD:   a1a7151 docs(launcher): codify five-second frontdoor and local evidence
```

The displayed `main` history contains PR #43 launcher commits rather than a demonstrated synchronization with `origin/main`. The operator did not provide `git status --short --branch` or `git rev-list --left-right --count main...origin/main` for the primary checkout.

**Decision:** the primary checkout is not a safe generic sprint base yet. Preserve it and use a sibling worktree until branch ancestry, dirty state, and upstream comparison are explicit.

`git diff --check` returned no output in the primary checkout. That proves whitespace validation only; it does not prove a clean worktree, correct branch ancestry, or absence of ignored/generated evidence.

## Local Worktree Map

| Worktree | HEAD / branch | Current classification | Safe action |
| --- | --- | --- | --- |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` | `a1a7151 [main]` | Primary branch ancestry and dirty state unverified; local `main` visibly contains launcher-lane commits | Preserve. Do not use as an unrelated sprint base until status and main/upstream comparison are recorded. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation` | `91704e6 [feat/route-branch-state-runtime-start]` | Active route-runtime proof worktree from prior handoffs | Preserve. Do not mutate from repo-floor or launcher-supervisor lanes. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-agent-status-relay` | `74b1df0 (detached HEAD)` | Detached agent/evidence worktree; uniqueness and generated artifacts unverified | Preserve pending `git status`, reachability, and artifact-retention proof. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence` | `b9e901c (detached HEAD)` | Historical launcher-evidence worktree | Preserve as evidence. Do not prune by age or detached state alone. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-operator-plan` | fast-forwarded to `2fd964a [agent/route-automation-operator-plan]` | PR #43 lane; supervisor observed zero local status entries at invocation | Safe only for the bounded PR #43 repair/validation lane. Do not use for repo-floor cleanup or unrelated work. |

No worktree or branch was deleted, detached, reset, cleaned, or repurposed by this sprint.

## Open PR Map Update

The operator's local `gh pr list --state open --limit 20` returned 19 open PRs. The highest-priority floor classifications remain:

| PR | Classification | Decision |
| --- | --- | --- |
| #50 | Current docs-only repo-floor map | Continue as the coordinator evidence lane. |
| #43 | Active launcher/harness lane | Keep isolated in `BlacksmithGuild-route-operator-plan`. It now has contract proof but a local Windows PowerShell runtime blocker. |
| #44 | Older repo-floor map | Superseded in content by #50; do not close or delete without separate proof. |
| #38 | Stale guardrail/harness stack | Recover only by selective replay from a current safe base. |
| #35, #34, #33, #32, #31, #30, #29, #28 | Older stacked harness/feedback lanes | Preserve dependency order; do not merge independently merely because an individual PR is mergeable. |
| #24, #20, #9, #8, #6, #5, #2 | Legacy route, governor, evidence, and schema lanes | Compare read-only first; no direct use as a fresh sprint base. |

PR #43 remains open, draft, and mergeable at head `2fd964ac679b4eb0e7403f6948bf4cf96ae7b484`. Its three remote contract workflows passed, but the local supervisor run below demonstrates that static/contract success did not reach launcher execution.

## PR #43 Local Execution Evidence

The route-operator worktree successfully fast-forwarded from `204cb8c` to `2fd964ac679b4eb0e7403f6948bf4cf96ae7b484`.

The root command then recorded:

```text
STARTED: The multimodal launcher-validation supervisor started.
PASSED: Remote fetch attempt 1 completed.
INFO: Branch agent/route-automation-operator-plan was at 2fd964ac with 0 local status entries.
INFO: The branch was 0 ahead and 0 behind origin/agent/route-automation-operator-plan.
FAILED: Cannot bind argument to parameter 'List' because it is an empty collection.
Exit code: 99
```

### Failure classification

- **Not a dirty-worktree blocker.** The supervisor reported zero local status entries.
- **Not a branch divergence blocker.** The branch reported zero ahead and zero behind.
- **Not a fetch blocker.** Fetch attempt one passed.
- **Not a launcher or CAUTION-window result.** The strict leaf workhorse and fast launcher frontdoor were never invoked.
- **Actual layer:** Windows PowerShell 5.1 supervisor mode-selection runtime.

The failure occurs while the supervisor constructs its first workspace candidate. `Get-WorkspaceCandidates` creates an empty generic list and passes it to `Add-CandidateUnique`. The typed mandatory `List` parameter rejects the empty collection before the first `current_synced` candidate can be added.

The smallest likely implementation repair is to allow an empty collection on that parameter, for example:

```powershell
function Add-CandidateUnique {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$List,

        [Parameter(Mandatory = $true)]
        $Candidate
    )
    # Existing body remains bounded.
}
```

This addendum does not apply that patch because PR #50 owns coordination only.

## Evidence and Artifact Retention

The failed run wrote or attempted to write these ignored local evidence surfaces in the PR #43 worktree:

```text
artifacts/latest/launcher-validation-supervisor.progress.log
artifacts/latest/launcher-validation-supervisor.handoff.md
artifacts/latest/launcher-validation-supervisor.result.json
artifacts/latest/launcher-validation-supervisor/<run-id>/
```

The leaf workhorse artifacts displayed by the CMD wrapper may be absent or stale because the leaf worker did not start. A follow-up agent must distinguish supervisor evidence from any pre-existing `launcher-validation-workhorse.*` latest pointers.

Do not delete or overwrite the failed supervisor packet before the repair sprint records it or confirms the stable latest pointers have been superseded by a successful rerun.

## Safe Bases and Parallel Lanes

| Lane | Safe base / worktree | Owned scope | Collision boundary |
| --- | --- | --- | --- |
| Repo-floor docs | PR #50 branch `docs/repo-floor-sprint-map-20260712` | This map and local-evidence addendum only | Do not edit launcher scripts or route runtime. |
| Supervisor binding repair | Exact PR #43 head `2fd964ac` in `BlacksmithGuild-route-operator-plan`, or a new sibling fix worktree from that head | `scripts/run-launcher-validation-supervisor.ps1`, focused verifier/fixture, PR #43 docs if needed | Do not edit `src/BlacksmithGuild/MapTrade/*`; do not mutate 037A validation or detached evidence worktrees. |
| Route runtime proof | `BlacksmithGuild-037a-validation` at its owned branch | Existing bounded MapTrade runtime files and proof | Do not edit launcher supervisor/workhorse files. |
| New unrelated work | Fresh sibling branch from verified `origin/main` | New bounded sprint only | Do not use the primary `main` checkout until its ancestry and dirty state are resolved. |
| Historical evidence review | Detached relay / PR25 worktrees, read-only | Reachability, unique commits, artifact retention | No cleanup until proof exists. |

## Validation Reached

```text
local git log evidence: received
local worktree list: received
local open PR list: received (19)
primary git diff --check: passed
PR #43 route worktree fast-forward: passed
PR #43 remote fetch: passed
PR #43 exact branch synchronization: passed (0 ahead / 0 behind)
PR #43 supervisor syntactic-English logging: observed
PR #43 supervisor result and handoff paths: emitted
PR #43 workspace mode selection: failed before first mode
PR #43 leaf workhorse execution: not reached
PR #43 launcher execution: not reached
Bannerlord runtime proof: not reached
```

## Proof-Level Classification

- **Contract proof:** reached for PR #43 remote checks.
- **Harness proof:** partial; the supervisor started and produced evidence, but did not select a workspace.
- **Static test proof:** reached remotely, insufficient for this PowerShell 5.1 binding case.
- **Build proof:** not reached by this local run.
- **Launcher/browser proof:** not reached.
- **Command ACK proof:** not reached.
- **Behavior observed proof:** supervisor failure behavior observed.
- **Live runtime proof:** not reached.

## Gaps / Risks

- The primary checkout's `main` branch may be ahead, behind, or diverged from `origin/main`; no assumption is safe from the displayed log alone.
- Primary dirty and ignored state remains unknown because `git status --short --branch --ignored` was not included.
- Detached worktrees may contain unique commits or runtime evidence.
- PR #43's green static contracts missed a Windows PowerShell 5.1 empty-collection binding failure.
- A successful supervisor retry after the binding fix still would not prove CAUTION handling, launcher handoff, campaign readiness, movement, or trade.
- Concurrent agents must not both edit `scripts/run-launcher-validation-supervisor.ps1` without explicit ownership.

## Exact Next Command

Create an isolated repair worktree at the exact failing PR #43 head without modifying the clean route-operator worktree:

```powershell
git -C "$env:USERPROFILE\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-operator-plan" fetch origin --prune; git -C "$env:USERPROFILE\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-operator-plan" worktree add -b fix/launcher-supervisor-empty-list "$env:USERPROFILE\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-launcher-supervisor-fix" 2fd964ac679b4eb0e7403f6948bf4cf96ae7b484
```

## Copy-Paste Handoff Prompt for the Repair Sprint

```text
EXECUTE THE REPO SPRINT. DO NOT REWRITE THIS PROMPT.

Repo:
EndeavorEverlasting/BlacksmithGuild

Branch / worktree:
fix/launcher-supervisor-empty-list
C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-launcher-supervisor-fix

Base:
PR #43 head 2fd964ac679b4eb0e7403f6948bf4cf96ae7b484

Sprint:
Fix Windows PowerShell 5.1 empty-list binding in the multimodal launcher-validation supervisor

Lane:
launcher harness repair / bounded runtime regression

Owned scope:
- scripts/run-launcher-validation-supervisor.ps1
- scripts/verify-launcher-validation-supervisor.ps1
- a focused synthetic/runtime regression fixture or test for first-candidate insertion into an empty generic list
- docs/handoff/launcher-validation-workhorse.md only if behavior documentation changes
- .github/workflows/governor-contracts.yml only if the new targeted verifier must be registered

Forbidden scope:
- Do not edit src/BlacksmithGuild/MapTrade/*
- Do not mutate BlacksmithGuild-037a-validation
- Do not mutate detached agent-status-relay or PR25 evidence worktrees
- Do not delete saves, branches, worktrees, PRs, or evidence
- Do not use git reset --hard, git clean, git stash, force push, or PR merge
- Do not claim launcher, campaign, movement, arrival, trade, or live runtime proof unless directly observed

Evidence from the failed local run:
- current route worktree was clean
- branch was exactly synchronized with origin/agent/route-automation-operator-plan
- fetch passed
- supervisor failed before selecting current_synced
- exact error: Cannot bind argument to parameter 'List' because it is an empty collection.
- failure seam: Add-CandidateUnique receives a newly created empty System.Collections.Generic.List[object]

Required behavior:
1. The first candidate can be added to an empty generic list under Windows PowerShell 5.1.
2. Empty-list handling has a focused executable regression test, not only text matching.
3. current_synced is selected for a clean, exactly synchronized expected branch.
4. Existing dirty/ahead/diverged isolated-mode behavior remains intact.
5. The supervisor still never resets, cleans, stashes, force-pushes, deletes saves/branches/worktrees, or merges a PR.
6. The supervisor writes syntactic-English result and handoff artifacts on both success and failure.

Run first:
git status --short --branch
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-launcher-validation-supervisor.ps1

Then implement, validate, commit, push, and open a bounded PR into agent/route-automation-operator-plan or update PR #43 through an explicitly safe integration path.

Final evidence must include:
- changed files
- focused regression result under Windows PowerShell 5.1
- existing supervisor/workhorse/frontdoor validators
- git diff --check
- commit SHA
- push/PR state
- exact local rerun command
```
