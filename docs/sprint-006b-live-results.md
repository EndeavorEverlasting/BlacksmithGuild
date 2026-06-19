# Sprint 006B — Auto Character Build Profiles — Live Certification

## Verdict

**Code shipped** — live cert pending after game restart + profile command run

## Scope

Turn 006A single hardcoded profile into a **registry-driven mode system** with seven selectable profiles. Default remains **ForgeQuartermasterWarlord** (upgraded attribute ceilings). F7 shows selected/default profiles before apply.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Registry | `DevTools/AutoCharacterBuild/AutoCharacterBuildProfileRegistry.cs` | 7 profiles, selection state, default id |
| Profile model | `AutoCharacterBuildProfile.cs` | Id, DisplayName, Description, ModeKind, IsDefault |
| Service | `AutoCharacterBuildService.cs` | Apply selected profile; Show/Set commands; map-ready notice |
| F7 | `ForgeStatus` + `AppendToReport` | Always shows selected/default/available before apply |
| Commands | `DevCommandRegistry` / `DevCommandBus` | Show x2, Set x7, Apply |

## Profile modes

| Id | Intent | Attribute emphasis |
|----|--------|------------------|
| **ForgeQuartermasterWarlord** (default) | Smithing + logistics + leadership | Int 8, End 8, Social 7 |
| SmithEconomist | Forge-money loop | End 10, Social 7, Int 7 |
| KingdomFounder | Politics and kingdom scaling | Social 9, Int 8, Cunning 5 |
| StewardSurgeonEngineer | Infrastructure and sieges | Int 10, Social 6, End 5 |
| WarCaptain | Battle command skeleton | Social 8, Cunning 8, End 6 |
| LightTouchVanillaPlus | Minimal intervention | Int 6, End 6, Social 5 |
| ShadowTrader | Trade/scouting/roguery skeleton | Social 8, Cunning 7, End 5 |

## Default profile targets (ForgeQuartermasterWarlord)

**Attributes:** Intelligence 8, Endurance 8, Social 7, Cunning 4, Vigor 3, Control 2

**Focus:** Steward/Crafting/Leadership 5; Medicine/Engineering/Charm 3; Trade 3; Athletics/Riding 2; Scouting/Tactics 2

**Skill floors:** Steward/Crafting 100, Leadership 75, Medicine/Engineering/Charm 50, Trade 40, Athletics/Riding 30, Scouting/Tactics 25

## Safety rules

| Rule | Detail |
|------|--------|
| Auto-apply | **New-game QuickStart bootstrap only** — applies **selected** profile |
| Continue | **No auto-apply** — one-shot notice: selected profile + run ApplyAutoCharacterBuild |
| Explicit command | `ApplyAutoCharacterBuild` applies currently selected profile |

## Live cert protocol

```powershell
Close Bannerlord → Forge.cmd → Continue → TBG READY

.\forge.ps1 -Command ShowAutoCharacterBuildProfiles -Wait
.\forge.ps1 -Command ShowAutoCharacterBuildProfile -Wait
# F7 → selected/default/available BEFORE apply

.\forge.ps1 -Command SetAutoCharacterBuildSmithEconomist -Wait
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
# JSON: profileId=SmithEconomist

.\forge.ps1 -Command SetAutoCharacterBuildForgeQuartermasterWarlord -Wait
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
# JSON: upgraded Int 8 / End 8 / Social 7
```

Press **F7** after each phase.

## PASS criteria

| Check | Expected |
|-------|----------|
| Profiles | ShowAutoCharacterBuildProfiles lists all 7 |
| Default | ShowAutoCharacterBuildProfile shows ForgeQuartermasterWarlord |
| F7 pre-apply | selectedProfile, defaultProfile, availableProfiles visible |
| Set | SetAutoCharacterBuildSmithEconomist changes selected |
| Apply | JSON profileId matches selected profile |
| Restore | ForgeQuartermasterWarlord apply uses upgraded targets |
| Safety | Continue did not auto-apply without command |
| Bootstrap | New SandBox may auto-apply selected profile only |

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_AutoCharacterBuild.json
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_Status.json
```

Key JSON fields:

```json
{
  "profileId": "SmithEconomist",
  "profile": "SmithEconomist",
  "profileDescription": "...",
  "selectedProfileAtApply": "SmithEconomist",
  "applied": true,
  "trigger": "command"
}
```

## Known gaps (post-006B)

| Gap | Detail |
|-----|--------|
| **Save-name enforcement** | Documented policy only for personal saves |
| **Profile persistence** | Selection is session-scoped, not saved to campaign |
| **No hotkeys** | File inbox commands only |
| **WarCaptain / ShadowTrader** | Skeleton modes — combat/roguery targets may need tuning |
| **005D / 005E** | Forge economics deferred |

## Risks

| Risk | Mitigation |
|------|------------|
| High attribute totals | Dev-only unspent-point grants |
| Skill XP overshoot | Report shows actual after-values |
| Session profile loss | Re-select after game restart |
| API drift | Per-field errors in JSON report |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| F7 empty profile section | Old DLL — Forge.cmd reinstall |
| Apply uses wrong profile | Run Set command before Apply |
| Auto on Continue | Bug — check DevSaveLoadUsed gate |
| Unknown profile on Set | Typo in command name |
