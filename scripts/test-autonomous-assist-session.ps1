# Offline regression: autonomous assist session loop — readiness, toggle, safety, post-handoff fast-fail, evidence.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')
. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')

$tmpRoot = Join-Path $env:TEMP "autonomous-assist-session-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function New-StatusFixture {
    param([hashtable]$StateMachine = $null, [hashtable]$Session = $null)
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $obj = [ordered]@{ updatedAt = $now; session = if ($Session) { $Session } else { [ordered]@{} } }
    if ($StateMachine) {
        if (-not $StateMachine.Contains('updatedAtUtc')) { $StateMachine['updatedAtUtc'] = $now }
        $obj['stateMachine'] = $StateMachine
    }
    return ($obj | ConvertTo-Json -Depth 8)
}

function New-RuntimeFixture {
    param([hashtable]$Fields = @{})
    $base = [ordered]@{
        schemaVersion = 1
        lastHeartbeatUtc = (Get-Date).ToUniversalTime().ToString('o')
        gracefulShutdownObserved = $false
    }
    foreach ($k in $Fields.Keys) { $base[$k] = $Fields[$k] }
    return ($base | ConvertTo-Json -Depth 6)
}

function Build-Readiness {
    param([string]$Surface, [bool]$WithStateMachine = $true, [bool]$StaleHeartbeat = $false)
    $statusPath = Join-Path $tmpRoot "status-$Surface.json"
    $session = [ordered]@{
        readinessSurface = $Surface
        canPollFileInbox = $true
        inGameAssistReady = $true
        canAcceptAssistiveCommand = $true
        campaignReady = $true
    }
    $sm = if ($WithStateMachine) {
        @{
            gameplaySurface = $Surface
            gameLifecycle = 'campaign_loaded'
            safeToExecuteTravel = ($Surface -in @('settlement_menu', 'campaign_map'))
            safeToExecuteSmithing = ($Surface -eq 'blacksmithing')
            safeToExecuteTrade = ($Surface -eq 'trading')
            canAcceptAssistiveCommand = $true
            blockReason = $null
        }
    } else { $null }
    New-StatusFixture -StateMachine $sm -Session $session | Set-Content -LiteralPath $statusPath -Encoding UTF8

    $hb = if ($StaleHeartbeat) { (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o') } else { (Get-Date).ToUniversalTime().ToString('o') }
    $runtimePath = Join-Path $tmpRoot "runtime-$Surface.json"
    New-RuntimeFixture @{ lastHeartbeatUtc = $hb } | Set-Content -LiteralPath $runtimePath -Encoding UTF8

    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $tmpRoot
    $ready.runtimeLifecycle = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $runtimePath
    $ready.heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $ready.runtimeLifecycle
    return $ready
}

# AutoAssistLoop starts after stateMachine readiness
$readySm = Build-Readiness -Surface 'settlement_menu'
$loopReady = Test-AutonomousAssistLoopReadiness -Readiness $readySm
if (-not $loopReady.ready) { throw "expected loop ready got $($loopReady.reason)" }
if (-not $loopReady.stateMachineConsumed) { throw 'stateMachineConsumed must be true' }
if (-not $loopReady.runtimeLifecycleConsumed) { throw 'runtimeLifecycleConsumed must be true' }
if ($loopReady.readinessConfidence -ne 'state_machine') { throw 'expected state_machine confidence' }

# missing stateMachine blocks autonomous loop
$readyNoSm = Build-Readiness -Surface 'settlement_menu' -WithStateMachine $false
$blockedNoSm = Test-AutonomousAssistLoopReadiness -Readiness $readyNoSm
if ($blockedNoSm.ready) { throw 'missing stateMachine must block loop' }
if ($blockedNoSm.reason -ne 'missing_stateMachine') { throw "expected missing_stateMachine got $($blockedNoSm.reason)" }

# stale RuntimeLifecycle heartbeat blocks autonomous loop
$readyStale = Build-Readiness -Surface 'settlement_menu' -StaleHeartbeat $true
$blockedStale = Test-AutonomousAssistLoopReadiness -Readiness $readyStale
if ($blockedStale.ready) { throw 'stale heartbeat must block loop' }
if ($blockedStale.reason -ne 'runtime_heartbeat_stale') { throw "expected runtime_heartbeat_stale got $($blockedStale.reason)" }

# settlement_menu permits travel action
$decisionSettlement = Get-AutonomousAssistIterationDecision -Readiness $readySm -AssistProfile 'training-map' -TargetSettlement 'Ortysia'
if ($decisionSettlement.decision -ne 'allowed') { throw "settlement_menu must allow travel got $($decisionSettlement.decision)" }
if ($decisionSettlement.commandSent -ne 'AssistiveLeaveTownAndTravel') { throw 'expected travel command' }

# campaign_map observes without spam
$readyMap = Build-Readiness -Surface 'campaign_map'
$decisionMap = Get-AutonomousAssistIterationDecision -Readiness $readyMap -AssistProfile 'training-map'
if ($decisionMap.decision -ne 'observe') { throw "campaign_map must observe got $($decisionMap.decision)" }
if ($decisionMap.commandSent) { throw 'campaign_map must not send command' }

# unsafe surface logs block
$readyConv = Build-Readiness -Surface 'conversation'
$readyConv.stateMachine.safeToExecuteTravel = $false
$decisionUnsafe = Get-AutonomousAssistIterationDecision -Readiness $readyConv -AssistProfile 'training-map' -StopOnUnsafeState:$true
if ($decisionUnsafe.decision -ne 'stop_unsafe_surface') { throw "unsafe surface must stop got $($decisionUnsafe.decision)" }

# toggle off
Write-TbgAssistToggle -BannerlordRoot $tmpRoot -Enabled $true -RequestedBy 'test' -Reason 'on' | Out-Null
if (Test-TbgAssistToggleOff -BannerlordRoot $tmpRoot) { throw 'toggle enabled must not read as off' }
Write-TbgAssistToggle -BannerlordRoot $tmpRoot -Enabled $false -RequestedBy 'user' -Reason 'stop autonomous assist loop' | Out-Null
if (-not (Test-TbgAssistToggleOff -BannerlordRoot $tmpRoot)) { throw 'toggle off must be detected' }

# CancelRun cancels entire runner
$cancelPath = Get-TbgCancelRunJsonPath -BannerlordRoot $tmpRoot
@{ reason = 'user_cancel'; requestedAtUtc = (Get-Date).ToUniversalTime().ToString('o') } | ConvertTo-Json |
    Set-Content -LiteralPath $cancelPath -Encoding UTF8
$script:TbgCancelRequested = $false
if (-not (Test-TbgCancelRequested -BannerlordRoot $tmpRoot)) { throw 'CancelRun must be detected' }

$clearedCancel = Clear-TbgStaleCancelRun -BannerlordRoot $tmpRoot -RunStartedAtUtc (Get-Date).ToUniversalTime().AddSeconds(1)
if (@($clearedCancel).Count -lt 1) { throw 'stale CancelRun must be cleared for a fresh session' }
if (Test-Path -LiteralPath $cancelPath) { throw 'stale CancelRun file must be removed' }
@{ reason = 'fresh_cancel'; requestedAtUtc = (Get-Date).ToUniversalTime().AddSeconds(5).ToString('o') } | ConvertTo-Json |
    Set-Content -LiteralPath $cancelPath -Encoding UTF8
$clearedFreshCancel = Clear-TbgStaleCancelRun -BannerlordRoot $tmpRoot -RunStartedAtUtc (Get-Date).ToUniversalTime()
if (@($clearedFreshCancel).Count -ne 0) { throw 'fresh CancelRun must not be cleared' }
Remove-Item -LiteralPath $cancelPath -Force -ErrorAction SilentlyContinue

# post-handoff fast fail — game gone after handoff, not 600s wait
$detAlive = [pscustomobject]@{ gameProcessRunning = $true }
$detGone = [pscustomobject]@{ gameProcessRunning = $false }
if (Test-TbgPostHandoffFastFail -Detection $detAlive -HandoffCompleted $true -AttachReady $false -GameProcessEverSeenAfterHandoff $true) {
    throw 'alive game must not fast-fail'
}
$ffSeen = Test-TbgPostHandoffFastFail -Detection $detGone -HandoffCompleted $true -AttachReady $false -GameProcessEverSeenAfterHandoff $true
if ($ffSeen.classification -ne 'process_disappeared_during_post_handoff') {
    throw "expected process_disappeared_during_post_handoff got $($ffSeen.classification)"
}
$ffNever = Test-TbgPostHandoffFastFail -Detection $detGone -HandoffCompleted $true -AttachReady $false -GameProcessEverSeenAfterHandoff $false
if ($ffNever.classification -ne 'game_exited_unexpectedly_before_attach') {
    throw "expected game_exited_unexpectedly_before_attach got $($ffNever.classification)"
}

# launcher-auto-nav exit must not terminate the parent runner
$childNav = Join-Path $tmpRoot 'fake-launcher-auto-nav.ps1'
@'
param(
    [string]$LaunchIntent,
    [string]$BannerlordRoot,
    [int]$TimeoutSec,
    [switch]$LaunchSetup,
    [int]$LauncherSelectionMaxMs,
    [string]$ExternalStateTimelinePath,
    [bool]$RespectUserForeground = $true
)
Write-Host 'launcher-auto: LAUNCH_STATE=handoff'
Write-Host 'launcher-auto: post-handoff: Bannerlord exited'
exit 3
'@ | Set-Content -LiteralPath $childNav -Encoding UTF8
$childResult = Invoke-TbgLauncherAutoNavChild -ScriptPath $childNav -LaunchIntent 'continue' `
    -BannerlordRoot $tmpRoot -ExternalStateTimelinePath (Join-Path $tmpRoot 'ExternalStateTimeline.json')
if ($childResult.exitCode -eq 0) { throw 'expected non-zero child nav exit' }
if ($childResult.text -notmatch 'post-handoff: Bannerlord exited') {
    throw 'child nav output must be captured for post-handoff classification'
}

# CertTarget continue is forwarded into launcher-auto-nav child command
$certNav = Join-Path $tmpRoot 'cert-target-launcher-auto-nav.ps1'
@'
param(
    [string]$LaunchIntent,
    [string]$BannerlordRoot,
    [int]$TimeoutSec,
    [switch]$LaunchSetup,
    [int]$LauncherSelectionMaxMs,
    [string]$ExternalStateTimelinePath,
    [bool]$RespectUserForeground = $true,
    [string]$CertTarget = 'any'
)
Write-Host "certTarget=$CertTarget"
exit 0
'@ | Set-Content -LiteralPath $certNav -Encoding UTF8
$certResult = Invoke-TbgLauncherAutoNavChild -ScriptPath $certNav -LaunchIntent 'continue' `
    -BannerlordRoot $tmpRoot -CertTarget 'continue' -ExternalStateTimelinePath (Join-Path $tmpRoot 'ExternalStateTimeline-cert.json')
if ($certResult.text -notmatch 'certTarget=continue') {
    throw 'Invoke-TbgLauncherAutoNavChild must forward CertTarget continue to launcher-auto-nav'
}

# launcher-menu / uncertain detections must not count as real game spawn for adoption paths
$hostedOnly = [pscustomobject]@{
    gameProcessRunning = $true
    gameAliveConfidence = 'launcher_hosted'
    gameProcessDetectionMethod = 'launcher_hosted_window'
    gameProcessCandidates = @()
}
if (Test-TbgRealGameSpawnDetection -Detection $hostedOnly) {
    throw 'launcher_hosted must not be treated as real game spawn'
}
$uncertainOnly = [pscustomobject]@{
    gameProcessRunning = $true
    gameAliveConfidence = 'process_detection_uncertain'
    gameProcessDetectionMethod = 'status_json_fresh'
    gameProcessCandidates = @()
}
if (Test-TbgRealGameSpawnDetection -Detection $uncertainOnly) {
    throw 'process_detection_uncertain must not be treated as real game spawn'
}
$definite = [pscustomobject]@{
    gameProcessRunning = $true
    gameAliveConfidence = 'definite'
    gameProcessDetectionMethod = 'process_name_bannerlord'
    gameProcessCandidates = @()
}
if (-not (Test-TbgRealGameSpawnDetection -Detection $definite)) {
    throw 'definite Bannerlord.exe detection must count as real game spawn'
}

# timeline / summary evidence files written
$evidenceDir = Join-Path $tmpRoot 'evidence'
$evidence = New-AutonomousAssistSessionEvidence -SessionId 'test-session' -CheckpointDir $evidenceDir `
    -AssistProfile 'training-map' -LaunchIntent 'continue' -TargetSettlement 'Ortysia'
$evidence.assistLoopStarted = $true
$evidence.assistLoopStartedWithoutHotkey = $true
Add-AssistSessionJsonl -List $evidence.timeline -Event ([ordered]@{ atUtc = (Get-Date).ToUniversalTime().ToString('o'); iteration = 1; decision = 'wait' })
$summary = [ordered]@{
    passFail = 'PASS'; failureClass = $null; stopReason = 'user_toggle_off'
    classification = 'user_toggle_off'; endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
}
Save-AutonomousAssistSessionEvidence -Evidence $evidence -Summary $summary -BannerlordRoot $tmpRoot `
    -StatusPath (Join-Path $tmpRoot 'status-settlement_menu.json') -RuntimeLifecyclePath (Join-Path $tmpRoot 'runtime-settlement_menu.json') | Out-Null
foreach ($required in @(
    'session-manifest.json', 'assist-loop-timeline.json', 'assist-loop-summary.json',
    'state-snapshots.jsonl', 'command-timeline.jsonl', 'toggle-events.jsonl',
    'safety-decisions.jsonl', 'travel-decisions.jsonl', 'training-decisions.jsonl'
)) {
    $p = Join-Path $evidenceDir $required
    if (-not (Test-Path -LiteralPath $p)) { throw "missing evidence file $required" }
}
$summaryParsed = Get-Content -LiteralPath (Join-Path $evidenceDir 'assist-loop-summary.json') -Raw | ConvertFrom-Json
if ($summaryParsed.classification -ne 'user_toggle_off') { throw 'summary must record final classification' }

# runner must not require hotkey
$runnerText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1') -Raw
foreach ($needle in @(
    'autonomous-assist-session.ps1', 'Write-TbgAssistToggle', 'assistLoopStartedWithoutHotkey',
    'Test-TbgPostHandoffFastFail', 'Get-AutonomousAssistIterationDecision', 'AssistToggle',
    'Invoke-TbgLauncherAutoNavChild', 'process_disappeared_during_post_handoff', '-CertTarget', 'navCertTarget'
)) {
    if ($runnerText -notmatch [regex]::Escape($needle)) {
        throw "run-autonomous-assist-session.ps1 missing: $needle"
    }
}
if ($runnerText -match 'Register-HotKey|SendKeys|Wait-Hotkey') {
    throw 'autonomous assist runner must not require hotkey for main path'
}

Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'PASS offline autonomous assist session regression'
exit 0
