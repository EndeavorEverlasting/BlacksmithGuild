# Continue Map Crash Bisect — Agent Handoff

**Last updated:** 2026-06-22  
**Branch:** `main`  
**Status:** **FIX SHIPPED — USER VERIFY REQUIRED**

## Problem

Continue load reaches map-ready in Phase1 then process exits before stable F7. Agent shell repro unreliable (focus/Safe Mode).

## What shipped

- `CampaignMapReadyOrchestrator` — immediate F7 flush + deferred heavy hooks + try/catch per hook
- `MapReadyHookFlags` + `TBG_MAP_READY_HOOK_MASK` env bisect
- `GameSessionState.SyncForgeStatus()` — `campaignReady` from `IsCampaignMapReady`

## USER verify

```powershell
git pull origin main
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# F7: campaignReady:true + canPollFileInbox:true ≥60s
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
```

Bisect: `$env:TBG_MAP_READY_HOOK_MASK = "0xEF"` (skip Treasury), `"0xDF"` (skip AutoCharacterBuild), `"0x0F"` (immediate only).

## Parallel

Agent A `feat/006c-4-sell-loop` @ `eddb23e` (rebased on main) — merge after USER confirms stable F7.

Agent C `feat/006c-4b-second-leg-travel` @ `db9c3b7` — **WIP, build FAIL** (missing `ForgeAdvisorSmoke` in enum; rebase onto main before continuing).
