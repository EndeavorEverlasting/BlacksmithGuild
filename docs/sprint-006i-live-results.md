# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**RE-CERT PARTIAL** — Path C PASS; load paths + Path B pending.

Handoff: [docs/checkpoints/post-006i-4-handoff.md](checkpoints/post-006i-4-handoff.md) · Plan (006I-5): [docs/plans/006i-5-continue-module-mismatch-load.plan.md](plans/006i-5-continue-module-mismatch-load.plan.md) · Plan (006I-4): [docs/plans/006i-4-quit-to-menu-intro-loop.plan.md](plans/006i-4-quit-to-menu-intro-loop.plan.md)

Rollback anchor: tag `006i-4-path-c-pass` @ `57f6062`

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Layer A handoff still pending formal cert. |
| 006I-3 | SHIPPED. Path B culture Back pending re-cert. |
| 006I-4 | **Path C USER PASS** (2026-06-19). Quit re-arm fix confirmed. |
| 006I-5 | SHIPPED — Continue/Module Mismatch/watchdog; user re-cert PENDING. |
| 005E economics | NEXT. Gated on 006I cert PASS. |

## 006I-4 fix (quit-to-menu intro replay) — CONFIRMED

**Diagnosis:** Hypothesis A — `MainMenuAutoLauncher` re-selected `SandBoxNewGame` on return to main menu because `_launchIntent` stayed `"play"` after first consume.

**Fix:** Clear intent memory after consume; block menu auto-select when intent consumed or bootstrap completed; permanent post-READY disarm latch; diagnostic logging.

**Cert:** Path C **USER PASS** 2026-06-19 — `decision=block reason=intent already consumed`; no intro replay; no Task Manager.

## 006I-5 fix (Continue load hang) — SHIPPED, RE-CERT PENDING

**Problem:** LaunchForge → Continue → Module Mismatch (manual Yes) → infinite `GameLoadingState` loading screen.

**Fix:**

| Piece | Location | Behavior |
|-------|----------|----------|
| Module Mismatch UIA | `launcher-auto-nav.ps1` | Auto-click Yes/OK/Continue; log visible buttons |
| Post-handoff watchdog | `launcher-auto-nav.ps1` | Poll Phase1/Status.json; kill Bannerlord after 180s stall |
| C# load stall log | `CampaignSetupStateTracker.cs` | Log + state stack after 180s in GameLoadingState |
| Continue entrypoint | `LaunchForgeContinue.cmd` | `-Launch -LaunchIntent continue` via launcher |
| Continue intent guard | `MainMenuAutoLauncher.cs` | Allow continue intent after bootstrap complete |
| Block log rate limit | `MainMenuAutoLauncher.cs` | Once per reason per session |

## Live cert record (2026-06-19 user session)

| Path | Result | Evidence |
|------|--------|----------|
| A — bootstrap to map | **PASS** | Phase1 ~02:32:04 — count=1, Options block, TBG READY |
| B — culture Back/Escape | **PENDING** | Not re-certified after 006I-4 |
| C — Pause → Quit | **USER PASS** | User confirmed; intent consumed block log ~02:31:27 |
| Continue load | **FAIL** | Module Mismatch hang; 006I-5 fix shipped, re-cert PENDING |
| Launcher handoff | **PENDING** | Need `handoff:` from `.\Forge.cmd` |

**Overall: PARTIAL** — not LIVE CERT PASS until B + load paths certified.

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
| Layer A handoff | **PENDING** — need `handoff:` from `.\Forge.cmd` |
| Load path matrix rows 1–5 | **PENDING** |
| Version bump | `v0.0.11` until full cert PASS |
| 005E economics | Blocked |

## Cert record

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — bootstrap | PASS | 2026-06-19 | Phase1 ~02:32:04 |
| B — culture Back | PENDING | | Prior FAIL — re-test needed |
| C — Quit | **USER PASS** | 2026-06-19 | 006I-4 confirmed |
| Continue load | PENDING | | 006I-5 shipped |
| Launcher handoff | PENDING | | Re-test via `.\Forge.cmd` |
