# Local Iteration Time Budget Doctrine

## Purpose

This doctrine exists because the local harness must serve the operator, not seize the operator's workstation.

AI agents must not issue long-running local tests by default. A 5-minute or 10-minute wait is not normal validation. A longer wait is allowed only for a small set of expected gameplay-long operations.

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

## Long-wait allowlist

There are only two timing classes:

1. normal operation: 30 seconds maximum
2. expected gameplay-long operation: longer than 30 seconds, never more than 5 minutes

The expected gameplay-long allowlist is intentionally small:

1. travel between settlements
2. blacksmithing batch work
3. trading batch work

No other task gets a long timeout by default.

A long-wait operation must be explicitly declared in the command, script parameter, output, and evidence. It must say which allowlisted class it belongs to and why it needs more than 30 seconds.

Acceptable evidence fields include:

```text
longWaitException=true
actionClass=travel_between_settlements
timeBudgetSec=180
maxTimeBudgetSec=300
reason=party is travelling across the campaign map
```

Silent long waits are forbidden.

## Long-wait ceilings

The hard ceiling for any expected gameplay-long operation is 5 minutes.

Recommended budgets:

| Action class | Default budget | Hard ceiling | Notes |
| --- | ---: | ---: | --- |
| `travel_between_settlements` | 180 seconds | 300 seconds | Use only after travel command ACK and active movement/route evidence. |
| `blacksmithing_batch_work` | 180 seconds | 300 seconds | Use only for actual batch smithing/refine/smelt/forge actions, not for menu discovery. |
| `trading_batch_work` | 180 seconds | 300 seconds | Use only for actual multi-item buy/sell batch execution, not for price reading or menu discovery. |

The five-minute ceiling is not a default. It is an upper bound for the allowlisted gameplay-long classes.

## Not long-wait operations

These are not long-wait operations and remain capped at 30 seconds:

- launching the game
- launcher navigation
- Continue / Play selection
- attach readiness
- detecting a process
- waiting for a command ACK
- reading JSON evidence
- classifying foreground loss
- checking whether movement proof exists
- menu discovery
- offline validation
- build verification unless the user explicitly asks for full validation
- cleanup / stop commands

If one of these cannot finish in 30 seconds, classify the failure and stop.

## Forbidden defaults

The following are forbidden as normal-path defaults:

- 120-second command acknowledgement waits
- 300-second launcher waits
- 600-second attach waits
- unbounded polling loops
- full validation bundles as the default double-click behavior
- live cert rituals unless the user explicitly requested certification
- treating the five-minute ceiling as a generic timeout for all tasks

Long timeout values may exist only behind one of the three allowlisted gameplay action classes.

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
- long waits are allowed only when the current action is one of the three allowlisted gameplay-long classes

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

### Allowed only for expected gameplay-long operations

```powershell
.\ForgeReboot.cmd -ActionClass travel_between_settlements -LongActionTimeoutSec 180
.\ForgeReboot.cmd -ActionClass blacksmithing_batch_work -LongActionTimeoutSec 180
.\ForgeReboot.cmd -ActionClass trading_batch_work -LongActionTimeoutSec 180
```

The timeout must never exceed 300 seconds.

### Forbidden unless explicitly authorized by the user

```powershell
.\ForgeVerify.cmd -Full
.\ForgeReboot.cmd -MaxIterations 3 with live game launch
scripts\run-autonomous-assist-session.ps1 -AttachWaitSec 600
scripts\launcher-auto-nav.ps1 -TimeoutSec 300
any manual cert command expected to run longer than 30 seconds
any generic 5-minute timeout not tied to travel, blacksmithing, or trading batch work
```

## Design principle

Do not make the operator wait for ambiguity.

After 30 seconds, classify the ambiguity, write the handoff, and stop.

For travel, blacksmithing, and trading batch work, a longer window is allowed only because the gameplay action itself can legitimately take longer. Even then, the five-minute limit is a ceiling, not a habit.

The product is not a patient spinner. The product is a disciplined local judge.
