# Sprint 006C — SandBox Intro Skip + Visible QuickStart Bootstrap — Live Certification

## Verdict

**FAIL on v1.4.6** — intro skip OK; character creation automation broken. Fixed in **006D** — see [sprint-006d-live-results.md](sprint-006d-live-results.md).

## Scope

Fix New Campaign SandBox bootstrap: skip the SandBox `campaign_intro` narrative cutscene, emit visible `TBG QUICKSTART` notices during setup, auto-advance character creation, and stop dev-save hijacking on `StartNewGame` so **New Campaign = always fresh bootstrap**.

## What shipped

| Piece | Location | Behavior |
|-------|----------|----------|
| Intro skip | `DevTools/QuickStart/SandboxCampaignIntroSkip.cs` | API probe; `VideoPlaybackState.OnActivate` skip; `CleanAndPushState` fallback; intro-flag prefix when field exists |
| Visible notices | `CampaignSetupStateTracker.cs` | One-shot cutscene/creation/stalled notices decoupled from trace log |
| Dev save gate | `DevToolsConfig.AutoLoadDevSaveOnStartNewGame = false` | `StartNewGame` no longer auto-loads dev save by default |
| Creation fallback | `AutoCharacterCreationPatches.cs` | `LaunchSandboxCharacterCreation` prefix; shared auto-advance helper; failure notices |
| Config | `AutoCharacterCreationConfig.SkipSandboxCampaignIntro = true` | SandBox intro skip ON (separate from launcher splash) |

## Bootstrap chain (after fix)

```text
New Campaign → SandBox → intro skip → auto character creation → map ready
  → TBG QUICKSTART / 006B auto-build → TBG READY
```

**Continue** path unchanged: loads pinned `BlacksmithGuild_DevStart*.sav`.

## Live cert protocol

### Path A — New Campaign bootstrap (primary)

```text
Close Bannerlord → Forge.cmd → New Campaign → SandBox
```

**PASS if:**

- Intro cutscene does **not** block (auto-skipped or never shown)
- Bottom-left shows at least one `TBG QUICKSTART:` notice during setup
- No manual character-creation clicks
- Phase1.log: `[TBG QUICKSTART] patches: OnLoadFinished=OK` (IntroSkip=OK preferred)
- Map ready → `TBG QUICKSTART: sandbox character auto-applied.` or 006B bootstrap notice
- `TBG READY`

### Path B — Continue regression

```text
Forge.cmd → Continue → TBG DEVSAVE / TBG READY
```

Dev save still loads; no intro skip required.

## Output files to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\
  BlacksmithGuild_Phase1.log          ← SandBox intro probe, patch status, transitions
  BlacksmithGuild_Status.json         ← quickStart.setupPhase, activeState
```

Key log lines:

```text
[TBG QUICKSTART] SandBox intro probe: introField=... launchSandbox=found ...
[TBG QUICKSTART] patches: IntroSkip=OK OnLoadFinished=OK LaunchSandboxCreation=OK ...
[TBG QUICKSTART] StartNewGame: fresh bootstrap (dev save load disabled).
```

## Known gaps (post-006C)

| Gap | Detail |
|-----|--------|
| **Live cert not run** | PASS requires user Phase1.log + in-game notice evidence |
| **Intro flag field** | Current game build may lack `_playedIntroVideo` — video-state skip is primary |
| **InGameNotice during raw video** | Skip fires before display; notices appear on transition |
| **Story Mode** | Correctly blocked — no automation |
| **Play→SandBox dev save** | Disabled by default; use **Continue** for daily loop |
| **SimulateCharacterCreation** | Probed only; reflection path remains primary |

## Risks

| Risk | Mitigation |
|------|------------|
| Game update renames intro/video APIs | SandBox intro probe log + layered fallbacks |
| Double character-creation push | `LaunchSandboxCharacterCreation` only when vanilla lands there |
| 006B bootstrap on New Campaign | Existing `DevSaveLoadUsed` gate unchanged |

## Failure classification

| Symptom | Likely cause |
|---------|--------------|
| Still on painted intro | Old DLL — close game, `Forge.cmd`, verify `IntroSkip=OK` |
| No bottom-left notices | Intro skip not firing — check probe + activeState in log |
| Dev save on New Campaign | `AutoLoadDevSaveOnStartNewGame` re-enabled in config |
| Manual character creation | `characterApi=SKIP` — game API drift |
| Continue broken | Unrelated — check dev save exists + pin-dev-save |
