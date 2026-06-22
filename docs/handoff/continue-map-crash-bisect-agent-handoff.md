# Continue Map Crash Bisect — Agent Handoff

**Last updated:** 2026-06-22  
**Branch:** `fix/f7-gate-stability` @ `376fb3c` — [PR #7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) → `main`  
**Status:** **Post-MapReady C# hardening in progress on `fix/f7-post-mapready-csharp-hardening` — USER F7 PASS required**

## Problem

Continue load crash chain on F7 Continue gate. USER path (@ `80ffa31`) now reaches **MapReady** then dies ~2s later (no `[TBG MAPREADY]`). Agent shell cannot validate — stuck at MapTransition when Cursor steals refocus.

## What shipped

| Area | Change |
|------|--------|
| **Scripts** | `Run-F7GateContinue.cmd` + `run-f7-gate-continue.ps1`; refocus in launcher-auto-nav + run-live-assistive-cert |
| **Safe Mode trail** | Launch log + F7 manifest `launchSignals.priorSessionCrashLikely` + `mapReadyHookMask` |
| **C# load gates** | `IsMapLoadTransitionWindow`; `CanPollHelpHotkeys` map/settlement only |
| **376fb3c** | `ImmediateHooksCompleted` + SubModule hotkey poll gate (fixes MapReady tick race) |
| **Agent B C# hardening** (`fix/f7-post-mapready-csharp-hardening`) | Entry/begin/ok/failed MAPREADY logs; 2-tick deferred delay; orchestrator runs before transition-window downstream gate; strict hotkey poll gate |

## F7 gate results

| Session | Verdict | Who | Phase1 last | Notes |
|---------|---------|-----|-------------|-------|
| `20260622-013214` | FAIL | **USER** | MapReady @ 01:33:23 | ~2s crash; no MAPREADY (pre-376fb3c) |
| `20260622-015132` | FAIL | Agent | MapReady @ 01:52:19 | **376fb3c** mask 0x0F: no hotkey trace (gate OK), no MAPREADY — interrupted |
| `20260622-011418` | FAIL | Agent | MapTransition @ 01:15:02 | Safe Mode chain |

Best USER repro: `docs/evidence/live-cert/20260622-013214/checkpoint-01-f7-gate/`  
Post-gate agent: `docs/evidence/live-cert/20260622-015132/` — see [f7-golden-path-diff-agent-handoff.md](f7-golden-path-diff-agent-handoff.md)

## Next step — USER terminal (required)

```powershell
git checkout fix/f7-gate-stability && git pull   # expect 376fb3c
$env:TBG_MAP_READY_HOOK_MASK = "0x0F"
dotnet build src/BlacksmithGuild/BlacksmithGuild.csproj -c Release
.\Run-F7GateContinue.cmd
# Minimize Cursor + PowerShell once game appears
```

If still fails after MapReady: try `0x1DF`, `0x1BF`, `0x00`. See `docs/handoff/f7-gate-cert-marathon-agent-handoff.md`.

## Parallel

- [PR #7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) — merge to `main` after USER F7 PASS  
- [PR #5](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/5) / [#6](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/6) — merge after F7 on main  

Do **not** merge #5/#6 until F7 stable on main.
