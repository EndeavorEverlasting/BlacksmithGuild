# Offline regression: shared checkpoint/finalization contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')

$tmpRoot = Join-Path $env:TEMP "automation-checkpoint-finalization-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

$events = New-Object System.Collections.Generic.List[object]
$sessionId = 'offline-checkpoint-test'

foreach ($checkpoint in @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started')) {
    Add-AutomationCheckpointEvent -List $events -CheckpointName $checkpoint -SessionId $sessionId `
        -Runner 'test-automation-checkpoint-finalization.ps1' | Out-Null
}

$beforeSummary = Test-AutomationPassCriteria -Events @($events.ToArray()) `
    -Summary ([pscustomobject]@{ assistLoopStarted = $true; stateMachineConsumed = $true; runtimeLifecycleConsumed = $true }) `
    -RequiredCheckpoints @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written') `
    -RequireAssistLoopStarted
if ($beforeSummary.pass) { throw 'checkpoint-only sequence must not pass before summary_written' }
if (@($events.ToArray() | Where-Object { $_.isTerminal -eq $true }).Count -ne 0) {
    throw 'checkpoint_reached events must not be terminal'
}

Add-AutomationCheckpointEvent -List $events -CheckpointName 'summary_written' -SessionId $sessionId `
    -Runner 'test-automation-checkpoint-finalization.ps1' | Out-Null
$strictBeforeTerminal = Test-AutomationPassCriteria -Events @($events.ToArray()) `
    -Summary ([pscustomobject]@{ assistLoopStarted = $true; stateMachineConsumed = $true; runtimeLifecycleConsumed = $true }) `
    -RequiredCheckpoints @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written') `
    -RequireAssistLoopStarted
if ($strictBeforeTerminal.pass) { throw 'strict criteria must not pass before terminal finalized_pass exists' }
$criteria = Get-AutomationProjectedTerminalCriteria -Events @($events.ToArray()) -State pass `
    -Summary ([pscustomobject]@{ assistLoopStarted = $true; stateMachineConsumed = $true; runtimeLifecycleConsumed = $true }) `
    -RequiredCheckpoints @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written') `
    -RequireAssistLoopStarted
if (-not $criteria.pass) { throw "expected projected terminal criteria pass, missing=$($criteria.missingCheckpoints -join ',')" }

$start = Start-AutomationFinalization -List $events -SessionId $sessionId -Runner 'test'
$terminal = Complete-AutomationFinalization -List $events -State pass -SessionId $sessionId `
    -Runner 'test' -Criteria $criteria -RelatedEventId $start.eventId -SummaryWritten:$true
if (-not $terminal.isTerminal -or $terminal.eventType -ne 'finalized_pass') {
    throw 'finalized_pass must be terminal'
}
if ($terminal.relatedEventId -ne $start.eventId) {
    throw 'finalized event must link to finalization_started'
}

$jsonl = Join-Path $tmpRoot 'checkpoint-events.jsonl'
Write-AutomationCheckpointEventsFile -Events @($events.ToArray()) -Path $jsonl | Out-Null
$lines = @(Get-Content -LiteralPath $jsonl)
if ($lines.Count -lt 7) { throw "expected jsonl events, got $($lines.Count)" }
if (($lines[-1] | ConvertFrom-Json).eventType -ne 'finalized_pass') {
    throw 'last event should be finalized_pass'
}

$modPath = Join-Path $tmpRoot 'BlacksmithGuild_AutomationEvents.jsonl'
(@{ schemaVersion = 1; eventId = 'mod-1'; atUtc = (Get-Date).ToUniversalTime().ToString('o'); eventType = 'checkpoint_reached'; checkpointName = 'probe_ack'; isTerminal = $false } |
    ConvertTo-Json -Compress) | Set-Content -LiteralPath $modPath -Encoding UTF8
$merged = Merge-AutomationCheckpointEvents -RunnerEvents @($events.ToArray()) -ModEventPaths @($modPath)
if (@($merged | Where-Object { $_.eventId -eq 'mod-1' }).Count -ne 1) {
    throw 'mod JSONL event must merge into checkpoint-events.jsonl'
}

$firstThrottle = Test-AutomationCheckpointThrottle -CheckpointName 'attach_ready' -ThrottleSeconds 60
$secondThrottle = Test-AutomationCheckpointThrottle -CheckpointName 'attach_ready' -ThrottleSeconds 60
if (-not $firstThrottle -or $secondThrottle) {
    throw 'duplicate checkpoint throttle must suppress immediate repeat'
}

Remove-Item -LiteralPath $tmpRoot -Recurse -Force
Write-Host 'PASS automation checkpoint finalization contract' -ForegroundColor Green
exit 0
