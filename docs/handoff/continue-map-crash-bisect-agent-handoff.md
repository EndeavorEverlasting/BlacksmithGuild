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

## Agent C F7 bisect update (2026-06-22 09:56–10:16 UTC)

The `.cmd` launch path (`run-agent-a-f7-bisect.ps1` via `Run-F7GateContinue.cmd`) failed before launch for all masks because `run-f7-gate-continue.ps1` hit PowerShell parse errors from corrupted em-dash log strings when invoked through the `.cmd` path. Direct PowerShell invocation is the valid path for the next run:

```powershell
powershell -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01
```

| Mask | Session | Launcher | Gate result |
|------|---------|----------|-------------|
| `0x01` | _no clean manifest_ | `continue_clicked` by SendMessage with Cursor foreground; Safe Mode No; MapReady; `[TBG MAPREADY] StatusFlush ok` | **FAIL** — game died during the 60s stability poll; launch-log write race blocked clean manifest. |
| `0x03` | `20260622-095619` | `continue_clicked` by SendMessage with Cursor foreground | **INCOMPLETE** — exited `-1` roughly 3 minutes in, likely cut off when `0x07` started. |
| `0x07` | `20260622-095957` | `continue_clicked` plus Safe Mode No | **FAIL exit 2** — `tbg_ready` / MapReady reached, then `game=gone-after-map-ready` at about 601s. |
| `0x0F` | `20260622-101016` | `continue_clicked` with Chrome foreground | **FAIL exit 2** — nav timed out at 300s, poll still saw `tbg_ready`, then `fail_game_gone_after_map_ready`. |

**Takeaway:** launcher automation under `RespectUserForeground` is working. Continue and Safe Mode are driven successfully even with Chrome/Cursor foreground. All completed masks that reached the F7 gate hit the same post-MapReady failure: `Bannerlord.exe` exits before the stability window completes. The hook mask does not appear to isolate the crash; hand off to Agent B for post-MapReady survival analysis. Avoid `forge-stop.ps1` while the bisect shell is running because it kills matching PowerShell children.

Evidence manifests:

- `docs/evidence/live-cert/20260622-095957/checkpoint-01-f7-gate/manifest.json`
- `docs/evidence/live-cert/20260622-101016/checkpoint-01-f7-gate/manifest.json`
- `docs/evidence/live-cert/f7-bisect-summary.json`
