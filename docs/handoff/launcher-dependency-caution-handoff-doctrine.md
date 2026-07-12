# Launcher Dependency Caution Handoff Doctrine

Bannerlord can show a launcher-stage **CAUTION** dialog when module dependency versions differ from the current game version. This is the native dependency-mismatch caution, not a BlacksmithGuild runtime proof artifact.

The expected default action for the unattended harness is **Confirm**.

## Why this belongs in the harness

This dialog appears after a valid native PLAY or CONTINUE handoff and before the target save/runtime evidence is available. Treating it as an unexpected frozen launcher failure strands an otherwise valid launch. Treating it as runtime proof would be worse.

The correct classification is:

```text
dependency_mismatch_caution_modal
```

The correct action is:

```text
confirm_dependency_caution
```

The expected log markers are:

```text
LAUNCH_STATE=modal_probe_started
WINDOW_DELTA after=frozen_click_unverified_or_operator_action
expectedWindowChange=game_spawned|dependency_caution_modal|safe_mode_modal|singleplayer_window
LAUNCH_STATE=dependency_caution_modal_detected
LAUNCH_STATE=dependency_caution_detected
classification=dependency_mismatch_caution_modal
defaultAction=confirm
CLICK_DEPENDENCY_CAUTION_RESULT result=confirm_dispatched
dependencyMismatchHandled=true
LAUNCH_STATE=launcher_setup_handoff_observed
```

## Safety boundary

The harness may confirm this dialog only when all of these are true:

1. a bound PLAY or CONTINUE click produced a handoff failure such as target invalidation, `click_unverified_timeout`, or `operator_action_required`;
2. the PID comes from the fresh `TbgLauncherWindowContext.v1` context;
3. the candidate window belongs to that same PID;
4. the candidate is not the Safe Mode modal;
5. the candidate is not already a Singleplayer runtime window;
6. the candidate has a usable foreground window and client rectangle;
7. foreground was acquired before real input;
8. the PID/HWND is revalidated immediately before clicking Confirm.

Do not use global title search as the primary authority. Use it only as supporting context after the bound PID/window relationship is established.

## Required failure-state logging

Silent fallback is not allowed. When the frozen navigator reports `click_unverified_timeout` or `operator_action_required`, the modal-aware wrapper must log enough state for a later agent to build on it:

```text
expectedPid
processExists
processName
originalHwnd
currentHwnd
sameHwnd
foregroundHwnd
foregroundMatches
title
client size
expectedNextStates
```

The key point is that the launcher does not need a process replacement to be in a new state. A native modal can reuse the same process and top-level HWND while changing the actionable window content. The harness must record that delta explicitly instead of reporting only that the click was unverified.

## Bounded full-close retry

The ordinary modal, PLAY, CONTINUE, and launcher-context mechanisms remain the primary path. Recovery is only for the exception path after those mechanisms return a nonzero or blocked result.

The default recovery budget is **one retry**, which means two total launch attempts:

```text
attempt 1 -> normal frozen/modal-aware launch
failure   -> force-close launcher process family
attempt 2 -> fresh launcher context and the same launch intent
failure   -> explicit dead end
```

The force-close scope is deliberately bounded to the Bannerlord launch family:

```text
Bannerlord
TaleWorlds.MountAndBlade.Launcher
Watchdog
```

The retry controller must not recursively retry without a budget. `MaxRecoveryRetries = 1` is the default. A second failure exhausts the budget.

Expected recovery log markers:

```text
LAUNCH_STATE=launcher_recovery_retry_scheduled
LAUNCH_STATE=launcher_recovery_force_close_started
LAUNCH_STATE=launcher_recovery_force_close_complete
LAUNCH_STATE=launcher_recovery_retry_started
LAUNCH_STATE=launcher_recovery_recovered
```

A failed final attempt must emit:

```text
LAUNCH_STATE=launcher_recovery_dead_end
classification=launcher_recovery_dead_end
sameFailureAsPrevious=true|false
failureClass=<semantic failure class>
failureSignature=<normalized signature>
```

If the second attempt fails in the same semantic way, `sameFailureAsPrevious=true` makes the dead end unambiguous. A different second failure still ends the run, but records the changed classification instead of hiding it. The parent launcher process reads and preserves the child attempt's terminal recovery state instead of overwriting it with a generic child-exit failure.

## Machine-readable recovery artifact

Every scheduled retry, force-close completion, retry start, recovery, or dead end updates:

```text
BlacksmithGuild_LauncherRecovery.json
```

Schema:

```text
TbgLauncherRecovery.v1
```

The artifact includes:

```text
launchIntent
state
attempt
maxAttempts
retryCount
failureClass
failureSignature
previousFailureSignature
sameFailureAsPrevious
innerExitCode
reason
terminatedProcesses
launcherContextPath
forceCloseScope
runtimeProofClaim=false
```

This artifact is local generated evidence. It is not committed to the repo and does not prove the game loaded successfully unless the state is `recovered`, and even `recovered` proves only launcher recovery. `CollectDiagnostics.cmd` copies the newest recovery artifact into the diagnostic bundle under `status/BlacksmithGuild_LauncherRecovery.json`.

## Runtime proof boundary

Confirming the caution dialog proves only this:

```text
native launcher dependency caution was handled
```

Recovering after the bounded force-close retry proves only this:

```text
launcher setup recovered after one bounded retry
```

Neither result proves:

- loaded DLL identity;
- exact save identity;
- campaign readiness;
- MapTrade Automation;
- movement;
- arrival;
- trade;
- visible trade surface;
- Manual cleanup.

Those still require the visible-trade workflow artifacts.

## Relationship to Safe Mode

This is the same class of problem as Safe Mode handling: a native Bannerlord modal appears after a valid launch handoff and must be classified, acted on, and logged. The action differs:

| Modal | Default harness action | Meaning |
|---|---|---|
| Safe Mode | Decline Safe Mode | Continue normal launch |
| Dependency caution | Confirm | Acknowledge version mismatch and continue launch |

Silent fallback is not allowed.
