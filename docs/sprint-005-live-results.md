# Sprint 005 — Candidate Source Boundary — Live Certification

## Verdict

**Harness PASS; 005A/005B inbox pending** — code shipped on `main` (`v0.0.7`)

2026-06-18 session: dev harness F7–F11 PASS, Sprint 001 cert 6/6 in Status JSON. Inbox commands for stub-fallback and doctrine were **not run** this session.

005A: `IForgeCandidateSource`, real scaffold, stub fallback.  
005B: doctrine + source dev commands via file inbox.  
005C: read-only recipe API probe (`ProbeForgeRecipes`, `BlacksmithGuild_RecipeProbe.json`).

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Source interface | `Forge/IForgeCandidateSource.cs` | `TryGetCandidates` + `ForgeCandidateSourceKind` |
| Stub oracle | `Forge/StubForgeCandidateSource.cs` | Implements interface; stable test IDs |
| Real scaffold | `Forge/RealForgeCandidateSource.cs` | Campaign guards; delegates to 005C probe |
| Probe service | `Forge/ForgeRecipeProbeService.cs` | Read-only API recon; writes RecipeProbe JSON |
| Service | `Forge/ForgeRecommendationService.cs` | Source selection, fallback, doctrine persistence |
| Dev commands | file inbox | `SetForgeCandidateSourceStub/Real`, `SetForgeDoctrine*`, `ShowForgeDoctrine`, `ProbeForgeRecipes` |

## Live cert protocol

### 005A — stub default

```powershell
Forge.cmd
# Load dev save → TBG READY
.\forge.ps1 -Command RankForgeCandidates -Wait
```

PASS: JSON `sourceKind=Stub`, `source=stub`, top Long Warblade score 11250.

**2026-06-18:** PASS (same session as 004B cert).

### 005A — real fallback

```powershell
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
```

PASS: JSON `sourceKind=StubFallback`, `fallbackUsed=true`, `source=stub-fallback`; Phase1.log warns real source unavailable; rankings still present. RecipeProbe JSON updated.

**2026-06-18:** Not run — optional follow-up.

### 005B — doctrine

```powershell
.\forge.ps1 -Command SetForgeDoctrineRareMetalConservation -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command ShowForgeDoctrine -Wait
```

PASS: ranking order may shift vs ProfitForge; notice log shows active doctrine.

**2026-06-18:** Not run — optional follow-up.

### 005C — recipe probe (read-only)

```powershell
.\forge.ps1 -Command ProbeForgeRecipes -Wait
# F7 — Recipe Probe section + Status JSON recipeProbe block
```

PASS: `BlacksmithGuild_RecipeProbe.json` written; `probeStatus=Ok`; Phase1.log `TBG REPORT: FORGE RECIPE PROBE`; no crash; stub oracle unchanged when ranking with stub source.

## Output files

```text
BlacksmithGuild_Phase1.log
BlacksmithGuild_ForgeRecommendations.json
BlacksmithGuild_RecipeProbe.json
BlacksmithGuild_Status.json
```

## Gates (updated 2026-06-18)

| Gate | Status |
|------|--------|
| 004B live cert | **PASS** |
| Dev harness F7–F11 | **PASS** |
| 003B treasury machinery | **PARTIAL PASS** |
| 005C probe code | **Shipped** — live cert pending after rebuild |

## Release hygiene (tracked, not fixed)

- `DevToolsConfig.AutoSkipCharacterCreation = true`
- `DevToolsConfig.HotkeyTraceEnabled = true`
- Review before any shareable release build
