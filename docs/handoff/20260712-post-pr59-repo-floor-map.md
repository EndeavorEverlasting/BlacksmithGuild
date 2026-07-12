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

---

## Wave 0 Local Evidence Reconciliation (2026-07-12, post-PR #60 merge)

### Preflight

| Field | Value |
|---|---|
| **Repository** | `EndeavorEverlasting/BlacksmithGuild` |
| **Primary path** | `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` |
| **Branch** | `main` |
| **HEAD** | `8fe0e7099842069144aab168643872e2b78b4aa9` (now synced to `origin/main`) |
| **Upstream** | `origin/main`, 0 ahead / 4 behind (before fast-forward), now synced |
| **Git status** | clean — no dirty, untracked, or staged files |
| **Conflicts** | none — `git diff --name-only --diff-filter=U` empty |
| **Interrupted ops** | none — no `MERGE_HEAD`, `CHERRY_PICK_HEAD`, `REVERT_HEAD`, `BISECT_LOG`, `rebase-apply`, or `rebase-merge` |
| **Worktrees** | 5 attached (see full map below) |
| **`git diff --check`** | PASS — no whitespace errors |

### Updated center of gravity

Current `origin/main` (and now local `main`) is at:

```
8fe0e70 docs(coordination): map post-PR59 repo floor (#60)
```

This includes all material from PRs #57 (interoperability), #58 (stale-PR recovery plan), #59 (syntactic-English recovery renderer), and #60 (this repo-floor map). The four new remote-only commits that were ahead of local `main` have been fast-forwarded into the local checkout.

The current 19 open PRs are inventoried above with the stale-PR recovery manifest from PR #58 as the authoritative ledger.

### Verified worktree map

| # | Path | Branch / HEAD | SHA | Upstream | Ahead/Behind `origin/main` | Dirty | Conflicted | Interrupted | Decision |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `BlacksmithGuild` (primary) | `main` | `8fe0e70` | `origin/main` | 0 ahead / 0 behind | clean | none | none | **Safe for new work.** Primary checkout is clean, synced, and non-conflicted. |
| 2 | `BlacksmithGuild-037a-validation` | `feat/route-branch-state-runtime-start` | `91704e6` | `origin/feat/route-branch-state-runtime-start` [gone] | 6 ahead / 80 behind | clean | none | none | **Retain** — active route-runtime worktree. Upstream branch was deleted on remote; branch now local-only. Do not mutate from other lanes. |
| 3 | `BlacksmithGuild-agent-status-relay` | detached | `74b1df0` | none (detached) | 0 ahead / 70 behind | clean | none | none | **Retain** — historical relay/evidence worktree. Read-only inspection; no cleanup until evidence archive manifest exists. |
| 4 | `BlacksmithGuild-pr25-launcher-evidence` | detached | `b9e901c` | none (detached) | 0 ahead / 114 behind | clean | none | none | **Retain** — historical launcher-evidence worktree. Read-only; no cleanup without evidence preservation proof. |
| 5 | `BlacksmithGuild-route-operator-plan` | `agent/route-automation-operator-plan` | `ddf8663` | `origin/agent/route-automation-operator-plan` | 111 ahead / 4 behind | clean | none | none | **Reuse for PR #43 lane only.** 22 ahead of upstream; contains merge of current main. Do not use for unrelated work. |

**Primary checkout now safe.** All five worktrees are clean, conflict-free, and have no interrupted operations.

### Verified ignored-artifact map

| Ignored path | File count | Approx size | Freshness | Owner / sprint | Decision |
|---|---|---|---|---|---|
| `.local/` | 5 | 1.7 KB | 2026-07-12 | Coordinator stop-hook state | **Retain** — active operator control surface |
| `artifacts/` | 43 | ~1.4 GB | newest: 2026-07-12 | PR #43 workhorse/supervisor; coordinator packets | **Retain** — active evidence; not disposable by age or ignored status alone |
| `docs/evidence/` | 1124 | ~1.1 GB | newest: 2026-07-05 | PR #8/#9 F7 gate evidence; live-cert marathons; reboot sessions | **Retain** — historical runtime evidence. Classify per compendium-preservation rules before any cleanup. |
| `docs/control/logs/open/` | 28 | 116 KB | newest: 2026-07-03 | Agent chat logs; autonomous-session targets | **Retain** — agent chat logs and session targets |
| `Module/BlacksmithGuild/bin/` | ~8 | build artifacts | varies | Build output | **Retain** — regenerated on build; harmless ignored output |
| `src/BlacksmithGuild/obj/` | ~many | build intermediates | varies | Build output | **Retain** — regenerated on build |
| `.cursor/rules/` | unknown | unknown | unknown | IDE/cursor config | **Retain** — local IDE config; not repo-owned |

