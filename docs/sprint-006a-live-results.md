# Sprint 006A — Auto Protagonist Build — Live Certification

## Verdict

**Superseded by 006B** for profile targets and mode selection — mechanics unchanged. See [sprint-006b-live-results.md](sprint-006b-live-results.md).

## Scope

Shape `Hero.MainHero` into the **ForgeQuartermasterWarlord** profile (Steward / Crafting / Leadership monster with bottleneck attributes protected). Post-creation `HeroDeveloper` mutations only — no character-creation UI automation, no inventory/gold/crafting changes.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Profile | `DevTools/AutoCharacterBuild/AutoCharacterBuildProfile.cs` | Attribute, focus, and skill floor targets |
| Service | `DevTools/AutoCharacterBuild/AutoCharacterBuildService.cs` | Apply orchestrator, JSON report, F7 section |
| Snapshot | `DevTools/AutoCharacterBuild/CharacterBuildSnapshot.cs` | Before/after capture for report |
| Progression | `DevTools/HeroProgressionDevTools.cs` | `EnsureAttribute`, `EnsureFocus`, `EnsureSkillFloor`, generic `AddSkillXp` |
| Auto hook | `Behaviors/BlacksmithGuildCampaignBehavior.cs` | One-shot apply on **new-game bootstrap only** |
| Command | `ApplyAutoCharacterBuild` | File inbox + risky/mutation gates |
| Config | `DevToolsConfig.AutoApplyCharacterBuild` | Default ON for bootstrap auto-apply |

## Safety rules

| Rule | Detail |
|------|--------|
| Auto-apply | **New-game QuickStart bootstrap only** — NOT Continue/dev-save reload |
| Explicit command | `ApplyAutoCharacterBuild` works on any disposable campaign when map-ready |
| Normal saves | Mod should be **OFF** on personal saves; no save-name API enforcement yet |
| Mutation warning | Bus logs `Use disposable campaign only.` for explicit command |

## Profile: ForgeQuartermasterWarlord

**Attributes:** Intelligence 7, Endurance 7, Social 6, Cunning 3, Vigor 2, Control 2

**Focus:** Steward/Crafting/Leadership 5; Medicine/Engineering/Charm 3; Trade/Athletics/Riding 2; Scouting/Tactics 1

**Skill floors:** Steward/Crafting 75, Leadership 50, Medicine/Engineering/Charm 40, Trade/Athletics/Riding 25

## Live cert protocol

### Path A — explicit command (primary)

1. Close Bannerlord → **`Forge.cmd`**
2. **Continue** → `TBG READY`
3. Run:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command ApplyAutoCharacterBuild -Wait
.\forge.ps1 -Command ShowForgeStatus -Wait
```

4. Press **F7**

### Path B — auto on new game (optional smoke)

1. Temporarily rename dev save so SandBox bootstraps fresh character
2. **Play → SandBox** → auto character creation → `TBG READY`
3. Verify Phase1.log contains `TBG CHARACTER:` without inbox command

## PASS criteria

| Check | Expected |
|-------|----------|
| Build | `dotnet build -c Release` succeeds |
| JSON | `BlacksmithGuild_AutoCharacterBuild.json` exists |
| Profile | `ForgeQuartermasterWarlord`, `applied=true` |
| Core skills | Steward/Crafting ≥ 75, Leadership ≥ 50 (or report explains API block) |
| Bottleneck attrs | Intelligence/Endurance/Social at targets (or report explains) |
| Focus | Steward/Crafting/Leadership focus = 5 |
| Log | Phase1.log `TBG CHARACTER:` line |
| Safety | Continue load did **not** auto-mutate without bootstrap |
| Regression | `RichSmithingProgressionTest` still works |

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
  "profile": "ForgeQuartermasterWarlord",
  "applied": true,
  "trigger": "command|quickstart-bootstrap",
  "before": { "attributes": {}, "focus": {}, "skills": {} },
  "after": { "attributes": {}, "focus": {}, "skills": {} },
  "changes": [],
  "warnings": [],
  "errors": []
}
```

## Known gaps (post-006A)

| Gap | Detail |
|-----|--------|
| **Save-name enforcement** | Documented policy only; no programmatic block on personal saves for explicit command |
| **Skill floor via XP** | May overshoot target level slightly; report shows actual after-values |
| **Attribute budget** | Dev-only unspent-point grants exceed vanilla creation budget |
| **005D live cert** | Deferred — forge ranking unchanged this sprint |
| **005E economics** | Deferred until protagonist loop is certified |
| **No hotkey** | File inbox command only this sprint |

## Risks

| Risk | Mitigation |
|------|------------|
| API drift on `HeroDeveloper` | Per-field try/catch → report errors, partial apply OK |
| Re-run on same hero | Ensure* methods are idempotent (delta-only) |
| Auto on Continue | Bootstrap-only gate + `DevSaveLoadUsed` check |
| Game update breaks skill XP curve | Bounded XP loop with max iterations |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| `applied=false` | Map not ready, MainHero null, or all APIs failed — inspect `errors[]` |
| Skills below floor | XP loop capped — inspect report warnings |
| No auto on new game | Dev save intercepted load; bootstrap flag not set |
| Auto on Continue | Bug — should not happen; check `DevSaveLoadUsed` gate |
| Command BLOCKED | Campaign not map-ready — wait for `TBG READY` |
