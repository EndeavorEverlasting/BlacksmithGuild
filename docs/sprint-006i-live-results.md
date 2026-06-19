# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**SHIPPED — LIVE CERT PENDING**

006I-2 implemented, built (`forge.ps1` PASS), committed at `6fb5825`. Live cert Paths A/B/C not yet run.

Handoff: [docs/checkpoints/post-006i-2-handoff.md](checkpoints/post-006i-2-handoff.md)

## Repo context

| Field | Value |
|-------|-------|
| HEAD | `6fb5825` |
| Version | `v0.0.11` |
| Remote | 4 commits behind local `main` — treat local git as authoritative |
| Build | PASS via `forge.ps1`; Release DLL installed to Bannerlord Modules |

## Sprint status

| Sprint | Status |
|--------|--------|
| 006H | LIVE CERT PASS. Do not regress narrative/bootstrap. |
| 006I hotfix | Partial PASS. Disarm fix and count=1 OnActivate skip confirmed. |
| 006I-2 | SHIPPED. Live cert PENDING. |
| 005E economics | NEXT. No plan file yet. Gated on 006I cert. |

## 006I-2 (post-regression from live cert FAIL)

**Symptoms (00:57 session):**

1. **Launcher:** `launcher-auto-nav timed out after 120s` — game already running; no handoff log.
2. **In-game:** `intro skip via CleanAndPushState (count=2)` during Options stage → creation reset loop; no TBG READY.

**Root causes:**

- `CleanAndPushStatePostfix` fired campaign video skip while `Phase == CharacterCreation` (Options subStage).
- `HasCrashReporterDialog()` false-positive blocked handoff for full timeout despite `Bannerlord.exe` running.

**Fix (006I-2, commit `6fb5825`):**

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

## Hotfix (006I — post-006H regression, commit `3758335`)

**Symptom:** Forge.cmd reached cutscene but did not skip; no TBG QUICKSTART notices; stuck before map.

**Root cause (Phase1.log):** `bootstrap disarmed: returned to main menu` fired on same tick as `auto-selecting SandBoxNewGame`.

**Fix:**

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

**Precondition:** Close Bannerlord completely. Confirm no `Bannerlord.exe` or Launcher processes remain.

**Run:**

```powershell
cd C:\Users\Cheex\Desktop\dev\Mods\Bannerlord\BlacksmithGuild
Forge.cmd
```

**Analyze:**

```powershell
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log" -Tail 80
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log" -Tail 30
Get-Content "C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json" -Tail 60
```

### Path table

| Path | Cert action | PASS condition |
|------|-------------|----------------|
| Forge exit | Forge.cmd completes launcher handoff | Launch.log has `handoff:` reason, no timeout |
| A | Full bootstrap to map | count=1 only, narrative advances, TBG READY |
| B | Culture stage Back | No full campaign_intro replay |
| C | Pause then Quit | Clean exit from bootstrap/map |

### PASS signatures

- Launch.log contains `handoff:`
- Phase1.log contains `intro skip: campaign video via OnActivate (count=1)`
- Phase1.log contains `TBG READY: campaign map ready`
- No launcher timeout
- No forward-bootstrap `CleanAndPushState (count=2)` before TBG READY
- No Options → Culture narrative restart

On culture Back (Path B), expect count=2 or higher only **after** Back from culture (not during Options).

### FAIL signatures

- `launcher-auto-nav timed out`
- `intro skip: campaign video via CleanAndPushState (count=2)` during forward bootstrap before TBG READY
- Options → Culture narrative restart
- `bootstrap disarmed: returned to main menu` between auto-select and intro skip

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
```

## Known gaps

| Gap | Status |
|-----|--------|
| Path A full bootstrap cert | **PENDING** — user must run `Forge.cmd` |
| Path B culture Back regression | **PENDING** — 006I culture-back fix never re-tested; blocked by count=2 loop until 006I-2 |
| Path C quit teardown | **PENDING** |
| Launcher handoff | **PENDING** — verify `handoff:` log; no 120s timeout |
| ForgeContinue.cmd post-006H | Optional regression; not re-run |
| Launcher false positives | Mitigated in 006I-2; UIA can still flake by GPU/driver/window timing |
| Tutorial skip | Out of scope |
| Profile-aware narrative picks | Not implemented |
| Version bump | Still `v0.0.11` — bump only after cert PASS |
| 005E economics | Next feature; no plan file yet; gated on 006I cert |

## Cert record

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | **PENDING** | | 006H regression; 006I-2 fixes loop + launcher |
| B — Culture Back | **PENDING** | | No cutscene replay |
| C — Quit (bootstrap + map) | **PENDING** | | Clean exit |
| Launcher handoff | **PENDING** | | `handoff:` log; no timeout |
