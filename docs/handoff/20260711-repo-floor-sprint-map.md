# 2026-07-11 Repo Floor Sprint Map

## Repo

`EndeavorEverlasting/BlacksmithGuild`

Default branch: `main`

Remote evidence source: GitHub connector. Local primary worktree state was not available through this environment, so local dirty/conflicted/ignored state must still be verified from the Windows checkout before any runtime or merge work.

## Branch

Sprint-map branch created from `main`:

```text
docs/repo-floor-sprint-map-20260711
```

Current remote `main` center of gravity:

```text
7417049f34a9de9daf05d0699b0afc3a1e00f175 docs(coordination): map post-PR #41 repo hygiene (#42)
5c20e9592d900f8b24b493ef75040be452b349b2 feat(harness): add effective policy English renderer (#41)
0a0fdc0fb7e80e1c55272ec1fb9f19ab86b4b661 feat(route): start branch-selected travel from campaign tick (#37)
aa015a5cdf35f4014daecd879c077fe275ffebdb docs(agent): add route workflow contracts (#36)
237398448089e58f50b4cf854a0e2b23d2f4e803 feat(mcp): add LSP symbol smoke harness (#40)
809f054351fc2f98f21eee8ac7f8f85adb34f8d2b21623e59745 feat(harness): add local agent and AI layer foundation (#39)
```

## PR / Sprint Context

This sprint is repo-floor coordination only. It does not implement feature work, does not launch Bannerlord, does not claim runtime proof, and does not edit runtime route source.

## Lane

`coordinator / cleanup / repo-floor / sprint map`

## Scope

- Verify remote repo, PRs, branch stack, and safe next sprint bases.
- Identify risky merge/conflict surfaces from GitHub metadata.
- Record local verification commands needed for primary worktree and sibling worktrees.
- Preserve route/runtime lanes from repo-floor mutation.
- Produce a committed sprint map for next agents.

## Forbidden Scope

- No feature implementation.
- No runtime claims.
- No Bannerlord launch.
- No route runtime source edits.
- No broad refactors.
- No destructive branch deletion.
- No PR closure.
- No local cleanup claims without local evidence.

## Remote PR Map

| PR | Title | Head | Base | State | Mergeable | Draft | Recommended floor action |
| --- | --- | --- | --- | --- | --- | --- | --- |
| #43 | fix(route): align automation with operator controls | `agent/route-automation-operator-plan` | `main` | open | true | true | Current main-based route automation/operator-plan lane. Keep isolated. Requires fresh live proof before merge. |
| #38 | docs(guardrails): codify worktree and runtime stop contracts | `docs-worktree-stop-guardrails` | `docs/agent-workflow-contracts` | open | false | false | Stacked guardrail PR. Since #36 is already on main, inspect/rebase/retarget in a PR38-specific worktree only. |
| #35 | feat(harness): add focused route proof lifecycle keeper | `feat/harness-focused-route-proof` | `agent-default-guardrail-map` | open | true | true | Older stacked focus-lifecycle lane. Do not mix with #43 until route operator plan is settled. |
| #34 | docs(concurrent): add PR34 concurrent sprint map | `docs-concurrent-sprint-map` | `agent-default-guardrail-implementation` | open | true | true | Older coordination stack. Likely superseded by #42/#38/#43 map work; inspect before closing. |
| #33 | feat(guardrails): add default guardrail implementation scripts | `agent-default-guardrail-implementation` | `agent-default-guardrail-map` | open | true | true | Older guardrail implementation stack. Candidate for supersession review, not deletion. |
| #32 | docs(guardrails): add default app guardrail map | `agent-default-guardrail-map` | `agent-feedback-stop-hook` | open | true | true | Older guardrail doctrine stack. Candidate for supersession review. |
| #31 | feat(agent): add stop hook trigger contract | `agent-feedback-stop-hook` | `agent-feedback-remediation-planner` | open | true | true | Older agent-feedback stack. Candidate for stack review. |
| #30 | feat(agent): add remediation planner | `agent-feedback-remediation-planner` | `agent-feedback-writer` | open | true | true | Older agent-feedback stack. Candidate for stack review. |
| #29 | feat(agent): add feedback summary writer | `agent-feedback-writer` | `agent-feedback-harness` | open | true | true | Older agent-feedback stack. Candidate for stack review. |
| #28 | docs(agent): add feedback harness doctrine | `agent-feedback-harness` | `main` | open | true | true | Oldest open agent-feedback base. Review against merged #39/#41 before keeping. |
| #24 | feat: add shared route/profile mode command contracts | `feat/shared-route-profile-contracts` | `main` | open | true | true | Older route/profile contracts. Inspect against #43 before continuing. |
| #20 | Codify governor activity handoff contract | `sprint/governor-activity-contract` | `main` | open | true | false | Non-draft older governor docs/contract lane. Inspect for inclusion or supersession. |
| #9 | docs(f7): add continue-gate bisect evidence and coordination log | `codex/update-pr-with-bisect-session-details` | `main` | open | false | false | Old evidence PR. Non-mergeable. Preserve evidence before any cleanup. |
| #8 | F7: Add Continue bisect tooling, em-dash grep safeguards, and agent handoff docs | `codex/stabilize-f7-launch-tooling-and-open-pr` | `fix/f7-gate-stability` | open | false | false | Old F7/tooling PR. Non-mergeable; likely stale stack. Preserve evidence before cleanup. |
| #6 | feat(006c-4b): second-leg auto-travel to sell town | `feat/006c-4b-second-leg-travel` | `feat/006c-4-sell-loop` | open | true | true | Old sell-loop stack. Do not merge without current route/operator review. |
| #5 | feat(006c-4): vanilla sell driver + multi-cycle guild loop | `feat/006c-4-sell-loop` | `main` | open | true | true | Old sell-loop stack. Candidate for archival/supersession review. |
| #2 | Document identity/disposition schema and clarify doctrine wording | `codex/design-identity-and-behavior-schema` | `main` | open | true | false | Independent docs/code wording PR. Low collision but stale; inspect before merge/close. |

