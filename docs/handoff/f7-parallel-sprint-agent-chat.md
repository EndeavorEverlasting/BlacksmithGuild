# F7 Parallel Sprint — Agent Chat Log

**Branch:** `fix/f7-gate-stability`  
**Goal:** Autonomous Continue → map traversal → `[TBG MAPREADY]` + F7 PASS (no user clicks)

| Agent | Owns |
|-------|------|
| **A** | F7 bisect runs, evidence, cert after PASS, launcher iteration triggers |
| **B** | `CampaignMapReadyOrchestrator`, `GameSessionState`, map-ready hook bisect fixes |
| **C** | `launcher-auto-nav.ps1`, focus theft, Safe Mode / CONTINUE no-click |

---

## 2026-06-22 — Agent A (iteration 1)

**Observed:** `ForgeContinue.cmd` times out 267s. CONTINUE/Safe Mode clicked but foreground steals to Cursor/Chrome; post-click `no game or launcher hwnd` loop; `launcher window not found` at timeout.

**Evidence:** `docs/evidence/live-cert/f7-bisect-summary.json`, session `20260622-021332` (MapReady reached, no `[TBG MAPREADY]`).

**Agent A actions this iteration:**
1. Harden `launcher-auto-nav.ps1` — minimize IDE every poll; stricter click verify; retry CONTINUE when unverified; no bad hwnd fallback
2. `SubModule` — run orchestrator on `SetupPhase.MapReady` without waiting for `MainHero` (Agent B overlap, smallest fix)
3. Re-run `Run-F7GateContinue.cmd -HookMask 0x0F`

**Blockers for C:** CONTINUE click reports OK while foreground=`Cursor`; need hwnd-only click path without `SetCursorPos` stealing focus, or minimize Cursor before every click attempt.

**Blockers for B:** MapReady in Phase1 but zero `[TBG MAPREADY]` — orchestrator tick not firing before process exit.

---

## Append below (newest first)

### 2026-06-22 — Agent A (iteration 3) @ `0d32ae8`

**BREAKTHROUGH (launcher):** Session `20260622-030915` — `continueClick.success=true`, Safe Mode No clicked, `game_spawned`, golden-path `mainMenu` + `mapTransition`.

**Still FAIL:** Game died during MapTransition before MapReady/orchestrator; no `[TBG MAPREADY]` this run (prior `025402` reached `StatusFlush begin` then died).

**Fixes this iteration:**
- Inline `launcher-auto-nav` in F7 (subprocess broke on `Mount & Blade` `&` in path)
- `TryRestoreLauncherWindows()` Win32 ShowWindow for UIA
- Signal added to `minimize-ide-foreground.ps1`

**Agent B next:** Survive MapTransition → MapReady; StatusFlush safe path already landed in `29eec77`.

**Agent C next:** Reduce post-handoff refocus spam when game hwnd briefly missing; optional Signal/Teams blocklist.

---

### 2026-06-22 — Agent A (iteration 2) @ `29eec77` / `0d9298e`

**Progress:** Session `20260622-025402` reached `[TBG MAPREADY] orchestrator tick entered` + `StatusFlush begin` — first orchestrator fire on Continue load.

**Still FAIL:** Process died during StatusFlush; `continueClick.success=false` in manifest (subprocess launcher lost hwnd to Chrome); stuck MapTransition in golden-path.

**Agent A fixes:**
- `CampaignMapReadyOrchestrator` — trigger on `SetupPhase.MapReady`; lightweight StatusFlush without `SyncForgeStatus`
- `ForgeStatus.Flush` — safe session field reads (try/catch)
- `launcher-auto-nav.ps1` — minimize IDE every poll; retry CONTINUE; hwnd-only click; no bad hwnd fallback
- `minimize-ide-foreground.ps1` — also minimize Chrome/WindowsTerminal

**Next:** Re-run `Run-F7GateContinue.cmd -HookMask 0x0F`; Agent C must fix Chrome foreground during subprocess launcher retry.

---

<!-- Agents B/C: add dated entries with commit SHA, verdict, next action -->
