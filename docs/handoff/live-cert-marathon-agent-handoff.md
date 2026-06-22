# Live Cert Marathon — Agent Handoff

**Last updated:** 2026-06-22  
**Baseline:** `main` (post map-ready orchestrator fix)  
**Sprint status:** Crash fix **shipped** — **USER VERIFY REQUIRED**  
**Crash fix:** [continue-map-crash-bisect-agent-handoff.md](continue-map-crash-bisect-agent-handoff.md)

## What shipped (do not re-implement)

- `FactionPowerPostureScanner` → `ClanContext.json`, F7 `clanPosture`, guild loop `FactionPosture` step
- `SmithingSmeltApi`, `SmithingLootWeaponScanner`, `SmithingSmeltService`
- Commands: `ProbeWeaponSmeltNow`, `RunWeaponSmeltNow`
- Guild loop: honest `capabilities.weaponSmelt`, `TryWeaponSmelt` at forge handoff
- `scripts/run-live-assistive-cert.ps1`, `run-weapon-smelt-cert.ps1`
- Export/collect scripts include smelt + marathon JSONs

## Build

| Check | Verdict | When |
|-------|---------|------|
| `dotnet build -c Release` | **PASS** | 2026-06-22 — 0 warnings, v0.0.11 installed |

## Crash triage (2026-06-22 Agent B)

### Disposable `Forge.cmd` (00:13)

| Signal | Detail |
|--------|--------|
| Launch.log | PLAY clicked, Safe Mode No, handoff verified; `launcher=no game=no` from **00:14:06** (~30s after PLAY) |
| Phase1 | SandBox auto-select → MapTransition → campaign tick at **00:13:40** — **no TBG READY** |
| Status.json | Stale: `campaignReady: false`, `canPollFileInbox: false` |
| Engine dumps | None in `logs/` or `crashes/` |

### Continue `ForgeContinue.cmd` (00:20) — **also crashes**

| Signal | Detail |
|--------|--------|
| Launch.log | CONTINUE attempt 6 + Safe Mode No; handoff verified **00:20:24**; `no game or launcher hwnd` from **00:20:36** (~12s after handoff, ~2s after map-ready log) |
| Phase1 | Continue intent → map ready at **Quyaz** **00:20:34** — full "campaign map ready" lines |
| Status.json | `canPollFileInbox: true`, settlement `Quyaz`, but **`campaignReady: false`** (process died before F7 flush completed) |
| Load warning | `RankForgeCandidates failed: Object reference not set to an instance of an object` (00:20:28) — seen on many prior sessions, likely not root cause |
| Diagnostics | `BlacksmithGuild_Diagnostics_20260622-002130.zip` |

**Verdict:** Continue gets further than disposable (map-ready in Phase1) but **still hard-crashes before stable F7 gate**. Do **not** run `-SkipLaunch` cert marathon until process stays alive ≥60s past map-ready with `campaignReady: true`.

### Investigation suspects (next agent)

1. **Mod reload / Safe Mode loop** — every launch hits Safe Mode; check `BlacksmithGuild_PendingReload.json`, Steam verify, close game before `dotnet build`
2. **Post-map init tick** — **fix shipped**: `CampaignMapReadyOrchestrator` + `TBG_MAP_READY_HOOK_MASK`
3. **Recent diff `e7690d9`..`aa46ea0`** — `FactionPowerPostureScanner` only runs in `ForgeStatus.Flush` when `_campaignReady && _mainHeroReady` (likely not reached before crash); still worth null-guard audit
4. **Engine / GPU** — no rgl_log or crash reporter captured; user may need Windows Event Viewer or Steam verify

## Live cert results

| Cert | Verdict | Evidence |
|------|---------|----------|
| Disposable bootstrap | **CRASH** | Phase1 stops at MapTransition 00:13:40; Launch.log process gone 00:14:06 |
| Continue bootstrap | **CRASH** | Phase1 map-ready Quyaz 00:20:34; process gone 00:20:36; manifest `docs/evidence/live-cert/20260622-002034/` |
| Continue marathon (-SkipLaunch) | **NOT RUN** | Blocked — no stable map-ready |
| Disposable marathon (-SkipLaunch) | **NOT RUN** | Blocked — no stable map-ready |
| 006B abort | **PENDING** | Blocked on crash |
| 006C-1 trade buy | **PENDING** | Blocked on crash |
| 006C-2 pack buy | **PENDING** | Blocked on crash |
| 006C-3 smelt | **PENDING** | Blocked on crash |
| 009A clan intel | **PENDING** | Blocked on crash |
| Faction posture | **PENDING** | Blocked on crash |

**Cold rule:** no stable map-ready → no PASS/FAIL verdict. Do not burn time on launcher UIA this sprint.

## Exact next local run path

**First: stabilize launch (user terminal, game focused, close Chrome/Cursor stealing focus)**

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
# Close Bannerlord completely first
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# Wait ≥60s on map. F7 MUST show: campaignReady=true, canPollFileInbox=true
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```

If Continue stable, optionally retry disposable after bootstrap fix (006E backlog).

## Output paths to analyze (post-export)

| Path | Cert |
|------|------|
| `docs/evidence/latest/README.md` | Export summary (must be fresh) |
| `BlacksmithGuild_AutonomousGuildLoop.json` | 006B, 006C loop |
| `BlacksmithGuild_MapTradeCert.json` | 006C-1/2 |
| `BlacksmithGuild_SmithingSmeltExecution.json` | 006C-3 |
| `BlacksmithGuild_ClanContext.json` | Faction posture + 009A |
| `docs/evidence/live-cert/<sessionId>/checkpoint-*/manifest.json` | Per-phase audit |
| `<Bannerlord>/BlacksmithGuild_Phase1.log` | Crash timestamp |
| `<Bannerlord>/BlacksmithGuild_Launch.log` | Process lifetime |
| `~/Documents/.../BlacksmithGuild_Diagnostics/*.zip` | Post-crash bundle |

## Known gaps (post-sprint)

- **Hard crash on load** — blocks all live certs (disposable + Continue)
- Disposable-only certs (006B mid-travel, 006C-1/2 trade, 006C-3 smelt mutation)
- 006C-4 sell + multi-cycle loop — blocked until 006C-1/2/3 PASS
- 006C-3b interior smithy smelt if headless fails
- 009A T3 courtship execution
- Ctrl+Alt+B hotkey cert separate from inbox abort

## Parallel sprint

- **Agent B (first):** crash repro → stable Continue → `-SkipLaunch` certs → export
- **Agent A:** `feat/006c-4-sell-loop` — **only after** Agent B confirms stable map + 006C-1/2/3 PASS

Do not merge Agent A until crash resolved and Continue certs pass.
