# Launcher Window Context Factoring

This document is the authoritative plan for factoring launcher PID/window selection across the automation stack.

It exists because the repo now has a strong baseline-selection spine, but not every entry point is forced to use it. Future agents should start here before touching launcher navigation, focus policy, Continue/Play automation, PR11 attach/execute, governor smoke bootstrap, or dev-save bootstrap.

## Why this exists

The old failure pattern was not simply "wrong window selected." The deeper issue was that different scripts made their own launcher/process/window decisions:

- some captured a baseline before launch
- some skipped that capture when a launcher already existed
- some searched all launcher PIDs
- some fell back to title/size heuristics
- some focus/dialog helpers searched by process name or window title

That means two scripts could both be "reasonable" and still choose different windows or stale process context.

The desired product behavior is one consistent launcher context shared by every launch-adjacent entry point.

## Current strongest path

The current strongest path is:

```text
open-bannerlord-launcher.ps1
  captures S1 baseline process/window snapshot before starting or reusing launcher

launcher-auto-nav.ps1
  loads S1 baseline
  captures/derives S2 after launcher request
  compares S1/S2
  scores candidates
  chooses one winner
  calls UIAHelper.SetPreferredLauncherWindow(hwnd, pid, score, reason)

UIA/coord click path
  prefers the chosen hwnd/pid
  only then considers PID-global or coordinate fallbacks
```

This is the right spine. It should become the only normal route.

## Known inconsistent entry points

These entry points can launch or navigate the launcher and therefore must eventually share one context:

- `scripts/open-bannerlord-launcher.ps1`
- `scripts/install-mod.ps1`
- `scripts/run-autonomous-assist-session.ps1`
- `scripts/run-pr11-town-travel-launch-attach-execute.ps1`
- `scripts/run-governor-disposable-smoke.ps1`
- `scripts/ensure-dev-save.ps1`
- `scripts/launcher-auto-nav.ps1`
- `scripts/autonomous-assist-session.ps1`

The specific weak pattern to eliminate is:

```powershell
$launcherRunning = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher'
if (-not $launcherRunning) {
    & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot
}
& (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $bannerlordRoot
```

Why this is wrong:

```text
If a launcher already exists, this skips the canonical S1/context writer.
launcher-auto-nav.ps1 may then use a stale S1 artifact or recapture fallback after the launcher is already present.
```

Existing launcher reuse is valid, but it must still refresh/write context.

## Required doctrine

```text
No launch-adjacent script may call launcher-auto-nav.ps1 without a fresh or intentionally reused LauncherWindowContext.

No caller may decide "launcher already running, skip open launcher" without also refreshing or writing the launcher context.

No click path may use heuristic title/size window selection while a valid LauncherWindowContext exists.

No fallback may be silent.

PID-global UIA is a fallback only after bound hwnd/pid context fails or is unavailable, and it must log why.

Coordinate fallback is a fallback only after bound hwnd/pid context fails or is unavailable, and it must log why.

Dialog handling may use specialized discovery only with an explicit reason because dialogs may not share the launcher hwnd.

Focus helpers must not bypass context silently.
```

## Canonical abstraction

Future implementation should introduce:

```text
TbgLauncherWindowContext
```

or equivalent.

Required fields:

```text
sessionId
launchIntent
baselineSnapshotPath
baselineCapturedUtc
baselineSource
processId
hwnd
processName
windowTitle
rect
score
reason
contextSource
isExistingLauncherReuse
isFreshLaunch
createdBy
```

Preferred function or script:

```text
Ensure-TbgLauncherWindowContext
```

Likely file:

```text
scripts/launcher-window-context.ps1
```

The function should own these cases:

```text
fresh launch:
  capture S1 before Start-Process
  start launcher
  let launcher-auto-nav derive S2 and bind winner

existing launcher reuse:
  capture current launcher/game-family process/window state as intentional reuse baseline
  mark isExistingLauncherReuse=true
  bind/revalidate visible launcher hwnd/pid before navigation

already attachable game:
  do not force launcher context
  report attach-ready path instead

actual game process running but not attachable:
  require Forge Stop approval path
  do not silently kill or reuse
```

Preferred future call shape:

```powershell
$context = Ensure-TbgLauncherWindowContext -BannerlordRoot $bannerlordRoot -LaunchIntent $LaunchIntent -Mode LaunchSetup
& (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') `
    -LaunchIntent $LaunchIntent `
    -BannerlordRoot $bannerlordRoot `
    -LauncherContextPath $context.path