Total ignored: ~2.5 GB across ~1200+ files. No deletion was performed. Primary evidence classes: coordinator control, launcher/runtime proof, build output, and historical certification evidence.

### What has changed since the map was written

1. **`main` advanced** from `75078de` to `8fe0e70` with PRs #57-#60 merged.
2. **PR #60 merged** this repo-floor map and its known unknowns.
3. **PR #43 upstream advanced** — `agent/route-automation-operator-plan` on remote is now at `2fd964a` (changed fork point). Local route-operator worktree at `ddf8663` is 22 ahead of remote upstream, reflecting a merge of `main`.
4. **PR #52** is still open, mergeable, and based on `agent/route-automation-operator-plan`. Base branch still exists and has advanced.
5. **PR #44** (`docs/repo-floor-sprint-map-20260711`) remote branch still exists at `19ed7ee`. Not deleted.
6. **Multiple new remote branches** appeared: `docs/post-pr59-repo-floor-map-20260712`, `docs/stale-pr-cherry-pick-sprint-20260712`, `feat/continuum-harness-interoperability`, `feat/stale-pr-recovery-syntactic-english`. These are merged or in-progress PR head branches.
7. **ForgeRepoHygiene.cmd** exists at the expected path; **ForgeStalePrRecovery.cmd** does not exist locally (not checked out yet). The stale-PR recovery script is at `scripts/tbg/Invoke-TbgStalePrRecovery.ps1`.

### Validation

```text
git fetch origin --prune:                PASS (new remote branches: docs/post-pr59-*, docs/stale-pr-*, feat/continuum-*, feat/stale-pr-*)
git status --short:                      PASS (clean)
git diff --check:                        PASS
git rev-parse HEAD:                      PASS (8fe0e7099842069144aab168643872e2b78b4aa9)
git diff --name-only --diff-filter=U:    PASS (empty - no conflicts)
interrupted ops check:                   PASS (none found)
worktree count:                          PASS (5)
worktree dirty state:                    PASS (all clean)
ForgeRepoHygiene.cmd exists:            PASS
ForgeStalePrRecovery.cmd exists:        FAIL (expected at root, missing; script exists at scripts/tbg/)
```

**Skipped but available for later:**
```powershell
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked    # not run - no -NoGitHub flag confirmed; root CMD exists
.\ForgeStalePrRecovery.cmd -Wave 0                 # cannot run - CMD wrapper missing; use scripts/tbg/Invoke-TbgStalePrRecovery.ps1 directly
Get-Content .\artifacts\latest\repo-hygiene-report.md
Get-Content .\artifacts\latest\stale-pr-recovery\stale-pr-recovery.report.md
```

### Updated safe bases

| Lane | Safe base / worktree | Status |
|---|---|---|
| **Independent new work** | Fresh branch from `origin/main` (`8fe0e70`) in a new sibling worktree | Primary checkout is safe but feature work should use an isolated sibling worktree per the existing clean-branch rule |
| **PR #43 continuation** | `BlacksmithGuild-route-operator-plan` at `ddf8663` | Worktree is clean and 22 ahead of upstream; use as-is for PR #43 bounded work |
| **PR #52 nested repair** | PR #52 head `2bb7077`, base `agent/route-automation-operator-plan` | PR #52 is mergeable; safe to merge into route-operator worktree after branch-local revalidation |
| **037a validation** | `BlacksmithGuild-037a-validation` at `91704e6` | Upstream gone; branch is local-only; preserve for owned route-runtime work |
| **Detached relay / PR25 evidence** | Read-only in their existing worktrees | No mutation; evidence classification is a separate sprint |
| **Stale PR replay** | Fresh branch from `origin/main` (`8fe0e70`) per PR #58 manifest | Do not use any stale PR head as a base |
| **Launcher extraction** | Fresh branch from `origin/main` in a dedicated sibling worktree | Primary is safe but launcher scripts overlap with PR #43 lane |
| **Continuum consumer** | `EndeavorEverlasting/Continuum` main | No BlacksmithGuild mutation |

