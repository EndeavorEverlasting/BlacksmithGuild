# Sprint 005C — Recipe API Reconnaissance — Live Certification

## Verdict

**Code shipped** — live cert pending after `Forge.cmd` rebuild + in-game probe run

## Scope

**Read-only reconnaissance only.** Probes Bannerlord crafting/smithing APIs, writes discovery JSON, does **not** craft, mutate inventory, or open smithy UI. Real candidate mapping and economics deferred to a future sprint.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Probe service | `Forge/ForgeRecipeProbeService.cs` | Assembly type scan, known entry points, `CraftingTemplate.All`, `CraftingCampaignBehavior` |
| Probe model | `Forge/ForgeRecipeProbeReport.cs` | JSON + Status summary types |
| Real source wire | `Forge/RealForgeCandidateSource.cs` | Runs probe on real source request; returns empty until economics mapping exists |
| Dev command | `ProbeForgeRecipes` | file inbox + dev command bus |
| F7 section | `ForgeStatus.cs` | Cached `recipeProbe` block in Status JSON |
| Evidence file | `BlacksmithGuild_RecipeProbe.json` | Machine-readable API discovery |

## Live cert protocol

1. Close Bannerlord → `Forge.cmd`
2. Load `BlacksmithGuild_DevStart.sav` → `TBG READY`
3. Run:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command ProbeForgeRecipes -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
```

4. **F7** — confirm Recipe Probe section in report
5. Inspect output files (see below)

## PASS criteria

| Check | Expected |
|-------|----------|
| Build | `dotnet build -c Release` succeeds |
| No crash | Campaign load + map ready + commands |
| ProbeForgeRecipes ACK | Success |
| RecipeProbe JSON | Exists; `probeStatus=Ok`; `templateCount` > 0 |
| Phase1.log | `TBG REPORT: FORGE RECIPE PROBE` with template/type counts |
| Status JSON | `recipeProbe` block populated |
| Stub regression | `RankForgeCandidates` (stub) still Long Warblade 11250 |
| Real fallback | `SetForgeCandidateSourceReal` + rank → `fallbackUsed=true`, probe JSON updated |

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_RecipeProbe.json
  BlacksmithGuild_ForgeRecommendations.json
  BlacksmithGuild_Status.json
```

## Known gaps (post-005C)

| Gap | Detail |
|-----|--------|
| **Candidate mapping** | Probe discovers templates; `ForgeCandidate` economics not computed from game APIs |
| **Real recommendations** | Still stub oracle + fallback for ranked output |
| **005A/005B inbox** | Optional — stub-fallback + doctrine commands not live-certified 2026-06-18 |
| **003B strict retest** | Optional — F10 3–5 days + `TreasurySnapshotNow` |

## Risks

- Bannerlord game updates may rename/move crafting types — probe uses reflection + known type names
- `CraftingTemplate.All` count varies by game version/DLC
- Returning template-only candidates without economics would break scoring — intentionally deferred

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Command timeout | Campaign not loaded / mod OFF |
| No RecipeProbe JSON | Write path blocked or campaign not ready |
| `probeStatus=Unavailable` | Map not ready — wait for `TBG READY` |
| Stub oracle changed | Regression — check `StubForgeCandidateSource` |
