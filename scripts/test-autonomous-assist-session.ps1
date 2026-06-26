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
. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')

$tmpRoot = Join-Path $env:TEMP "autonomous-assist-session-$PID"
if (Test-Path -LiteralPath $tmpRoot) { Remove-Item -LiteralPath $tmpRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null

function New-StatusFixture {
    param(
        [hashtable]$StateMachine = $null,
        [hashtable]$Session = $null,
        [hashtable]$RecursiveBranchState = $null
    )
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $obj = [ordered]@{ updatedAt = $now; session = if ($Session) { $Session } else { [ordered]@{} } }
    if ($StateMachine) {
        if (-not $StateMachine.Contains('updatedAtUtc')) { $StateMachine['updatedAtUtc'] = $now }
        $obj['stateMachine'] = $StateMachine
    }
    if ($RecursiveBranchState) {
        if (-not $RecursiveBranchState.Contains('updatedAtUtc')) { $RecursiveBranchState['updatedAtUtc'] = $now }
        $obj['recursiveBranchState'] = $RecursiveBranchState
    }
    return ($obj | ConvertTo-Json -Depth 10)
}

function New-RecursiveBranchFixture {
    param(
        [string]$NextPlannedBranch = 'observe_only',
        [string]$NextActionReason = 'recursive_branch_observe_only',
        [string]$CurrentTown = 'Ortysia',
        [hashtable]$BranchOverrides = @{}
    )
    $now = (Get-Date).ToUniversalTime().ToString('o')
    $branches = [ordered]@{
        travel = [ordered]@{ state = 'blocked'; reason = 'travel_surface_blocked' }
        trade = [ordered]@{ state = 'blocked'; reason = 'trade_surface_not_open' }
        smith_refine = [ordered]@{ state = 'blocked'; reason = 'smithing_surface_not_open' }
        rest_wait = [ordered]@{ state = 'available'; reason = 'safe_wait_surface' }
        tavern_scan = [ordered]@{ state = 'blocked'; reason = 'not_at_settlement_surface' }
        companion_roster = [ordered]@{ state = 'unknown'; reason = 'companion_roster_not_scanned' }
        avoid_threat = [ordered]@{ state = 'unknown'; reason = 'threat_state_unknown_until_posture_scan_consumed' }
        observe_only = [ordered]@{ state = 'available'; reason = 'always_safe_fallback' }
    }
    foreach ($k in $BranchOverrides.Keys) { $branches[$k] = $BranchOverrides[$k] }
    return @{
        schemaVersion = 1
        updatedAtUtc = $now
        currentTown = $CurrentTown
        currentSettlementId = 'town_ES3'
        gameplaySurface = 'campaign_map'
        terminal = $false
        nextActionRequired = $true
        nextPlannedBranch = $NextPlannedBranch
        nextActionReason = $NextActionReason
        branches = $branches
    }
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
    param(
        [string]$Surface,
        [bool]$WithStateMachine = $true,
        [bool]$StaleHeartbeat = $false,
        [hashtable]$RecursiveBranchState = $null,
        [bool]$StaleRecursiveBranch = $false
    )
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
    $rbs = $RecursiveBranchState
    if ($rbs -and $StaleRecursiveBranch) {
        $rbs = @{} + $rbs
        $rbs['updatedAtUtc'] = (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o')
    }
    New-StatusFixture -StateMachine $sm -Session $session -RecursiveBranchState $rbs |
        Set-Content -LiteralPath $statusPath -Encoding UTF8

    $hb = if ($StaleHeartbeat) { (Get-Date).ToUniversalTime().AddMinutes(-10).ToString('o') } else { (Get-Date).ToUniversalTime().ToString('o') }
    $runtimePath = Join-Path $tmpRoot "runtime-$Surface.json"
    New-RuntimeFixture @{ lastHeartbeatUtc = $hb } | Set-Content -LiteralPath $runtimePath -Encoding UTF8

    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $tmpRoot
    $ready.runtimeLifecycle = Read-Pr11RuntimeLifecycle -BannerlordRoot $tmpRoot -Path $runtimePath
    $ready.heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $ready.runtimeLifecycle
    return $ready
}

# fresh recursiveBranchState.observe_only drives observe decision on campaign_map
$observeRbs = New-RecursiveBranchFixture -NextPlannedBranch 'observe_only' -NextActionReason 'branch_truth_requires_fresh_observation'
$readyObserve = Build-Readiness -Surface 'campaign_map' -RecursiveBranchState $observeRbs
if (-not $readyObserve.recursiveBranchFresh) { throw 'recursiveBranchState fixture must be fresh' }
$decisionObserve = Get-AutonomousAssistIterationDecision -Readiness $readyObserve -AssistProfile 'training-map'
if ($decisionObserve.decision -ne 'observe') { throw "recursive observe_only must observe got $($decisionObserve.decision)" }
if ($decisionObserve.recursiveBranchConsumed -ne $true) { throw 'recursiveBranchState must be consumed when fresh' }
if ($decisionObserve.plannedBranch -ne 'observe_only') { throw "expected plannedBranch observe_only got $($decisionObserve.plannedBranch)" }

# fresh recursiveBranchState.travel on settlement_menu allows travel when gate open
$travelRbs = New-RecursiveBranchFixture -NextPlannedBranch 'travel' `
    -NextActionReason 'surface_allows_travel_recompute_destination_from_fresh_state' `
    -BranchOverrides @{ travel = [ordered]@{ state = 'available'; reason = 'surface_allows_travel' } }
$readyTravel = Build-Readiness -Surface 'settlement_menu' -RecursiveBranchState $travelRbs
$decisionTravel = Get-AutonomousAssistIterationDecision -Readiness $readyTravel -AssistProfile 'training-map' -TargetSettlement 'Ortysia'
if ($decisionTravel.decision -ne 'allowed') { throw "recursive travel must allow travel got $($decisionTravel.decision)" }
if ($decisionTravel.plannedBranch -ne 'travel') { throw 'recursive travel must plan travel branch' }

# trade branch must not execute without profitability evidence
$tradeRbs = New-RecursiveBranchFixture -NextPlannedBranch 'trade' `
    -NextActionReason 'market_profitability_not_evaluated' `
    -BranchOverrides @{ trade = [ordered]@{ state = 'unknown'; reason = 'market_profitability_not_evaluated' } }
$readyTrade = Build-Readiness -Surface 'trading' -RecursiveBranchState $tradeRbs
$decisionTrade = Get-AutonomousAssistIterationDecision -Readiness $readyTrade -AssistProfile 'training-map'
if ($decisionTrade.decision -eq 'allowed') { throw 'trade branch must not execute without evidence' }
if ($decisionTrade.decision -ne 'observe') { throw "trade branch must observe got $($decisionTrade.decision)" }
if ($decisionTrade.plannedBranch -ne 'trade') { throw 'trade branch must preserve planned branch name' }

foreach ($branchCase in @(
        @{ branch = 'smith_refine'; expect = 'observe' },
        @{ branch = 'tavern_scan'; expect = 'observe' },
        @{ branch = 'companion_roster'; expect = 'observe' }
    )) {
    $branchRbs = New-RecursiveBranchFixture -NextPlannedBranch $branchCase.branch `
        -NextActionReason "$($branchCase.branch)_evidence_missing"
    $readyBranch = Build-Readiness -Surface 'campaign_map' -RecursiveBranchState $branchRbs
    $decisionBranch = Get-AutonomousAssistIterationDecision -Readiness $readyBranch -AssistProfile 'training-map'
    if ($decisionBranch.decision -eq 'allowed') { throw "$($branchCase.branch) must not execute without evidence" }
    if ($decisionBranch.decision -ne $branchCase.expect) {
        throw "$($branchCase.branch) must $($branchCase.expect) got $($decisionBranch.decision)"
    }
    if ($decisionBranch.recursiveBranchConsumed -ne $true) { throw "$($branchCase.branch) must consume fresh recursiveBranchState" }
}

$threatRbs = New-RecursiveBranchFixture -NextPlannedBranch 'avoid_threat' `
    -NextActionReason 'threat_gate_blocked' `
    -BranchOverrides @{ avoid_threat = [ordered]@{ state = 'blocked'; reason = 'threat_gate_blocked' } }
$readyThreat = Build-Readiness -Surface 'campaign_map' -RecursiveBranchState $threatRbs
$decisionThreat = Get-AutonomousAssistIterationDecision -Readiness $readyThreat -AssistProfile 'training-map'
if ($decisionThreat.decision -eq 'allowed') { throw 'avoid_threat must not execute without evidence' }
if ($decisionThreat.decision -notin @('block', 'observe')) {
    throw "avoid_threat must block or observe got $($decisionThreat.decision)"
}
if ($decisionThreat.plannedBranch -ne 'avoid_threat') { throw 'avoid_threat must preserve planned branch name' }

# stale recursiveBranchState falls back to surface-derived decision
$staleRbs = New-RecursiveBranchFixture -NextPlannedBranch 'observe_only'
$readyStaleRbs = Build-Readiness -Surface 'settlement_menu' -RecursiveBranchState $staleRbs -StaleRecursiveBranch $true
if ($readyStaleRbs.recursiveBranchFresh) { throw 'stale recursiveBranchState must not be fresh' }
$decisionStaleRbs = Get-AutonomousAssistIterationDecision -Readiness $readyStaleRbs -AssistProfile 'training-map' -TargetSettlement 'Ortysia'
if ($decisionStaleRbs.recursiveBranchConsumed -eq $true) { throw 'stale recursiveBranchState must not be consumed' }
if ($decisionStaleRbs.decision -ne 'allowed') { throw 'stale recursiveBranchState must fall back to surface travel on settlement_menu' }

# campaign-loop-summary from recursiveBranchState preserves nextPlannedBranch on non-terminal cycle
$cycleSummary = Merge-AutonomousAssistCampaignLoopSummary -Summary @{ passFail = 'IN_PROGRESS' } `
    -SessionId 'recursive-branch-test' -TargetSettlement 'Danustica' `
    -LastDecision $decisionObserve -CycleId 3 `
    -RecursiveBranchState $readyObserve.recursiveBranchState -RecursiveBranchFresh $true
if (-not $cycleSummary.campaignLoopSummary) { throw 'campaignLoopSummary missing' }
if ($cycleSummary.campaignLoopSummary.terminal -ne $false) { throw 'non-terminal cycle must have terminal=false' }
if ($cycleSummary.campaignLoopSummary.nextActionRequired -ne $true) { throw 'non-terminal cycle must require next action' }
if ($cycleSummary.campaignLoopSummary.nextPlannedBranch -ne 'observe_only') {
    throw "campaign summary must use recursive nextPlannedBranch got $($cycleSummary.campaignLoopSummary.nextPlannedBranch)"
}
if ($cycleSummary.campaignLoopSummary.currentTown -ne 'Ortysia') {
    throw "campaign summary must use recursive currentTown got $($cycleSummary.campaignLoopSummary.currentTown)"
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
$cancelPath = Join-Path $tmpRoot 'BlacksmithGuild_CancelRun.json'
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
    iterationCount = 1; terminalState = 'pass'
}
$summary = Merge-AutonomousAssistCampaignLoopSummary -Summary $summary -SessionId 'test-session' `
    -TargetSettlement 'Ortysia' -LastDecision ([pscustomobject]@{ actionConsidered = 'observe_route'; decision = 'observe'; reason = 'campaign_map_observe_no_spam' }) `
    -CycleId 1
Save-AutonomousAssistSessionEvidence -Evidence $evidence -Summary $summary -BannerlordRoot $tmpRoot `
    -StatusPath (Join-Path $tmpRoot 'status-settlement_menu.json') -RuntimeLifecyclePath (Join-Path $tmpRoot 'runtime-settlement_menu.json') | Out-Null
foreach ($required in @(
    'session-manifest.json', 'assist-loop-timeline.json', 'assist-loop-summary.json', 'campaign-loop-summary.json',
    'state-snapshots.jsonl', 'command-timeline.jsonl', 'toggle-events.jsonl',
    'safety-decisions.jsonl', 'travel-decisions.jsonl', 'training-decisions.jsonl'
)) {
    $p = Join-Path $evidenceDir $required
    if (-not (Test-Path -LiteralPath $p)) { throw "missing evidence file $required" }
}
$summaryParsed = Get-Content -LiteralPath (Join-Path $evidenceDir 'assist-loop-summary.json') -Raw | ConvertFrom-Json
if ($summaryParsed.classification -ne 'user_toggle_off') { throw 'summary must record final classification' }
if ($summaryParsed.nextActionRequired -ne $false) { throw 'terminal assist summary must not require next action' }
$campaignParsed = Get-Content -LiteralPath (Join-Path $evidenceDir 'campaign-loop-summary.json') -Raw | ConvertFrom-Json
$campaignCheck = Test-AutomationCampaignLoopSummary -Summary $campaignParsed
if (-not $campaignCheck.pass) { throw 'campaign-loop-summary.json failed contract' }

# attach_ready must require Agent B state_machine confidence, not legacy fields only
$runnerText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-autonomous-assist-session.ps1') -Raw
if ($runnerText -match 'canPollFileInbox\s+-and\s+\$ready\.inGameAssistReady') {
    throw 'attach loop must not break on legacy readiness fields alone'
}
if ($runnerText -notmatch 'Test-AutonomousAssistLoopReadiness') {
    throw 'attach loop must use Test-AutonomousAssistLoopReadiness'
}

# runner must not require hotkey
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
