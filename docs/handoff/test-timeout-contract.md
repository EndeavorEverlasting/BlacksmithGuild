# Test Timeout Contract

This document codifies the short-timeout doctrine for BlacksmithGuild offline verifiers, smoke wrappers, and agent sprint plans.

The project has historically used long waits to make launcher/game automation robust. That was useful during discovery, but it makes agent work slow, hides hangs, and encourages fake patience instead of sharper classifications.

The default rule is now:

```text
Most offline tests and contract verifiers should complete within 30 seconds.
Longer waits require an explicit runtime reason and a named classification.
```

## Scope

This doctrine applies to:

```text
scripts/verify-*.ps1
scripts/test-*.ps1
offline contract checks
operator smoke wrappers
assist/launcher harness polling loops
future PR validation plans
```

It does not mean every live Bannerlord runtime action must finish in 30 seconds. Real launcher/game startup, disposable save bootstrap, and visible travel proof may need longer, but those paths must be labeled as runtime proof and must not be confused with offline verifier time.

## Timeout tiers

### Tier 0: static/offline verifier

Target:

```text
<= 30 seconds
```

Examples:

```text
verify-governor-operator-harness-contract.ps1
verify-regent-route-horse-contract.ps1
verify-post-attach-actionability-contract.ps1
verify-launcher-window-context-contract.ps1
verify-engine-toggle-authority-contract.ps1
test-powershell-utf8-bom-contract.ps1
```

Allowed work:

```text
read source files
check required strings/structure
parse local scripts
validate docs/contracts
```

Forbidden work:

```text
launch Bannerlord
wait for UI focus
wait for campaign load
poll runtime JSON for minutes
sleep for long stabilization windows
```

### Tier 1: bounded script smoke

Target:

```text
<= 30 seconds per wait segment
```

A bounded script smoke may have multiple phases, but each phase should have a short timeout and a named failure class.

Example classifications:

```text
launcher_context_missing
status_heartbeat_stale
command_ack_timeout
safe_idle_no_branch_progress
safe_idle_clock_stopped
movement_not_observed
operator_focus_required
```

### Tier 2: live runtime proof

Target:

```text
longer than 30 seconds allowed only when explicitly classified as live runtime proof
```

Examples:

```text
disposable dev-save bootstrap
launcher PLAY/CONTINUE automation
visible mechanics proof
movement observation
```

Requirement:

```text
Every wait above 30 seconds must be justified by the proof mode and must emit a progress classification.
```

## Required patterns

Prefer centralized constants:

```powershell
$DefaultOfflineTimeoutSeconds = 30
$DefaultPollIntervalMilliseconds = 500
```

Prefer bounded waits:

```powershell
$deadline = (Get-Date).AddSeconds($DefaultOfflineTimeoutSeconds)
while ((Get-Date) -lt $deadline) {
    # poll/check once
    Start-Sleep -Milliseconds $DefaultPollIntervalMilliseconds
}
throw "timeout: <classification>"
```

Do not use anonymous sleeps:

```powershell
Start-Sleep -Seconds 60
Start-Sleep -Seconds 120
Start-Sleep -Seconds 300
```

If a long wait is unavoidable, it must be named:

```powershell
$LauncherStartupTimeoutSeconds = 120 # live runtime proof only: launcher startup can be slow
```

and the script must report why it is waiting.

## Agent sprint rule

Every future sprint prompt should ask agents to report:

```text
longest offline verifier runtime
any waits over 30 seconds
any waits over 30 seconds that remain justified
any suspected hang points converted into fail-fast classifications
```

## Refactor targets

Agents should inspect and shorten these first:

```text
scripts/verify-*.ps1
scripts/test-*.ps1
scripts/run-*-smoke*.ps1
scripts/run-autonomous-assist-session.ps1
scripts/autonomous-assist-session.ps1
scripts/launcher-auto-nav.ps1
scripts/pr11-runtime-state-consumer.ps1
```

Refactor principle:

```text
A test should fail with a useful classification before it makes the user wait.
```

## What not to do

Do not blindly replace all timeouts with 30 seconds.

Instead:

```text
offline verifiers: target 30 seconds or less
poll segments: 30 seconds per segment
live runtime proof: longer allowed with named classification and progress logging
```

Do not call a shorter timeout a PASS by itself. A shorter timeout is only useful if the failure classification gets sharper.

## Next implementation sprint

Create or update:

```text
scripts/verify-test-timeout-contract.ps1
```

The verifier should scan `scripts/verify-*.ps1`, `scripts/test-*.ps1`, and core runner scripts for:

```text
Start-Sleep -Seconds 60/120/180/300
TimeoutSeconds defaults above 30 in offline verifiers
hard-coded 300-second loops without proof-mode classification
unclassified polling loops
```

It should allow longer waits only when the script contains a live-runtime marker such as:

```text
live runtime proof
launcher startup
disposable dev-save bootstrap
visible mechanics proof
operator focus
```

The goal is not to make every runtime action short. The goal is to make offline tests short and runtime waits honest.
