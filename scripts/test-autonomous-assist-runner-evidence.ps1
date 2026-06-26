# Offline regression: autonomous assist runner evidence bundle writes campaign-loop-summary.json
# and checkpoint-events.jsonl with exactly one terminal finalization — no game launch.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')
. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')
. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')

$tmpRoot = Join-Path $env:TEMP "autonomous-assist-runner-evidence-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
$evidenceDir = Join-Path $tmpRoot 'evidence'
$bannerlordRoot = Join-Path $tmpRoot 'bannerlord'
New-Item -ItemType Directory -Force -Path $evidenceDir, $bannerlordRoot | Out-Null

$sessionId = 'offline-runner-evidence-test'
$runner = 'test-autonomous-assist-runner-evidence.ps1'
$evidence = New-AutonomousAssistSessionEvidence -SessionId $sessionId -CheckpointDir $evidenceDir `
    -AssistProfile 'training-map' -LaunchIntent 'continue' -TargetSettlement 'Ortysia'
$evidence.assistLoopStarted = $true
$evidence.assistLoopStartedWithoutHotkey = $true
$evidence.iterationCount = 2

$lastDecision = [pscustomobject]@{
    atUtc = (Get-Date).ToUniversalTime().ToString('o')
    actionConsidered = 'observe_route'
    decision = 'observe'
    reason = 'campaign_map_observe_no_spam'
    plannedBranch = 'observe_only'
    recursiveBranchConsumed = $true
}

$recursiveBranchState = @{
    schemaVersion = 1
    updatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    currentTown = 'Ortysia'
    currentSettlementId = 'town_ES3'
    gameplaySurface = 'campaign_map'
    terminal = $false
    nextActionRequired = $true
    nextPlannedBranch = 'observe_only'
    nextActionReason = 'branch_truth_requires_fresh_observation'
    branches = @{
        travel = @{ state = 'blocked'; reason = 'travel_surface_blocked' }
        trade = @{ state = 'blocked'; reason = 'trade_surface_not_open' }
        smith_refine = @{ state = 'blocked'; reason = 'smithing_surface_not_open' }
        rest_wait = @{ state = 'available'; reason = 'safe_wait_surface' }
        tavern_scan = @{ state = 'blocked'; reason = 'not_at_settlement_surface' }
        companion_roster = @{ state = 'unknown'; reason = 'companion_roster_not_scanned' }
        avoid_threat = @{ state = 'unknown'; reason = 'threat_state_unknown_until_posture_scan_consumed' }
        observe_only = @{ state = 'available'; reason = 'always_safe_fallback' }
    }
}
$rbsDir = Join-Path $tmpRoot 'rbs'
New-Item -ItemType Directory -Force -Path $rbsDir | Out-Null
$rbsPath = Join-Path $rbsDir 'status.json'
(@{ stateMachine = @{ gameplaySurface = 'campaign_map' }; recursiveBranchState = $recursiveBranchState } |
    ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $rbsPath -Encoding UTF8
$parsedRbs = Read-Pr11RecursiveBranchStateFromStatus -StatusPath $rbsPath
if (-not $parsedRbs.fresh) { throw 'runner evidence recursiveBranchState fixture must be fresh' }

Write-AutonomousAssistCycleCampaignSummary -Evidence $evidence -LastDecision $lastDecision `
    -SessionId $sessionId -TargetSettlement 'Ortysia' -CycleId 2 `
    -RecursiveBranchState $parsedRbs -RecursiveBranchFresh $true | Out-Null
$midCycle = Get-Content -LiteralPath (Join-Path $evidenceDir 'campaign-loop-summary.json') -Raw | ConvertFrom-Json
if ($midCycle.terminal -ne $false) { throw 'mid-cycle campaign summary must be non-terminal' }
if ($midCycle.nextPlannedBranch -ne 'observe_only') { throw 'mid-cycle summary must use recursive nextPlannedBranch' }
if ($midCycle.currentTown -ne 'Ortysia') { throw 'mid-cycle summary must use recursive currentTown' }

foreach ($checkpoint in @(
    'session_started', 'attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed',
    'assist_loop_started', 'cycle_completed', 'next_action_planned'
)) {
    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName $checkpoint `
        -SessionId $sessionId -Phase 'assist_loop' -Runner $runner `
        -Reason $(if ($checkpoint -eq 'next_action_planned') { 'branch=observe_only' } else { $null }) | Out-Null
}

$assistSummary = @{
    passFail = 'PASS'
    stopReason = 'user_toggle_off'
    failureClass = $null
    endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    iterationCount = 2
    assistLoopStarted = $true
    assistLoopStartedWithoutHotkey = $true
    stateMachineConsumed = $true
    runtimeLifecycleConsumed = $true
    readinessConfidence = 'state_machine'
    travelExecuted = $false
    gameProcessAlive = $true
}

Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'summary_written' `
    -SessionId $sessionId -Phase 'finalization' -Runner $runner -Reason 'assist-loop-summary.json prepared' | Out-Null

