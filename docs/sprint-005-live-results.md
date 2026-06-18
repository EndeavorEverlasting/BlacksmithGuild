# Sprint 005 — Candidate Source Boundary — Live Certification

## Verdict

**Pending live certification** — code shipped on `main` (`v0.0.7`)

005A: `IForgeCandidateSource`, real scaffold, stub fallback.  
005B: doctrine + source dev commands via file inbox.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Source interface | `Forge/IForgeCandidateSource.cs` | `TryGetCandidates` + `ForgeCandidateSourceKind` |
| Stub oracle | `Forge/StubForgeCandidateSource.cs` | Implements interface; stable test IDs |
| Real scaffold | `Forge/RealForgeCandidateSource.cs` | Campaign guards; returns empty until 005C API work |
| Service | `Forge/ForgeRecommendationService.cs` | Source selection, fallback, doctrine persistence |
| Dev commands | file inbox | `SetForgeCandidateSourceStub/Real`, `SetForgeDoctrine*`, `ShowForgeDoctrine` |

## Live cert protocol

### 005A — stub default

```powershell
Forge.cmd
# Load dev save → TBG READY
.\forge.ps1 -Command RankForgeCandidates -Wait
```

PASS: JSON `sourceKind=Stub`, `source=stub`, top Long Warblade score 11250.

### 005A — real fallback

```powershell
.\forge.ps1 -Command SetForgeCandidateSourceReal -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
```

PASS: JSON `sourceKind=StubFallback`, `fallbackUsed=true`, `source=stub-fallback`; Phase1.log warns real source unavailable; rankings still present.

### 005B — doctrine

```powershell
.\forge.ps1 -Command SetForgeDoctrineRareMetalConservation -Wait
.\forge.ps1 -Command RankForgeCandidates -Wait
.\forge.ps1 -Command ShowForgeDoctrine -Wait
```

PASS: ranking order may shift vs ProfitForge; notice log shows active doctrine.

## Output files

```text
BlacksmithGuild_Phase1.log
BlacksmithGuild_ForgeRecommendations.json
BlacksmithGuild_Status.json
```

## Gates before Sprint 005C (real recipes)

| Gate | Status |
|------|--------|
| 004B live cert | Pending |
| 003B F10 treasury retest | Pending |

## Release hygiene (tracked, not fixed)

- `DevToolsConfig.AutoSkipCharacterCreation = true`
- `DevToolsConfig.HotkeyTraceEnabled = true`
- Review before any shareable release build
