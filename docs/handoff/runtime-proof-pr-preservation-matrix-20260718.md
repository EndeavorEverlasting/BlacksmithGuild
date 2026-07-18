# Runtime Proof PR Preservation Matrix

```text
[TBG | P21 | Runtime Proof Convergence | preservation | 2026-07-18]
```

## Floor

| Item | Value |
|---|---|
| Current `origin/main` | `e67ea9ed31d4a21551faf6c8a1dcec0011bc884b` |
| P18 | `6eda01ada78778b0f8fb9cca70f3b4afb1d77f70` (PR #90) |
| P19 | `493ea9d93a47ec61451e212ed81437a8f817fda7` (PR #92) |
| P20 | squash-merged as PR #95 → `502226a443ceceb7f3e961f05a6ca03a772b0670` |
| P21 | squash-merged as PR #96 → `e67ea9ed31d4a21551faf6c8a1dcec0011bc884b` |
| PR #86 reconstruction | `e58e47f0744774e462f108f0a667bbbfaedd9475` |
| P21 feature head (pre-squash) | `58c07d7f8fd7f91cbd8760b8c92d44e0a0a5e4e1` on `repair/window-runtime-proof-convergence` |

## Disposition summary

| Source | Decision | Destination / reason |
|---|---|---|
| PR #86 | already on current `main` | Primary coordinator reconstruction; do not replay |
| PR #96 / P21 | merged to `main` | Lifecycle-aware coordinator gate + this matrix |
| PR #69 unique coordinator files | **superseded_recorded** | Adapted by PR #86; lifecycle-extended by PR #96; close after closure-gate evidence below |
| PR #69 BOM-only launcher scripts | superseded / rejected | Do not re-import obsolete launcher-validation stack |
| PR #43 route/launcher stack | **historical_retained** / provenance | `CONFLICTING` vs main; leave open; extract only if a unique gap remains after historical preservation sprint |
| P19 lifecycle contracts | consume only | Coordinator gates on registered lifecycle artifacts |
| P20 routing surfaces | forbidden for P21 edits | Skills/capabilities/operations/artifact-engine registry untouched by P21 |

## PR #69 file ledger

| Path | Classification | Current-main destination |
|---|---|---|
| `.tbg/harness/fixtures/visible-trade-proof.fixtures.json` | adapted by PR #86; extended by P21 | keep/adapt on main |
| `Run-VisibleTradeProof.cmd` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `Show-LatestVisibleTradeProof.cmd` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `Stop-TbgRuntime.cmd` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `Toggle-TbgEvidenceAutomation.cmd` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `scripts/run-visible-trade-proof.ps1` | adapted by PR #86; P21 lifecycle gate | keep/adapt |
| `scripts/visible-trade-proof-event-schema.ps1` | adapted by PR #86; P21 stages | keep/adapt |
| `scripts/visible-trade-proof-capsule.ps1` | already on main via PR #86 | keep/adapt |
| `scripts/publish-visible-trade-proof-evidence.ps1` | already on main via PR #86 | keep/adapt |
| `scripts/show-latest-visible-trade-proof.ps1` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `scripts/stop-tbg-runtime-proof.ps1` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `scripts/toggle-tbg-evidence-automation-proof.ps1` | already on main via PR #86 | keep (byte-identical vs PR #69 head) |
| `scripts/test-visible-trade-proof-coordinator.ps1` | adapted by PR #86; P21 gate tests | keep/adapt |
| `scripts/verify-visible-trade-proof-coordinator.ps1` | already on main via PR #86 | keep/adapt |
| `scripts/visible-trade-lifecycle-gate.ps1` | P21-only on main | keep |
| `scripts/visible-trade-launch-boundary.ps1` | rejected | PR #43 launcher contract; not on main |
| launcher-validation BOM-only scripts | superseded | Already rejected by PR #86 reconstruction |

## PR #43 cluster ledger

| Cluster | Classification | Notes |
|---|---|---|
| Visible-trade cycle contracts/fixtures | superseded / provenance | Replaced by PR #86 coordinator surface |
| Launcher validation workhorse/frontdoor imports | rejected as stale architecture for this lane | Do not wholesale merge; current main uses compatibility gate + ForgeContinue operator |
| Operator/hostile-escape/docs mass | out of P21 owned scope | Leave for later historical preservation sprint |
| Mergeability | `CONFLICTING` / `DIRTY` vs main | Expected; do not rebase wholesale |
| Disposition | **historical_retained** | Branch `agent/route-automation-operator-plan` @ `2cbe33ffb60ededddd287635241912f7399b6fe0` kept open as provenance |

## Newly required by P19/P20

| Requirement | P21 action |
|---|---|
| Consume registered lifecycle artifact filenames | `scripts/visible-trade-lifecycle-gate.ps1` |
| Distinguish action dispatch / modal transition / host handoff / campaign readiness | Coordinator stages `window-lifecycle`, `modal-transition`, `launcher-handoff` |
| Fail closed on quarantine/stale/missing lifecycle JSON | Gate terminal states added |
| Do not edit P20 routing registries | Confirmed forbidden |

## Closure gate

| Gate | Status | Evidence |
|---|---|---|
| P21 PR merges | **PASS** | PR #96 squash-merged → `origin/main` @ `e67ea9e` |
| PR #69: no unique coordinator value outside current main + P21 | **PASS** | All 14 coordinator paths from PR #69 body exist on `origin/main`; CMD wrappers and three status/stop/toggle scripts are byte-identical to `900820b`; adapted scripts carry P21 lifecycle stages; rejected `visible-trade-launch-boundary.ps1` remains absent |
| PR #69 stacked non-coordinator delta | **not coordinator value** | Three-dot diff vs main lists launcher/hostile-escape/route stack files owned by PR #43 provenance; classified superseded/rejected for this lane |
| PR #43 close | **HOLD** | Leave open until historical preservation sprint proves every useful launcher/route item preserved or explicitly rejected |

### PR #69 close authorization

Close PR #69 as **superseded by PR #86 + PR #96** with branch retention (do not delete `feat/visible-trade-one-click-proof-relay` in this sprint).

Replacement / successor references:

- PR #86 reconstruction head lineage on main
- PR #96 lifecycle-aware coordinator @ `e67ea9e`
- This matrix path: `docs/handoff/runtime-proof-pr-preservation-matrix-20260718.md`

### PR #43 retention authorization

Do **not** close PR #43 in this sprint. Record `historical_retained` with conflicting merge state preserved.

## Proof ceiling for this matrix

Repository/static preservation proof only. Live launcher, campaign, ACK, movement, and trade remain separate and still require disposable-save authority.