```

## Entry points that must use it

### `open-bannerlord-launcher.ps1`

Should become a thin wrapper around `Ensure-TbgLauncherWindowContext` for open/reuse logic.

### `install-mod.ps1`

Should not separately decide launcher context. It should call the canonical function before `launcher-auto-nav.ps1`.

### `run-autonomous-assist-session.ps1`

If it launches, it must ensure context even when launcher already exists. If it attaches to an already-ready session, launcher context is not required.

### `run-pr11-town-travel-launch-attach-execute.ps1`

Same rule as autonomous assist: any path that calls `launcher-auto-nav.ps1` must first ensure context.

### Governor/dev-save smoke scripts

Any bootstrap path that opens or reuses the launcher must call the same context function rather than inventing its own process policy.

### `launcher-auto-nav.ps1`

Should consume a context path when provided. If no context is provided, it may create a fallback context only with a logged `context_missing` or `context_recaptured_fallback` classification.

## Allowed fallbacks and required logging

Fallbacks are not banned. Silent fallbacks are banned.

Allowed fallback classes:

```text
context_missing
context_stale
context_hwnd_invalid
context_pid_gone
context_rect_unavailable
dialog_outside_launcher_context
pid_global_uia_fallback
coordinate_fallback
operator_focus_required
```

Each fallback must log:

```text
why the bound context could not be used
which fallback was selected
which pid/hwnd/title was acted on
whether the action was background-safe or foreground/real-input
```

## Forbidden patterns

Do not add new code that does any of the following:

```text
calls launcher-auto-nav.ps1 after skipping open-bannerlord-launcher.ps1 because launcher already exists
clicks PLAY/CONTINUE from title/size heuristic while a valid context exists
uses Get-Process -Name TaleWorlds.MountAndBlade.Launcher | Select-Object -First 1 as authority
uses FindProcessMainWindowRoot as authority for launch navigation
uses GetBestLauncherWindowForCoords as normal path instead of fallback path
uses PID-global UIA before bound hwnd/pid UIA
forces foreground without context or explicit focus policy
```

## Contract verifier

The current documentation contract is enforced by:

```text
scripts/verify-launcher-window-context-contract.ps1
```

That verifier intentionally proves the doctrine and plan are present. It does not claim the full refactor is complete.

A later implementation verifier should fail if any launch-adjacent script calls `launcher-auto-nav.ps1` without first ensuring context.

## Staged implementation plan

### Stage 1: Documentation and contract

Status: this document.

Deliverables:

```text
docs/handoff/launcher-window-context-factoring.md
docs/operator/governor-test-harness.md section
scripts/verify-launcher-window-context-contract.ps1
```

### Stage 2: Shared context function

Create:

```text
scripts/launcher-window-context.ps1
```

Add:

```text
Ensure-TbgLauncherWindowContext
Read-TbgLauncherWindowContext
Write-TbgLauncherWindowContext
Test-TbgLauncherWindowContextFresh
```

### Stage 3: Entry-point migration

Migrate:

```text
install-mod.ps1
run-autonomous-assist-session.ps1
run-pr11-town-travel-launch-attach-execute.ps1
run-governor-disposable-smoke.ps1
ensure-dev-save.ps1
```

### Stage 4: Launcher auto-nav consumption

Add `-LauncherContextPath` to `launcher-auto-nav.ps1` and make it prefer the context over fallback artifact discovery.

### Stage 5: Fallback contract hardening

Make verifier fail for normal-path heuristics. Keep dialog exceptions explicit and logged.

### Stage 6: Runtime proof

Only after Stage 2-5, run visible mechanics proof on an approved disposable save. Runtime proof is not part of this documentation sprint.

## Final handoff format

Future agents working this lane should use:

```text
SPRINT HANDOFF - Launcher Window Context Factoring

START:
- branch:
- starting SHA:
- working tree clean:

ANALYSIS:
- launcher entry points inspected:
- context gaps found:
- fallback paths found:

IMPLEMENTATION:
- context file:
- functions added:
- entry points migrated:
- launcher-auto-nav context consumption:
- fallback logging added:

VERIFICATION:
- launcher context verifier:
- post-attach verifier:
- governor verifier:
- BOM:
- build if source changed:

RUNTIME:
- live proof run yes/no:
- if yes, summary path:
- movement proof classification:

EVIDENCE HYGIENE:
- runtime evidence committed yes/no:

FINAL HYGIENE:
- git status --short:
- git diff --check:
- git log --branches --not --remotes --oneline:
- git ls-files --others --exclude-standard:

NEXT ACTION:
- exact next command or blocker:
```

## Core ruling

```text
Launcher PID/window selection must become one shared context.
Every launch-adjacent entry point must use it.
Existing launcher reuse still needs context.
Fallbacks are allowed only when logged and classified.
The full refactor is a later implementation sprint.
```
