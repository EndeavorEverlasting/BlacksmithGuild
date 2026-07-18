# Launcher Safe Mode Handoff Doctrine

Safe Mode is part of launcher handoff.

It is not post-launch gameplay.
It is not a next-sprint map/runtime problem.
It is not solved by adding a longer timeout.

## Required handoff classification

After PLAY or CONTINUE, frozen launcher hwnd invalidation must classify the next state:

``text
frozen_target_invalidated
  -> game_spawned
  -> Safe Mode modal
  -> operator_action_required
``

## Safe Mode rule

If the same launcher process exposes a window titled Safe Mode, the launcher path must treat it as a handoff substate.

For Bannerlord Safe Mode, the intended action is:

``text
Alt+N = No = decline Safe Mode = continue normal launch
``

Do not use `Alt+C` unless the actual dialog has a Continue button with C as its accelerator.
Do not choose Safe Mode for normal ForgeContinue smoke.
Do not treat Safe Mode as runtime proof.
Do not hide Safe Mode behind a longer wait.

## Required evidence tokens

Future launcher handoff work must preserve explicit Safe Mode evidence:

``text
safe_mode_detected
decline_safe_mode
safe_mode_normal_launch
safeModeHandled=true
postInvalidationResult=game_spawned
post_handoff_watch
operator_action_required
``

Silent fallback is not allowed.