## Worktree Map

Local worktrees cannot be verified from GitHub. Treat all local worktree safety as unknown until these commands run locally:

```powershell
$UserProfile = [Environment]::GetFolderPath('UserProfile')
$PrimaryRepo = Join-Path $UserProfile 'Desktop\dev\Mods\Bannerlord\BlacksmithGuild'
Set-Location $PrimaryRepo
git fetch origin --prune
git status --short --ignored
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20
```

Expected local paths to verify, based on prior handoffs:

```text
C:\Users\<current-user>\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
C:\Users\<current-user>\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-037a-validation
```

Do not mutate `BlacksmithGuild-037a-validation` from repo-floor work. That path belongs to the 037B MCP/LSP validation lane.

## Dirty / Conflicted State

Remote GitHub evidence cannot prove local dirty state, local ignored artifacts, local conflicts, or mid-merge status.

Local agent must stop immediately if any of these appear:

```text
UU <file>
AA <file>
DU <file>
UD <file>
MERGE_HEAD exists
REBASE_HEAD exists
CHERRY_PICK_HEAD exists
```

If conflicted, identify exact files and involved branch/commit before any repair.

## Safe Base Branches for Next Sprints

| Sprint lane | Safe base | Reason |
| --- | --- | --- |
| New repo-floor docs/map sprint | `main` | `main` already includes #36, #37, #39, #40, #41, #42 and is the cleanest current coordination base. |
| Route automation/runtime proof continuation | PR #43 head `agent/route-automation-operator-plan` | #43 is current main-based route automation draft and should own runtime route/operator-plan changes. |
| PR38 guardrail repair | `docs-worktree-stop-guardrails` in a dedicated PR38 worktree, then retarget/rebase decision against `main` | #38 is non-mergeable and still based on `docs/agent-workflow-contracts`; do not repair from primary runtime checkout. |
| MCP/LSP follow-up | `main` or a fresh branch from `main` unless specifically continuing 037B evidence | #40 is already on main; avoid mutating stale validation worktree unless intentionally continuing 037B. |
| Old agent-feedback stack cleanup | Start from #28 upward, one PR at a time | PR #28 through #35 are stacked; closing/retargeting requires preservation proof and supersession review. |
| Old F7 evidence cleanup | PR #8 / #9 branches only, with evidence-preservation review | Both are non-mergeable; do not delete without preserving evidence and naming replacement docs. |
| Sell-loop legacy review | PR #5/#6 branches only | Old draft runtime automation stack; likely collides conceptually with newer route/operator lanes. |

## Safe Parallel Work

