# Local Iteration Time Budget Doctrine

## Purpose

This doctrine exists because the local harness must serve the operator, not seize the operator's workstation.

AI agents must not issue long-running local tests by default. A 5-minute or 10-minute wait is not normal validation. It is an exceptional operation and must be explicitly justified before it runs.

The default local testing posture is short, bounded, classifying, and interruptible.

## Hard rule

Normal operations must not wait more than 30 seconds.

This applies to:

- launcher detection
- Continue / Play selection
- attach readiness
- command acknowledgement
- assist-loop polling
- evidence harvest
- foreground recovery
- short movement proof sampling
- Reboot iteration
- offline validation steps
- process cleanup

If a normal path cannot produce success within 30 seconds, it must stop and classify the state. It must not keep waiting in hope.

## Allowed long-wait exceptions

Only these operation classes may exceed 30 seconds:

1. long-distance travel
2. smithing with a large party
3. massive trade operation
4. explicit user-requested full validation
5. explicit user-requested manual certification

A long wait must be explicit in the command, script parameter, output, and evidence.

Acceptable evidence fields include:

```text
longWaitException=true
actionClass=long_distance_travel
timeBudgetSec=180
reason=party is travelling across the campaign map
```

Silent long waits are forbidden.

## Forbidden defaults

The following are forbidden as normal-path defaults:

- 120-second command acknowledgement waits
- 300-second launcher waits
- 600-second attach waits
- unbounded polling loops
- full validation bundles as the default double-click behavior
- live cert rituals unless the user explicitly requested certification

These values may exist only behind an explicit long-wait action class or explicit user-requested full validation/certification mode.

## Harness behavior

A harness should prefer classification over waiting.

When a state cannot complete inside the normal 30-second budget, the harness must write a useful local result such as:

- `launcher_not_ready`
- `continue_not_found`
- `game_process_not_observed`
- `attach_not_ready`
- `foreground_blocked`
- `command_ack_timeout`
- `movement_observation_indeterminate`
- `evidence_harvest_timeout`
- `process_cleanup_incomplete`

The output must tell the next agent what to inspect and why.

## Reboot behavior

Reboot is the local iteration layer. It must not become a long-running cert ritual.

Required behavior:

- normal Reboot iterations use 30-second action windows
- repeated normalized context stops as `stable_gap`
- visible mechanics proof stops early as success
- operator interruption stops cleanly
- launcher/deploy/process problems are classified
- movement proof is checkpoint-based and does not rely only on `partyMovedDistance`

If Reboot proves visible mechanics, it should not continue merely to exhaust `MaxIterations`.

## ForgeVerify behavior

`ForgeVerify.cmd` must be safe as the default validation entrypoint.

Required behavior:

- default mode is fast validation
- each normal validation step has a 30-second budget
- full validation is opt-in only
- build-heavy or live-cert-heavy checks belong in explicit full mode
- failures stop with a clear section label and exit code
- output/evidence should identify the command that exceeded budget

The user should not have to type long PowerShell chains.

The AI should not run long validation chains unless the user explicitly asks for full validation.

## Agent command policy

AI agents must follow this command policy:

### Allowed by default

```powershell
$env:FORGE_NO_PAUSE=1
.\ForgeVerify.cmd -Fast
.\ForgeReboot.cmd -MaxIterations 1
Remove-Item Env:\FORGE_NO_PAUSE -ErrorAction SilentlyContinue
```

### Allowed with care

```powershell
.\ForgeReboot.cmd -MaxIterations 2 -NormalActionTimeoutSec 30
```

### Forbidden unless explicitly authorized by the user

```powershell
.\ForgeVerify.cmd -Full
.\ForgeReboot.cmd -MaxIterations 3 with live game launch
scripts\run-autonomous-assist-session.ps1 -AttachWaitSec 600
scripts\launcher-auto-nav.ps1 -TimeoutSec 300
any manual cert command expected to run longer than 30 seconds
```

## Design principle

Do not make the operator wait for ambiguity.

After 30 seconds, classify the ambiguity, write the handoff, and stop.

The product is not a patient spinner. The product is a disciplined local judge.