$start = Start-AutomationFinalization -List $evidence.checkpointEvents -SessionId $sessionId `
    -Phase 'finalization' -Runner $runner -Reason 'user_toggle_off'
$criteria = Get-AutomationProjectedTerminalCriteria -Events @($evidence.checkpointEvents.ToArray()) `
    -State pass -Summary ([pscustomobject]$assistSummary) -RequireAssistLoopStarted `
    -RequiredCheckpoints @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')
Complete-AutomationFinalization -List $evidence.checkpointEvents -State pass -SessionId $sessionId `
    -Phase 'finalization' -Runner $runner -Reason 'user_toggle_off' -Criteria $criteria `
    -RelatedEventId $start.eventId -SummaryWritten:$true -GameProcessAlive $true | Out-Null

$assistSummary.terminalState = 'pass'
$assistSummary.finalizedEventId = @($evidence.checkpointEvents.ToArray() | Where-Object { $_.isTerminal -eq $true } | Select-Object -Last 1).eventId
$assistSummary.automationPassCriteria = $criteria

$assistSummary = Merge-AutonomousAssistCampaignLoopSummary -Summary $assistSummary -SessionId $sessionId `
    -TargetSettlement 'Ortysia' -LastDecision $lastDecision -CycleId 2 `
    -RecursiveBranchState $parsedRbs -RecursiveBranchFresh $true -CurrentTown 'Ortysia'
if (-not $assistSummary.campaignLoopSummary) { throw 'Merge-AutonomousAssistCampaignLoopSummary did not set campaignLoopSummary' }

$statusPath = Join-Path $bannerlordRoot 'BlacksmithGuild_Status.json'
$runtimePath = Join-Path $bannerlordRoot 'BlacksmithGuild_RuntimeLifecycle.json'
(@{
    stateMachine = @{ hasStateMachine = $true; gameplaySurface = 'campaign_map' }
    recursiveBranchState = $recursiveBranchState
} | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $statusPath -Encoding UTF8
'{"parseOk":true,"lastHeartbeatUtc":"2026-01-01T00:00:00Z"}' | Set-Content -LiteralPath $runtimePath -Encoding UTF8

Save-AutonomousAssistSessionEvidence -Evidence $evidence -Summary $assistSummary `
    -BannerlordRoot $bannerlordRoot -StatusPath $statusPath -RuntimeLifecyclePath $runtimePath | Out-Null

foreach ($required in @(
    'checkpoint-events.jsonl', 'campaign-loop-summary.json', 'assist-loop-summary.json',
    'session-manifest.json', 'assist-loop-timeline.json'
)) {
    $p = Join-Path $evidenceDir $required
    if (-not (Test-Path -LiteralPath $p)) { throw "missing runner evidence file: $required" }
}

$terminalCount = @(
    Get-Content -LiteralPath (Join-Path $evidenceDir 'checkpoint-events.jsonl') |
        ForEach-Object { $_ | ConvertFrom-Json } |
        Where-Object { $_.isTerminal -eq $true }
).Count
if ($terminalCount -ne 1) { throw "expected exactly one terminal checkpoint event; got $terminalCount" }

$campaignParsed = Get-Content -LiteralPath (Join-Path $evidenceDir 'campaign-loop-summary.json') -Raw | ConvertFrom-Json
if (-not (Test-AutomationCampaignLoopSummary -Summary $campaignParsed).pass) {
    throw 'runner-emitted campaign-loop-summary.json failed contract'
}
if ($campaignParsed.terminal -ne $true) { throw 'terminal session must write terminal=true campaign summary' }
if ($campaignParsed.nextActionRequired -eq $true) { throw 'terminal campaign summary must not require next action' }

$recursiveVerifier = Join-Path $PSScriptRoot 'test-recursive-campaign-output-contract.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $recursiveVerifier -EvidenceDir $evidenceDir
if ($LASTEXITCODE -ne 0) { throw 'recursive output verifier failed on runner-emitted evidence dir' }

Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'PASS offline autonomous assist runner evidence emission' -ForegroundColor Green
exit 0
