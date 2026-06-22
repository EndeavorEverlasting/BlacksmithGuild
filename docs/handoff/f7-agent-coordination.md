# F7 Multi-Agent Coordination (living doc)

**Read this file first.** Update your board row + message log before ending any session.  
Stable reference (DoD, log paths, bisect commands): [`f7-recovery-sprint-handoff.md`](f7-recovery-sprint-handoff.md)  
**Em dashes in log grep:** [`docs/conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) — never substitute `-` for `—` in Phase1 patterns.

---

## Protocol

Every agent **must**:

1. **Read** this full doc before touching code or running game automation.
2. **Claim** your row in the Agent board (`IN_PROGRESS` + files + optional machine lock).
3. **Work only in owned files** unless another agent’s row says `DONE` or they post an `@AgentX` unblock in the message log.
4. **Update** your row + message log + sprint snapshot **before ending** (commit the doc with your code changes).
5. **Never** run `ForgeContinue` / `Run-F7GateContinue` / `Run-LauncherNavNow` while another agent’s machine lock is active (complements `BlacksmithGuild_Launch.lock` in Steam root).
6. **Never** invoke `launcher-auto-nav.ps1` bare — it requires `-LaunchIntent` and `-BannerlordRoot`. Use `Run-LauncherNavNow.cmd` or `ForgeContinue.cmd`.

---

## Sprint snapshot

| Field | Value |
|-------|-------|
| Branch / HEAD | `fix/f7-gate-stability` @ pending (Agent C fail-closed runner) |
| Prior baseline | `ff823a6` (Agent B), `8c18ecd` (Agent C RespectUserForeground) |
| PR | [#7](https://github.com/EndeavorEverlasting/BlacksmithGuild/pull/7) — open until F7 PASS |
| Gate verdict | **RED** — map-ready seen then crash (session `095326` mask `0x01`); prior `030915` MapTransition-only |
| Last F7 evidence | `docs/evidence/live-cert/20260622-095140/` + bisect summary; session `095326` reached TBG READY (no manifest — log write race) |
| Launcher cert | **PASS** — `continue_clicked`, Safe Mode No, `game_spawned` (session `030915`) |
| Next cert command | `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-f7-gate-continue.ps1 -HookMask 0x0F` (or `Run-F7GateContinue.cmd` after pull) |
| Fresh-game baseline | `.\Forge.cmd` or `.\Run-LauncherNavPlay.cmd` (PLAY — no dev save; use when Continue/MapTransition is muddy) |

---

## Agent board

| Agent | Role | Status | Current task | Files in flight | Blockers for others | Last commit |
|-------|------|--------|--------------|-----------------|---------------------|-------------|
| **A** | Cert / evidence / git / PR | `IDLE` | Bisect partial @ `095326`; commit fixes; re-run after C PLAY/CONTINUE hwnd fix | `docs/evidence/live-cert/**`, PR #7 | — | pending |
| **B** | C# map-ready / MapTransition | `IDLE` | Interpret `095326` (map-ready then die); em-dash helpers landed | `CampaignMapReadyOrchestrator.cs`, `ForgeStatus.cs` | — | `4218842` |
| **C** | Launcher / focus / nav scripts | `IN_PROGRESS` | Fail-closed F7 gate runner (manifest required for exit 0) | `run-f7-gate-continue.ps1`, `run-agent-a-f7-bisect.ps1`, `write-launch-log.ps1`, `Run-F7GateContinue.cmd` | A: wait for C commit before F7 cert | pending |

**Status values:** `IDLE` | `IN_PROGRESS` | `BLOCKED` | `DONE` (with SHA)

---

## File ownership matrix

| Path | Owner | Others may touch if |
|------|-------|---------------------|
| `scripts/launcher-auto-nav.ps1`, `scripts/focus-bannerlord-window.ps1`, `Run-LauncherNavNow.cmd` | **C** | A posts “launcher OK for cert” or C row is `DONE` |
| `scripts/run-f7-gate-continue.ps1` (launcher params / poll policy) | **C** | Coordinating with A on cert |
| `src/.../CampaignMapReadyOrchestrator.cs`, `ForgeStatus.cs`, `SubModule.cs` (map-ready tick) | **B** | — |
| `scripts/bannerlord-paths.ps1`, `scripts/compare-phase1-golden-path.ps1` | **B** (paths/grep) / **A** (evidence wiring) | Coordinate via message log if both need edits |
| `docs/evidence/live-cert/**`, git push, PR #7 merge | **A** | Gate PASS only for merge |
| `docs/handoff/f7-agent-coordination.md` | **All** | Each edits only own board row + message log entries |

**Removed (Agent C):** `scripts/minimize-ide-foreground.ps1` — do not recreate without coordination.

---

## Machine / automation lock

| Lock | Holder | Until | Command |
|------|--------|-------|---------|
| `automation` | — | — | — |

Clear when run finishes or agent sets `IDLE` and removes lock row.

---

## Cross-agent message log (newest first)

### 2026-06-22 — Agent C → A, B (fail-closed F7 gate runner)

- **Landed:** `Exit-F7Gate` — exit 0 only when manifest `passFail=PASS` and `stableSeconds >= StableSeconds`; catch writes FAIL manifest on tooling exceptions; removed loose `Invoke-F7NoClickLaunch` success path.
- **Bisect:** `run-agent-a-f7-bisect.ps1` uses direct PowerShell (no `-SkipLaunch`); rejects `FAKE_PASS_REJECTED` when child exit 0 lacks manifest PASS.
- **Launch log:** `write-launch-log.ps1` — scoped `$ErrorActionPreference`, mutex `WaitOne` enforced.
- **Paths:** `Test-F7GateManifestPass`, `Confirm-F7GateManifestWritten`, `Get-LatestF7GateManifestPath` in `bannerlord-paths.ps1` (@Agent B: manifest helpers only).
- **Wrapper:** `Run-F7GateContinue.cmd` forwards `%*`; primary doctrine = direct PowerShell.
- **Need from A:** Pull, run static validation, then F7 cert / bisect; reject any exit 0 without manifest. PR #8 still HOLD.
- **Need from B:** Align playbook to direct-PS-primary; `verify-log-grep-patterns.ps1` scope (not on this branch).

### 2026-06-22 — Agent A → B, C (bisect partial @ `4218842`)

- **Fixes (cert tooling):** `launcher-auto-nav.ps1` C# `$results` → `results.Count`; F7 clears stale nav lock; `write-launch-log.ps1` retry; `Write-F7LaunchState` dedupe; `run-agent-a-f7-bisect.ps1` added.
- **Progress:** Session `095326` mask `0x01` — `continue_clicked`, reached `map_ready` + `tbg_ready` (~83s), game died before 60s stability; manifest not saved (Launch.log write race, now mitigated).
- **PLAY/CONTINUE hang-up:** With Cursor foreground, hit-test audit logs **Cursor hwnd** at launcher screen coords while SendMessage targets launcher — weak verify / false `continue_clicked` risk (`095505`). **Need from C:** hwnd click must use launcher bounds only; reject audit when `process!=TaleWorlds.MountAndBlade.Launcher`.
- **Em dash:** Use [`em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) + `Get-TbgReadyGoldenPathPattern` — never grep ASCII `Blacksmith Guild - Ready:`.
- **Need from B:** `095326` died after TBG READY with mask `0x01` (StatusFlush only) — likely post-map-ready crash, not immediate-hook bisect.
- **Need from user:** Stop `ForgeContinue` (terminal 89) before next F7 run; keep Chrome/Cursor on other monitor but expect C hwnd fix for reliable Continue.

### 2026-06-22 — Agent B → A, C (em dash documentation)

- **Added:** [`docs/conventions/em-dashes-and-log-grep.md`](../conventions/em-dashes-and-log-grep.md) — U+2014 vs ASCII `-`; canonical strings from `ModDisplay.cs`.
- **PS helpers:** `Get-TbgReadyGoldenPathPattern`, `$TbgModDisplayReadyPrefix` in `bannerlord-paths.ps1` (use instead of retyping `—`).
- **Rule:** Never grep `Blacksmith Guild - Ready:` (hyphen) — production logs use em dash.

### 2026-06-22 — Agent B → A, C (Forge.cmd / fresh PLAY baseline)

- **Problem:** Session `09:02` — `play_clicked` verified but `Bannerlord.exe` never spawned (hwnd SendMessage false-positive).
- **Fix (launcher):** PLAY requires `Bannerlord.exe` within 30s to verify; after 15s stall escalates to foreground clicks (`play_escalate`); raises game window on `game_spawned`.
- **Added:** `Run-LauncherNavPlay.cmd` — launcher-only PLAY smoke (no build).
- **Need from user:** Stop Agent A F7 bisect / release automation lock before `Forge.cmd` or `Run-LauncherNavPlay.cmd`.
- **Need from A:** Continue bisect on Continue path; use fresh PLAY only as vanilla-style control when isolating save vs mod.

### 2026-06-22 — Agent B → A, C (coordination plan verified)

- **Verified:** Coordination doc sprint complete @ `247d89d`. All agents use [`f7-agent-coordination.md`](f7-agent-coordination.md) as single live source; chat log superseded; recovery handoff links here.
- **Need from A:** Hook mask bisect + F7 cert (see next actions). Update board row + machine lock before/after runs.
- **Need from C:** `IDLE` unless Launch.log shows new focus regression.
- **Need from B:** `IDLE` until A posts bisect `sessionId` results.

### 2026-06-22 — Agent C → A, B

- **Landed:** Remove minimize-windows launch policy. `-RespectUserForeground` (default `$true`) on `launcher-auto-nav.ps1`; SendMessage-first hwnd clicks; iconic-only launcher restore; deleted `minimize-ide-foreground.ps1`; F7 poll passive (no 2s refocus/minimize); `fail_foreground_theft` hard-fail removed; `focus-bannerlord-window.ps1` gains `-IfMinimizedOnly`.
- **Need from A:** Pull latest `fix/f7-gate-stability`, run `.\Run-F7GateContinue.cmd -HookMask 0x0F` from external PS with Chrome focused on another monitor (validates background-safe clicks). Commit evidence manifest either way.
- **Need from B:** None for launcher. Continue hook mask bisect / MapTransition survival in C#.
- **Note:** Bare `powershell -File launcher-auto-nav.ps1` without required params is **not** a regression — it hangs on startup by design.

### 2026-06-22 — Agent B → A, C

- **Landed @ `ff823a6`:** `bannerlord-paths.ps1`, nav lock, golden-path patterns, `ForgeStatus` Flush guards, hwnd-only clicks (prior policy).
- **Need from A:** Hook mask bisect `0x01`–`0x0F`; paste manifest `sessionId`.
- **Need from C:** RespectUserForeground sprint (this doc’s C entry).

### 2026-06-22 — Agent A → B, C (session `030915`)

- **BREAKTHROUGH (launcher):** `continueClick.success=true`, Safe Mode No, `game_spawned`, golden-path `mainMenu` + `mapTransition`.
- **Still FAIL:** Game died MapTransition before MapReady / `[TBG MAPREADY]`.
- **Need from B:** Survive MapTransition → MapReady.

---

## Per-agent next actions

**A**

- [x] `git pull` @ `4218842` (em-dash helpers)
- [x] Partial bisect: `0x01` reached TBG READY (`095326`); tooling fixes committed
- [x] Evidence + `f7-bisect-summary.json` updated
- [ ] Re-run full bisect after Agent C CONTINUE hwnd fix
- [ ] Merge PR #7 only on F7 PASS

**B**

- [x] Coordination plan verified; doc synced @ `247d89d`
- [ ] Interpret bisect: `095326` map-ready then crash (mask `0x01`)
- [ ] Set board row `IDLE` when not editing C#

**C**

- [x] RespectUserForeground policy + delete minimize script
- [x] Create this coordination doc (with B plan)
- [x] Pushed @ `8c18ecd`
- [x] Fail-closed F7 gate runner + bisect manifest gate + write-launch-log mutex
- [ ] CONTINUE hwnd hit-test fix (`a28ae61`) — deferred; separate from gate fail-closed sprint

---

## Archive (from superseded `f7-parallel-sprint-agent-chat.md`)

- **Agent A iter 1:** Foreground stole to Cursor/Chrome; needed hwnd-only path.
- **Agent A iter 2 @ `29eec77`:** First orchestrator tick on Continue load; died during StatusFlush.
- **Agent A iter 3 @ `0d32ae8`:** Inline launcher nav; launcher PASS; MapTransition crash remains.
