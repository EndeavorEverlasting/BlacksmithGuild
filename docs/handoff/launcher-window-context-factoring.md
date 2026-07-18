# Launcher Window Context Factoring

This document is the authoritative plan for factoring launcher PID/window selection across the automation stack.

It exists because the repo now has a strong baseline-selection spine, but not every entry point is forced to use it. Future agents should start here before touching launcher navigation, focus policy, Continue/Play automation, PR11 attach/execute, governor smoke bootstrap, or dev-save bootstrap.

Related doctrine:

```text
docs/handoff/launcher-duration-and-log-evidence-doctrine.md
docs/handoff/duration-entrypoint-sweep.md
```

These companion docs own the policy that launcher logs are live state, operator activity is valid evidence, and front-door callers may not hide long duration overrides while the callee appears policy-compliant.

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
  captures/derives S2 post-launch/request snapshot
  compare S1/S2
  scores candidates
  bind preferred hwnd/pid
  calls UIAHelper.SetPreferredLauncherWindow(hwnd, pid, score, reason)

UIA/coord click path
  prefers the chosen hwnd/pid
  only then considers PID-global or coordinate fallbacks
```

This is the right spine. It should become the only normal route.

## Non-negotiable PID selection principle

Forge and ForgeContinue must take a snapshot of the relevant launcher/game-family PIDs just before opening any game component, then take a second snapshot after the launch request, and then choose only from the difference.

```text
S1 = before opening launcher/game component
S2 = after opening launcher/game component
candidate set = S2 - S1
chosen launcher target = one selected hwnd/pid from candidate set
```

The selected hwnd/pid is then the launch target for the PLAY/CONTINUE phase. The script must not repeatedly rescan all top-level windows and reconsider unrelated windows as equal candidates.

Once a launcher hwnd/pid is selected for the click phase, that selection is frozen until one of these happens:

```text
- the selected process exits
- the selected hwnd becomes invalid
- the selected window is explicitly classified as not launcher-capable
- the script transitions out of launcher-click phase into post-handoff/game-spawn phase
```

After the PLAY/CONTINUE click is accepted or the game process spawns, launcher selection must stop. New game windows, loading windows, or Singleplayer windows must not be promoted back into launcher click selection.

This prevents the bad loop:

```text
1. choose actual launcher window
2. click CONTINUE
3. see launcher/game transitional windows
4. rescore the same PID or a new game-ish hwnd
5. click CONTINUE again against the wrong phase
6. repeat analysis until timeout or accidental success
```

## Operator action principle

The user may click Play or Continue manually during launcher automation.

A manual click that advances the workflow is evidence, not interference. If the game process spawns, the launcher target invalidates in a way consistent with handoff, `Launch.log` reports `game_spawned`, or the Phase1/status artifacts appear, automation must consume that state transition and proceed to post-handoff classification.

Required classification language:

```text
operator_click_allowed
operator_or_external_handoff_detected
game_spawned_before_script_click
game_spawned_during_click_phase
launcher_target_invalidated_after_operator_click
post_handoff_watch
```

Forbidden behavior:

```text
treating user click as automation failure
waiting for script-click proof after external handoff is already proven
continuing to click launcher controls after game_spawned
claiming product PASS from game_spawned alone
```

## Fallback ordering principle

Bound PID/window context first. Global PID search second. Coordinate/title/size fallback last, logged, and only with a reason.

```text
1. Bound LauncherWindowContext hwnd/pid
2. S1/S2 delta-selected hwnd/pid
3. PID-global UIA fallback, only after bound context fails or is unavailable
4. Coordinate fallback, only after bound context and PID-global UIA fail or are unavailable
5. Operator focus prompt, only when automation cannot act safely
```

No fallback may erase or replace the fact that a bound hwnd/pid existed. Fallbacks must explain why that bound target could not be used.

## Launch phase state machine

Launcher automation must use explicit phases. A phase transition is more important than another window scan.

```text
pre_launch_snapshot
launcher_opened_or_reused
s2_delta_captured
launcher_target_selected
launcher_click_phase
continue_clicked_or_play_clicked
operator_or_external_handoff_detected
post_click_spawn_wait
game_spawned
post_handoff_watch
map_or_menu_readiness_probe
attach_ready_or_blocked
```

Rules:

```text
launcher_target_selected -> launcher_click_phase:
  use frozen hwnd/pid unless invalidated by a named reason

