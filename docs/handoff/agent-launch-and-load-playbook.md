# Agent Launch and Load Playbook

Read [f7-agent-coordination.md](f7-agent-coordination.md) first. This playbook explains which launch command to use, where a failure belongs, and how to avoid misleading F7 evidence.

Related: [em-dashes-and-log-grep.md](../conventions/em-dashes-and-log-grep.md) · [launcher-foreground-doctrine.md](../conventions/launcher-foreground-doctrine.md) · [f7-recovery-sprint-handoff.md](f7-recovery-sprint-handoff.md)

---

## F7 invocation doctrine

**Primary (agents / bisect / automation / grep-sensitive):**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F
```

**Wrapper (secondary — convenience only):**

```powershell
.\Run-F7GateContinue.cmd -HookMask 0x0F
```

`Run-F7GateContinue.cmd` is a thin forwarder to the same PowerShell script (`%*` passthrough, `-NoProfile`). Agent C landed fail-closed manifest gating @ `325aacd`; agents should still prefer direct PowerShell for bisect and cert to avoid extra `cmd /c` nesting.

**Never:**

- `cmd /c` around bisect runs that inspect ready-line text
- Nested quoting through cmd for Unicode-sensitive grep patterns
- Concurrent `ForgeContinue` and F7 gate runs

**Before F7 work**, run the grep guard:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-log-grep-patterns.ps1
```

---

## Commands

| Intent | Command | Meaning |
|--------|---------|---------|
| PLAY | `Forge.cmd` or `forge.ps1 -Launch -LaunchIntent play` | New campaign/bootstrap path. |
| CONTINUE | `ForgeContinue.cmd` or `forge.ps1 -Launch -LaunchIntent continue` | Continue-save path through launcher automation. |
| F7 gate / bisect | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F` | **Agent-primary** F7 cert path. |
| F7 wrapper | `.\Run-F7GateContinue.cmd -HookMask 0x0F` | Same gate; thin `.cmd` forwarder. |
| Full bisect | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-agent-a-f7-bisect.ps1` | Full mask loop; do not run concurrently with `ForgeContinue`. |

Do not invoke `launcher-auto-nav.ps1` bare — it requires `-LaunchIntent` and `-BannerlordRoot`. Use `Run-LauncherNavNow.cmd`, `Run-LauncherNavPlay.cmd`, or `ForgeContinue.cmd`.

---

## Layer A vs Layer B

| Stage | Runs in | Evidence | Owner |
|-------|---------|----------|-------|
| Launcher opened/clicked PLAY or CONTINUE | PowerShell / Windows UI automation | `BlacksmithGuild_Launch.log` | Agent C |
| Dialog handling: Module Mismatch, CAUTION, Safe Mode | Launcher/UI automation plus in-game fallback | Launch log and Phase1 log | Agent C |
| Main menu chooses New/Continue | `Bannerlord.exe` mod code | `BlacksmithGuild_Phase1.log` | Agent A if gate run; Agent C if launch routing |
| Save load / map transition | `Bannerlord.exe` | Phase1 + status JSON | Agent A |
| F7 status and 60s stability poll | Gate script and game status | manifest/evidence | Agent A |

---

## Failure ownership

- No launcher window, no click, stale nav lock: **Agent C**.
- Game starts but menu intent is wrong: **Agent C** with Layer B log evidence.
- Map transition crash, status never stabilizes, or 60s poll fails: **Agent A**.
- Bad grep pattern or em-dash parsing issue: **Agent B** (`verify-log-grep-patterns.ps1`, em-dash docs).
- Docs disagree with this matrix: update `f7-agent-coordination.md` first.

---

## Ready-line handling

The canonical C# ready line uses an em dash:

```text
Blacksmith Guild — Ready:
```

(U+2014 — not ASCII `-`.)

Scripts must not search for `Blacksmith Guild - Ready` or `Blacksmith Guild - Ready:` as a grep/log-ready pattern. Use `Get-TbgReadyGoldenPathPattern` or `Test-Phase1ReadyLine` from [`scripts/bannerlord-paths.ps1`](../../scripts/bannerlord-paths.ps1).

`TBG READY` is **legacy shorthand only** — acceptable in old logs and dev prefixes, but new automation should match the em-dash `ModDisplay` line above.

See [em-dashes-and-log-grep.md](../conventions/em-dashes-and-log-grep.md).

---

## Log path meanings

| Log | Meaning |
|-----|---------|
| `BlacksmithGuild_Launch.log` | Launcher/automation audit trail and handoff notes. |
| `BlacksmithGuild_Phase1.log` | In-game mod lifecycle, menu, map-ready, and hook messages. |
| `BlacksmithGuild_Status.json` | Current status snapshot used by F7 and polling. |
| Gate manifest | Terminal gate evidence at `docs/evidence/live-cert/<sessionId>/checkpoint-01-f7-gate/manifest.json`; required before any PASS claim. |

---

## When each agent owns the next move

- **Agent A** owns the next move once CONTINUE is clicked and the run enters load/map/stability polling.
- **Agent C** owns the next move before the game handoff or when launch routing/dialog automation fails.
- **Agent B** owns grep guard, em-dash docs, and launch-language consistency — not runner behavior or F7 cert execution.
