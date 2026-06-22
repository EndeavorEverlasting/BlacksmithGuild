# Automation Playbook — The Blacksmith Guild

**Player-facing guide:** what runs automatically, what you trigger once, and where to look when the in-game feed is awkward.

**Launch paths:** [launch-and-doc-index.md](launch-and-doc-index.md)  
**Hotkeys / inbox commands:** [player-command-guide.md](player-command-guide.md)  
**Message feed / F7:** [in-game-surfaces.md](in-game-surfaces.md)  
**VanillaLegit / Smithing 275:** [plans/008a-vanilla-legit-aserai-tradesmith.plan.md](plans/008a-vanilla-legit-aserai-tradesmith.plan.md)

---

## Launch → map ready

| Path | Command | When |
|------|---------|------|
| Daily dev | `ForgeContinue.cmd` | Existing save, campaign map |
| Fresh bootstrap | `Forge.cmd` | New SandBox campaign (disposable cert) |
| Desktop menu | `tools/LaunchControl/Launch-Control.cmd` | Same as above via shortcuts |

**Ready signal:** F7 → `campaignReady: true` or in-game `TBG READY: campaign map ready`.

---

## What runs automatically vs what you run once

### Automatic (no extra command)

| When | What |
|------|------|
| Map ready (first tick) | `TBG READY` notice, command surface written, optional treasury snapshot |
| Daily tick | Fake forge advisor lines (cosmetic); gold test **off** by default |
| After `RunAutonomousGuildLoopNow` started | Tick FSM continues travel / cohesion / trade probe until one cycle completes |

### Manual / one-shot (you or agent trigger)

| Action | Command / hotkey |
|--------|------------------|
| Market action plan | **Ctrl+Alt+M** or `MarketSnapshotNow` |
| Forge + crew advisory | **Ctrl+Alt+R** or `RunSmithingAdvisoryNow` |
| Advisory guild loop (no travel) | **Ctrl+Alt+G** or `RunGuildLoopNow` |
| **Autonomous guild loop** (travel + scan + cohesion) | `RunAutonomousGuildLoopNow` |
| Horse / pack capacity advice | `AnalyzeHorseMarket` (in town) |
| Charcoal refine (bounded mutation) | `RunBlacksmithAutomationNow` or `RunSmithingSafeActionNow` |
| Export evidence for AI | `ExportTbgEvidence.cmd` |

**Do not confuse:** `RunGuildLoopNow` (Ctrl+Alt+G) = read-only market + forge rank.  
`RunAutonomousGuildLoopNow` = visible travel, cohesion, blocked trade handoff (006B).

---

## After map ready — one autonomous cycle

```powershell
.\ForgeContinue.cmd
# F7: campaignReady true
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\ExportTbgEvidence.cmd
```

**Typical flow inside one cycle:**

1. Preflight — campaign map ready  
2. Market scan — nearest towns, spreads, smithing inputs  
3. Cohesion — danger / convergence check if travel needed  
4. Visible travel — toward procurement or trade town (if mission selected)  
5. Trade step — **probe only today** (honest block if execution not proven)  
6. Forge handoff — optional `RunBlacksmithAutomationNow` (charcoal refine if materials allow)

Primary JSON: `BlacksmithGuild_AutonomousGuildLoop.json` — read `capabilities` and `steps` for honest gaps.

---

## Manual advisory loop (map only)

On the **open campaign map** (not inside settlement menus):

1. **Ctrl+Alt+M** — trade routes, BUY@NEAREST, TOP SPREADS  
2. Travel manually or `ShowAutoTravelChoices` → `AutoTravelChoice1`  
3. Enter town → trade manually (no auto buy/sell yet)  
4. **Ctrl+Alt+R** or **Ctrl+Alt+G** — forge rank, crew, material gaps  
5. Enter smithy → craft manually  
6. Repeat at next town

---

## Smithing 275 (Legendary Smith) — VanillaLegit expectations

| Question | Answer |
|----------|--------|
| Is 275 possible? | **Yes** — vanilla Crafting XP (smithing, refining, smelting, orders). Max skill 330. |
| Does TBG auto-give 275? | **No.** No hidden post-map skill injection on VanillaLegit. |
| What does the mod do? | **Hands, not levels:** travel, market scan, charcoal refine, forge **advisory**. XP accrues at vanilla rates when you perform those actions. |
| DevOverride testing | Floors Crafting at 100–125 only — not your personal save path. |

Legendary Smith is a **long-term campaign goal**, not a launch outcome. Grind like vanilla; the mod reduces repetitive input.

---

## Command context matrix

| Command | Best location | In-game feed? | JSON |
|---------|---------------|---------------|------|
| `MarketSnapshotNow` | Campaign map | Yes (Ctrl+Alt+M) | `MarketIntel.json` |
| `RunAutonomousGuildLoopNow` | Campaign map | Partial (travel notices) | `AutonomousGuildLoop.json` |
| `AnalyzeHorseMarket` | **Stopped at town** or **inside settlement** | Yes on map; compact line inside town | `HorseMarketIntel.json` |
| `ShowHorseMarketIntel` | Campaign map | Replays last scan (no re-scan) | Same JSON (cached) |
| `AnalyzeTavernHeroes` | Map at town or inside tavern | Yes | `TavernHeroIntel.json` |
| `NavigateToSettlementTavernNow` | Map at town | Yes | Phase1 `[TBG TAVERN]` |
| Inside settlement menus | Most **map-only** commands blocked | Feed often hidden | Use `ExportTbgEvidence.cmd` |

