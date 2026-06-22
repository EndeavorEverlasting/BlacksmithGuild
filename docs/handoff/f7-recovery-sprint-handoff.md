# F7 Recovery Sprint Handoff

Start with [f7-agent-coordination.md](f7-agent-coordination.md), then use [agent-launch-and-load-playbook.md](agent-launch-and-load-playbook.md) for PLAY vs CONTINUE and Layer A/B ownership.

Current verdict: **RED**. F7/Continue does not yet have stable campaign-map evidence. Recent partial progress: hook mask `0x01` reached MapReady and `[TBG MAPREADY] StatusFlush ok`, then died during the 60s stability poll.

Canonical next bisect:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01
```

Avoid `cmd /c` and `.cmd` wrappers during this bisect, and do not run `forge-stop.ps1` while a bisect child is active.


## Latest Agent A bisect result

Agent C completed the `0x03` → `0x07` → `0x0F` loop after about 19 minutes with exit code `2`. `0x03` session `20260622-095619` was incomplete after an apparent cutoff. `0x07` session `20260622-095957` reached `tbg_ready` / MapReady and then failed as `game=gone-after-map-ready`. `0x0F` session `20260622-101016` also saw `tbg_ready` after launcher nav timeout and failed as `fail_game_gone_after_map_ready`. The gate remains **RED** and this now points to post-MapReady survival rather than hook-mask isolation.