| Lane | Owner | Safe scope | Forbidden collision |
| --- | --- | --- | --- |
| Route runtime/operator | Agent A / route lane | PR #43 only | Do not edit PR38 docs, old feedback stack, or repo-floor map. |
| PR38 guardrails | PR38 validator | `docs-worktree-stop-guardrails` docs/scripts/contracts | Do not edit `src/BlacksmithGuild/MapTrade/*`. |
| Repo floor | Coordinator | docs-only sprint map, PR inventory, local command checklist | Do not retarget/close/delete without proof. |
| MCP/LSP | 037B/040 lane | MCP/LSP harness and symbol smoke only | Do not claim symbol navigation if LSP project load is missing. |
| Old stack review | Cleanup agent | read-only compare/supersession review | Do not close PRs until replacement path is documented. |

## Validation Output

Remote checks completed:

```text
Repository metadata fetched.
Open PR list fetched.
Recent main commit center of gravity fetched.
New sprint-map branch created from main: docs/repo-floor-sprint-map-20260711.
This sprint map committed on that branch.
```

Local checks skipped in this environment:

```text
git status --short --ignored
git worktree list
git diff --check
PowerShell harness validators
build
Bannerlord launch/live cert
```

## Gaps / Risks

- Primary local worktree state remains unknown until local commands run.
- Sibling worktree state remains unknown until `git worktree list` runs locally.
- PR #38 remains non-mergeable and stacked on `docs/agent-workflow-contracts`; because #36 is already in main, it likely needs retarget/rebase analysis from a dedicated PR38 worktree.
- PR #43 is the current route automation lane and is draft intentionally pending live proof.
- PR #28 through #35 form an old stacked agent-feedback/guardrail/focus chain. They are mergeable but may be superseded by #38/#39/#41/#42/#43.
- PR #8 and PR #9 are non-mergeable older F7 evidence/tooling branches. Do not delete until evidence is preserved or intentionally superseded.
- PR #5/#6 are old sell-loop runtime automation drafts. They likely require product/safety review before any continuation.
- GitHub `mergeable=true` does not prove tests pass.
- GitHub `mergeable=false` does not identify local conflict files; local checkout or GitHub conflict UI is still required.

## Exact Next Command

For the local repo-floor agent:

```powershell
$UserProfile = [Environment]::GetFolderPath('UserProfile')
$PrimaryRepo = Join-Path $UserProfile 'Desktop\dev\Mods\Bannerlord\BlacksmithGuild'
Set-Location $PrimaryRepo
git fetch origin --prune
git status --short --ignored
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20
```

## Copy-Paste Handoff Prompt for Next Sprint

```text
You are continuing The Blacksmith Guild repo.

Repo:
EndeavorEverlasting/BlacksmithGuild

Sprint:
Local repo-floor validation after remote sprint-map commit

Lane:
coordinator / cleanup / local evidence pass

Owned scope:
- Verify primary local worktree state.
- Verify sibling worktrees.
- Verify dirty/conflicted/ignored state.
- Confirm whether docs/repo-floor-sprint-map-20260711 is present remotely and whether a local PR should be opened/updated.
- Confirm PR #43, PR #38, and old stacked PR states from local gh.
- Produce exact next command for either PR43 live-proof lane, PR38 repair lane, or old-stack cleanup lane.

Forbidden scope:
- No feature implementation.
- No Bannerlord launch.
- No runtime proof claims.
- No route source edits.
- No branch deletion.
- No PR closure.
- No cleanup without proof.

Start:
$UserProfile = [Environment]::GetFolderPath('UserProfile')
$PrimaryRepo = Join-Path $UserProfile 'Desktop\dev\Mods\Bannerlord\BlacksmithGuild'
Set-Location $PrimaryRepo
git fetch origin --prune
git status --short --ignored
git branch --show-current
git log --oneline --decorate -8
git worktree list
gh pr list --state open --limit 20

Then inspect:
- PR #43 as current route automation/operator-plan lane.
- PR #38 as non-mergeable guardrails lane.
- PR #28-#35 as old stacked feedback/guardrail/focus lanes.
- PR #8/#9 as old non-mergeable F7 evidence/tooling lanes.
- PR #5/#6 as old sell-loop runtime automation drafts.

Final response must include:
repo, branch, PR/sprint context, lane, scope, forbidden scope, work completed, PR map, worktree map, changed files, validation output, gaps/risks, exact next command, and copy-paste handoff prompt for the next sprint.
```
