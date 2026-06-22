# Live Cert Marathon — Agent Handoff

**Last updated:** 2026-06-21  
**Sprint:** 006C-3 weapon smelt + faction power posture + live cert orchestrator

## What shipped

- `FactionPowerPostureScanner` → `ClanContext.json`, F7 `clanPosture`, guild loop `FactionPosture` step
- `SmithingSmeltApi`, `SmithingLootWeaponScanner`, `SmithingSmeltService`
- Commands: `ProbeWeaponSmeltNow`, `RunWeaponSmeltNow`
- Guild loop: honest `capabilities.weaponSmelt`, `TryWeaponSmelt` at forge handoff
- `scripts/run-live-assistive-cert.ps1`, `run-weapon-smelt-cert.ps1`
- Export/collect scripts include smelt + marathon JSONs

## Live cert results

| Cert | Verdict | Evidence |
|------|---------|----------|
| 006B abort | USER PENDING | `AutonomousGuildLoop.json` → `verdict: Aborted` |
| 006C-1 trade buy | USER PENDING | `MapTradeCert.json` / `MapTradeProbe.json` |
| 006C-2 pack buy | USER PENDING | `MapTradePackAnimalProbe.json` |
| 006C-3 smelt | USER PENDING | `SmithingSmeltProbe.json`, `SmithingSmeltExecution.json` |
| 009A clan intel | USER PENDING | `Run-ClanIntelCert.cmd` (6 JSON files) |
| Faction posture | USER PENDING | `ClanContext.json` → `factionPowerPosture` |

Record PASS/FAIL after `Run-LiveAssistiveCert.cmd -Session all`.

## Verify commands

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeStop.cmd
.\Run-LiveAssistiveCert.cmd -Session disposable
.\ForgeStop.cmd
.\Run-LiveAssistiveCert.cmd -Session continue
.\ExportTbgEvidence.cmd
```

## Output paths

- `docs/evidence/live-cert/<sessionId>/checkpoint-*/manifest.json`
- `docs/evidence/latest/`
- `<Bannerlord>/BlacksmithGuild_*.json`
- `<Bannerlord>/BlacksmithGuild_Phase1.log`

## Known gaps

- 006C-4 sell + multi-cycle loop
- 006C-3b smithy interior smelt if headless `DoSmelting` fails on map
- 009A courtship execution (T3)
- Ctrl+Alt+B hotkey cert separate from inbox abort

## Next sprint options

1. **006C-4** — sell path + multi-cycle guild loop
2. **006C-3b** — interior smithy walk if smelt blocked
3. **009A T3** — visible courtship execution

## Parallel sprint (optional second agent)

- Agent A: `feat/006c-4-sell-loop` — sell driver coding
- Agent B: re-run `Run-LiveAssistiveCert.cmd` on Continue save, record PASS/FAIL only

Do not merge Agent A until Agent B confirms no regression on 006C-1/2/3 JSON rubrics.
