# F7 Parallel Sprint — Agent Chat Log

> **Superseded by [`blacksmithguild-agent-coordination.md`](blacksmithguild-agent-coordination.md)** — use the coordination doc for live sprint state, file ownership, and cross-agent messages. This file is kept as historical archive only.

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

---

## Append below (archived — do not add new entries here)

### 2026-06-22 — Agent B (F7 recovery sprint)

**Landed (Phases 0–2 + partial 3):** `bannerlord-paths.ps1`, nav lock, golden-path patterns, ForgeStatus guards @ `ff823a6`.

### 2026-06-22 — Agent A (iteration 3) @ `0d32ae8`

**BREAKTHROUGH (launcher):** Session `20260622-030915` — `continueClick.success=true`, Safe Mode No, `game_spawned`, golden-path `mainMenu` + `mapTransition`.

### 2026-06-22 — Agent A (iteration 2) @ `29eec77`

**Progress:** Session `20260622-025402` reached `[TBG MAPREADY] StatusFlush begin`.
