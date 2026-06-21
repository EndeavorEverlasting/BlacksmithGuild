# Sprint 008A — Vanilla-Legit Aserai Trade-Smith + Assistive Guild Automation

**Status:** CODE SHIPPED — **USER live cert PENDING** (Path A culture/provenance + blacksmith automation)  
**Branch:** `main`  
**Extends:** [007a Track 1.5](007a-guild-loop-advisory-automation.plan.md)

---

## One-sentence goal

Start a real personal save by visibly choosing Aserai and vanilla upbringing decisions, record the costs/tradeoffs, then run bounded smithing automation using real stamina and materials.

---

## Mode definitions

| Mode | Meaning | Default |
|------|---------|---------|
| **VanillaLegit** | Build via vanilla culture/upbringing menus. No hidden post-map stat injection. | **Yes** |
| **Assistive** | Automation reduces repetitive input; preserves real resources, stamina, time, prices, risk. | **Yes** |
| **DevOverride** | Post-map profile mutation (`ApplyAutoCharacterBuild`). Testing only. | **No** |

**Principle:** Automate the hands, not the consequences.

Config surface: [`DevToolsConfig.cs`](../../src/BlacksmithGuild/DevTools/DevToolsConfig.cs)

---

## Tracks (implementation map)

| Track | Deliverable | Code | USER cert |
|-------|-------------|------|-----------|
| 1 | `BlacksmithGuild_CharacterBuildProvenance.json` | `CharacterBuildProvenanceService.cs` | Path A bootstrap |
| 2 | Aserai culture default + fallback | `CharacterCultureResolver.cs` + `CharacterCreationReflection.cs` | Path A bootstrap |
| 3 | Doctrine-weighted upbringing | `AseraiTradeSmithDecisionMap.cs` | Path A bootstrap |
| 4 | Visible traversal pacing | `CampaignSetupStateTracker.cs` + `DevToolsConfig` | Path A bootstrap |
| 5 | Doctrine JSON + `ShowCharacterDoctrine` | `CharacterDoctrineService.cs` | Read-only OK |
| 6 | Post-map injection off | `AutoCharacterBuildService.TryApplyQuickStartBootstrap` gated | Path A bootstrap |
| 7 | `RunBlacksmithAutomationNow` | `BlacksmithAutomationService.cs` | Continue/disposable map |
| 8 | Stage D read-only | `SmithingRestPlanService.cs` (pre-existing) | Already shipped |
| 9 | Player guide | `docs/player-command-guide.md` | Docs only |

---

## Evidence files

Runtime (Bannerlord install folder):

- `BlacksmithGuild_CharacterBuildProvenance.json`
- `BlacksmithGuild_CharacterDoctrine.json`
- `BlacksmithGuild_BlacksmithAutomation.json`

Export: `.\ExportTbgEvidence.cmd` → `docs/evidence/latest/`

---

## USER cert gates

### Path A — Vanilla-Legit character creation

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

PASS when Phase1 contains:

```text
[TBG QUICKSTART] preferred culture: aserai
[TBG QUICKSTART] culture auto-selected: Aserai (count=N)
[TBG CHARACTER] visible traversal: on pauseMs=750
[TBG CHARACTER] postMapProfileApply skipped: VanillaLegit
```

And **does not** contain:

```text
ForgeQuartermasterWarlord applied=True trigger=quickstart-bootstrap changes=24
```

F7 must show:

```text
mode: VanillaLegit + Assistive
build: AseraiTradeSmith
culture: Aserai
postMapInjection: off
```

Save as `TBGPersonalAserai001`.

### Blacksmith automation

```powershell
.\forge.ps1 -Command RunBlacksmithAutomationNow -Wait
.\ExportTbgEvidence.cmd
```

PASS: refines one charcoal when hardwood exists and charcoal low, **or** blocks cleanly (`BuyMaterialsFirst`, `RestNeeded`, `CraftManual`, `NoSafeAction`).

---

## Known gaps / risks

| Gap | Mitigation |
|-----|------------|
| Aserai menu option IDs vary by game version | Doctrine scores by menu text tags; discovery cert still recommended |
| Upbringing discovery not yet captured in repo | Run Path A once; paste Phase1 narrative lines to `docs/evidence/character-creation-menus/` |
| Visible pacing may slow bootstrap | Set `CharacterCreationVisibleMode = false` in `DevToolsConfig` for regression |
| Safe headless **craft** API not proven | Automation returns `CraftManual` when top candidate exists |
| Stage D rest/time **mutation** not in scope | `RunSmithingRestPlanNow` remains read-only |

---

## DevOverride testing

To re-enable post-map profile apply for disposable testing:

1. Set `DevToolsConfig.LegitimacyMode = DevOverride`
2. Set `DevToolsConfig.AutoApplyCharacterBuild = true`
3. Run `ApplyAutoCharacterBuild` on map (explicit DevOverride command)

Do **not** use DevOverride for personal Aserai Trade-Smith saves.
