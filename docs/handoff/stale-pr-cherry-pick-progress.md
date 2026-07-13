# Stale branch cherry-pick progress

> **Overall: INCOMPLETE**
> **0 of 16 stale pull requests are complete (0%).**
> **Current distribution: 2 in progress, 4 blocked, and 10 not started.**
> **Next: Wave A, PR #9: Validate and merge pull request 65, then record the final historical-retention or supersession disposition for pull request 9.**

The authoritative machine-readable ledger is `.tbg/plans/stale-pr-recovery-20260712/progress.json`. This Markdown file is generated from that ledger and the committed recovery plan.

## Completion rule

The stale-branch cherry-pick process is finished only when every planned source pull request has one terminal status: `replayed_and_merged`, `superseded_recorded`, `rejected_recorded`, or `historical_retained`. An open replacement pull request is progress, not completion.

## Progress table

| Wave | Source PR | Status | Replacement PR | Blocked by | Disposition or evidence | Next action |
|---|---:|---|---:|---|---|---|
| A | #9 | 🟡 replacement pr open | #65 | — | Historical coordination value replayed in pull request 65; final disposition remains pending until the replacement is merged and the source record is updated. | Validate and merge pull request 65, then record the final historical-retention or supersession disposition for pull request 9. |
| A | #34 | 🟡 replacement pr open | #65 | — | The concurrent sprint map was replayed in pull request 65; final supersession remains pending until the replacement is merged and the source record is updated. | Validate and merge pull request 65, then record pull request 34 as superseded by the maintained current-main copy. |
| B | #2 | ⬜ not started | — | — | — | Inspect pull request 2 against current main and decide whether to replay its coherent identity-schema delta or record a rejection. |
| C | #8 | ⬜ not started | — | — | — | Map every unresolved F7 review lesson to current code, current tests, or an explicit rejection. |
| D1 | #28 | ⬜ not started | — | — | — | Map the feedback-harness manifest fields into the current harness or record explicit rejections. |
| D1 | #29 | ⬜ not started | — | — | — | Adapt or reject the feedback writer against the current effective-context schema. |
| D1 | #30 | ⬜ not started | — | — | — | Port or reject the pure remediation planner using current result schemas and fixtures. |
| D1 | #31 | ⬜ not started | — | — | — | Reconcile only the stop-hook trigger map with the current hook-result and policy-reporting schemas. |
| D2 | #32 | ⬜ not started | — | — | — | Merge unique guardrail fields into current contracts or record why each field is superseded. |
| D2 | #33 | ⬜ not started | — | — | — | Replay pure tools only when current-schema tests prove they cannot create false PASS results. |
| D3 | #35 | ⛔ blocked dependency | — | #43, #52 | — | Wait for the active launcher and route lineage to settle, then reconcile only unique focused-route utility value. |
| E | #20 | ⬜ not started | — | — | — | Reconstruct the useful governor handoff model, tests, and review requirements against current main. |
| E | #24 | ⛔ blocked dependency | — | #43, #52 | — | Wait for the active route and operator-control lineage to settle, then classify each helper as keep, superseded, or reject. |
| E | #38 | ⬜ not started | — | — | — | Map each unique guardrail to a maintained replacement or an explicit rejection and retain provenance. |
| F | #5 | ⛔ blocked dependency | — | #43, #52 | — | Wait for the maintained route lineage to settle, then reconstruct the sell-loop contract from current main with fresh proof. |
| F | #6 | ⛔ blocked dependency | — | #43, #52 | — | Wait for pull request 5 value to be reconstructed and for the maintained route lineage to settle. |

## Active work excluded from stale recovery

| PR | Status | Reason |
|---:|---|---|
| #43 | active_excluded | Active route and launcher-validation foundation. This pull request is not stale-recovery work. |
| #52 | active_excluded | Bounded repair owned by pull request 43. This pull request is not stale-recovery work. |

## Operator commands

Refresh and display the dashboard:

```powershell
.\ForgeStalePrProgress.cmd status
```

Record an in-progress replacement:

```powershell
.\ForgeStalePrProgress.cmd set -PrNumber 9 -Status replacement_pr_open -ReplacementPr 65 -Disposition "Historical value is in PR #65." -Evidence "PR #65"
```

Record a terminal disposition only after its gate is satisfied:

```powershell
.\ForgeStalePrProgress.cmd set -PrNumber 9 -Status historical_retained -Disposition "The maintained replacement merged and the source remains reachable as history." -Evidence "PR #65 merged; replacement commit <sha>" -NextAction "No further replay work remains for PR #9."
```

## Exact next command

```powershell
gh pr view 65 --json number,title,state,isDraft,mergeable,headRefOid,baseRefName,checks
```

## Proof boundary

This dashboard proves only that the committed plan and progress ledger were reconciled. A terminal status must cite the replacement, rejection, or retention evidence. The dashboard does not itself prove a cherry-pick, merge, build, launcher action, gameplay behavior, or runtime result.
