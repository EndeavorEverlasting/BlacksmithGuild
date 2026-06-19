# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**SHIPPED — RE-CERT PENDING**

006I-3 shipped at `3cdbdd3` after **PARTIAL** cert on 2026-06-19. Do not mark PASS until Paths A/B/C re-run with fresh logs.

Handoff: [docs/checkpoints/post-006i-3-handoff.md](checkpoints/post-006i-3-handoff.md) · Plan: [docs/plans/006i-3-narrow-skip-gate.plan.md](plans/006i-3-narrow-skip-gate.plan.md) · Plan (006I-4): [docs/plans/006i-4-quit-to-menu-intro-loop.plan.md](plans/006i-4-quit-to-menu-intro-loop.plan.md)

## Current blocking glitch

Path C remains unsafe.

Observed:

```text
Quit / return toward main menu
→ campaign intro replays
→ user cannot get past it
→ Task Manager required
```

Status:

- 006I-3 shipped a guard attempt.
- Re-cert is pending.
- If still reproducible, proceed to 006I-4.

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Layer A handoff still pending formal cert. |
| 006I-3 | SHIPPED. Re-cert PENDING after narrow gate + quit guard. |
| 006I-4 | PLANNING ONLY. Quit-to-menu intro replay loop if Path C still fails. |
| 005E economics | NEXT. Gated on 006I cert PASS. |

## Live cert record (2026-06-19 user session)

| Path | Result | Evidence |
|------|--------|----------|
| A — bootstrap to map | **PARTIAL PASS** | Screenshot: TBG READY, Summer 1 1084, Danustica, report ~01:22:29. Pasted 00:57 Phase1 tail FAIL (count=2 loop — stale/pre-fix). |
| B — culture Back/Escape | **FAIL** | User: cutscene replays on Back or Escape from culture menu. |
| C — Pause → Quit | **FAIL** | User: quit requires Task Manager. Continue via LaunchForge loads map but quit broken. |
| Launcher handoff | **INCONCLUSIVE** | Pasted Launch.log 00:57: timeout, no `handoff:`. LaunchForge path not full Forge.cmd cert. |

**Overall: PARTIAL** — not LIVE CERT PASS.

## 006I-3 fix (post-PARTIAL cert)

**Root causes:**

- 006I-2 blocked all skips during `CharacterCreation`, including culture-Back campaign intro re-push.
- Phase poll lag allowed count=2 at Options before Phase updated.
- Intro skip could fire during quit/`InitialState` teardown.

**Fix:**

| Piece | Location | Behavior |
|-------|----------|----------|
| Forward one-shot | `SandboxCampaignIntroSkip.cs` | `_forwardIntroSkipDone` after count=1 |
| Narrow CleanAndPush gate | `SandboxCampaignIntroSkip.cs` | Block Options/post-forward creation; allow `CharacterCreationCultureStage` |
| Direct subStage read | `SandboxCampaignIntroSkip.cs` | `GetCurrentCreationSubStage()` bypasses Phase lag |
| OnActivate gate | `SandboxCampaignIntroSkip.cs` | `ShouldBlockOnActivateIntroSkip()` — same narrow rules |
| Quit guards | `SandboxCampaignIntroSkip.cs` | No skip when Phase Complete or `InitialState` |
| Counter reset | `SandboxCampaignIntroSkip.cs` | Reset on `Game.End` |

Prior fixes retained: 006I hotfix (disarm + OnActivate), 006I-2 launcher handoff.

## Live cert protocol (re-run after 006I-3)

**Precondition:** Close Bannerlord completely. Confirm no `Bannerlord.exe` or Launcher processes.

**Run:**

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
.\Forge.cmd
```

PowerShell requires `.\Forge.cmd` (not bare `Forge.cmd`).

**Analyze:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 120
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 60
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 100
```

See [docs/checkpoints/post-006i-3-handoff.md](checkpoints/post-006i-3-handoff.md) for PASS/FAIL rubric and analysis response template. Do not mark PASS without fresh A/B/C evidence.

### Path table

| Path | Cert action | PASS condition |
|------|-------------|----------------|
| Forge exit | `.\Forge.cmd` completes launcher handoff | Launch.log has `handoff:` reason, no timeout |
| A | Full bootstrap to map | count=1 only before TBG READY; no Options loop; TBG READY |
| B | Culture stage Back or Escape | No full campaign_intro replay (count=2+ after Back OK) |
| C | Pause then Quit | Clean exit without Task Manager |

### PASS signatures

- Launch.log contains `handoff:`
- Phase1.log: `intro skip: campaign video via OnActivate (count=1)`
- Phase1.log: `TBG READY: campaign map ready`
- No forward-bootstrap `CleanAndPushState (count=2)` before TBG READY
- Phase1.log may show `intro skip blocked: CleanAndPushState` at Options (006I-3)
- Path B: skip at Culture Back without full cutscene

### FAIL signatures

- `launcher-auto-nav timed out`
- `CleanAndPushState (count=2)` before TBG READY without block log
- Options → Culture narrative restart
- Culture Back full cutscene replay
- Quit requires Task Manager

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
```

## Known gaps

| Gap | Status |
|-----|--------|
| 006I-3 re-cert Paths A/B/C | **PENDING** — close Bannerlord, run `.\Forge.cmd` |
| Path B culture Back | **FAIL** in 2026-06-19 session — 006I-3 fix targets this |
| Path C quit teardown | **FAIL** in 2026-06-19 session — 006I-3 quit guard; may need more |
| Layer A handoff | **PENDING** — need `handoff:` in Launch.log from `.\Forge.cmd` |
| Fresh log tails from ~01:22 PASS session | Not collected — re-run required |
| ForgeContinue.cmd | Optional regression |
| Version bump | `v0.0.11` until cert PASS |
| 005E economics | Blocked |

## Cert record (updated after re-cert only)

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — bootstrap | PARTIAL PASS | 2026-06-19 | Screenshot only; re-cert after 006I-3 |
| B — culture Back | FAIL | 2026-06-19 | Cutscene on Back/Escape |
| C — Quit | FAIL | 2026-06-19 | Task Manager required |
| Launcher handoff | PENDING | | Re-test via `.\Forge.cmd` |
