# Agent Handoff — Sprint 006B Map Trade + Cohesion + Autonomous Guild Loop

**Copy-paste this entire document to any AI agent continuing BlacksmithGuild work.**

---

## Repo

- **Path:** `C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild`
- **Remote:** `https://github.com/EndeavorEverlasting/BlacksmithGuild`
- **Branch for 006B:** `feat/006b-map-trade-cohesion` → PR to `main`
- **Main head includes:** PR #3 Launch Control (`tools/LaunchControl/`), 006A tavern hero, auto-travel, 006B character profiles
- **Doctrine:** Automate the hands, not the consequences — visible movement, probe-first APIs, honest blocks, disposable saves for mutations

---

## Module map

| Module | Folder | Role |
|--------|--------|------|
| **Cohesion** | `src/BlacksmithGuild/Cohesion/` | Shared tactical brain: party scan, intent inference, scoring, visible player movement |
| **MapTrade** | `src/BlacksmithGuild/MapTrade/` | Autonomous trade FSM; asks Cohesion on danger; vanilla trade probe |
| **GuildLoop orchestrator** | `src/BlacksmithGuild/GuildLoop/AutonomousGuildLoopService.cs` | `RunAutonomousGuildLoopNow` — one bounded cycle |
| **Advisory guild loop (existing)** | `src/BlacksmithGuild/Forge/GuildLoopService.cs` | `RunGuildLoopNow` / Ctrl+Alt+G — market + forge rank only, NOT autonomous travel |
| **Movement helper** | `src/BlacksmithGuild/DevTools/CampaignMapMovementHelper.cs` | `SetMoveGoToSettlement` + reflection fallbacks |
| **Launch** | `tools/LaunchControl/` | Desktop/Start Menu wrapper for Forge.cmd / ForgeContinue.cmd |

**Design law:** MapTrade asks Cohesion; orchestrator chains both. No duplicate convergence logic inside MapTrade.

**Integration contract:**

```csharp
// When bandit/army risk is medium/high or mission would block:
CohesionEngine.BuildPlanForObjective(CohesionObjective objective) → CohesionOpportunity

// Map trade danger hooks in MapTradeAutonomousService + MapTradeRouteSafetyAnalyzer
// Orchestrator: AutonomousGuildLoopService calls MapTradeMissionSelector, CohesionEngine, MapTradeVanillaTradeDriver, BlacksmithAutomationService
```

---

## Commands (all registered in DevCommandRegistry + dev-command-names.ps1)

### Cohesion

| Command | Type | JSON |
|---------|------|------|
| `AnalyzeCohesionOpportunities` | read-only | `BlacksmithGuild_CohesionOpportunities.json` |
| `ShowCohesionPlan` | read-only | last analyze + move status |
| `RunVisibleCohesionMoveNow` | **mutation + risky gate** | `BlacksmithGuild_CohesionMove.json` |
| `AbortCohesionMoveNow` | control | — |
| `SetCohesionDoctrineTradeForge` / `Relief` / `Escort` / `BanditSuppression` | config | — |

### Map trade

| Command | Type |
|---------|------|
| `AnalyzeMapTradeRouteSafety` | read-only → `BlacksmithGuild_MapTradeRouteSafety.json` |
| `RunAutonomousVisibleTradeRouteNow` | **mutation + risky gate** → `BlacksmithGuild_MapTradeCert.json` |
| `AbortMapTradeRouteNow` | control |
| `ShowMapTradeRouteStatus` | read-only |
| `AnalyzeTacticalConvergence` | alias → `AnalyzeCohesionOpportunities` (TradeForge) |
| `ShowTacticalConvergence` | alias → `ShowCohesionPlan` |
| `RunForgeHandoffAfterTradeNow` | read-only + optional one `RunBlacksmithAutomationNow` |

### Autonomous guild loop

| Command | Type | JSON |
|---------|------|------|
| `RunAutonomousGuildLoopNow` | **mutation + risky gate** | `BlacksmithGuild_AutonomousGuildLoop.json` |

---

## Config keys (DevToolsConfig.cs)

**MapTrade*:** `MapTradeAutonomousMode`, `MapTradeVisibleMode`, `MapTradeDecisionPauseMs`, route/trade limits, hostile radii, `MapTradeAutoRunForgeHandoff`, `MapTradeAllowDirectInventoryMutation` (false), `MapTradeAllowDirectGoldMutation` (false), `MapTradeAllowTeleport` (false)

**Cohesion*:** `CohesionMinimumEngageRatio`, `CohesionMinimumSurvivalRatio`, `CohesionScanRadius`, `CohesionDecisionPauseMs`, `CohesionDefaultDoctrine`, etc.

**GuildLoop*:** `GuildLoopAutonomousMode`, `GuildLoopMaxCyclesPerCommand` (1), `GuildLoopAutoRunForgeHandoff`, `GuildLoopPreferSmithingInputs`, `GuildLoopAllowTravelOnlyIfTradeBlocked`, `GuildLoopProbeWeaponSmeltOnStart`

---

## Tick wiring (BlacksmithGuildCampaignBehavior.OnCampaignTick)

