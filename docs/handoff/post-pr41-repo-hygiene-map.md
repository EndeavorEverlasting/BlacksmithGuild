# Post-PR #41 Repository Hygiene and Sprint Map

```text
[TBG | Repo Hygiene / PR Map | Post-PR #41 | branch: docs/post-pr41-repo-hygiene]
```

## Context

- Repository: `EndeavorEverlasting/BlacksmithGuild`
- Snapshot: `2026-07-11T13:10:47Z`
- Coordinator branch: `docs/post-pr41-repo-hygiene`
- Coordinator base: `origin/main` at `aa015a5cdf35f4014daecd879c077fe275ffebdb`
- Lane: coordinator / cleanup map
- Owned scope: Git, GitHub PR, branch, worktree, conflict, and ignored-artifact inventory
- Forbidden scope: feature implementation, route-runtime edits, Bannerlord launch, `ForgeReboot`, command inbox writes, save mutation, runtime claims, and destructive cleanup
- Changed file for this sprint: `docs/handoff/post-pr41-repo-hygiene-map.md`

This is a read-only evidence map except for this document. No existing branch, worktree, ignored artifact, conflict, PR state, or runtime surface was modified.

## Coordinator decisions

1. Use current `origin/main` for independent work.
2. Treat PR #41 and PR #37 as clean sibling lanes with deliberately separate static and runtime ownership.
3. Do not use PR #38 or any PR #28-#35 head as a general sprint base.
4. Preserve the conflicted primary checkout exactly as-is until its route owner resolves the in-progress merge.
5. Preserve ignored runtime evidence until its owning PR is merged or an explicit retention decision is recorded.
6. Perform no branch or worktree deletion in this map-only sprint.

## Open PR topology

```text
origin/main @ aa015a5
├── #41 static harness/reporting @ 93be1c0
├── #37 route runtime @ 91704e6
├── #38 broad guardrails lane on moved docs/agent-workflow-contracts base [conflicted]
├── #28 → #29 → #30 → #31 → #32
│                              ├── #33 → #34
│                              └── #35
├── #24 route/profile command contracts [stale]
├── #20 governor activity handoff [stale salvage candidate]
├── #5 → #6 sell/travel runtime stack [very stale, unproven]
├── #8 → #9 F7 history [conflicted/partly superseded]
└── #2 identity schema [very stale, small replay candidate]
```

Drift below is `behind/ahead` relative to current `origin/main`, not the PR's named base.

