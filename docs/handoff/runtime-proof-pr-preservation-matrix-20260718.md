# Runtime Proof PR Preservation Matrix

```text
[TBG | P21 | Runtime Proof Convergence | preservation | 2026-07-18]
```

## Floor

| Item | Value |
|---|---|
| Current `origin/main` | `502226a443ceceb7f3e961f05a6ca03a772b0670` |
| P18 | `6eda01ada78778b0f8fb9cca70f3b4afb1d77f70` (PR #90) |
| P19 | `493ea9d93a47ec61451e212ed81437a8f817fda7` (PR #92) |
| P20 | squash-merged as PR #95 → `502226a` |
| PR #86 reconstruction | `e58e47f0744774e462f108f0a667bbbfaedd9475` |
| P21 branch | `repair/window-runtime-proof-convergence` |

## Disposition summary

| Source | Decision | Destination / reason |
|---|---|---|
| PR #86 | already on current `main` | Primary coordinator reconstruction; do not replay |
| PR #69 unique coordinator files | adapted by PR #86 | Present on current main under `Run-VisibleTradeProof.cmd` and `scripts/*visible-trade*` |
| PR #69 BOM-only launcher scripts | superseded / rejected | Do not re-import obsolete launcher-validation stack |
| PR #43 route/launcher stack | retain as provenance | Conflicting against main; extract only if a unique gap remains after P21 |
| P19 lifecycle contracts | consume only | Coordinator now gates on registered lifecycle artifacts |
| P20 routing surfaces | forbidden for P21 edits | Skills/capabilities/operations/artifact-engine registry untouched |

## PR #69 file ledger

| Path | Classification | Current-main destination |
|---|---|---|
| `.tbg/harness/fixtures/visible-trade-proof.fixtures.json` | adapted by PR #86; extended by P21 | keep/adapt on main |
| `Run-VisibleTradeProof.cmd` | already on main via PR #86 | keep |
| `Show-LatestVisibleTradeProof.cmd` | already on main via PR #86 | keep |
| `Stop-TbgRuntime.cmd` | already on main via PR #86 | keep |
| `Toggle-TbgEvidenceAutomation.cmd` | already on main via PR #86 | keep |
| `scripts/run-visible-trade-proof.ps1` | adapted by PR #86; P21 lifecycle gate | keep/adapt |
| `scripts/visible-trade-proof-event-schema.ps1` | adapted by PR #86; P21 stages | keep/adapt |
| `scripts/visible-trade-proof-capsule.ps1` | already on main via PR #86 | keep |
| `scripts/publish-visible-trade-proof-evidence.ps1` | already on main via PR #86 | keep |
| `scripts/show-latest-visible-trade-proof.ps1` | already on main via PR #86 | keep |
| `scripts/stop-tbg-runtime-proof.ps1` | already on main via PR #86 | keep |
| `scripts/toggle-tbg-evidence-automation-proof.ps1` | already on main via PR #86 | keep |
| `scripts/test-visible-trade-proof-coordinator.ps1` | adapted by PR #86; P21 gate tests | keep/adapt |
| `scripts/verify-visible-trade-proof-coordinator.ps1` | already on main via PR #86 | keep |
| `scripts/visible-trade-launch-boundary.ps1` | rejected | PR #43 launcher contract; not on main |
| launcher-validation BOM-only scripts | superseded | Already rejected by PR #86 reconstruction |

## PR #43 cluster ledger

| Cluster | Classification | Notes |
|---|---|---|
| Visible-trade cycle contracts/fixtures | superseded / provenance | Replaced by PR #86 coordinator surface |
| Launcher validation workhorse/frontdoor imports | rejected as stale architecture for this lane | Do not wholesale merge; current main uses compatibility gate + ForgeContinue operator |
| Operator/hostile-escape/docs mass | out of P21 owned scope | Leave for later historical preservation sprint |
| Mergeability | `CONFLICTING` vs main | Expected; do not rebase wholesale |

## Newly required by P19/P20

| Requirement | P21 action |
|---|---|
| Consume registered lifecycle artifact filenames | `scripts/visible-trade-lifecycle-gate.ps1` |
| Distinguish action dispatch / modal transition / host handoff / campaign readiness | New coordinator stages `window-lifecycle`, `modal-transition`, `launcher-handoff` |
| Fail closed on quarantine/stale/missing lifecycle JSON | Gate terminal states added |
| Do not edit P20 routing registries | Confirmed forbidden |

## Closure gate

- PR #69: close only after this P21 PR merges and no unique coordinator value remains outside current main + P21.
- PR #43: leave open/draft unless every useful launcher/route item is proven preserved or explicitly rejected with evidence.

## Proof ceiling for this matrix

Repository/static preservation proof only. Live launcher, campaign, ACK, movement, and trade remain separate.
