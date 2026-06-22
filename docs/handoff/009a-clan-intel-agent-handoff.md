# 009A Clan Intel — Agent Handoff

**Last updated:** 2026-06-21  
**Commit:** `977b445` on `main`  
**Status:** CODE SHIPPED — USER live cert **PENDING**

---

## Doctrine

Court secretary, not social wizard. Read-only intel only. No relation injection, forced marriage, kingdom join, or guild-loop wiring.

---

## Commands → JSON

| Command | Type | Output file |
|---------|------|-------------|
| `AnalyzeClanContext` | Read-only | `BlacksmithGuild_ClanContext.json` |
| `ShowClanContext` | Replay cache | same |
| `AnalyzeNobleNetwork` | Read-only | `BlacksmithGuild_NobleNetwork.json` |
| `ShowNobleNetwork` | Replay cache | same |
| `AnalyzeMarriageCandidates` | Read-only | `BlacksmithGuild_MarriageCandidates.json` |
| `ShowCourtshipPlan` | Read-only aggregate | `BlacksmithGuild_CourtshipPlan.json` |
| `AnalyzeClanRoles` | Read-only | `BlacksmithGuild_ClanRoles.json` |
| `ProbeCourtshipApi` | Read-only probe | `BlacksmithGuild_CourtshipProbe.json` |

Runtime path: Bannerlord install folder (`BasePath.Name`). Mirror: `docs/evidence/latest/` via `ExportTbgEvidence.cmd`.

---

## Code map

`src/BlacksmithGuild/ClanIntel/`

| File | Role |
|------|------|
| `ClanIntelModels.cs` | DTOs + envelope |
| `ClanJsonWriter.cs` | JSON + evidence mirror |
| `ClanIntelDoctrine.cs` | Aserai-aligned scoring weights |
| `ClanContextScanner.cs` / `ClanContextService.cs` | Tier, renown, posture |
| `NobleNetworkScanner.cs` / `NobleNetworkService.cs` | Ranked noble targets |
| `MarriageCandidateScanner.cs` / `MarriageCandidateService.cs` | Spouse candidates |
| `ClanRouteSafetyHelper.cs` | Distance + hostile scan |
| `CourtshipPlanService.cs` | Aggregation + `ClanRoleBoardService` |
| `CourtshipProbeService.cs` | MarriageModel / conversation API probe |

Registration: `DevCommandRegistry.cs`, `DevCommandBus.cs`, `scripts/dev-command-names.ps1`.

---

## USER cert (T1)

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\ForgeContinue.cmd
# F7: campaignReady true, campaign map
.\Run-ClanIntelCert.cmd
.\ExportTbgEvidence.cmd
```

**PASS when:**

- All 6 JSON files exist
- `readOnly: true`, `mutationApplied: false` on each
- Non-empty `verdict` on each
- No C# exceptions in `BlacksmithGuild_Phase1.log`

**T2:** `ProbeCourtshipApi` hints document MarriageModel + conversation methods.  
**T3 (future):** `RunVisibleCourtshipAttemptNow` — not built.

---

## JSON fields to analyze

**ClanContext:** `playerClan`, `socialPriorities[]`, `recommendedActions[]`, `kingdomPosture`  
**NobleNetwork:** `targets[]`, `topTarget` — `strategicValue`, `routeSafety`, `relation`  
**MarriageCandidates:** `candidates[]`, `category`, `warnings` (always includes courtship not certified)  
**CourtshipPlan:** `topCandidate`, `travelPlan`, `certificationGaps[]`  
**ClanRoles:** `roles{}`, `recruitmentGaps[]`  
**CourtshipProbe:** `hints[]` with `available` flags

---

## Known gaps

- `RunVisibleCourtshipAttemptNow` not built
- `courtshipAvailable` always `null`
- Not wired into `RunAutonomousGuildLoopNow`
- `PartySizeLimit` / `WorkshopLimit` via reflection (may be null)
- Marriage eligibility fallback heuristic when `MarriageModel` unavailable
- Governor slot is advisory placeholder
- `AnalyzeKingdomAlignment` standalone deferred (posture in `AnalyzeClanContext`)

---

## Risks

| Risk | Mitigation |
|------|------------|
| MarriageModel API drift | Probe-first; nullable fields |
| False marriage positives | Never `courtshipAvailable: true` without dialogue cert |
| Hero scan performance | `MaxScanDistance` 160 cap |
| Social mutation creep | All commands read-only; no risky gate |

---

## Next sprints

| Target | Depends on |
|--------|------------|
| `RunVisibleCourtshipAttemptNow` | T3 courtship dialogue cert |
| Guild loop clan intel hook | Stable courtship path |
| `AnalyzeClanPartyReadiness` | 007+ cohesion clan-helper work |

---

## Build

```powershell
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
```