### Gaps and risks

1. ForgeStalePrRecovery.cmd does not exist at repo root. The referenced stale-PR recovery script at `scripts/tbg/Invoke-TbgStalePrRecovery.ps1` exists and can be called directly, but the CMD wrapper promised by the map is absent. A follow-up lane should either create the wrapper or update the map.
2. ForgeRepoHygiene.cmd exists but has not been executed in this Wave 0. The hygiene report and stale-PR recovery report at `artifacts/latest/` do not exist yet.
3. PR #43's local worktree (route-operator-plan) is 22 commits ahead of its upstream. These commits include a merge of `main`. The exact delta from the upstream head `2fd964a` should be inspected before any push or PR update.
4. PR #52's head (`2bb7077`) is not fetched into any local worktree. A fetch + checkout or dedicated worktree is required to inspect or merge it.
5. The 037a-validation upstream branch was deleted on remote. The worktree now holds 6 local-only commits. These should be classified before the worktree is released or archived.
6. The two detached worktrees (agent-status-relay and pr25-launcher-evidence) are 70 and 114 commits behind `origin/main` respectively. They contain historical evidence that must be preserved but also may have unique unreachable commits that need archiving before the worktrees can be released.
7. Ignored artifacts total ~2.5 GB across ~1200+ files. No cleanup was performed. The large evidence directories (`docs/evidence/` at 1.1 GB, `artifacts/` at 1.4 GB) must be inventory-classified by a separate compendium-preservation lane before any deletion.

### Next safe commands

**Remaining Wave 0 commands (optional, adds hygiene reports):**
```powershell
.\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
& .\scripts\tbg\Invoke-TbgStalePrRecovery.ps1 -Wave 0
```

**Primary lane (coordinator / documentation):** This reconciliation is committed as the local-evidence update. No further changes required in this lane.

**Next execution lane:** The highest-value bounded next sprint is **PR #52 merge into PR #43 branch**, followed by launcher supervisor validation. The copy-paste handoff is below.

### Handoff for next agent

```text
You are continuing the BlacksmithGuild local Wave 0 completion.

Repo: EndeavorEverlasting/BlacksmithGuild
Primary path: C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Current main: 8fe0e7099842069144aab168643872e2b78b4aa9
Sprint: Local Wave 0 floor proof — remaining hygiene and PR #52 resolution
Lane: coordinator / cleanup / PR integration

Verified local state:
- primary checkout: main @ 8fe0e70, clean, synced with origin/main
- 5 worktrees all clean, none conflicted, no interrupted ops
- ForgeRepoHygiene.cmd exists at root
- ForgeStalePrRecovery.cmd MISSING at root (exists at scripts/tbg/Invoke-TbgStalePrRecovery.ps1)
- PR #43 route-operator worktree: agent/route-automation-operator-plan @ ddf8663, 22 ahead of upstream
- PR #52: mergeable, head 2bb7077, base agent/route-automation-operator-plan
- 037a-validation: feat/route-branch-state-runtime-start @ 91704e6, upstream gone
- agent-status-relay: detached @ 74b1df0, 70 behind origin/main
- pr25-launcher-evidence: detached @ b9e901c, 114 behind origin/main

Remaining work:
1. Run ForgeRepoHygiene.cmd and record its report
2. Create ForgeStalePrRecovery.cmd wrapper or use Invoke-TbgStalePrRecovery.ps1 directly
3. Fetch PR #52 head and merge into route-operator worktree for branch-local validation
4. Validate launcher supervisor with empty-list fix in the merged branch
5. Update or supersede PR #43 with the validated head

Forbidden:
- No feature implementation
- No Bannerlord launch or runtime claims
- No deletion of worktrees, branches, PRs, or ignored evidence
- No cleanup of 037a-validation, relay, or PR25 evidence
- No ForgeReboot or save mutation

---

## Wave 0 Gap Resolution (2026-07-12, second pass)

### Gap 1: ForgeStalePrRecovery.cmd missing — RESOLVED

The wrapper exists at `ForgeStalePrRecovery.cmd`. It was included in the PRs #57-#60 commits that were fetched and fast-forwarded to local `main` during the first Wave 0 pass. It is a 6-line CMD wrapper that calls `scripts/tbg/Invoke-TbgStalePrRecovery.ps1`.

### Gap 2: ForgeRepoHygiene.cmd not executed — RESOLVED

Ran successfully:

```text
Command: .\ForgeRepoHygiene.cmd -NoGitHub -FailOnBlocked
Output: artifacts/latest/repo-hygiene-report.md
        artifacts/latest/repo-hygiene-report.json