continue_clicked_or_play_clicked -> post_click_spawn_wait:
  do not re-enter launcher candidate scoring unless click failure is proven and game has not spawned

operator_or_external_handoff_detected -> post_handoff_watch:
  accept user/manual/external Play or Continue if logs/process/status prove forward progress

game_spawned -> post_handoff_watch:
  stop clicking launcher controls
  stop classifying game windows as launcher controls

post_handoff_watch -> map_or_menu_readiness_probe:
  report readiness or blocked state, not silence
```

The logs must make these phases visible. Seeing repetitive top-level-window analysis after a frozen launcher target exists is a bug unless the log also contains an explicit invalidation reason.

## Post-handoff product readiness doctrine

A successful launcher click is not a finished product.

```text
continue_clicked != map_ready
Bannerlord.exe spawned != attach_ready
loading complete != assistive_ready
assistive_ready != user_guided
```

After game spawn, the product must produce one of these outcomes:

```text
map_ready
main_menu_ready
loading_still_in_progress
attach_ready
attach_blocked
hotkeys_ready
assistive_commands_ready
operator_action_required
post_handoff_idle_unactionable
```

If the game loads slowly, the post-handoff watcher must emit progress classifications instead of appearing dead. If the game reaches a usable state but no handoff, no activity, and no message-log guidance is emitted, that is `post_handoff_idle_unactionable`, not PASS.

The in-game message log should guide the operator after readiness, for example:

```text
TBG ready: Ctrl+Alt+T cycles engine mode.
TBG ready: Ctrl+Alt+G runs GuildLoop.
TBG ready: Ctrl+Alt+M writes Market Intel.
TBG ready: Ctrl+Alt+B aborts active autonomous movement.
```

The exact wording can change, but the product must not leave the operator staring at a loaded game with no handoff, no activity, and no suggested next command.

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

No repeated S1/S2 reselection is allowed after launcher target selection unless the selected hwnd/pid is explicitly invalidated.

No spawned game window may be promoted back into launcher click selection after continue_clicked_or_play_clicked.

No fallback may be silent.

PID-global UIA is a fallback only after bound hwnd/pid context fails or is unavailable, and it must log why.

Coordinate fallback is a fallback only after bound hwnd/pid context fails or is unavailable, and it must log why.

Operator activity is valid workflow evidence when logs/process/status prove forward progress.

Dialog handling may use specialized discovery only with an explicit reason because dialogs may not share the launcher hwnd.

Focus helpers must not bypass context silently.

Post-handoff watch must emit readiness, blocked, or post_handoff_idle_unactionable classification.

A loaded game with no handoff, no activity, and no message-log command guidance is unfinished product behavior, not PASS.
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
phase
selectionFrozen
invalidationReason
postHandoffClassification
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

It must also freeze the selected launcher hwnd/pid for the click phase. It must not keep rescoring top-level windows after the selection is already good enough to click. Re-selection is allowed only after a named invalidation reason.

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
post_handoff_idle_unactionable
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
rescans all top-level windows after a launcher target has already been selected without invalidating the selected hwnd/pid
promotes a spawned game window or Singleplayer window back into launcher click selection
keeps retrying launcher CONTINUE after game_spawned or handoff state is observed
forces foreground without context or explicit focus policy
treats operator click as failure when process/log/status evidence proves handoff
```

## Verifier anchors

operator guidance shown yes/no
Runtime proof is not part of this documentation sprint.

## Contract verifier

The current documentation contract is enforced by:

```text
scripts/verify-launcher-window-context-contract.ps1
```

That verifier intentionally proves the doctrine and plan are present. It does not claim the full refactor is complete.

A later implementation verifier should fail if any launch-adjacent script calls `launcher-auto-nav.ps1` without first ensuring context.

## Staged implementation plan

### Stage 1: Documentation and contract

Status: this document plus companion duration/operator evidence doctrine.

Deliverables:

```text
docs/handoff/launcher-window-context-factoring.md
docs/handoff/launcher-duration-and-log-evidence-doctrine.md
docs/handoff/duration-entrypoint-sweep.md
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
