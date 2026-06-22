# Sprint 006C — Assistive Guild Loop (close the vision)

**Status:** 006C-1 CODE SHIPPED @ `main` — USER cert pending  
**Doctrine:** VanillaLegit — automate hands (travel, scan, refine), not skill levels or hidden stat injection  
**Branch:** `main` (006C-2+ from `feat/006c-2-pack-animal-buy` when started)

---

## Vision (one paragraph)

Launch → safe map travel → capacity / horses → food diversity → hero churn → trade → smelt non-combat gear → companion rotation → optional grind participation → eventual allied-party delegation. All assistive; player consequences stay vanilla.

---

## Phased deliverables

| Phase | Deliverable | Depends on | Honest gap today |
|-------|-------------|------------|------------------|
| **006C-1** | Vanilla trade driver (buy with gold/inventory delta proof) | Gauntlet/menu walk | **CODE SHIPPED** — USER cert pending |
| **006C-2** | Pack-animal buy mission + horse market → MapTrade integration | 006C-1 | **CODE SHIPPED** — USER cert pending |
| **006C-3** | Weapon smelt probe → execution if API proven | Smithing API research | `GuildLoopProbeWeaponSmeltOnStart` stub |
| **006C-4** | Multi-cycle guild loop (`guildLoopMaxCyclesPerCommand` + cooldown) | 006C-1 stable | Max 1 cycle per command |
| **006D** | Food / steward provisioning advisor + optional buy | Market/trade driver | Not built |
| **006E** | Tavern hero recruit in guild loop (bounded, doctrine-scored churn) | Settlement nav | Tavern intel separate from loop |
| **006F** | Companion rotation / stamina posse | Smithing advisory | [005e-smithing-posse-stamina-output.plan.md](005e-smithing-posse-stamina-output.plan.md) backlog |
| **007+** | Cohesion clan-helper movement; allied delegation | API probes | Player-party only |

---

## Sprint A+B shipped (assistive vision prep)

| Item | Path |
|------|------|
| Player automation playbook | [automation-playbook.md](../automation-playbook.md) |
| Horse market interior UX | `HorseMarketRecommendationService` — map OR interior gate |
| `ShowHorseMarketIntel` cache replay | On campaign map |
| `AgentAutoLoop` on map ready | Off by default; disposable-save gated |
| Stale doc fixes | `functionality-status.md`, `forge-zero-click-contract.md` |

---

## Launch-time automation

| Config | Default | Behavior |
|--------|---------|----------|
| `AgentAutoLoop` | `false` | One `RunAutonomousGuildLoopNow` on first map-ready tick |
| `GuildLoopAutonomousMode` | `true` | Master switch for autonomous loop |
| `GuildLoopMaxCyclesPerCommand` | `1` | Bounded per inbox command |

Enable (disposable only):

```powershell
.\scripts\write-agent-iteration-config.ps1 -Mode AutoLoop
.\Forge.cmd
```

Documented in [automation-playbook.md](../automation-playbook.md).

**Future:** Launch Control menu item "Continue + start guild loop" (config flag).

---

## Live cert rubric (006C entry)

```powershell
.\ForgeContinue.cmd
.\forge.ps1 -Command RunAutonomousGuildLoopNow -Wait
.\forge.ps1 -Command AnalyzeHorseMarket -Wait    # inside town OR at gate
.\forge.ps1 -Command ShowHorseMarketIntel -Wait    # on map — replay
.\ExportTbgEvidence.cmd
```

**PASS when:** trade driver shows gold/inventory delta on disposable save; horse buy mission or honest block with proof; multi-cycle opt-in does not infinite-loop.

---

## JSON paths

| File | Phase |
|------|-------|
| `BlacksmithGuild_AutonomousGuildLoop.json` | All |
| `BlacksmithGuild_MapTradeCert.json` | 006C-1 |
| `BlacksmithGuild_HorseMarketIntel.json` | 006C-2 |
| `BlacksmithGuild_SmithingSafeAction.json` | 006C-3 smelt |
| `BlacksmithGuild_MarketIntel.json` | 006D food advisor |

---

## Handoff prompt

```text
DOCTRINE: VanillaLegit — Smithing 275 is vanilla grind; mod automates hands, not levels.
READ: docs/automation-playbook.md, docs/handoff/006b-map-trade-cohesion-agent-handoff.md
006C-1: vanilla trade driver with delta proof — highest risk
006C-2: horse market → pack buy mission
BRANCH: feat/006c-assistive-guild-loop from main after 006B merge
```
