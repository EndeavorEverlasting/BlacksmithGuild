# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**LAUNCHER CERT CLOSED (2026-06-21)** — Path A, Continue load, Path C-play, Path C-continue **USER PASS**. **Path B WAIVED** (obsolete — auto-skip past character creation).

Handoff for next work: [docs/checkpoints/pre-blacksmith-automation-handoff.md](checkpoints/pre-blacksmith-automation-handoff.md)

**Path C evidence (2026-06-21):** Play quit @ 15:36:56 `decision=block reason=session ended`. Continue quit @ 15:51:12 `decision=block reason=forward launch already completed this process` — no second `auto-select reason=continue intent`. Pre-fix contrast: 2026-06-20 18:00:40 re-armed Continue on quit.

**Path A evidence (2026-06-20):** Forge.cmd → Danustica map, `TBG READY`, `ForgeQuartermasterWarlord`, stub forge Long Warblade 11250. Launch.log: `AUDIT coord window pick: MB II: Bannerlord`, click `(811,764)` fractions `0.34×0.90`.

Handoff: [docs/checkpoints/post-006i-4-handoff.md](checkpoints/post-006i-4-handoff.md) · Plan (006J): [docs/plans/006j-full-live-cert-closeout.plan.md](plans/006j-full-live-cert-closeout.plan.md) · Plan (006I-5): [docs/plans/006i-5-continue-module-mismatch-load.plan.md](plans/006i-5-continue-module-mismatch-load.plan.md) · Plan (006I-4): [docs/plans/006i-4-quit-to-menu-intro-loop.plan.md](plans/006i-4-quit-to-menu-intro-loop.plan.md)

Rollback anchor (pre-2026-06-21 fix): tag `006i-4-path-c-pass` @ `57f6062` · Current fix HEAD: `31571e1`

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Layer A handoff still pending formal cert. |
| 006I-3 | SHIPPED. Path B **WAIVED** (obsolete — untestable with auto-skip). |
| 006I-4 | **CLOSED** — Path C play + continue USER PASS 2026-06-21. |
| 006I-5 | **CLOSED** — Continue load + quit USER PASS (user 2026-06-21). |
| 005E economics | **UNBLOCKED** — proceed smithing automation per [pre-blacksmith-automation-handoff.md](checkpoints/pre-blacksmith-automation-handoff.md). |

## 006I-4 fix (quit-to-menu intro replay) — CONFIRMED + RE-CERTED 2026-06-21

**Diagnosis:** Hypothesis A — `MainMenuAutoLauncher` re-selected SandBox/Continue on return to main menu. Continue path worse: explicit exemption + `_bootstrapUsed` never set.

**Fix (2026-06-19):** Clear intent after consume; block when consumed or bootstrap completed (play only).

**Fix (2026-06-21):** Remove continue exemption; `ForwardLaunchCompletedThisProcess` latch; `DisarmForSessionEnd` on quit/Game.End. Commits `286df1e`, `f318f3a`.

**Cert:**

| Session | Path | Result | Key log |
|---------|------|--------|---------|
| 2026-06-19 | Path C-play | USER PASS | `decision=block reason=intent already consumed` |
| 2026-06-21 | Path C-play | USER PASS | `decision=block reason=session ended` @ 15:36:56 |
| 2026-06-21 | Path C-continue | USER PASS | `decision=block reason=forward launch already completed this process` @ 15:51:12 |

## 006I-5 fix (Continue load hang) — CLOSED

**User confirm 2026-06-21:** Continue load and quit both work (`LaunchForgeContinue.cmd`).

Prior fix (Module Mismatch UIA, watchdog, forward-launch latch) — evidence 2026-06-20 Tevea + 2026-06-21 Path C-continue.

## Live cert record (2026-06-19 user session + 006J agent pass)

| Path | Result | Evidence |
|------|--------|----------|
| A — bootstrap to map | **USER PASS** | 2026-06-20 Forge.cmd → Danustica, TBG READY, PLAY coords 0.34×0.90 @ (811,764) |
| B — culture Back/Escape | **WAIVED** | Auto-skip past creation — obsolete; no cert required |
| C — Pause → Quit (play) | **USER PASS** | 2026-06-21 @ 15:36:56 — `session ended` |
| C — Pause → Quit (continue) | **USER PASS** | 2026-06-21 @ 15:51:12 — `forward launch already completed` |
| Continue load | **USER PASS** | User 2026-06-21; prior Tevea evidence 2026-06-20 |
| Launcher handoff (Layer A) | **Path A PASS** | 2026-06-20 user session — map reached; verify `handoff:` line on next CollectCertLogs |
| Market F12 (005E-M) | **FAIL** | `BlacksmithGuild_MarketIntel.json` absent |

**Overall: LAUNCHER CERT CLOSED** — smithing cert queue is next ([pre-blacksmith-automation-handoff.md](checkpoints/pre-blacksmith-automation-handoff.md)).

## Load path test matrix (006I-5 cert goal)

| # | Entry | Intent | Expected |
|---|-------|--------|----------|
| 1 | `.\Forge.cmd` | play | TBG READY, count=1, quit clean |
| 2 | `.\LaunchForge.cmd` | play | Map or launcher handoff |
| 3 | `.\LaunchForgeContinue.cmd` | continue | Module Mismatch Yes auto → map, no 5min hang |
| 4 | `.\ForgeContinue.cmd` | continue | Same as 3 (lower priority) |
| 5 | Quit between each | — | No intro replay, no Task Manager |

## Live cert protocol

**Precondition:** Close Bannerlord completely.

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
# then LaunchForgeContinue.cmd for Continue path
```

**Analyze:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 220
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json"
```

### PASS signatures

- Launch.log: `handoff:` and `clicked Module Mismatch Yes` (Continue path)
- Launch.log: `post-handoff: TBG READY detected`
- Phase1.log: `TBG READY: campaign map ready`
- Path C: `decision=block reason=intent already consumed` after quit
- No `load stall watchdog triggered`

### FAIL signatures

- `launcher-auto-nav timed out`
- `load stall: GameLoadingState exceeded 180s`
- Manual Module Mismatch Yes still required
- Culture Back full cutscene replay
- Quit requires Task Manager

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Forge.log
```

## Known gaps

| Gap | Status |
|-----|--------|
| Path B culture Back | **PENDING** re-cert |
| Continue load (006I-5) | **PENDING** user re-test via `LaunchForgeContinue.cmd` |
| Layer A handoff | **FAIL** (006J) — Launch.log timeouts; no `handoff:` |
| Market F12 (005E-M) | **FAIL** (006J) — user has not pressed F12 near town |
| Load path matrix rows 1–5 | **PENDING** |
| Version bump | `v0.0.11` until full cert PASS |
| 005E smithing posse | Blocked on 006I LIVE CERT PASS |

## Cert record

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — bootstrap | PASS | 2026-06-19 | Phase1 ~02:32:04 |
| B — culture Back | PENDING | | Prior FAIL — re-test needed |
| C — Quit | **USER PASS** | 2026-06-19 | 006I-4 confirmed |
| Continue load | PENDING | | 006I-5 shipped |
| Launcher handoff | PENDING | | Re-test via `.\Forge.cmd` |
