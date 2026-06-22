# Sprint 009A-0 — Clan Context, Noble Network, and Courtship Intel

**Status:** CODE SHIPPED @ `977b445` on `main` — USER live cert PENDING  
**Branch:** `main` (also `feat/009a-clan-intel` tracking same commit)  
**Doctrine:** Read-only court secretary — no relation injection, no forced marriage

## Commands

| Command | Output |
|---------|--------|
| `AnalyzeClanContext` | `BlacksmithGuild_ClanContext.json` |
| `ShowClanContext` | replay cache |
| `AnalyzeNobleNetwork` | `BlacksmithGuild_NobleNetwork.json` |
| `ShowNobleNetwork` | replay cache |
| `AnalyzeMarriageCandidates` | `BlacksmithGuild_MarriageCandidates.json` |
| `ShowCourtshipPlan` | `BlacksmithGuild_CourtshipPlan.json` |
| `AnalyzeClanRoles` | `BlacksmithGuild_ClanRoles.json` |
| `ProbeCourtshipApi` | `BlacksmithGuild_CourtshipProbe.json` |

## USER cert

```powershell
.\ForgeContinue.cmd
.\scripts\run-clan-intel-cert.ps1
.\ExportTbgEvidence.cmd
```

## Code map

`src/BlacksmithGuild/ClanIntel/`
