# Player Command Guide

**What do I press? What command do I run? What JSON should I look at?**

Evidence export (no screenshots needed):

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\ExportTbgEvidence.cmd
```

Then paste `docs/evidence/latest/README.md` to any AI agent.

---

## Play now (skip cert ceremony)

**Fastest path to gameplay on an existing save:**

```powershell
.\ForgeStop.cmd
.\ForgeContinue.cmd
```

Wait for **campaign map** (not character creation). Press **F7** — confirm `campaignReady: true`.

**Play loop (no cert CMD files):**

1. **Ctrl+Alt+M** on map → trade action plan (read-only)
2. Enter town → Trade manually
3. **Ctrl+Alt+R** or **Ctrl+Alt+G** → forge/guild advisory (read-only)
4. Enter smithy → craft manually

**Skip unless you explicitly want them:** `RunCharacterBuildVisibleCert.cmd`, `RunStageCCharcoalCert.cmd`, `RunStageBSmithingCert.cmd`, catalog/matrix scripts, Sprint 001/002 harness checks in Status.json.

See [checkpoints/play-now-cert-triage.md](checkpoints/play-now-cert-triage.md).

---

## Inbox commands require campaign map

`.\forge.ps1 -Command <Name> -Wait` only works when:

- Mod is loaded and **campaign map is ready** (`campaignReady: true` in F7 / `BlacksmithGuild_Status.json`)
- `session.canPollFileInbox: true`

Commands **do not run** during character creation, main menu, or loading. A stale `BlacksmithGuild_CommandAck.json` used to cause false PASS; `Send-ForgeCommand` now clears the ack file and requires matching `command` name.

If `-Wait` times out, you are not on the map yet — use **hotkeys** (Ctrl+Alt+M/R/G) instead, or finish `ForgeContinue.cmd` first.

---

## Quick reference

| Goal | In-game input | PowerShell command | Output JSON | What it proves |
|------|---------------|-------------------|-------------|----------------|
| Status | **F7** | `.\forge.ps1 -Command ShowForgeStatus -Wait` | `BlacksmithGuild_Status.json` | Mod loaded, map phase, cert state, last command |
| Command list | **F8** (`ListScenarios`) | — (F8 writes surface) | `BlacksmithGuild_CommandSurface.json` | All hotkeys + inbox commands + Stage D exposed |
| Market intel | **Ctrl+Alt+M** | `.\forge.ps1 -Command MarketSnapshotNow -Wait` | `BlacksmithGuild_MarketIntel.json` | Nearest towns, spreads, buy/sell action plan |
| Horse market intel | — | `.\forge.ps1 -Command AnalyzeHorseMarket -Wait` | `BlacksmithGuild_HorseMarketIntel.json` | Read-only capacity buffer + pack/war mount buy/hold/sell advice |
| Forge rank | **Ctrl+Alt+R** | `.\forge.ps1 -Command RankForgeCandidates -Wait` | `BlacksmithGuild_ForgeRecommendations.json` | Real/stub source honesty, top craft, material gaps |
| Smithing crew | — | `.\forge.ps1 -Command RunSmithingAdvisoryNow -Wait` | `BlacksmithGuild_SmithingAdvisory.json` | Crew roles, reserves, refine/craft prep |
| Guild loop | **Ctrl+Alt+G** | `.\forge.ps1 -Command RunGuildLoopNow -Wait` | `BlacksmithGuild_GuildLoopReport.json` | Unified market + forge + crew + action plan |
| Stage C refine | — | `.\RunStageCCharcoalCert.cmd` | `BlacksmithGuild_SmithingSafeAction.json` | One headless hardwood→charcoal mutation (Tier 3) |
| Stage D rest plan | — (inbox only) | `.\forge.ps1 -Command RunSmithingRestPlanNow -Wait` | `BlacksmithGuild_SmithingRestPlan.json` | Read-only rest recommendation (no time mutation) |
| Character doctrine | — | `.\forge.ps1 -Command ShowCharacterDoctrine -Wait` | `BlacksmithGuild_CharacterDoctrine.json` | VanillaLegit + Aserai Trade-Smith doctrine |
| Choice catalog (008C) | — | `.\scripts\run-character-build-catalog.ps1` | `BlacksmithGuild_CharacterChoiceCatalog.json` | Live menu options + parsed rewards |
| Variant matrix (008C) | — | `.\RunCharacterBuildVariantMatrix.cmd -NoPause` | `character_runs/BlacksmithGuild_CharacterBuildRun_*.json` | Sequential VanillaLegit variant runs |
| Best build (008C) | — | `.\forge.ps1 -Command SelectCharacterBuildBestNow -Wait` | `BlacksmithGuild_CharacterBuildBest.json` | Winner among clean VanillaLegit runs |
| **Visible personal cert (008C-Fix)** | — | `.\RunCharacterBuildVisibleCert.cmd` | `BlacksmithGuild_CharacterVisibleReplay.json` | **Required gate for TBGPersonalAserai001** |
| Legitimacy assert (read-only) | — | `.\scripts\assert-character-legitimacy.ps1 -PersonalCert` | stdout JSON | Provenance + Phase1 session checks |
| Blacksmith automation | — | `.\forge.ps1 -Command RunBlacksmithAutomationNow -Wait` | `BlacksmithGuild_BlacksmithAutomation.json` | One bounded safe action (charcoal refine or clean block) |
| Auto-travel choices | — | `.\forge.ps1 -Command ShowAutoTravelChoices -Wait` | Phase1 `[TBG TRAVEL]` lines | Read-only ranked town/village list (campaign map required) |
| Auto-travel move | — | `.\forge.ps1 -Command AutoTravelChoice1 -Wait` | Phase1 `[TBG TRAVEL] auto-travel started` | Tier 2 mutation — main party map movement + hostile pause monitor |
| Export evidence | — | `.\ExportTbgEvidence.cmd` | `docs/evidence/latest/README.md` | Repo-local snapshot for agents |

---

## Starting a real Aserai Trade-Smith save

**Do not save `TBGPersonalAserai001` after catalog/matrix scripts** — those use AgentHeadless (invisible, 12 steps/tick). That path is agent-only.

### Certified personal baseline (recommended)

1. Close Bannerlord.
2. Run `.\RunCharacterBuildVisibleCert.cmd` (or `.\Forge.cmd` — also writes UserVisible config).
3. Watch culture/upbringing choices (visible traversal; ~750ms pause; lower-left `TBG:` notices).
4. Confirm Aserai selected in Phase1: `culture auto-selected: Aserai` and `visible traversal: on`.
5. Reach campaign map.
6. Press **F7**.
7. Confirm:
   - mode: VanillaLegit + Assistive
   - build: AseraiTradeSmith
   - culture: Aserai
   - postMapInjection: off
8. Run `.\scripts\assert-character-legitimacy.ps1 -PersonalCert` — must PASS.
9. Save as `TBGPersonalAserai001`.

### Quick launch (Forge.cmd)

1. Close Bannerlord.
2. Run `.\Forge.cmd`.
3. Watch culture/upbringing choices (visible traversal; ~750ms pause between steps).
4. Confirm Aserai selected in Phase1: `culture auto-selected: Aserai`.
5. Reach campaign map.
6. Press **F7**.
7. Confirm:
   - mode: VanillaLegit + Assistive
   - build: AseraiTradeSmith
   - culture: Aserai
   - postMapInjection: off
8. Save as `TBGPersonalAserai001`.

Inspect JSON:

- `BlacksmithGuild_CharacterBuildProvenance.json` — `visibleTraversalUsed`, `upbringingChoices`, verdict
- `BlacksmithGuild_CharacterVisibleReplay.json` — cert completion (`completed: true`)
- `BlacksmithGuild_CharacterDoctrine.json` — doctrine axes

---

## Blacksmith automation

Run:

```powershell
.\forge.ps1 -Command RunBlacksmithAutomationNow -Wait
```

Expected:

- Refines one charcoal if hardwood exists and charcoal is low.
- Blocks cleanly if hardwood is missing (`BuyMaterialsFirst`).
- Recommends manual craft if crafting mutation is not yet proven (`CraftManual`).
- Does **not** auto-buy, auto-rest, or loop unbounded.

Regression for Stage C alone: `.\RunStageCCharcoalCert.cmd`

---

## Fallback hotkeys (when F-keys swallowed)

| Input | Command |
|-------|---------|
| Ctrl+Alt+7 | ShowForgeStatus (F7) |
| Ctrl+Alt+8 | ListScenarios (F8) |
| Ctrl+Alt+9 | AdvanceOneDay (F9) |
| Ctrl+Alt+D | AdvanceOneDay (daily tick — **not** Stage D) |

**Stage D has no hotkey** in this build. Use inbox: `RunSmithingRestPlanNow`.

---

## Typical agent workflow

1. On campaign map, press **Ctrl+Alt+G** (guild loop) and **F8** (refresh command surface).
2. From PowerShell:

```powershell
.\forge.ps1 -Command RunSmithingRestPlanNow -Wait
.\ExportTbgEvidence.cmd
```

3. Paste to agent:

```text
docs/evidence/latest/README.md
docs/evidence/latest/BlacksmithGuild_GuildLoopReport.json
docs/evidence/latest/BlacksmithGuild_SmithingRestPlan.json
```

---

## JSON locations

Runtime files are written to the **Bannerlord install folder** (see `GameFolder` in csproj):

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
```

Committed copies live at:

```text
docs/evidence/latest/
```

Collect full cert bundle (stdout, for paste): `CollectCertLogs.cmd`

---

## Related docs

- [functionality-status.md](functionality-status.md) — what is certified
- [certification-doctrine.md](certification-doctrine.md) — Tier 0–3 cert rules
- [in-game-surfaces.md](in-game-surfaces.md) — feed channels and hotkey gates