```csharp
AutoTravelService.OnCampaignTick();
CohesionExecutionDriver.OnCampaignTick();
MapTradeAutonomousService.OnCampaignTick();
AutonomousGuildLoopService.OnCampaignTick();
```

---

## JSON paths to analyze

| File | Source |
|------|--------|
| `BlacksmithGuild_AutonomousGuildLoop.json` | **Primary sprint deliverable** — `RunAutonomousGuildLoopNow` |
| `BlacksmithGuild_CohesionOpportunities.json` | `AnalyzeCohesionOpportunities` |
| `BlacksmithGuild_CohesionMove.json` | `RunVisibleCohesionMoveNow` |
| `BlacksmithGuild_MapTradeRouteSafety.json` | `AnalyzeMapTradeRouteSafety` |
| `BlacksmithGuild_MapTradeCert.json` | `RunAutonomousVisibleTradeRouteNow` |
| `BlacksmithGuild_MapTradeForgeHandoff.json` | forge handoff step |
| `BlacksmithGuild_ArmyPressureWindows.json` | army pressure analyzer |
| `BlacksmithGuild_MarketIntel.json` | market scan (existing) |
| `BlacksmithGuild_BlacksmithAutomation.json` | charcoal refine handoff (existing) |
| `BlacksmithGuild_Status.json` | F7 readiness (existing) |
| `BlacksmithGuild_LaunchControlLastRun.json` | Launch Control (after install) |

Runtime: Bannerlord install folder (`GameFolder` in csproj). Mirrored: `docs/evidence/latest/` via `ExportTbgEvidence.cmd`.

---

## Live cert sequence (USER on disposable save)

```powershell
# Optional: install Launch Control shortcuts once
powershell -NoProfile -ExecutionPolicy Bypass -File tools/LaunchControl/Install-LaunchControl.ps1

.\ForgeContinue.cmd
# Wait for campaign map — F7 campaignReady: true

.\forge.ps1 -Command AnalyzeCohesionOpportunities -Wait
.\forge.ps1 -Command AnalyzeMapTradeRouteSafety -Wait
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\forge.ps1 -Command ShowMapTradeRouteStatus -Wait
.\ExportTbgEvidence.cmd
```

### PASS criteria

- Build: `dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release` succeeds
- Cohesion analyze JSON has party snapshots + intent confidence
- Guild loop JSON `verdict` is `Complete` or honest `Blocked` with `capabilities` flags
- Visible map movement observed (no teleport, no forced combat)
- Trade/smelt/capacity gaps explicitly in `capabilities` block — do not treat as PASS if faked

---

## Known gaps (honest — do not over-promise)

| Gap | Sprint state | Follow-on 006C |
|-----|--------------|----------------|
| Vanilla town buy/sell | Probe + reflection candidates; `TryExecuteBuy` blocks with `VisibleTradeDriverUnavailable` | Gauntlet/menu walk hardening, gold/inventory delta proof |
| Pack-animal / capacity | `ProbePackAnimalBuyApi` → false in JSON | `BuyPackAnimalForCapacityThenTrade` mission |
| Weapon buy + smelt | `ProbeSmithingSmeltApi` → false; no fake smelt | Headless smelt if API proven |
| Headless craft | Still `CraftManual` in forge rank | Smithing craft API research |
| Multi-cycle rinse-repeat | `guildLoopMaxCyclesPerCommand = 1` | Bounded auto-loop + cooldown; optional `AgentAutoLoop` |
| Cohesion reroute/escort/clan helpers | Fall through to blocked in execution driver | Extend `CohesionExecutionDriver` |
| Allied faction detection | Simplified (no `IsAllyOf` on this API version) | Stance-based allied classification |
| Live cert | USER must run on Windows + Bannerlord | — |

---

## Do NOT

- Teleport or raw position-set parties
- Direct gold/inventory mutation when config forbids it
- Force party merge or battle results
- Fake weapon smelt or pack-animal buy in JSON
- Unbounded autonomous loops
- Conflate `RunGuildLoopNow` (advisory) with `RunAutonomousGuildLoopNow` (mutation FSM)

---

## 006C scope preview

1. Prove vanilla buy/sell with before/after gold + inventory deltas
2. Pack-animal buy mission + capacity buffer automation
3. Weapon procurement + headless smelt if API proven
4. Multi-hop trade loop with cooldown (`guildLoopMaxCyclesPerCommand > 1` gated)
5. Harden cohesion reroute/escort/clan helper commands

---

## Repo hygiene checklist

1. `git status` clean (no modified/untracked source except intentional evidence under `docs/evidence/latest/`)
2. Feature branch pushed: `git push -u origin feat/006b-map-trade-cohesion`
3. PR open to `main` (separate from PR #2 identity schema docs)
4. PR #3 merged to main (Launch Control)
5. Delete stale local branch `feat/006a-tavern-hero` if merged

---

## Build

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```

---

## Related docs

- `docs/plans/006b-map-trade-cohesion.plan.md`
- `docs/player-command-guide.md`
- `docs/functionality-status.md` (update after USER live cert)
