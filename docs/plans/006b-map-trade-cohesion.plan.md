# Sprint 006B — Map Trade, Cohesion, Autonomous Guild Loop

**Branch:** `feat/006b-map-trade-cohesion`  
**Distinct from:** `006b-build-profiles.plan.md` (character profiles — already on main)

## Delivered

- `src/BlacksmithGuild/Cohesion/` — analyze + visible player movement FSM
- `src/BlacksmithGuild/MapTrade/` — route safety, mission select, vanilla trade probe, tick FSM
- `src/BlacksmithGuild/GuildLoop/AutonomousGuildLoopService.cs` — `RunAutonomousGuildLoopNow`
- Command wiring in DevCommandRegistry/Bus/CommandSurface + campaign tick hooks
- PR #3 Launch Control merged to `main`

## Live cert (USER, disposable save)

```powershell
.\ForgeContinue.cmd
.\forge.ps1 -Command AnalyzeCohesionOpportunities -Wait
.\forge.ps1 -Command AnalyzeMapTradeRouteSafety -Wait
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

## Known gaps → 006C

- Vanilla town buy/sell execution (probe only)
- Pack-animal capacity buy
- Weapon smelt automation
- Multi-cycle rinse-repeat (`guildLoopMaxCyclesPerCommand = 1`)

See `docs/handoff/006b-map-trade-cohesion-agent-handoff.md` for full agent prompt.
