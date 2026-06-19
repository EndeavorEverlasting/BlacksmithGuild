# Sprint 006I — Intro Skip Lifecycle — Live Certification

## Verdict

**LIVE CERT PENDING** — code shipped; user must run Paths A/B/C below.

## Scope

Fix intro skip firing at wrong lifecycle points:

- **Culture Back** replayed full `campaign_intro` cutscene because `IsSkippableVideoState` returned false once `BootstrapUsed` was set.
- **Pause → Quit** could loop on loading/cutscene because bootstrap stayed armed (`IsBootstrapArmed`) during teardown; `CleanAndPushState`/`FinishVideoState` intercepted non-exit video states.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Campaign-path-only skip | `SandboxCampaignIntroSkip.cs` | Removed `BootstrapUsed` block; skip only when `VideoPath` contains `campaign`; narrow fallback when path unreadable and forward bootstrap only |
| Repeat skip hardening | `SandboxCampaignIntroSkip.cs` | Sets `_playedIntroVideo` before `OnVideoFinished`; logs skip count |
| Bootstrap disarm | `CampaignSetupStateTracker.cs` | `DisarmBootstrap`, `NotifyCampaignMapReady`, main-menu return disarm in `Poll` |
| Map-ready disarm | `BlacksmithGuildCampaignBehavior.cs` | Calls `NotifyCampaignMapReady()` when TBG READY fires |
| Quit disarm | `SandboxCampaignIntroSkip.cs` | Harmony prefix on `Game.End` → disarm |
| Main menu guard | `MainMenuAutoLauncher.cs` | Skip auto-launch when `Campaign.Current != null` |

## Root cause

```text
Culture Back → game re-pushes campaign_intro VideoPlaybackState
BootstrapUsed == true → IsSkippableVideoState returned false → full cutscene replay
```

Quit loop: intro skip remained armed after map ready if `CompleteSetup` desynced; teardown pushed video states that were forcibly finished, re-entering load chain.

## Live cert protocol

**Precondition:** Close Bannerlord → `Forge.cmd` (installs fresh DLL).

### Path A — Forward bootstrap (006H regression)

```text
Forge.cmd → TBG READY
```

**PASS:** six narrative menus advanced; no Family stall; map Summer 1, 1084.

### Path B — Culture Back (new)

```text
Forge.cmd → at culture stage press Back
```

**PASS:** no full painted `campaign_intro` replay (may flash/skip instantly).  
**FAIL:** intro cutscene with subtitles plays again.

### Path C — Quit (new)

```text
Pause → Quit to desktop (during bootstrap AND after TBG READY)
```

**PASS:** exits normally; no infinite loading.  
**FAIL:** loading/cutscene loop; Task Manager required.

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
```

Key PASS lines:

```text
[TBG QUICKSTART] intro skip: campaign video via CleanAndPushState (count=...)
[TBG QUICKSTART] bootstrap disarmed: campaign map ready
[TBG QUICKSTART] bootstrap disarmed: game end
```

On culture Back, expect `count=2` or higher (forward skip + back skip).

Must NOT see repeated `CleanAndPushState video skip` during quit after disarm.

## Known gaps (post-006I ship)

| Gap | Status |
|-----|--------|
| Live cert Paths A/B/C | **PENDING** — user must run |
| ForgeContinue.cmd post-006H | Still optional regression |
| Tutorial skip | Out of scope |
| Profile-aware narrative picks | Not implemented |
| VideoPlaybackState patch | May still fail on v1.4.6; CleanAndPushState remains primary |

## Cert record

| Path | Result | Date | Notes |
|------|--------|------|-------|
| A — Forge.cmd bootstrap | **PENDING** | | 006H regression |
| B — Culture Back | **PENDING** | | No cutscene replay |
| C — Quit (bootstrap + map) | **PENDING** | | Clean exit |