| PR | State | Base → head | Drift | Files / checks | Coordinator disposition |
|---|---|---|---:|---|---|
| [#41](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/41) English policy renderer | Draft; `MERGEABLE/CLEAN` | `main` → `sprint/english-policy-renderer` @ `93be1c0` | 0 / 1 | 28; Governor and Harness Policy Reports pass | Safe static review lane. Merge when its draft/approval decision is made; do not mix with route runtime. |
| [#38](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/38) worktree/runtime-stop guardrails | Open; `CONFLICTING/DIRTY` | `docs/agent-workflow-contracts` → `docs-worktree-stop-guardrails` @ `e618349` | 3 / 53 | 35; no Governor/Harness check listed | Not a base. Reconstruct the still-needed guardrail-only delta from current main instead of untangling the broad historical branch in place. |
| [#37](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/37) route-visible-start runtime | Open; `MERGEABLE/CLEAN` | `main` → `feat/route-branch-state-runtime-start` @ `91704e6` | 0 / 6 | 3; Governor passes | Clean runtime sibling of #41. Keep in its isolated worktree; merge only after route-specific review/proof decisions. |
| [#35](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/35) focused route proof | Draft; `MERGEABLE/CLEAN` | `agent-default-guardrail-map` → `feat/harness-focused-route-proof` @ `4b291a9` | 3 / 47 | 8; Governor passes | Valid only as intentional #32 child. Its base is dependency-incomplete, so it is not a general CMD/runtime-test base. |
| [#34](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/34) concurrent sprint map | Draft; `MERGEABLE/CLEAN` | `agent-default-guardrail-implementation` → `docs-concurrent-sprint-map` @ `63610be` | 3 / 48 | 6; Governor passes | Factually stale after #35-#41 and inherits #32/#33 drift. Supersede with this map or refresh from current main. |
| [#33](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/33) guardrail scripts | Draft; `MERGEABLE/CLEAN` | `agent-default-guardrail-map` → `agent-default-guardrail-implementation` @ `3406029` | 3 / 32 | 4; Governor passes | Preserve pending architecture decision. Head is 3 commits behind its current #32 base; selectively port after #32 is reconciled. |
| [#32](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/32) default guardrail map | Draft; `MERGEABLE/CLEAN` | `agent-feedback-stop-hook` → `agent-default-guardrail-map` @ `d004aea` | 3 / 31 | 6; Governor passes | Preserve pending architecture decision. Head is 1 commit behind current #31 and is not dependency-complete. |
| [#31](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/31) stop-hook contract | Draft; `MERGEABLE/CLEAN` | `agent-feedback-remediation-planner` → `agent-feedback-stop-hook` @ `c4a6c93` | 3 / 23 | 7; Governor passes | Reconcile against merged #39 and #41 hook/done-gate behavior before retaining. |
| [#30](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/30) remediation planner | Draft; `MERGEABLE/CLEAN` | `agent-feedback-writer` → `agent-feedback-remediation-planner` @ `b6f126b` | 3 / 15 | 3; Governor passes | Preserve only as a #28-#31 stack layer; otherwise port unique behavior into current harness architecture. |
| [#29](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/29) feedback writer | Draft; `MERGEABLE/CLEAN` | `agent-feedback-harness` → `agent-feedback-writer` @ `c8bab98` | 3 / 12 | 2; Governor passes | Same stack-only disposition as #30. |
| [#28](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/28) feedback doctrine | Draft; `MERGEABLE/CLEAN` | `main` → `agent-feedback-harness` @ `1655925` | 3 / 10 | 6; Governor passes | Root of the historical agent stack. Decide keep-versus-supersede against merged #39/open #41 before refreshing bottom-up. |
| [#24](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/24) route/profile command contracts | Draft; `MERGEABLE/CLEAN` | `main` → `feat/shared-route-profile-contracts` @ `e3c0b14` | 131 / 13 | 12; Governor passes | Do not merge/rebase blindly or use as a base. Port still-needed CMD/profile contracts to a fresh selected runtime lane. |
| [#20](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/20) governor activity handoff | Open; `MERGEABLE/CLEAN` | `main` → `sprint/governor-activity-contract` @ `2839b37` | 296 / 4 | 3; review bot only | Unique salvage candidate, but high-churn service changed later. Replay onto current main and add current validation rather than merging as-is. |
| [#9](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/9) F7 bisect evidence | Open; `CONFLICTING/DIRTY` | `main` → `codex/update-pr-with-bisect-session-details` @ `ef0c95c` | 496 / 1 | 5; review bots only | Historical/superseded evidence. Preserve any still-valid prose, then close by explicit operator decision; never merge stale evidence blobs. |
| [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) F7 tooling | Open; `CONFLICTING/DIRTY` | `fix/f7-gate-stability` → `codex/stabilize-f7-launch-tooling-and-open-pr` @ `d8a0e0e` | 496 / 3 | 19; review bot only | Partly absorbed and later revised. Audit unique docs/tests, replay selectively on current main, and replace/close the old PR. |
| [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) second-leg travel | Draft; `MERGEABLE/CLEAN` | `feat/006c-4-sell-loop` → `feat/006c-4b-second-leg-travel` @ `2b5b7e1` | 499 / 10 | 7; review bot only | Never merge alone. Rebuild #5 on current main first, then replay #6 and run fresh runtime validation—or close both. |
| [#5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) sell loop | Draft; `MERGEABLE/CLEAN` | `main` → `feat/006c-4-sell-loop` @ `9ec17ac` | 499 / 5 | 15; review bot only | Very stale and its runtime gates remain unchecked. Do not use as a base; selectively reimplement on current main if still desired. |
| [#2](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/2) identity schema | Open; `MERGEABLE/CLEAN` | `main` → `codex/design-identity-and-behavior-schema` @ `6109034` | 526 / 1 | 3; review bots only | Small, unique replay candidate. Reapply on current main, resolve `NEXT_STEPS.md`, build, and replace/close the old PR. |

## Stack and overlap findings

- PR #41 and PR #37 have no exact changed-path overlap and are clean sibling branches from current main.
- PR #37 changes exactly the three route-runtime files that were forbidden in the #41 lane.
- PR #38 has no exact path collision with #41/#37/#35, but its 35-file surface semantically overlaps harness, route proof, and runtime-stop ownership. Its conflict is caused by its moved/diverged base relationship.
- PR #28-#34 have no exact path overlap with #41, but duplicate merged #39/open #41 concepts: hooks, policy gates, evidence, done gates, workspace coordination, and reporting.
- PR #32 is 1 commit behind its current #31 base. PR #33 is 3 commits behind its current #32 base. GitHub's `CLEAN` label does not make those heads dependency-complete.
- PR #35 and PR #34 fork from the #32/#33 historical guardrail stack; neither is a safe general base.
- PR #20 and PR #5/#6 touch high-churn GuildLoop/MapTrade sources. Exact-path independence from newer PRs does not remove semantic/runtime risk.
- PR #8/#9 carry historical proof and tooling that main has partly absorbed or superseded.

## Worktree map

Drift is `ahead/behind` relative to `origin/main`.

| Local worktree | Branch / head | Drift | State | Artifacts | Decision |
|---|---|---:|---|---:|---|
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild` | `feat/route-owned-clock-resume` @ `f3df09b`; no upstream | 25 / 3 | 16 changed/indexed paths; merge in progress from `22fdddb`; `MapTradeAutonomousService.cs` unresolved | 41 files, 1,494,689,751 bytes | Protected active integration lane. Preserve untouched; not a base for side work. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation` | `feat/route-branch-state-runtime-start` @ `91704e6`; tracks origin | 6 / 0 | Clean; exact PR #37 head | 9 files, 95,449 bytes | Retain through #37 review/runtime disposition. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-english-policy-renderer` | `sprint/english-policy-renderer` @ `93be1c0`; tracks origin | 1 / 0 | Clean; exact PR #41 head | 15 files, 192,324 bytes | Retain through #41 review/merge. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr23` | `feat/engine-toggle-authority` @ `28bba47`; tracks origin | 0 / 75 | Clean; PR #23 merged | none | Evidence-backed cleanup candidate after operator confirmation. No deletion in this sprint. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-pr25-launcher-evidence` | detached @ `b9e901c` (merge of PR #27) | 0 / 34 | Clean; directory name no longer matches head | 22 files, 2,922,699,747 bytes | Do not remove until the 2.92 GB runtime-evidence retention/archive decision is explicit. |
| `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-repo-hygiene` | `docs/post-pr41-repo-hygiene` @ `aa015a5`; tracks `origin/main` | 0 / 0 | Clean before this map | none | Coordinator lane for this document only. |

`git worktree prune --dry-run --verbose` produced no stale administrative entries.

## Primary conflict inventory

The protected primary checkout is not merely dirty; it is in a real merge:

- `MERGE_HEAD`: `22fdddb1f7a1aa64a2d009b8f7cee857aefbf899` (`pr-37-route-branch-state-runtime-start`)
- Unresolved path: `src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs`
- Other route files modified: `MapTradeEvidenceWriter.cs`, `MapTradeModels.cs`
- Staged surface: 15 paths, approximately 489 insertions and 3,679 deletions, plus the unmerged file
- Unstaged conflict-side surface: approximately 305 insertions and 2 deletions in the unresolved service
- No upstream is configured for `feat/route-owned-clock-resume`

This lane must be resolved by its route owner. Do not reset, abort, stash, switch, or copy files out of it from a coordinator sprint.

## Branch hygiene

- Local `main` is at `9a22b29`, three commits behind `origin/main`; it is not checked out. No ref update was performed.
- Ten local branches are reported merged into `origin/main`, including the worktree-bound `feat/engine-toggle-authority`. A merged branch list is evidence for review, not authorization to delete user-owned refs.
- `docs/agent-workflow-contracts` contains post-merge commits and is the moved base of conflicted PR #38. Do not use it as a new base.
- `pr37-clean-runtime` is a local-only branch four commits ahead of `origin/main`; preserve it until the route owner classifies it.
- `feat/route-owned-clock-resume`, `pr-37-route-branch-state-runtime-start`, and `pr-36-agent-workflow-contracts` are not proven disposable merely because related PRs exist or were squash-merged.
- No remote branch was deleted or retargeted.

## Ignored/generated artifact map

All mapped `artifacts/` trees are ignored by `.gitignore` (`artifacts/` rule). `git clean -ndX -- artifacts/latest` confirms they are cleanable generated surfaces, but not that deletion is safe.

| Lane | Evidence snapshot | Classification |
|---|---|---|
| Primary route integration | 41 files; ~1.49 GB; oldest 2026-06-18; newest merge-safety conflict copy 2026-07-06 | Retain. It contains route proof logs and conflict-preservation copies tied to the unresolved merge. |
| PR #37 worktree | 9 files; ~95 KB; newest `route-visible-start.result.json` on 2026-07-08 | Retain through #37 disposition. |
| PR #41 worktree | 15 files; ~192 KB; renderer/readiness/workspace reports from 2026-07-11 | Retain through #41 review; safe regeneration can be assessed after merge. |
| Detached launcher-evidence worktree | 22 files; ~2.92 GB; runtime command proof last updated 2026-07-05 | Retention decision required. Do not treat the clean Git status as permission to delete runtime evidence. |

No ignored artifact, temp file, or generated report was removed in this sprint.

## Safe next sprint bases

| Intended sprint | Safe base |
|---|---|
| Independent docs, coordinator, or static work | Current `origin/main` at `aa015a5` |
| Work that explicitly requires PR #41 effective-policy/reporting APIs | Prefer updated `main` after #41 merges; otherwise explicitly stack on `sprint/english-policy-renderer` @ `93be1c0` |
| Work that explicitly requires PR #37 route-start behavior | Explicitly stack on `feat/route-branch-state-runtime-start` @ `91704e6`, or wait for merge |
| Guardrail-only recovery from PR #38 | Fresh current-main branch with a selectively reconstructed delta; never #38's current head/base |
| Agent feedback/guardrail stack retention | Refresh bottom-up from #28 only after keep-versus-supersede decision; repair #32/#33 drift before children |
| Legacy governor/identity/F7/sell-loop work | Fresh current-main branch and selective replay; never the stale PR head |
| Rebuilt second-leg travel (#6) | A refreshed #5 that itself starts from current main |

There is no safe single existing base for a combined save-load → route → town-entry → visible-trading CMD sprint today. PR #37 is current-main-based; PR #35 and PR #38 live on separate historical stacks. Reconcile the required proof/guardrail pieces onto current main or a merged #37 first.

## Cleanup decision ledger

| Candidate | Proof | Action in this sprint |
|---|---|---|
| PR #23 worktree/branch | Clean, merged PR, no artifacts, head ancestor of main | Preserve; eligible for later explicit removal. |
| Detached launcher-evidence worktree | Clean and head ancestor of main, but 2.92 GB ignored runtime evidence | Preserve; retention/archive decision blocks removal. |
| Primary ignored artifacts | Ignored/generated, but tied to active unresolved merge | Preserve. |
| PR #37 / PR #41 ignored artifacts | Ignored/generated and reproducible in part, but current PR evidence | Preserve until PR disposition. |
| Open legacy branches/PRs | Stale or superseded evidence exists | No closure/deletion without explicit operator decision. |

## Validation evidence

Commands executed:

```powershell
git fetch origin
git status --short
git branch --show-current
git log --oneline --decorate -8
git worktree list
git worktree prune --dry-run --verbose
gh pr list --state open --limit 50
gh pr view 41 --json number,title,state,isDraft,mergeable,baseRefName,headRefName,headRefOid,changedFiles,statusCheckRollup
gh pr checks 41
git diff --check
```

Additional read-only checks inspected every worktree's status, conflict paths, upstream, drift, ignored-artifact inventory, active Git operation markers, PR files, stack ancestry, and check rollups.

Results:

- 18 open PRs mapped.
- 6 local worktrees mapped.
- PR #41 checks pass and its head matches `93be1c0`.
- Coordinator worktree began clean on current `origin/main`.
- Primary conflict and `MERGE_HEAD` confirmed without modification.
- No stale worktree administration entries found.
- No destructive cleanup performed.

Skipped checks:

- `dotnet build src\BlacksmithGuild\BlacksmithGuild.csproj`: skipped because this is a documentation-only map and build requires the separate runtime-state preflight.
- Bannerlord/CMD/live validation: forbidden in this sprint.

## Gaps and risks

- GitHub mergeability can be green while a stacked head omits newer commits from its named base; #32/#33 prove this.
- Review-bot success is not build, harness, or runtime proof for the legacy PRs.
- The primary merge is the highest local data-loss risk. Any cleanup command aimed at the protected checkout is unsafe until its owner finishes or deliberately preserves and aborts the merge.
- Approximately 4.4 GB of ignored evidence is present across the primary and detached launcher-evidence worktrees. Disk cleanup must follow an evidence-retention decision.
- PR #34's open sprint map is stale and should not be treated as current coordination truth.

## Exact next command

```powershell
gh pr view 41 --repo EndeavorEverlasting/BlacksmithGuild --web
```
