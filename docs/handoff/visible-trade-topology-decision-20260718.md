# Visible-Trade PR Topology Decision

```text
[TBG | Repo Floor / Topology | P06 | 2026-07-18]
```

## Context

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Branch: `chore/visible-trade-topology-convergence`
- Base: `main` at `96a182a2fba4646855a92f6e1118d368d8183005`
- Sprint: P06 repo floor and PR topology convergence
- Lane: repo-floor hygiene / stale-PR recovery / integration planning

## Local floor state

| Item | Value |
|---|---|
| Primary worktree | `/workspace/EndeavorEverlasting/BlacksmithGuild` |
| Branch | `main` fast-forwarded to `origin/main` |
| HEAD | `96a182a` |
| Dirty state | clean |
| Conflicts | none |
| Interrupted ops | none |
| Worktrees | 1 (primary) |

## PR dispositions

| PR | State | Decision |
|---:|---|---|
| #2 | Closed | Superseded by PR #66. Same three files replayed onto current main. Merge commit `96a182a2fba4646855a92f6e1118d368d8183005`. |
| #66 | Merged | Wave B identity/disposition schema replay. No further action. |
| #43 | Open, non-mergeable (`dirty`) | Retain as provenance. Do not merge or rebase wholesale. Source of launcher/route contracts for focused extraction. |
| #69 | Open, mergeable against PR #43 (`unstable`) | Reconstruct unique 22-file coordinator value onto current `main` in a replacement branch. Do not continue stacking on PR #43. |

## PR #43 / PR #69 strategy

Selected strategy: **2. Reconstruct only unique current value onto modern `main`.**

Rationale:

- PR #43 is 157 files / 128 commits and reports `mergeable_state: dirty` against `main`. Refreshing the whole stack would repeatedly conflict with evolved mainline contracts (checkpoint discipline, composed E2E, skill routing, sprint capsule, game compatibility gate).
- PR #69 is 22 files / 1 commit stacked on PR #43 head `2cbe33ffb60ededddd287635241912f7399b6fe0`. It depends on PR #43 for launcher and route contracts, but it also imports some of those contracts via its own coordinator surface.
- Modern `main` already contains the game-compatibility gate, composed E2E harness, canonical sprint capsule, and checkpoint discipline. The remaining work is consumer integration, not another generic harness foundation.

Therefore P14 will:

1. Create a fresh branch `repair/visible-trade-proof-current-main` from current `origin/main`.
2. Inventory the 22 PR #69 files and classify each as keep, adapt, superseded, or reject.
3. Reconstruct only the unique coordinator value (event schema, capsule, publication guardrails, CMD entrypoints, tests/verifiers) using current-main harness entrypoints.
4. Preserve the old `feat/visible-trade-one-click-proof-relay` and `agent/route-automation-operator-plan` branches as provenance until unique value is visibly retained.
5. Open/update a current-main replacement PR and comment on PR #69 with the replacement and retained provenance.

## Owned files for P14 reconstruction

From PR #69 file list, the owned surface for reconstruction:

- `.tbg/harness/fixtures/visible-trade-proof.fixtures.json` — adapt to current fixture schema and E2E profile.
- `Run-VisibleTradeProof.cmd` — keep as root entrypoint; route to current coordinator.
- `Show-LatestVisibleTradeProof.cmd` — keep as status entrypoint.
- `Stop-TbgRuntime.cmd` — keep; route through `ForgeStop.cmd soft` instead of ad hoc force-kill.
- `Toggle-TbgEvidenceAutomation.cmd` — keep if evidence toggle remains current; otherwise supersede.
- `scripts/publish-visible-trade-proof-evidence.ps1` — adapt to current publication/sanitization contract.
- `scripts/run-visible-trade-proof.ps1` — core coordinator; adapt to current harness, stop path, compatibility gate, checkpoint discipline, E2E profile, and sprint capsule.
- `scripts/show-latest-visible-trade-proof.ps1` — keep as status reader.
- `scripts/stop-tbg-runtime-proof.ps1` — adapt to repo-owned stop path.
- `scripts/test-visible-trade-proof-coordinator.ps1` — adapt tests to current fixtures and negative cases.
- `scripts/toggle-tbg-evidence-automation-proof.ps1` — keep or supersede per current toggle contract.
- `scripts/verify-visible-trade-proof-coordinator.ps1` — adapt to current dry-run validation.
- `scripts/visible-trade-proof-capsule.ps1` — keep capsule shape; adapt to current sprint-capsule contract.
- `scripts/visible-trade-proof-event-schema.ps1` — keep event schema; integrate with current E2E artifact registry.
- `scripts/visible-trade-launch-boundary.ps1` — already on main; PR #69 only added a BOM byte. Mark as superseded on main.
- `scripts/launcher-fast-frontdoor.ps1`, `scripts/run-launcher-validation-workhorse.ps1`, `scripts/test-launcher-validation-supervisor-isolated-remote.ps1`, `scripts/test-launcher-validation-workhorse-validation-only.ps1`, `scripts/verify-bannerlord-save-layout-contract.ps1`, `scripts/verify-launcher-validation-supervisor.ps1`, `scripts/verify-launcher-validation-workhorse.ps1` — these are BOM-only edits in PR #69. They already exist on main in current form; mark as superseded.

## P14 base and worktree

- Base: `main` at `96a182a2fba4646855a92f6e1118d368d8183005` (or newer after P06 PR merges).
- Repair branch: `repair/visible-trade-proof-current-main`.
- Worktree: primary checkout or a fresh sibling worktree from current `origin/main` if another lane owns the primary.
- Merge order: open replacement PR against `main`; do not merge in P14; leave for P15 after runtime proof.

## Retained provenance

- `agent/route-automation-operator-plan` head `2cbe33ffb60ededddd287635241912f7399b6fe0` remains untouched.
- `feat/visible-trade-one-click-proof-relay` head `900820b2a5a5b09e694c9c08e8664c93f54d8680` remains untouched.
- PR #43 and PR #69 remain open until the replacement PR visibly retains their unique value and is merged or explicitly held.

## Validation performed

- GitHub metadata for PR #2, #43, #66, #69 inspected.
- Local `main` fast-forwarded to `origin/main` safely.
- `git status --short` clean.
- `git diff --check` pending.
- Stale-PR ledger JSON syntax validated.
- Dashboard markdown regenerated from ledger.

## Not performed

- No PowerShell/BOM contract validation (no `pwsh`/`powershell` in this environment).
- No `dotnet build` (no dotnet in this environment).
- No Bannerlord launch or runtime proof.
- No PR #69 reconstruction (P14 scope).

## Exact next command

```powershell
git checkout -b repair/visible-trade-proof-current-main origin/main
```
