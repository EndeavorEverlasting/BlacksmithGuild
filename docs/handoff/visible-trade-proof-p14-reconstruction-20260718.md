# Visible-Trade Proof P14 Reconstruction

```text
[TBG | Visible Trade Reconstruction | P14 | 2026-07-18]
```

## Base

- Branch: `repair/visible-trade-proof-current-main`
- Base: `origin/main` at `6db020f80f0fd754a6922cbb1ac5246d08480581` (includes merged PR #83)
- Worktree: `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild-visible-trade-repair`
- Provenance retained: `feat/visible-trade-one-click-proof-relay` @ `900820b`, `agent/route-automation-operator-plan` @ `2cbe33f`

## File classification (PR #69 → current main)

| Path | Decision | Notes |
|---|---|---|
| `.tbg/harness/fixtures/visible-trade-proof.fixtures.json` | keep/adapt | Unique fixture pack |
| `Run-VisibleTradeProof.cmd` | keep | Root entrypoint |
| `Show-LatestVisibleTradeProof.cmd` | keep | Status entrypoint |
| `Stop-TbgRuntime.cmd` | keep | Routes to soft stop helper |
| `Toggle-TbgEvidenceAutomation.cmd` | keep | Operator toggle surface |
| `scripts/publish-visible-trade-proof-evidence.ps1` | adapt | Default PR comment target no longer hardcodes #43 |
| `scripts/run-visible-trade-proof.ps1` | adapt | Current-main helpers, validators, compatibility gate |
| `scripts/show-latest-visible-trade-proof.ps1` | keep | Status reader |
| `scripts/stop-tbg-runtime-proof.ps1` | keep | Uses repo `forge-stop.ps1` |
| `scripts/test-visible-trade-proof-coordinator.ps1` | adapt | Asserts helper surface; rejects PR #43 imports |
| `scripts/toggle-tbg-evidence-automation-proof.ps1` | keep | Uses main `bannerlord-paths.ps1` |
| `scripts/verify-visible-trade-proof-coordinator.ps1` | adapt | Adds missing `Assert-Equal` |
| `scripts/visible-trade-proof-capsule.ps1` | keep | Capsule + sanitization |
| `scripts/visible-trade-proof-event-schema.ps1` | keep | Event schema |
| `scripts/visible-trade-proof-helpers.ps1` | new | Minimal `Get-TbgObjectProperty` / `Get-TbgFileSha256` |
| `scripts/visible-trade-launch-boundary.ps1` | reject | PR #43 launcher contract; unused after helper split |
| `scripts/visible-trade-cycle-contract.ps1` | reject | PR #43 route contract; not imported |
| BOM-only launcher validation scripts (7) | supersede | Not present on current main; do not re-import |

## Adaptation summary

1. Replace PR #43 dotsources with `visible-trade-proof-helpers.ps1`.
2. Point static validators at `scripts/tbg/Test-TbgSkillRouting.ps1` and `scripts/tbg/Test-TbgStateEnvelope.ps1`.
3. Invoke `Assert-TbgGameCompatibilityGate.ps1 -Gate runtime-proof` before launch.
4. Remove unsupported `-AllowFocusSteal` from launch operator invocation.
5. Evidence publication comments only when an explicit `PrNumber` is supplied.

## Proof boundary

P14 proves reconstruction and harness/static validation only until a live runtime run is collected. Launcher/command-ack/movement/buy/sell claims require a separate runtime proof chain.

## Runtime attempt (2026-07-18 Windows)

| Step | Result |
|---|---|
| Soft stop via `scripts/stop-tbg-runtime-proof.ps1` | PASS (no Bannerlord processes) |
| Release build + install | PASS; built/installed SHA256 match `C9E645F6...` |
| Disposable save inventory | **BLOCKED** — 0 approved disposable saves |
| Live certify launch | Not started — would use `LaunchIntent continue` and risk personal-save mutation |

Replacement PR: https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/86  
Commit: `22a535cdfbaf3a00ff90ae488c3ee71ac9483ff2`

### Exact next command

```powershell
$env:TBG_NO_PAUSE='1'; .\Run-Governor-Ensure-DevSave.cmd
```
