# 006I-5 Plan — Continue Load + Module Mismatch + Stall Watchdog

## Status

**IN PROGRESS** — implementation shipped; user re-cert PENDING.

| Gate | Status |
|------|--------|
| 006I-4 Path C quit | **USER PASS** (tag `006i-4-path-c-pass` @ `57f6062`) |
| 006I overall cert | **PARTIAL** — Path B + load paths pending |
| Module Mismatch UIA | SHIPPED |
| LaunchForgeContinue.cmd | SHIPPED |
| Load stall watchdog | SHIPPED (C# 180s + script post-handoff) |
| 005E economics | BLOCKED |

## Problem

User flow: Forge → play OK → LaunchForge → play OK → LaunchForge → Continue → **Module Mismatch** (manual Yes) → **stuck on loading screen** 5+ minutes.

**Root cause:** No automation for Module Mismatch → Yes; Continue load never completes. `launcher-auto-nav.ps1` handled Safe Mode, CAUTION Confirm, crash reporter — zero Module Mismatch handling.

**Stale Status.json:** `activeState=GameLoadingState`, `setupPhase=Complete`, `campaignReady=true`.

## Tracks

### Track 1 — Module Mismatch auto-Yes

**File:** `scripts/launcher-auto-nav.ps1` (UIAHelper inline C#)

- `HasModuleMismatchDialog()` — search for "Module Mismatch" or "mismatch" text
- `ClickModuleMismatchYes()` — click Yes / OK / Continue
- `LogVisibleModuleMismatchButtons()` — log buttons on first sighting
- Poll while launcher **and** Bannerlord.exe exist (in-game dialog after handoff)

### Track 2 — LaunchForge Continue entrypoint

**File:** `LaunchForgeContinue.cmd`

```powershell
forge.ps1 -Launch -LaunchIntent continue
```

Mirror `ForgeContinue.cmd` but opens launcher (like `LaunchForge.cmd`) for manual mod-checkbox workflows.

### Track 3 — Loading stall watchdog

**Layer A — C#:** `CampaignSetupStateTracker.cs`

- Track elapsed time in `GameLoadingState`
- After 180s: log `[TBG QUICKSTART] load stall: GameLoadingState exceeded 180s` + state stack snapshot + `AnnounceSetupStalled`

**Layer B — Script:** `launcher-auto-nav.ps1` post-handoff watch

- Poll Phase1.log for `TBG READY` or C# stall signature
- Poll Status.json for `GameLoadingState` duration
- After 180s with no progress: log + `Stop-Process Bannerlord` + exit 1

### Track 4 — Continue path must not re-bootstrap

**File:** `MainMenuAutoLauncher.cs`

- Fresh `continue` intent must auto-select ContinueCampaign even when bootstrap completed this process
- Play intent remains blocked after bootstrap complete (006I-4 guard retained)

### Track 5 — Log spam cleanup

**File:** `MainMenuAutoLauncher.cs`

- Rate-limit `decision=block` logs to once per reason per session

## Load path test matrix (cert goal)

| # | Entry | Intent | Expected |
|---|-------|--------|----------|
| 1 | `.\Forge.cmd` | play | TBG READY, count=1, quit clean |
| 2 | `.\LaunchForge.cmd` | play | Map or launcher handoff |
| 3 | `.\LaunchForgeContinue.cmd` | continue | Module Mismatch Yes auto → map, no 5min hang |
| 4 | `.\ForgeContinue.cmd` | continue | Same as 3 (lower priority) |
| 5 | Quit between each | — | No intro replay, no Task Manager |

## Output paths to analyze

```text
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Phase1.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Launch.log
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Status.json
C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord\BlacksmithGuild_Forge.log
```

## PASS signatures

- Launch.log: `launcher-auto: clicked Module Mismatch Yes`
- Launch.log: `post-handoff: TBG READY detected` (or Phase1 `TBG READY: campaign map ready`)
- Phase1.log: no `load stall: GameLoadingState exceeded 180s`
- Continue reaches map without manual Yes or Task Manager

## FAIL signatures

- `load stall watchdog triggered`
- `load stall: GameLoadingState exceeded 180s`
- Manual Module Mismatch Yes still required
- 5+ minute loading screen hang

## Scope lock

- Do **not** start 005E until 006I load paths certified
- Do **not** bump version
- Do **not** push without user request
- Do **not** revert 006I-4 quit fix
