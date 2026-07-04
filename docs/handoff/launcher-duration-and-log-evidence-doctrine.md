# Launcher Duration and Log Evidence Doctrine

This doctrine exists because launcher automation already writes useful evidence, but the front-door scripts allowed a long launcher wait to bypass the shared 30-second duration policy.

The failure pattern was simple:

```text
Forge.cmd / ForgeContinue.cmd passed -TimeoutSec 120 into launcher-frozen-context-nav.ps1.
The launcher context verifier checked the frozen-nav script default, but not the front-door wrapper arguments.
A single PLAY/CONTINUE click could then wait against the whole launcher budget.
Agents saw PID/window/log evidence, but treated it as after-action evidence instead of live control state.
```

That is forbidden going forward.

## Plain rule

Launcher logs are live state. They are not decoration.

The automation must read and classify the current launch state before guessing, waiting, or proposing a new launcher patch.

## Duration rule

Thirty seconds is the default launcher/test budget.

Front-door wrappers must not pass a long timeout to launcher navigation unless all of the following are true:

```text
- the long run is explicitly requested
- AllowLongRun is present
- LongRunReason is present
- the reason explains why the run is not a normal launcher/test path
```

Normal front doors include:

```text
Forge.cmd
ForgeContinue.cmd
LaunchForgeContinue.cmd
forge.ps1 -Launch
scripts/install-mod.ps1 -Launch
```

These normal front doors must use the shared duration policy default. They must not hardcode:

```text
-TimeoutSec 120
-TimeoutSec 300
-TimeoutSec 600
```

or any other long launcher budget.

## Click verification rule

The overall launch budget is not a per-click budget.

A PLAY/CONTINUE click gets a short verification window. The click verifier should look quickly for:

```text
game_spawned
frozen_target_invalidated
click_unverified_timeout
```

If no evidence appears quickly, the script should log the result and retry or classify. A single missed or unverified click must not consume the whole overall launch budget.

Required log states:

```text
CLICK_VERIFY_POLICY
CLICK_VERIFY_STARTED
CLICK_VERIFY_RESULT
LAUNCH_STATE=click_unverified_timeout
```

## Log evidence rule

Before changing launcher logic or claiming launch status, agents must inspect the relevant log/status artifacts:

```text
Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
RuntimeLifecycle.json
ForgeStatus.json
```

The last known `LAUNCH_STATE` is the starting point for diagnosis.

## State classification rule

Launcher automation must classify state transitions instead of waiting silently.

Minimum classifications:

```text
launcher_target_selected
launcher_click_phase
continue_clicked_or_play_clicked
game_spawned
post_handoff_watch
hotkeys_ready
assistive_commands_ready
operator_action_required
post_handoff_idle_unactionable
```

## No PASS from loading alone

`game_spawned` is not product success.

```text
game_spawned != hotkeys_ready
game_spawned != assistive_ready
game_spawned != automation_allowed
loaded_game != controlled_runtime
```

A loaded game is a checkpoint. It is not completion.

## Contract expectations

The verifier must check both doctrine and callers.

It is not enough to verify that `launcher-frozen-context-nav.ps1` defaults to the shared duration policy. The verifier must also check that `Forge.cmd` and `ForgeContinue.cmd` do not override the default with a long timeout.

The verifier must fail if launcher front doors reintroduce long waits without explicit long-run markers and reasons.
