# Duration Entrypoint Sweep

This sweep exists to prevent long waits from hiding in callers while the callee appears compliant with the shared 30-second duration policy.

The rule is simple:

```text
Check the callee.
Check the caller.
Check the wrapper.
Check the runner.
```

A script can appear compliant because its default timeout is policy-bound, while a caller quietly passes `-TimeoutSec 120`, `-TimeoutSec 300`, `-AttachWaitSec 600`, or `-MaxRuntimeMinutes 30`.

That caller override is policy-relevant and must be reviewed.

## Default rule

Thirty seconds is the default budget for tests, verifiers, smoke runs, CMD wrappers, launch wrappers, and observation harnesses.

A longer duration is allowed only when it is explicit and explained:

```text
AllowLongRun=true
LongRunReason=<specific reason>
```

Documented legacy debt may exist in a baseline, but a baseline is not permission to add new long waits.

## Sweep targets

These files are launch-adjacent or runtime-observation entry points and must be checked whenever the duration policy changes:

```text
Forge.cmd
ForgeContinue.cmd
LaunchForgeContinue.cmd
Run-LauncherNavNow.cmd
Run-LauncherNavPlay.cmd
forge.ps1
scripts/install-mod.ps1
scripts/open-bannerlord-launcher.ps1
scripts/launcher-window-context.ps1
scripts/launcher-frozen-context-nav.ps1
scripts/launcher-auto-nav.ps1
scripts/invoke-forge-launch-operator.ps1
scripts/run-autonomous-assist-session.ps1
scripts/autonomous-assist-session.ps1
scripts/run-pr11-town-travel-launch-attach-execute.ps1
scripts/ensure-dev-save.ps1
scripts/run-live-assistive-cert.ps1
scripts/run-stage-b-smithing-advisory-cert.ps1
scripts/run-stage-c-charcoal-cert.ps1
scripts/run-town-to-town-trade-assist-cert.ps1
scripts/run-tavern-hero-intel-cert.ps1
scripts/run-weapon-smelt-cert.ps1
scripts/run-character-build-catalog.ps1
scripts/test-local-iteration-contract-stubs.ps1
```

## Forbidden hidden overrides

Normal front doors and launcher-adjacent wrappers must not pass hidden long waits such as:

```text
-TimeoutSec 120
-TimeoutSec 180
-TimeoutSec 240
-TimeoutSec 300
-TimeoutSec 600
-AttachWaitSec 600
-BootstrapAttachWaitSec 1200
-ContinueAttachWaitSec 600
-MaxRuntimeMinutes 30
```

If a long duration remains because it is live-cert or autonomous-run debt, it must be either:

```text
- moved behind AllowLongRun / LongRunReason
- reduced to the 30-second policy default
- documented in the duration inventory baseline as existing debt
```

## Evidence-first replacement candidates

Before adding or keeping a wait, check whether one of these artifacts can advance the state machine instead:

```text
Launch.log
BlacksmithGuild_Phase1.log
BlacksmithGuild_Status.json
RuntimeLifecycle.json
ForgeStatus.json
BlacksmithGuild_CommandAck.json
BlacksmithGuild_CommandInbox.json
ExternalStateTimeline.json
window-snapshot-S1-pre-launch.json
launcher-window-context.json
```

The workflow should prefer evidence consumption over arbitrary waiting.

## Operator activity rule

Operator activity is not interference by default.

If the user clicks Play or Continue, and logs/process/status evidence proves the workflow advanced, the script must classify and continue from the advanced state.

Required classifications:

```text
operator_click_allowed
operator_or_external_handoff_detected
game_spawned_before_script_click
game_spawned_during_click_phase
post_handoff_watch
```

Forbidden classifications:

```text
operator clicked, therefore automation failed
script did not click, therefore ignore game_spawned
wait for script-click proof after external handoff is proven
```

## Review checklist

For each entry point:

```text
1. Does it pass a timeout to another script?
2. Is that timeout greater than 30 seconds?
3. Is it a normal front door, smoke, verifier, or observation harness?
4. If long, does it have AllowLongRun and LongRunReason?
5. Can logs/status files prove the same transition sooner?
6. Does operator activity advance the state machine instead of breaking it?
7. Does the verifier cover this caller, not just the callee?
```

## Expected verifier posture

The verifier should fail if:

```text
- Forge.cmd or ForgeContinue.cmd passes a long timeout into launcher navigation
- a click verifier uses the whole overall launcher deadline as its per-click deadline
- launcher doctrine omits operator activity as valid evidence
- duration doctrine omits caller/wrapper sweep requirements
```

The verifier may still allow documented baseline debt, but only as named debt. It must not allow new hidden long waits to enter through a caller override.
