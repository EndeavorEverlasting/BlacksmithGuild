# Player Command Guide

**What do I press? What command do I run? What JSON should I look at?**

Evidence export (no screenshots needed):

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\ExportTbgEvidence.cmd
```

Then paste `docs/evidence/latest/README.md` to any AI agent.

---

## Quick reference

| Goal | In-game input | PowerShell command | Output JSON | What it proves |
|------|---------------|-------------------|-------------|----------------|
| Status | **F7** | `.\forge.ps1 -Command ShowForgeStatus -Wait` | `BlacksmithGuild_Status.json` | Mod loaded, map phase, cert state, last command |
| Command list | **F8** (`ListScenarios`) | — (F8 writes surface) | `BlacksmithGuild_CommandSurface.json` | All hotkeys + inbox commands + Stage D exposed |
| Market intel | **Ctrl+Alt+M** | `.\forge.ps1 -Command MarketSnapshotNow -Wait` | `BlacksmithGuild_MarketIntel.json` | Nearest towns, spreads, buy/sell action plan |
| Forge rank | **Ctrl+Alt+R** | `.\forge.ps1 -Command RankForgeCandidates -Wait` | `BlacksmithGuild_ForgeRecommendations.json` | Real/stub source honesty, top craft, material gaps |
| Smithing crew | — | `.\forge.ps1 -Command RunSmithingAdvisoryNow -Wait` | `BlacksmithGuild_SmithingAdvisory.json` | Crew roles, reserves, refine/craft prep |
| Guild loop | **Ctrl+Alt+G** | `.\forge.ps1 -Command RunGuildLoopNow -Wait` | `BlacksmithGuild_GuildLoopReport.json` | Unified market + forge + crew + action plan |
| Stage C refine | — | `.\RunStageCCharcoalCert.cmd` | `BlacksmithGuild_SmithingSafeAction.json` | One headless hardwood→charcoal mutation (Tier 3) |
| Stage D rest plan | — (inbox only) | `.\forge.ps1 -Command RunSmithingRestPlanNow -Wait` | `BlacksmithGuild_SmithingRestPlan.json` | Read-only rest recommendation (no time mutation) |
| Character doctrine | — | `.\forge.ps1 -Command ShowCharacterDoctrine -Wait` | `BlacksmithGuild_CharacterDoctrine.json` | VanillaLegit + Aserai Trade-Smith doctrine |
| Blacksmith automation | — | `.\forge.ps1 -Command RunBlacksmithAutomationNow -Wait` | `BlacksmithGuild_BlacksmithAutomation.json` | One bounded safe action (charcoal refine or clean block) |
| Export evidence | — | `.\ExportTbgEvidence.cmd` | `docs/evidence/latest/README.md` | Repo-local snapshot for agents |

---

## Starting a real Aserai Trade-Smith save

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

- `BlacksmithGuild_CharacterBuildProvenance.json` — upbringing choices + verdict
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
