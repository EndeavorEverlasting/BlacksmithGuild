# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**LIVE CERT PENDING** — 006I hotfix (3758335) partial PASS; **006I-2 shipped** (creation-phase skip gate + launcher handoff). User must re-run Paths A/B/C.

## 006I-2 (post-regression from live cert FAIL)

**Symptoms (00:57 session):**

1. **Launcher:** `launcher-auto-nav timed out after 120s` — game already running; no `Bannerlord.exe detected — handoff` log.
2. **In-game:** `intro skip via CleanAndPushState (count=2)` during Options stage → creation reset loop; no TBG READY.

**Root causes:**

- `CleanAndPushStatePostfix` fired campaign video skip while `Phase == CharacterCreation` (Options subStage).
- `HasCrashReporterDialog()` false-positive blocked handoff for full timeout despite `Bannerlord.exe` running.

**Fix (006I-2):**

| Piece | Location | Behavior |
|-------|----------|----------|
| Creation gate (OnActivate) | `SandboxCampaignIntroSkip.cs` | `IsCharacterCreationBootstrapActive()` blocks skip during active creation |
| Creation gate (CleanAndPush) | `SandboxCampaignIntroSkip.cs` | Block skip entirely when `Phase == CharacterCreation` |
| Stable handoff | `launcher-auto-nav.ps1` | 3-poll stable game + launcher gone or Safe Mode/PLAY path |
| Crash reporter handoff | `launcher-auto-nav.ps1` | Immediate handoff after No click if game running |
| Crash reporter heuristic | `launcher-auto-nav.ps1` | Text scan disabled when game main window present |
| Slow-path timeout | `launcher-auto-nav.ps1` | Extend to 180s when Safe Mode or crash reporter clicked |
| Handoff logging | `launcher-auto-nav.ps1` | `handoff: <reason>` lines |

Plan: [docs/plans/006i-2-creation-skip-gate.plan.md](plans/006i-2-creation-skip-gate.plan.md)

## Hotfix (006I — post-006H regression)

**Symptom:** Forge.cmd reached cutscene but did not skip; no TBG QUICKSTART notices; stuck before map.

**Root cause (Phase1.log):** `bootstrap disarmed: returned to main menu` fired on same tick as `auto-selecting SandBoxNewGame`.

**Fix (3758335):**

- `MainMenuAutoLauncher.IsForwardLaunchInProgress` blocks disarm during SandBoxNewGame transition
- `GameState.OnActivate` Harmony prefix replaces broken `VideoPlaybackState.OnActivate` patch on v1.4.6

**Partial validation:** count=1 OnActivate skip confirmed; premature disarm fixed.

## Scope (006I original)

Fix intro skip firing at wrong lifecycle points:

- **Culture Back** replayed full `campaign_intro` cutscene because `IsSkippableVideoState` returned false once `BootstrapUsed` was set.
- **Pause → Quit** could loop on loading/cutscene because bootstrap stayed armed during teardown.

## What shipped (006I + 006I-2)

| Piece | Location | Behavior |
|-------|----------|----------|
| Campaign-path-only skip | `SandboxCampaignIntroSkip.cs` | Skip only when `VideoPath` contains `campaign` |
| Repeat skip hardening | `SandboxCampaignIntroSkip.cs` | Sets `_playedIntroVideo` before `OnVideoFinished`; logs skip count |
| Creation-phase gate | `SandboxCampaignIntroSkip.cs` | Block skip during CharacterCreation (006I-2) |
| Bootstrap disarm | `CampaignSetupStateTracker.cs` | `DisarmBootstrap`, `NotifyCampaignMapReady`, main-menu return disarm |
| Forward launch guard | `MainMenuAutoLauncher.cs` | `IsForwardLaunchInProgress` blocks premature disarm |
| Video skip patch | `SandboxCampaignIntroSkip.cs` | `GameState.OnActivate` prefix (v1.4.6) |
| Launcher handoff | `launcher-auto-nav.ps1` | Robust Bannerlord.exe handoff (006I-2) |

## Live cert protocol

**Precondition:** Close Bannerlord → `Forge.cmd` (installs fresh DLL).

### Path A — Forward bootstrap (006H regression)

```text
Forge.cmd → TBG READY
```

**PASS:** `handoff:` in Launch.log; count=1 intro skip only; six narrative menus; no count=2 during Options; map Summer 1, 1084.

### Path B — Culture Back

```text
Forge.cmd → at culture stage press Back
```

**PASS:** no full painted `campaign_intro` replay (may flash/skip instantly).

### Path C — Quit

```text
Pause → Quit to desktop (during bootstrap AND after TBG READY)
```

**PASS:** exits normally; no infinite loading.

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
```

Key PASS lines:

```text
launcher-auto: handoff: Bannerlord.exe stable
[TBG QUICKSTART] intro skip: campaign video via OnActivate (count=1)
TBG READY: campaign map ready
```

Must NOT appear during forward bootstrap before TBG READY:

```text
intro skip: campaign video via CleanAndPushState (count=2)
bootstrap disarmed: returned to main menu
launcher-auto-nav timed out
```

On culture Back (Path B), expect count=2 or higher only **after** Back from culture (not during Options).

## Known gaps

| Gap | Status |
|-----|--------|
| Live cert Paths A/B/C | **PENDING** — user must run after 006I-2 |
| ForgeContinue.cmd post-006H | Optional regression |
| Tutorial skip | Out of scope |
| Profile-aware narrative picks | Not implemented |
| Culture-back fix (`BootstrapUsed` block removed) | Shipped in 006I — blocked by loop until 006I-2; re-test on Path B |

## Cert record

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | **PENDING** | | 006H regression; 006I-2 fixes loop + launcher |
| B — Culture Back | **PENDING** | | No cutscene replay |
| C — Quit (bootstrap + map) | **PENDING** | | Clean exit |
| Launcher handoff | **PENDING** | | `handoff:` log; no 120s timeout |