**Horse market location rules (2026-06-21 fix):**

- `AnalyzeHorseMarket` works on the **campaign map at a town gate** or **inside the settlement** (marketplace / town UI).  
- Inside a town: you get a **compact summary** in the feed; full colored report is in JSON. Press **Enter** to scroll, or exit to map and run `ShowHorseMarketIntel`.  
- `ShowHorseMarketIntel` requires the **open campaign map** — replays the last scan without re-reading the market.

JSON cert fields: `sessionPhase`, `settlementResolveMethod` (`partyCurrentSettlement` | `playerEncounter`).

---

## Stopping automation (exit ladder)

Automation is certified for **single-player SandBox/Continue campaign** only (not custom battle / multiplayer).

| Tier | When | Action |
|------|------|--------|
| **Natural** | Default | Wait — one cycle ends; check `BlacksmithGuild_AutonomousGuildLoop.json` → `verdict` |
| **Safe in-game** | Campaign map open, dev tools on | **Ctrl+Alt+B** or `.\forge.ps1 -Command AbortAutonomousGuildLoopNow -Wait` |
| **Disable next launch** | Agent auto-loop armed | `.\scripts\write-agent-iteration-config.ps1 -Mode Manual` before next `Forge.cmd` |
| **Emergency** | Launcher/script runaway or UI trap | `.\ForgeStop.cmd` from repo root |

**Ctrl+Alt+B** stops all active TBG movement automation: autonomous guild loop, cohesion move, map trade route, and auto-travel. Party holds on the map; JSON shows `verdict: Aborted` where applicable.

**Not an abort:** right-click hold on the map pauses vanilla movement but does **not** clear the guild-loop FSM — use **Ctrl+Alt+B**.

**Cheat console (disposable saves only):** `cheat_mode = 1` in `engine_config.txt` enables Alt+` sanity checks; not required for **Ctrl+Alt+B**. See [in-game-surfaces.md](in-game-surfaces.md).

Legacy per-FSM inbox aborts still work: `AbortCohesionMoveNow`, `AbortMapTradeRouteNow`.

---

## Optional launch-time auto-loop (off by default)

For **disposable `Forge.cmd` bootstrap only** — not Continue / personal saves:

```powershell
.\scripts\write-agent-iteration-config.ps1 -Mode AutoLoop
.\Forge.cmd
```

When `autoLoop: true` in `BlacksmithGuild_AgentIterationConfig.json`, the mod runs **one** `RunAutonomousGuildLoopNow` cycle on first map-ready tick.

```powershell
.\scripts\write-agent-iteration-config.ps1 -Mode Manual   # disable
```

**Gates:** `AgentAutoLoop` default `false`; requires `CampaignSetupStateTracker.UsedDisposableQuickStartPath`; respects `GuildLoopAutonomousMode`.

---

## Accessibility / arthritis-friendly workflow

- **Visible pauses:** character creation and risky commands use bounded delays (`CharacterCreationVisibleMode`, cohesion/trade pause ms).  
- **One-cycle commands:** `RunAutonomousGuildLoopNow` and `RunBlacksmithAutomationNow` do not loop unbounded.  
- **Launch Control:** fewer launcher clicks — [tools/LaunchControl/README.md](../tools/LaunchControl/README.md).  
- **When the feed is hard to see:** run `ExportTbgEvidence.cmd` and paste `docs/evidence/latest/README.md` to any agent — no screenshots required.  
- **Fallback hotkeys:** Ctrl+Alt+7–1 when F-keys are swallowed — [in-game-surfaces.md](in-game-surfaces.md).

---

## JSON to analyze after a session

| File | Purpose |
|------|---------|
| `BlacksmithGuild_AutonomousGuildLoop.json` | Primary automation cert |
| `BlacksmithGuild_HorseMarketIntel.json` | Capacity / pack-animal advice |
| `BlacksmithGuild_MarketIntel.json` | Trade routes and action plan |
| `BlacksmithGuild_Status.json` | F7 / session phase |
| `docs/evidence/latest/README.md` | After `ExportTbgEvidence.cmd` |

---

## Known gaps (honest — not bugs)

- Vanilla town buy/sell execution (probe only)  
- Pack-animal purchase automation  
- Weapon smelt execution  
- Food / steward provisioning  
- Multi-cycle guild loop (`guildLoopMaxCyclesPerCommand = 1`)  
- Hero churn in guild loop  
- Smithing 275 shortcut on VanillaLegit (**intentionally none**)

Roadmap: [plans/006c-assistive-guild-loop.plan.md](plans/006c-assistive-guild-loop.plan.md)
