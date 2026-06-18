# Sprint 005D — Real Forge Candidates — Live Certification

## Verdict

**Code shipped** (`36f309b` + QuickStart `cf257a9`) — live cert pending after game restart + rank run

## Scope

Map `CraftingTemplate.All` into ranked `ForgeCandidate` entries with read-only economics. Stub oracle unchanged as regression baseline. No crafting, inventory mutation, or smithy UI.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Economics | `Forge/ForgeRecipeEconomics.cs` | SmithingModel material costs when design builds; heuristic fallback |
| Mapper | `Forge/ForgeRealCandidateMapper.cs` | `CraftingTemplate.All` → `real.template.*` candidates (cap 100) |
| Real source | `Forge/RealForgeCandidateSource.cs` | Probe + map; stub fallback when empty |
| Report | `Forge/ForgeRecommendationService.cs` | JSON/F7: `economicsMode`, `templateCount`, `mappedCount` |
| Reference | `BlacksmithGuild.csproj` | `TaleWorlds.Localization` for template names |

## Live cert protocol

1. Close Bannerlord → **`Forge.cmd`** (build + install + launcher)
2. **Continue** (dev save pinned) or **Play → SandBox** (auto-load / auto-character) → `TBG READY`
3. Run:

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
```

4. **F7** — Forge Recommendations: `source=real`, `fallbackUsed=false`, real template names
5. Stub regression:

```powershell
.\forge.ps1 -Command SetForgeCandidateSourceStub -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
```

Expect top **Long Warblade** score **11250**.

## PASS criteria

| Check | Expected |
|-------|----------|
| Build | `dotnet build -c Release` succeeds |
| Real rank | `source=real`, `sourceKind=Real`, `fallbackUsed=false`, `ranked` > 0 |
| Names | Top entries use `real.template.*` IDs, not `stub.*` |
| Economics | JSON includes `economicsMode` (`exact`, `heuristic`, or `mixed`) |
| Template parity | `templateCount` in recommendations JSON ≈ probe `templateCount` |
| Stub regression | `source=stub`, Long Warblade 11250 |
| Phase1.log | `TBG REPORT: FORGE RECOMMENDATIONS` with real source metadata |
| No crash | Map ready; no craft/inventory mutation |

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_Phase1.log
  BlacksmithGuild_ForgeRecommendations.json
  BlacksmithGuild_RecipeProbe.json
  BlacksmithGuild_Status.json
```

Key JSON fields (`BlacksmithGuild_ForgeRecommendations.json`):

```json
{
  "source": "real",
  "sourceKind": "Real",
  "fallbackUsed": false,
  "economicsMode": "exact|heuristic|mixed",
  "templateCount": 0,
  "mappedCount": 0,
  "ranked": [ { "id": "real.template.*", "source": "real" } ]
}
```

## Known gaps (post-005D)

| Gap | Detail |
|-----|--------|
| **Sale value parity** | Value uses material-cost markup + stats/difficulty; not full `ItemObject.Value` from generated weapons |
| **Crafting orders** | Order prices not folded into economics (005E) |
| **Doctrine on real set** | Doctrine scoring works; real-candidate tuning deferred to 005E |
| **Template cap** | Mapper capped at 100 templates for perf |
| **QuickStart** | **Shipped** (`cf257a9`) — live cert pending — [docs/sprint-003c-live-results.md](docs/sprint-003c-live-results.md) |
| **005A/005B inbox cert** | Optional |

## Risks

| Risk | Mitigation |
|------|------------|
| Economics API incomplete | `economicsMode=heuristic` + rank order still useful |
| Skill gate too aggressive | Slack +25 over smithing skill; unreadable gate includes all |
| Game update breaks types | 005C probe JSON catches drift |
| Bad ranks vs player intuition | 005D is v1 math; tune in 005E |
| Bannerlord running during build | `BlacksmithGuild_PendingReload.json` — close game, re-run `Forge.cmd` |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| `fallbackUsed=true` | Mapper returned 0 — check probe `templateCount`, Phase1.log map detail |
| All `stub.*` IDs | Source still stub — run `SetForgeCandidateSourceReal` first |
| `economicsMode=heuristic` only | Default designs failed — acceptable v1; inspect template build orders |
| Command timeout | Campaign not loaded / mod OFF |
| Install blocked | Close Bannerlord, run `Forge.cmd` again |
