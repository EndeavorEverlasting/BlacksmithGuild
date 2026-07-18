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

Operator action is evidence. If the user clicks Play or Continue and the game transitions forward, that is a valid handoff signal, not automation failure.

The automation must read and classify the current launch state before guessing, waiting, or proposing a new launcher patch.

## Duration rule

Thirty seconds is the default launcher/test budget.

This rule applies everywhere unless a specific path is explicitly declared as a long-run path with a reason. The default applies to:

```text
front-door CMD wrappers
PowerShell launch wrappers
tests
verifiers
smoke runs
observation harnesses
launcher navigation
post-click verification
post-handoff readiness probes
command waits
attach probes
save/bootstrap probes
```

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
scripts/invoke-forge-launch-operator.ps1
Run-LauncherNavNow.cmd
Run-LauncherNavPlay.cmd
```

These normal front doors must use the shared duration policy default. They must not hardcode:

```text
-TimeoutSec 120
-TimeoutSec 300
-TimeoutSec 600
-AttachWaitSec 600
-MaxRuntimeMinutes 30
```

or any other long launcher/test budget without explicit long-run classification.

## Click verification rule

The overall launch budget is not a per-click budget.

A PLAY/CONTINUE click gets a short verification window. The click verifier should look quickly for:

```text
game_spawned
frozen_target_invalidated
operator_or_external_handoff_detected
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

## Operator action is evidence

The user may click Play or Continue manually during launcher automation.

If the user click causes a valid state transition, automation must consume that transition and continue from the new state. It must not fail because the script was not the actor that performed the click.

Valid evidence includes:

```text
Bannerlord.exe spawned
launcher hwnd/pid invalidated after click phase began
Launch.log reports game_spawned
Phase1 log appears or updates
Status.json reports modLoaded, campaignReady, canPollFileInbox, or hotkeys-ready equivalent
RuntimeLifecycle.json reports an attachable or campaign session state
```

Required classifications:

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
continuing to click launcher controls after game_spawned
treating operator click as automation failure
waiting for the script's own click proof after external handoff is already proven
claiming product PASS from game_spawned alone
```

## Log evidence rule

Before changing launcher logic or claiming launch status, agents must inspect the relevant log/status artifacts:

```text
Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
RuntimeLifecycle.json
ForgeStatus.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_CommandInbox.json
ExternalStateTimeline.json
```

The last known `LAUNCH_STATE` is the starting point for diagnosis.

If a status file, command ack, lifecycle file, or log line proves that the state transition already happened, the workflow must consume that evidence instead of waiting for an arbitrary alternate state that may not occur.

## State classification rule

Launcher automation must classify state transitions instead of waiting silently.

Minimum classifications:

```text
launcher_target_selected
launcher_click_phase
continue_clicked_or_play_clicked
operator_or_external_handoff_detected
game_spawned
post_handoff_watch
module_log_seen
status_json_seen
hotkeys_ready
assistive_commands_ready
operator_action_required
post_handoff_idle_unactionable
```

## Candidate evidence-consuming paths

The following paths are first-class candidates for replacing arbitrary waits with log/status consumption:

```text
launcher Play/Continue handoff
post-handoff readiness after game_spawned
existing attachable session reuse
command inbox / command ack waits
dev-save creation and save-file discovery
campaign attach waits
autonomous assist attach waits
acceptance/status scan summary
```

Known better pattern:

```text
Send-ForgeCommand already accepts CommandAck.json or Status.json as command evidence.
Other waits should copy that model: multiple authoritative evidence sources may advance the workflow.
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

It is not enough to verify that `launcher-frozen-context-nav.ps1` defaults to the shared duration policy. The verifier must also check that `Forge.cmd`, `ForgeContinue.cmd`, and other launcher-adjacent entry points do not override the default with a long timeout.

The verifier must fail if launcher front doors reintroduce long waits without explicit long-run markers and reasons.

The verifier must fail if the frozen click verifier lets one click consume the whole launch budget.

The verifier must require doctrine for operator activity as valid workflow evidence.
