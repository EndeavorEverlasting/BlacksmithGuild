# Sprint 004 — Forge Recommendation Model — Live Certification

## Verdict

**LIVE CERT PASS** — 2026-06-18 session (`v0.0.7`, loaded `BlacksmithGuild_DevStart.sav`)

Sprint 004A (ReportFormatter) + 004B (stub recommendation model). Evidence: Phase1.log + JSON + F7 + Status JSON.

## Environment

| Field | Value |
|-------|-------|
| Module | `v0.0.7` |
| Branch | `main` |
| Candidate source | `stub` (stable IDs, no real recipe browser) |
| Default doctrine | `ProfitForge` |
| Dev loop | `Forge.cmd` → load `BlacksmithGuild_DevStart.sav` → `TBG READY` |

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Expanded model | `ForgeCandidate.cs` | `id`, `source`, `netProfit`, `doctrineScore`, `finalScore` |
| Layered scoring | `ForgeAdvisor.cs` | net profit → doctrine layer → final score |
| Stub source | `Forge/StubForgeCandidateSource.cs` | 3 stable fake candidates |
| Service | `Forge/ForgeRecommendationService.cs` | rank, JSON, structured report, F7 cache |
| Dev command | `RankForgeCandidates` | file inbox + dev command bus |
| F7 compact line | `ForgeStatus.cs` | `TBG FORGE: top=... score=... doctrine=... source=stub` |
| JSON evidence | `BlacksmithGuild_ForgeRecommendations.json` | machine-readable ranked list |

## Live retest protocol

1. `Forge.cmd` (game closed) → load dev save → `TBG READY`
2. `.\forge.ps1 -Command RankForgeCandidates -Wait`
3. **F7** — confirm compact forge line + full report sections in Phase1.log
4. Inspect `BlacksmithGuild_ForgeRecommendations.json` and `BlacksmithGuild_Status.json` → `forgeRecommendations` block

## PASS criteria

| Check | Result (2026-06-18) |
|-------|---------------------|
| RankForgeCandidates ACK | Success |
| JSON written | PASS — `BlacksmithGuild_ForgeRecommendations.json` |
| Top candidate (ProfitForge) | PASS — Long Warblade, finalScore **11250** |
| Top 3 order | PASS — Long Warblade → Heavy Glaive Pattern → Officer Sidearm |
| F7 compact line | PASS — `TBG FORGE: top=Long Warblade score=11250 doctrine=ProfitForge source=stub` |
| Phase1.log report | PASS — `TBG REPORT: FORGE RECOMMENDATIONS` |
| Status JSON | PASS — `forgeRecommendations.topCandidateName=Long Warblade` |

## Live cert log excerpts (2026-06-18)

```text
TBG REPORT: FORGE RECOMMENDATIONS
reportId: forge-recommendations-20260618-182326
top: Long Warblade | finalScore: 11250 | source: stub | doctrine: ProfitForge
TBG FORGE: top=Long Warblade score=11250 doctrine=ProfitForge source=stub
```

## Original PASS criteria

## Stub candidate reference scores (ProfitForge)

| ID | Name | netProfit | finalScore |
|----|------|-----------|------------|
| `stub.twohanded.longwarblade` | Long Warblade | 11250 | 11250 |
| `stub.polearm.heavyglaive` | Heavy Glaive Pattern | 9750 | 9750 |
| `stub.onehanded.officersidearm` | Officer Sidearm | 5200 | 5200 |

## Output files to analyze

```text
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Phase1.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Forge.log
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_Status.json
Documents\Mount and Blade II Bannerlord\BlacksmithGuild_ForgeRecommendations.json
```

## Known gaps (post-ship)

| Gap | Detail |
|-----|--------|
| **003B treasury retest** | PARTIAL PASS — machinery proven; strict F10 multi-day + `TreasurySnapshotNow` cert block optional |
| **Real recipe source** | 005C read-only probe shipped; candidate mapping + economics deferred |
| **Doctrine selection** | Dev commands only; no player doctrine UI |
| **005A/005B inbox** | Not run in 2026-06-18 session — optional follow-up |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Command timeout | Campaign not loaded / mod OFF |
| No JSON | Write path blocked or command failed |
| Wrong top score | Doctrine or scoring regression — check `ForgeAdvisor` layers |
| F7 missing forge line | Run `RankForgeCandidates` first (cached read on F7) |
