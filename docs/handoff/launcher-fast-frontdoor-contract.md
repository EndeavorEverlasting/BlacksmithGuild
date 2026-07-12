# Launcher Fast Frontdoor Contract

## Purpose

`Forge.cmd` and `ForgeContinue.cmd` must not leave an operator staring at the Bannerlord launcher for a minute or more. The root command path owns a bounded launcher state machine with short phases, explicit evidence, and one retry.

## Timing contract

```text
total budget: 30 seconds
normal phase budget: 5 seconds
maximum launch attempts: 2
full-close retries: 1
```

A single PLAY, CONTINUE, CAUTION, or post-Confirm observation must not consume the whole run budget. Obvious launcher states should be classified within approximately five seconds.

## Root command chain

```text
Forge.cmd / ForgeContinue.cmd
-> forge.ps1 -Launch ... -LaunchManual
-> build, install, open launcher, write fresh launcher context
-> scripts/launcher-fast-frontdoor.ps1
-> click PLAY or CONTINUE
-> classify game handoff or dependency CAUTION
-> click Confirm
-> wait for game handoff
-> one force-close/fresh-launch retry only after failure
-> explicit success or dead end
```

`-LaunchManual` is intentional only in this paired root-command chain. It prevents `forge.ps1` from starting the older 60-second modal wrapper because `launcher-fast-frontdoor.ps1` owns all launcher UI navigation immediately afterward.

The root commands must not call either of these directly:

```text
scripts/launcher-frozen-context-nav.ps1
scripts/launcher-modal-aware-context-nav.ps1
```

## Dependency CAUTION semantics

The CAUTION panel overlays the existing PLAY / CONTINUE launcher menu.

Correct path:

```text
PLAY or CONTINUE menu
-> click requested intent
-> dependency CAUTION appears
-> click Confirm
-> launcher disappears or transitions
-> game process/window appears
```

`Cancel` is forbidden as automated dependency-CAUTION recovery. Cancel or closing the overlay returns to the underlying launcher menu and does not advance the launch.

A force-close retry is allowed only when:

- the intent click does not produce a game or CAUTION state;
- Confirm cannot be dispatched safely;
- the CAUTION remains after Confirm;
- the launcher menu returns after Confirm and the bounded correction still does not start the game; or
- Confirm is dispatched but no game handoff appears before the five-second phase deadline.

The mere presence of CAUTION is not a retry trigger.

## DPI and coordinate contract

The frontdoor calls `SetProcessDPIAware` before reading physical window bounds. Real-input coordinates come from `GetWindowRect`, not DPI-virtualized client coordinates. Every click records:

```text
label
pid
hwnd
physical screen x/y
fractions
dpiAware=true
```

The state machine captures screenshots before and after the intent and Confirm phases. A central darkness ratio helps distinguish the black CAUTION overlay from the normal launcher menu without OCR.

## Automatic local evidence

Every root launcher run writes ignored evidence inside the repo:

```text
artifacts/latest/launcher-frontdoor/<run-id>/
artifacts/latest/launcher-frontdoor.result.json
```

A run folder can contain:

```text
frontdoor.log
launch-tail.log
launcher-window-context.json
attempt-1-menu-before.png
attempt-1-after-intent.png
attempt-1-after-confirm.png
attempt-1-terminal.png
attempt-2-*.png
result.json
```

`artifacts/` remains ignored. These are local debugging inputs for the next agent, not committed runtime proof. The operator should not have to paste routine launcher logs or screenshots back into chat for the agent to understand the failure.

## Terminal states

Success:

```text
LAUNCH_STATE=launcher_setup_handoff_observed
```

Attempt failure:

```text
LAUNCH_STATE=fast_attempt_failed
```

Retry:

```text
LAUNCH_STATE=fast_retry_scheduled
LAUNCH_STATE=fast_retry_force_close_complete
```

Final failure:

```text
LAUNCH_STATE=launcher_recovery_dead_end
```

The machine-readable schema is:

```text
TbgLauncherFastFrontdoor.v1
```

Launcher handoff is not campaign-ready, movement, arrival, or trade proof.
