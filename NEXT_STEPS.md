# Next Steps

## Phase 1A: Confirm skeleton (current)

Pass condition:

- Game launches
- Mod appears in launcher as **The Blacksmith Guild**
- Campaign loads
- In-game BlacksmithGuild messages appear
- Log file `BlacksmithGuild_Phase1.log` is written
- No crash

## Phase 1B: Manual real candidate ranker (v0.1.1)

After Phase 1A passes:

- Bump `Version` in `Module/BlacksmithGuild/SubModule.xml` to `v0.1.1`
- Replace fake candidates in `SubModule.cs` with hard-coded **real** weapon rows from manual forge testing

Fields per candidate:

- `WeaponClass`
- `DesignName`
- `EstimatedValue`
- `EstimatedMaterialCost`
- `RareMaterialPenalty`

Scoring (unchanged):

```text
Score = EstimatedValue - EstimatedMaterialCost - RareMaterialPenalty + DoctrineBonus
```

Still no Harmony, no automation, no smithing API enumeration.

Branch: `feature/phase-1b-manual-candidates` off `main`.

## Phase 1C: Read current selected forge design

Find Bannerlord classes/methods for:

- current crafting template
- selected crafting pieces
- material requirements
- weapon design value

Likely starting points:

- `TaleWorlds.Core.Crafting`
- `TaleWorlds.Core.WeaponDesign`
- `TaleWorlds.CampaignSystem.SandBox.GameComponents.Map.DefaultSmithingModel`

## Do not start with full auto-generation

The search space is too large. First rank known candidates, then selected design, then saved designs, then combinations.

Math before hammer.
