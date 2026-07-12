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

## Runtime proof boundary

Confirming the caution dialog proves only this:

```text
native launcher dependency caution was handled
```

It does **not** prove:

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
