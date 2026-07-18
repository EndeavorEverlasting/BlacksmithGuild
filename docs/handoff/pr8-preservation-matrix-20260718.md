# PR #8 Preservation Matrix (P17)

```text
[TBG | STALE PR RECOVERY | P17 | WAVE C PR #8 | 2026-07-18]
```

## Source

| Field | Value |
|---|---|
| Source PR | [#8](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8) |
| Head | `d8a0e0e209846c230e129bb82f288978d8a757aa` |
| Base (stale) | `fix/f7-gate-stability` |
| Mergeable | CONFLICTING |
| Commits | `11f357d` (June evidence summary), `bc0d033` (fail-closed runner restore), `d8a0e0e` (handoff note) |
| Recovery branch | `recovery/pr8-f7-lessons-current-main` |
| Floor | `origin/main` @ `e58e47f` |

## Per-file classification

| Path | Decision | Destination / evidence |
|---|---|---|
| `scripts/run-f7-gate-continue.ps1` | **reject** (stub risk) / **already on main** (real runner) | Current main keeps the fail-closed real runner. `verify-f7-runner-contract.ps1` rejects PR #8-sized stubs. |
| `scripts/run-agent-a-f7-bisect.ps1` | **already on main** | Current main retains end-to-end bisect semantics; PR #8 `-SkipLaunch`-leaning stub rejected per bridge. |
| `scripts/bannerlord-paths.ps1` | **already on main** (richer) | `Get-TbgReadyGoldenPathPattern`, `[char]0x2014` ready prefix, and Phase1 helpers retained/expanded on main. |
| `scripts/verify-log-grep-patterns.ps1` | **already on main** | Scans `scripts/` and root wrappers; invoked by `verify-f7-runner-contract.ps1`. |
| `scripts/verify-f7-runner-contract.ps1` | **already on main** (expanded) | Fail-closed contract + stub detection already on main; P17 extends it to require `forge.ps1 -VerifyLogPatterns`. |
| `scripts/write-launch-log.ps1` | **already on main** | Mutex + caller `$ErrorActionPreference` restore already present. |
| `Run-F7GateContinue.cmd` | **already on main** | Wrapper forwards to the real PS runner. |
| `forge.ps1` `-VerifyLogPatterns` | **adapt / replay** | Missing on main before P17; restored from PR #8 head without adopting PR #8's weaker `LaunchIntent` default. |
| `docs/conventions/em-dashes-and-log-grep.md` | **already on main** (richer) | Main doc is more complete than PR #8's shortened version. |
| `docs/handoff/f7-agent-coordination.md` | **superseded** | Main redirects to live coordination/runtime-state docs; June agent-board snapshot rejected as current truth. |
| `docs/handoff/agent-launch-and-load-playbook.md` and related F7 handoffs | **already on main / superseded** | Current playbooks and control docs supersede stale RED-gate tables. |
| `docs/evidence/live-cert/f7-bisect-summary.json` | **reject as proof** / **historical retained** | June 2026 summary remains reachable; not fresh runtime proof for current main. |
| `docs/handoff/pr8-cherry-pick-bridge.md` | **already on main** | Parts-bin policy already recorded. |
| `tools/LaunchControl/README.md` | **already on main / superseded** | No unique outstanding lesson vs current LaunchControl docs. |

## Per-commit classification

| Commit | Decision | Notes |
|---|---|---|
| `11f357d` docs: record F7 bisect loop failure summary | **historical retained** | Evidence summary only; not a current PASS claim. |
| `bc0d033` fix(f7): restore fail-closed runner contract on PR8 | **already on main** (intent) | Fail-closed real runner + stub rejection live on main; do not replay the PR #8 branch file body. |
| `d8a0e0e` docs(handoff): record PR8 fail-closed runner restore | **superseded** | Bridge/handoff docs on main already encode the lesson. |

## Explicit rejections

1. Blind merge/rebase of PR #8 into main.
2. Replacing current `run-f7-gate-continue.ps1` with any smaller exit-0 wrapper.
3. Treating June `f7-bisect-summary.json` or RED-gate tables as current proof.
4. Reintroducing stale PLAY/CONTINUE agent-board snapshots as live coordination truth.

## Validation commands

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-f7-runner-contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\forge.ps1 -VerifyLogPatterns
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgStalePrRecovery.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\tbg\Test-TbgStalePrRecoveryProgress.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\test-powershell-utf8-bom-contract.ps1
git diff --check
```

## Proof boundary

Expected level: repository hygiene + contract/static proof.  
Proof ceiling: no fresh launcher, campaign, movement, trade, or runtime proof.
