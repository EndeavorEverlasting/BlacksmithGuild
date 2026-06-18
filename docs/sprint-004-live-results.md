# Sprint 004 — Forge Recommendation Model — Live Certification

## Verdict

**Pending live certification** — code shipped 2026-06-18 (`v0.0.7`)

Sprint 004A (ReportFormatter) + 004B (stub recommendation model) built together. In-game PASS not yet recorded.

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

| Check | Expected |
|-------|----------|
| RankForgeCandidates ACK | Success |
| JSON written | `BlacksmithGuild_ForgeRecommendations.json` with `topCandidate` + `ranked[]` |
| Top candidate (ProfitForge) | Long Warblade, finalScore **11250** |
| Top 3 order | Long Warblade → Heavy Glaive Pattern → Officer Sidearm |
| F7 compact line | `TBG FORGE: top=Long Warblade score=11250 doctrine=ProfitForge source=stub` |
| Phase1.log report | `TBG REPORT: FORGE RECOMMENDATIONS` with `reportId` + Top 3 section |
| Status JSON | `forgeRecommendations.topCandidateName=Long Warblade` |

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
| **003B treasury retest** | Still pending — F10 3–5 days + `TreasurySnapshotNow` |
| **Real recipe source** | Stub only; no Bannerlord crafting API reads |
| **Doctrine selection** | Hard-coded `ProfitForge` in `RunRankNow`; no player doctrine UI |
| **Live cert** | This document — fill PASS/FAIL after in-game run |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Command timeout | Campaign not loaded / mod OFF |
| No JSON | Write path blocked or command failed |
| Wrong top score | Doctrine or scoring regression — check `ForgeAdvisor` layers |
| F7 missing forge line | Run `RankForgeCandidates` first (cached read on F7) |
