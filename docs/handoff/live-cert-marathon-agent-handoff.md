# Live Cert Marathon — Agent Handoff

**Last updated:** 2026-06-22  
**Baseline:** `main` @ `15d1611` (origin synced, working tree clean)  
**Sprint status:** Code shipped; **not cert-complete**

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
| `dotnet build -c Release` | **PASS** | 2026-06-22 — 0 warnings |

## Live cert results

| Cert | Verdict | Evidence |
|------|---------|----------|
| Marathon disposable bootstrap (unattended) | **BLOCKED** | `docs/evidence/live-cert/20260621-235604/checkpoint-01-map-ready/manifest.json` — map ready timeout; launcher UIA / Terminal foreground |
| Disposable marathon (-SkipLaunch) | **NOT RUN** | Requires manual `Forge.cmd` + F7 ready first |
| Continue marathon (-SkipLaunch) | **NOT RUN** | Requires manual `ForgeContinue.cmd` + F7 ready |
| 006B abort | **PENDING** | `AutonomousGuildLoop.json` → `verdict: Aborted` |
| 006C-1 trade buy | **PENDING** | `MapTradeCert.json` / `MapTradeProbe.json` |
| 006C-2 pack buy | **PENDING** | `MapTradePackAnimalProbe.json` |
| 006C-3 smelt | **PENDING** | `SmithingSmeltProbe.json`, `SmithingSmeltExecution.json` |
| 009A clan intel | **PENDING** | 6 clan JSON files via `Run-ClanIntelCert.cmd` |
| Faction posture | **PENDING** | `ClanContext.json` → `factionPowerPosture` |

**Do not fix launcher automation for Agent B.** Failure mode was focus/UIA, not inbox/clan/smelt/guild-loop bugs.

## Exact next local run path

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\Forge.cmd
# Keep launcher focused. F7: campaignReady=true, canPollFileInbox=true
.\Run-LiveAssistiveCert.cmd -Session disposable -SkipLaunch -FromCheckpoint 2
.\ForgeContinue.cmd
# F7 ready again
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
.\ExportTbgEvidence.cmd
```

Update `docs/functionality-status.md` PASS/FAIL table from exported JSON rubrics.

## Output paths to analyze (post-export)

| Path | Cert |
|------|------|
| `docs/evidence/latest/README.md` | Export summary (must be fresh) |
| `BlacksmithGuild_AutonomousGuildLoop.json` | 006B, 006C loop |
| `BlacksmithGuild_MapTradeCert.json` | 006C-1/2 |
| `BlacksmithGuild_SmithingSmeltExecution.json` | 006C-3 |
| `BlacksmithGuild_ClanContext.json` | Faction posture + 009A |
| `docs/evidence/live-cert/<sessionId>/checkpoint-*/manifest.json` | Per-phase audit |

## Known gaps (post-cert)

- 006C-4 sell + multi-cycle loop
- 006C-3b smithy interior smelt if headless fails on map
- 009A T3 visible courtship execution
- Ctrl+Alt+B hotkey cert (inbox abort used for 006B)

## Parallel sprint

- **Agent B (first):** manual launch → `-SkipLaunch` certs → export → rubric table
- **Agent A (after 006C-1/2/3 PASS on Continue):** `feat/006c-4-sell-loop` — sell driver only

Do not merge Agent A until Agent B confirms no regression on 006C-1/2/3 JSON rubrics.
