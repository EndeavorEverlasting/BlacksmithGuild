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

## Agent B sprint repro (2026-06-22 00:50, main @ 0c9f171)

**F7 gate: FAIL (agent shell).** Build PASS. CONTINUE handoff verified **00:50:32**; `launcher=no game=no` from **00:50:45** (~13s after handoff). Phase1 stops at `MapTransition` (**00:50:38–43**); no `[TBG MAPREADY]`, no campaign map ready. Status.json stale: `campaignReady: false`, `canPollFileInbox: false`. Cursor foreground during launch. Evidence: `docs/evidence/live-cert/20260622-004953/`.

**Next step:** USER terminal verify only — agent shell cannot reliably hold game focus. Hook-mask bisect **not applicable** until map-ready is reached.


```powershell
git pull origin main
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\ForgeContinue.cmd
# F7: campaignReady:true + canPollFileInbox:true ≥60s
.\Run-LiveAssistiveCert.cmd -Session continue -SkipLaunch
```

Bisect: `$env:TBG_MAP_READY_HOOK_MASK = "0xEF"` (skip Treasury), `"0xDF"` (skip AutoCharacterBuild), `"0x0F"` (immediate only).

## Obsolete branch

`fix/continue-map-crash-bisect` — deleted from origin (same fix as `main` @ `5839e64`).

## Parallel

Agent A `feat/006c-4-sell-loop` @ `8316b74` (rebased on main) — [PR #5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) draft; merge after USER confirms stable F7.

Agent C `feat/006c-4b-second-leg-travel` @ `5b67d6d` (stacked on `8316b74`) — [PR #6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) draft; Release build **PASS** 2026-06-22.