Verdict: ATTENTION
Reason: One or more local branches track deleted upstream refs; inspect reachability before deletion.
```

Specifically, `feat/route-branch-state-runtime-start` (037a-validation worktree) has a `[gone]` upstream. This is the only local branch with a deleted upstream.

### Gap 3: PR #43 route-operator 22 ahead — CLASSIFIED

All 22 ahead commits are non-unique — they consist entirely of:
- a merge commit of `origin/main` into `agent/route-automation-operator-plan`
- commits already on `origin/main` that were pulled in by the merge
- the local earlier floor-map commits (PR #50, etc.)

No unique unpublished work exists in the 22-ahead delta. The worktree is safe to push if desired, but the merge of `main` should be re-validated against the latest `origin/main` first.

### Gap 4: PR #52 head not fetched — FETCHED

`fix/launcher-supervisor-empty-list` at `2bb7077` has been fetched into the route-operator worktree's `FETCH_HEAD`. The head is mergeable and ready for branch-local validation. Not yet merged — that is a separate implementation/validation lane.

### Gap 5: 037a-validation 6 local-only commits — CLASSIFIED

Branch `feat/route-branch-state-runtime-start` at `91704e6` has 6 unique commits not reachable from any remote:

| Commit | Message | Classification |
|---|---|---|
| `fa1cef6` | feat(route): add route-start cert fields | Feature implementation — unique, not on main |
| `c7999c5` | feat(route): write route-start life cert | Feature implementation — unique, not on main |
| `1de6417` | feat(route): start branch-selected travel on campaign tick | Feature implementation — unique, not on main |
| `7b5b836` | fix(route): use campaign party position API | Fix — applies to same feature surface |
| `fe6d07d` | fix(route): preserve branch auto-start retry after failed start | Fix — applies to same feature surface |
| `91704e6` | fix(route): emit cert for branch-state blockers | Fix — applies to same feature surface |

These are 6 unique feature/fix commits implementing branch-selected route travel. They are not abandoned or unstable work — they are real implementation that was never merged. Upstream was deleted when the PR branch was superseded. **Decision: preserve.** Retain the worktree and branch. Do not prune. The 6 commits should be selectively replayed onto current `main` in a separate implementation sprint.

### Gap 6: Detached worktrees (agent-status-relay, pr25-launcher-evidence) — CLASSIFIED

Both detached worktrees have **zero unique commits not reachable from `origin/main`**. They are read-only checkouts of old SHAs:

| Worktree | SHA | Unique commits ahead of `origin/main` | Artifacts |
|---|---|---|---|
| `agent-status-relay` | `74b1df0` | 0 | `artifacts/` ignored directory |
| `pr25-launcher-evidence` | `b9e901c` | 0 | `.local/`, build artifacts, evidence |

Both can be released (pruned) after any useful evidence files are archived or noted as consumed. **Decision: retain for now** — they are harmless, not blocking any lane, and may contain referenced evidence paths. Mark as safe-to-release in a future cleanup sprint after evidence paths are recorded.

### Gap 7: Compendium preservation classification — COMPLETE

A full compendium-preservation inventory report is appended below.

---

## Compendium Preservation: Ignored Artifact Classification

### Classification Rules

For every artifact surface, the following are recorded:
- **owner** — sprint, PR, or agent that created the evidence
- **branch / head** — exact commit that produced it
- **proof level** — what type of evidence it represents
- **freshness** — newest file timestamp
- **size / count** — total files and bytes
- **replacement or archive status** — whether a superseding record exists
- **safe deletion gate** — condition under which deletion is safe

No deletion was performed. All evidence is preserved.

### `.local/` — Coordinator Control Surface

| Field | Value |
|---|---|
| Files | 5 |
| Size | 1.7 KB |
| Freshness | 2026-07-12 04:21 |
| Contents | 4 governor-smoke summaries (2026-06-27), 1 operator stop-requested JSON (2026-07-12) |
| Owner | Coordinator / governor-smoke sprint |
| Proof level | Operator control surface |
| Deletion gate | Safe to delete `governor-smoke/` subdirectories once operator confirms stop-requested is current. `forge-stop-requested.json` should be preserved as active operator surface. |

### `artifacts/latest/` — Current Coordinator + Evidence Packet

| Field | Value |
|---|---|
| Files | 2 (currently) |
| Size | 32 KB |
| Freshness | 2026-07-12 15:39 |
| Contents | `tbg-chat-packet.json`, `tbg-chat-packet.md` |
| Owner | Coordinator / relay / current sprint |
| Proof level | Current status packet |
| Deletion gate | Safe to overwrite on next packet generation. Preserve until superseded by next wave. |

### `artifacts/route-owned-clock-live-proof/` — Runtime Launcher Evidence

| Field | Value |
|---|---|
| Files | 33 |
| Size | ~1.4 GB |
| Freshness | 2026-07-05 18:43 |
| Contents | 21 JSON files (AgentIterationConfig, CommandAck, RuntimeLifecycle, Status, etc.), 11 raw Bannerlord Phase1.log copies, 1 BLOCKER text file |
| Owner | PR #43 route / launcher runtime proof sprint |
| Proof level | Live runtime launcher proof |
| Safe deletion | **NOT YET.** Contains the only copies of Bannerlord runtime evidence from clock-based route proof. The 1 GB Phase1.log is also duplicated in `docs/evidence/live-cert/20260624-132648/`. |
| Largest file | `collected/...BlacksmithGuild_Phase1.log` — 1068 MB (copy of live-cert evidence) |
| Deletion gate | After PR #43 route proof is superseded by a fresh successful launcher validation run and the evidence is archived with a manifest. |

### `artifacts/merge-safety/` — Conflict Preservation Copies

| Field | Value |
|---|---|
| Files | 5 |
| Size | 53 KB |
| Freshness | 2026-07-06 15:50 |
| Contents | Pre-PR #37 local MapTrade backup (3 files), PR #37 conflict `MapTradeBehavior.cs` copies (2 files) |
| Owner | Merge safety lane |
| Proof level | Conflict preservation |
| Deletion gate | Safe to delete after PR #37 conflict is resolved and the correct version is on `main`. The conflict is long resolved (PR #37 merged at `0a0fdc0`). |

### `artifacts/local-superseded/` — Superseded Documentation

| Field | Value |
|---|---|
| Files | 1 |
| Size | 4.4 KB |
| Freshness | 2026-07-05 03:17 |
| Contents | Superseded `auto-travel-clock-resume-doctrine.md` |
| Owner | Documentation |
| Deletion gate | Safe to delete — superseded by current version in `docs/handoff/` |

### `docs/evidence/` — Historical Runtime Certification Evidence

#### `docs/evidence/live-cert/` (1071 files, ~1.1 GB)

Organized into timestamped run directories. Major categories:

| Category | Date range | Runs | Size | Contents |
|---|---|---|---|---|
| F7 gate checkpoint attempts | 2026-06-21 to 2026-06-22 | ~45 | ~1 MB | `BlacksmithGuild_Status.json` checkpoint files — all sub-100 KB |
| PR #11 launch/attach/execute | 2026-06-24 to 2026-06-25 | ~20 | ~1.12 GB | Full certification runs including 1 GB Phase1.log (from `20260624-132648`), process snapshots, state classifications, termination detection |
| Autonomous assist sessions | 2026-06-25 to 2026-07-05 | ~40 | ~2 MB | Session transcripts, process snapshot series, timeline schemas |
| Reboot sessions | 2026-06-28 to 2026-07-05 | 8 | ~195 KB | ForgeReboot restart checkpoints |

**Key finding:** The 1 GB `BlacksmithGuild_Phase1.log` in `20260624-132648-pr11-launch-attach-execute/` is the single largest file and is duplicated in `artifacts/route-owned-clock-live-proof/20260705-163225/collected/`. Two copies of the same 1 GB file exist on disk.

| Safe deletion gate | Condition |
|---|---|
| `BlacksmithGuild_Status.json` checkpoints | Safe to delete after a current `origin/main` agent status relay confirms the current registration state — **but preserve the directory structure as evidence record** |
| PR #11 Phase1.log + collected copy | Safe to delete only after PR #43 rerun produces fresh equivalent evidence under current harness |
| Autonomous assist sessions | Safe to delete after the compendium-preservation skill records provenance and unique insight |
| Reboot sessions | Safe to delete after reboot evidence is documented in a handoff |

#### `docs/evidence/f7-wave2-cert-console.log` + `f7-wave3-cert-console.log`

| Field | Value |
|---|---|
| Size | 17.8 KB + 36.6 KB |
| Freshness | 2026-06-22 |
| Contents | F7 gate certification console output |
| Deletion gate | Preserve as historical record until F7 evidence is archived in handoff docs |

### `docs/control/logs/open/` — Agent Chat Logs and Session Targets

| Field | Value |
|---|---|
| Files | 28 |
| Size | 116 KB |
| Freshness | 2026-07-03 |
| Notable | Agent chat transcripts, session attach docs, window-delta doctrine, autonomous-assist target, town-to-town trade cert, live-cert marathon |
| Deletion gate | Preserve. These are operational coordination records. Delete only after a separate compendium-preservation lane inventories each file's unique value. |

### `Module/BlacksmithGuild/bin/` — Build Output

| Field | Value |
|---|---|
| Files | ~8 |
| Contents | `0Harmony.dll`, `BlacksmithGuild.dll`, `BlacksmithGuild.pdb` (shipping + editor variants) |
| Deletion gate | Safe to delete — regenerated on next `dotnet build`. Harmless ignored output. |

### `src/BlacksmithGuild/obj/` — Build Intermediates

| Field | Value |
|---|---|
| Files | ~many |
| Contents | C# compiler object files |
| Deletion gate | Safe to delete at any time. Regenerated on build. |

### `.cursor/rules/` — IDE/Local Config

| Field | Value |
|---|---|
| Files | unknown |
| Contents | Cursor IDE rules |
| Deletion gate | Ignored by `.gitignore`. Not repo-owned. Preserve as local config. |

### Summary

| Surface | Files | Size | Retention | Deletion available? |
|---|---|---|---|---|
| `.local/` | 5 | 1.7 KB | Active control surface | No (stop-requested active) |
| `artifacts/latest/` | 2 | 32 KB | Current packet | Overwrite next wave |
| `artifacts/route-owned-clock-live-proof/` | 33 | ~1.4 GB | Active runtime proof | No — supersession gate |
| `artifacts/merge-safety/` | 5 | 53 KB | Historical conflict copies | **Yes** — safe to delete |
| `artifacts/local-superseded/` | 1 | 4.4 KB | Superseded doc | **Yes** — safe to delete |
| `docs/evidence/live-cert/` | 1071 | ~1.1 GB | Historical runtime cert | No — evidence archive |
| `docs/evidence/` (root logs) | 2 | 54 KB | Historical F7 cert | No — evidence archive |
| `docs/control/logs/open/` | 28 | 116 KB | Coordination logs | No — inventory first |
| `Module/.../bin/` | ~8 | build artifacts | Build output | **Yes** — safe to delete |
| `src/.../obj/` | many | build intermediates | Build output | **Yes** — safe to delete |
| `.cursor/rules/` | unknown | unknown | Local IDE config | Preserve |

**Immediately safe deletion candidates** (zero evidence loss):
- `artifacts/merge-safety/*` (53 KB)
- `artifacts/local-superseded/*` (4.4 KB)
- All `Module/.../bin/*` and `src/.../obj/*` (rebuilt on demand)

**Not yet safe to delete** (requires supersession gate):
- `artifacts/route-owned-clock-live-proof/*` (~1.4 GB) — only after PR #43 fresh rerun
- `docs/evidence/live-cert/*` (~1.1 GB) — only after evidence archive manifest completed
- `docs/control/logs/open/*` (116 KB) — only after inventory

### Updated Gap Assessment

| Gap | Status | Resolution |
|---|---|---|
| Gap 1: ForgeStalePrRecovery.cmd | **RESOLVED** | File exists at root (6-line wrapper) |
| Gap 2: ForgeRepoHygiene.cmd | **RESOLVED** | Executed. Verdict: ATTENTION (one upstream-gone branch) |
| Gap 3: PR #43 22 ahead | **CLASSIFIED** | All commits are merged-main content, no unique unpublished work |
| Gap 4: PR #52 head fetch | **FETCHED** | `2bb7077` in route-operator worktree FETCH_HEAD |
| Gap 5: 037a-validation 6 commits | **CLASSIFIED** | 6 unique feature/fix commits. Preserve. Selective-replay candidate for current main |
| Gap 6: Detached worktrees | **CLASSIFIED** | Zero unique commits. Safe to release after evidence path archiving |
| Gap 7: Compendium preservation | **COMPLETE** | Full classification above. Safe deletion candidates identified |

### Validation

```text
ForgeRepoHygiene.cmd execution:       PASS (report written, verdict ATTENTION)
ForgeStalePrRecovery.cmd execution:   PASS (state: READY_local_floor_collection, 14 instructions)
PR #52 fetch into route-operator:     PASS (head 2bb7077 at FETCH_HEAD)
037a commit classification:           PASS (6 unique commits identified)
Detached worktree commit analysis:    PASS (0 unique commits on both)
Compendium classification:            PASS (11 surfaces classified, 3 safe-to-delete)
git diff --check:                     PASS
git status --short:                   clean (1 modified doc)
```

### Updated Safe Bases

| Lane | Base | Worktree | Status |
|---|---|---|---|
| Independent new work | Fresh branch from `origin/main` | New sibling worktree | Safe |
| PR #43 continuation | `agent/route-automation-operator-plan` | route-operator | Clean, 22 ahead (checked), safe |
| PR #52 validation | `fix/launcher-supervisor-empty-list` | route-operator (FETCH_HEAD) | Fetched, not merged |
| 037a feature replay | Fresh branch from `origin/main` | New worktree | Replay 6 unique commits |
| Stale PR recovery | Fresh branch from `origin/main` | Per PR #58 manifest | Script ready |
| Detached evidence cleanup | Read-only | agent-status-relay, pr25 | Zero unique commits, safe to release |
| Launcher extraction | Fresh branch from `origin/main` | New sibling worktree | Primary safe but isolate |

### Next Commands

```powershell
# Optional: delete safe-cleanup candidates (53 KB + 4.4 KB + build artifacts)
Remove-Item -LiteralPath 'artifacts/merge-safety' -Recurse -Force
Remove-Item -LiteralPath 'artifacts/local-superseded' -Recurse -Force

# De-duplicate 1 GB Phase1.log
# The collected copy in artifacts/route-owned-clock-live-proof/ duplicates the original
# in docs/evidence/live-cert/20260624-132648-pr11-launch-attach-execute/
# Preserve the original; delete the collected copy after proof that both are identical

# Next bounded implementation lane: merge PR #52 into route-operator and validate supervisor
git -C 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-operator-plan' merge FETCH_HEAD
powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-operator-plan\scripts\verify-launcher-validation-supervisor.ps1'

# Next implementation lane: selective replay of 037a 6 unique commits
git worktree add -b feat/route-travel-replay "$env:USERPROFILE\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-route-travel-replay" origin/main
```
