# Agent Launch and Load Playbook

Read [f7-agent-coordination.md](f7-agent-coordination.md) first. This playbook explains which launch command to use, where a failure belongs, and how to avoid misleading F7 evidence.

## Commands

| Intent | Command | Meaning |
|---|---|---|
| PLAY | `Forge.cmd` or `forge.ps1 -Launch -LaunchIntent play` | New campaign/bootstrap path. |
| CONTINUE | `ForgeContinue.cmd` or `forge.ps1 -Launch -LaunchIntent continue` | Continue-save path through launcher automation. |
| F7 cert smoke | `.\Run-F7GateContinue.cmd -HookMask 0x0F` | Current Agent A rerun path after Agent C hwnd fix. |
| F7 direct script | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x01` | Direct Unicode-safe script path for low-level troubleshooting. |
| Full bisect | `.\scripts\run-agent-a-f7-bisect.ps1` | Full mask loop; do not run concurrently with ForgeContinue. |

Do not use `cmd /c` around bisect runs that inspect ready-line text; corrupted Unicode/em-dash strings can produce false results. The repo wrapper `Run-F7GateContinue.cmd` is acceptable for the current cert rerun because it forwards directly to the BOM-protected PowerShell script.

## Layer A vs Layer B

| Stage | Runs in | Evidence | Owner |
|---|---|---|---|
| Launcher opened/clicked PLAY or CONTINUE | PowerShell / Windows UI automation | `BlacksmithGuild_Launch.log` | Agent B |
| Dialog handling: Module Mismatch, CAUTION, Safe Mode | Launcher/UI automation plus in-game fallback | Launch log and Phase1 log | Agent B |
| Main menu chooses New/Continue | `Bannerlord.exe` mod code | `BlacksmithGuild_Phase1.log` | Agent A if gate run; Agent B if launch routing |
| Save load / map transition | `Bannerlord.exe` | Phase1 + status JSON | Agent A |
| F7 status and 60s stability poll | Gate script and game status | manifest/evidence | Agent A |

## Failure ownership

- No launcher window, no click, stale nav lock: Agent B.
- Game starts but menu intent is wrong: Agent B with Layer B log evidence.
- Map transition crash, status never stabilizes, or 60s poll fails: Agent A.
- Bad grep pattern or em-dash parsing issue: Agent C.
- Docs disagree with this matrix: Coordinator updates `f7-agent-coordination.md` first.

## Ready-line handling

The visual ready line uses an em dash and should come from `Get-TbgReadyGoldenPathPattern`. Scripts must not search for `Blacksmith Guild - Ready` as a grep/log-ready pattern. See [../conventions/em-dashes-and-log-grep.md](../conventions/em-dashes-and-log-grep.md) and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
```

## Log path meanings

| Log | Meaning |
|---|---|
| `BlacksmithGuild_Launch.log` | Launcher/automation audit trail and handoff notes. |
| `BlacksmithGuild_Phase1.log` | In-game mod lifecycle, menu, map-ready, and hook messages. |
| `BlacksmithGuild_Status.json` | Current status snapshot used by F7 and polling. |
| Gate manifest | Terminal gate evidence; required before any PASS claim. |

## When each agent owns the next move

- Agent A owns the next move once CONTINUE is clicked and the run enters load/map/stability polling.
- Agent B owns the next move before the game handoff or when launch routing/dialog automation fails.
- Agent C owns the next move when a script grep, encoding, or stale documentation issue can corrupt the verdict.


## Latest Agent A bisect update

Agent C completed the `0x03` → `0x07` → `0x0F` loop after about 19 minutes with exit code `2` (**game failure, not launch tooling**). `0x07` session `20260622-095957` and `0x0F` session `20260622-101016` both reached `tbg_ready` / MapReady and then failed as game-gone-after-map-ready before the 60s stability window. Launcher automation under `RespectUserForeground` is working; treat the next technical focus as Agent B post-MapReady survival, not hook-mask isolation.
