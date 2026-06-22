# PLAY / CONTINUE F7 Gate Sprint — Coordination Log

**Last updated:** 2026-06-22  
**PR:** https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/8  
**Status:** Launcher automation unblocked; post-MapReady survival remains failing.

## Message log

| Time (UTC) | Agent | Update |
|------------|-------|--------|
| 2026-06-22 09:56 | Agent C | `.cmd` bisect path (`run-agent-a-f7-bisect.ps1` via `Run-F7GateContinue.cmd`) exited 1 immediately. All four masks failed before launch because `run-f7-gate-continue.ps1` hit PowerShell parse errors from corrupted em-dash log strings when invoked through the `.cmd` path. |
| 2026-06-22 09:56 | Agent C | Direct PowerShell invocation worked better for mask `0x01`: Continue clicked by SendMessage with Cursor foreground, Safe Mode No handled, MapReady reached, and `[TBG MAPREADY] StatusFlush ok`; Bannerlord then died during the 60s stability poll and the launch-log write race prevented a clean manifest. |
| 2026-06-22 10:15 | Agent C | Masks `0x03` -> `0x07` -> `0x0F` completed after about 19 minutes with exit code 2 for completed masks, indicating game failure rather than launch tooling failure. |

## F7 bisect results

| Mask | Session | Launcher | Gate result |
|------|---------|----------|-------------|
| `0x01` | _no clean manifest_ | `continue_clicked` by SendMessage with Cursor foreground; Safe Mode No; MapReady; `[TBG MAPREADY] StatusFlush ok` | **FAIL** — game died during the 60s stability poll; launch-log write race blocked clean manifest. |
| `0x03` | `20260622-095619` | `continue_clicked` by SendMessage with Cursor foreground | **INCOMPLETE** — exited `-1` roughly 3 minutes in, likely cut off when `0x07` started. |
| `0x07` | `20260622-095957` | `continue_clicked` plus Safe Mode No | **FAIL exit 2** — `tbg_ready` / MapReady reached, then `game=gone-after-map-ready` at about 601s. |
| `0x0F` | `20260622-101016` | `continue_clicked` with Chrome foreground | **FAIL exit 2** — nav timed out at 300s, poll still saw `tbg_ready`, then `fail_game_gone_after_map_ready`. |

## Takeaway

Launcher automation under `RespectUserForeground` is working: Continue and Safe Mode can be driven while Chrome/Cursor owns foreground. All completed runs that reached the F7 gate share the same failure: MapReady is reached, then `Bannerlord.exe` exits before the stability window completes. Hook masks do not appear to isolate the crash, so the next investigation should move to post-MapReady survival rather than additional launcher bisecting.

## Next steps

1. Stop ForgeContinue and release the nav lock before the next attempt.
2. Use direct invocation, not the `.cmd` path:
   ```powershell
   powershell -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01
   ```
3. Avoid `forge-stop.ps1` while the bisect shell is running because it kills matching PowerShell children.
4. Hand off to Agent B for post-MapReady survival investigation; no need to rerun `0x03` unless a clean manifest for that mask is required.
