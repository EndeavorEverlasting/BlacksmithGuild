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

## Agent shell repro (2026-06-22 00:32, main @ 7461235)

**F7 gate: FAIL.** Process died ~4s after `MainMenu -> MapTransition`; never reached map-ready (`[TBG MAPREADY]` absent). Last Phase1 line: intro blocked (`not skippable video state`). ForgeContinue launcher timed out 267s after process vanish.

**Implication:** orchestrator fix targets post-map-ready hooks; this repro dies earlier — bisect may need QuickStart/intro path or USER terminal verify (agent focus unreliable; Cursor stole foreground @ 00:32:17).


```powershell
git pull origin main
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# F7: campaignReady:true + canPollFileInbox:true ≥60s
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
```

Bisect: `$env:TBG_MAP_READY_HOOK_MASK = "0xEF"` (skip Treasury), `"0xDF"` (skip AutoCharacterBuild), `"0x0F"` (immediate only).

## Obsolete branch

`fix/continue-map-crash-bisect` — same fix as `main` (`5839e64`); safe to delete from origin after doc sync.

## Parallel

Agent A `feat/006c-4-sell-loop` @ `eddb23e` (rebased on main) — [PR #5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) draft; merge after USER confirms stable F7.

Agent C `feat/006c-4b-second-leg-travel` @ `e45691a` (rebased on `eddb23e`) — [PR #6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) draft; Release build **PASS** 2026-06-22.
