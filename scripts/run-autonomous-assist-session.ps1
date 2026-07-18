# Autonomous assist session — launch, attach, auto-start assist loop, evidence harvest.
param(
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$AssistProfile = 'training-map',
    [ValidateSet('default', 'economic_loop', 'full_campaign_handoff')]
    [string]$CertProfile = 'default',
    # Live full-campaign work is segmented. Default attach-only so a bare profile never starts a 12-minute mega-run.
    [ValidateSet('attach', 'movement', 'arrival', 'handoff', 'trade', 'horse', 'provision', 'manpower')]
    [string]$CertSegment = 'attach',
    [int]$TradeIterationTarget = 10,
    [int]$HorseAcquisitionTarget = 1,
    [int]$ProvisionAcquisitionTarget = 1,
    [int]$ManpowerAcquisitionTarget = 1,
    [string]$TargetSettlement = $null,
    [int]$MaxRuntimeMinutes = 30,
    [switch]$StopOnUnsafeState,
    [switch]$StopOnUserToggle,
    [int]$AttachWaitSec = 600,
    [int]$PollIntervalSec = 5,
    [int]$TravelCommandCooldownSec = 45,
    [int]$ProbeTimeoutSec = 45,
    [int]$ExecuteTimeoutSec = 120,
    [int]$ForegroundLossStopSec = 8,
    [switch]$SkipBuild,
    [switch]$SkipLaunch,
    [switch]$DryRun,
    [switch]$WhatIf,
    # Focus policy: by default this runner respects the user's foreground window so the operator can
    # keep using the machine. Pass -AllowFocusSteal to permit aggressive foreground-click escalation.
    [switch]$AllowFocusSteal
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
$startSha = (git rev-parse HEAD).Trim()

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
. (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1')
. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'dev-command-names.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')
. (Join-Path $PSScriptRoot 'pr11-assistive-execute-contract.ps1')
. (Join-Path $PSScriptRoot 'process-lifecycle-authority.ps1')
. (Join-Path $PSScriptRoot 'pr11-runtime-state-consumer.ps1')
. (Join-Path $PSScriptRoot 'automation-checkpoint-contract.ps1')
. (Join-Path $PSScriptRoot 'automation-boundary-contract.ps1')
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')
. (Join-Path $PSScriptRoot 'governor-operator-common.ps1')
. (Join-Path $PSScriptRoot 'full-campaign-handoff-cert.ps1')

$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\${sessionId}-autonomous-assist-session"
$certLogPath = Join-Path $checkpointDir 'cert-run-output.txt'
$transcriptStarted = $false
$cancelled = $false
$cyclePhase = 'loading'
$routeAgent = 'Agent C - External State Classifier / Assistive Runner'
Clear-GovernorStopSentinel -RepoRoot $repoRoot

function Write-SessionLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    if (-not (Test-Path -LiteralPath $checkpointDir)) {
        New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null
    }
    if (-not $transcriptStarted) {
        Add-Content -LiteralPath $certLogPath -Value $line -Encoding UTF8
    }
    Write-Host $line
}

function Read-AutonomousAssistJsonArtifact {
    param(
        [string]$BannerlordRoot,
        [string]$FileName
    )
    try {
        $path = Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName $FileName) `
            -Preferred (Join-Path (Get-BannerlordDocsRoot) $FileName)
        if ($path -and (Test-Path -LiteralPath $path)) {
            return [pscustomobject]@{ path = $path; json = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json) }
        }
    } catch { }
    return $null
}

function Get-AutonomousAssistForegroundStatus {
    param($Detection)

    $foreground = Get-F7ForegroundWindowInfo
    $gamePids = @()
    if ($Detection) {
        if ($Detection.gameProcessPid) {
            $gamePids += [int]$Detection.gameProcessPid
        }
        if ($Detection.gameProcessCandidates) {
            $gamePids += @($Detection.gameProcessCandidates | ForEach-Object {
                    if ($_.pid) { [int]$_.pid }
                })
        }
    }
    $gamePids = @($gamePids | Where-Object { $_ -gt 0 } | Select-Object -Unique)
    $foregroundPid = if ($foreground -and $foreground.processId) { [int]$foreground.processId } else { 0 }
    $matchesGame = ($foregroundPid -gt 0 -and $gamePids -contains $foregroundPid)
    $lossObserved = ($gamePids.Count -gt 0 -and $foregroundPid -gt 0 -and -not $matchesGame)
    return [pscustomobject]@{
        foreground = $foreground
        gamePids = @($gamePids)
        matchesGameProcess = [bool]$matchesGame
        lossObserved = [bool]$lossObserved
    }
}

function Get-AutonomousAssistEngineTravelTarget {
    param(
        [object]$Readiness,
        [string]$BannerlordRoot,
        [string]$ExplicitTarget = $null
    )
    if (-not [string]::IsNullOrWhiteSpace($ExplicitTarget)) {
        return [pscustomobject]@{ target = $ExplicitTarget; source = 'explicit_parameter'; path = $null }
    }

    $recursiveTarget = Get-AutonomousAssistRecursiveTravelTarget -RecursiveBranchState $Readiness.recursiveBranchState
    if (-not [string]::IsNullOrWhiteSpace($recursiveTarget)) {
        return [pscustomobject]@{ target = $recursiveTarget; source = 'recursiveBranchState'; path = $Readiness.statusPath }
    }

    $governor = Read-AutonomousAssistJsonArtifact -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_CampaignGovernorDecision.json'
    if ($governor -and $governor.json) {
        foreach ($candidate in @($governor.json.proposedActivity.targetTown, $governor.json.routeCouncilRecommendedDestination, $governor.json.destinationCandidate)) {
            if (-not [string]::IsNullOrWhiteSpace([string]$candidate)) {
                return [pscustomobject]@{ target = [string]$candidate; source = 'CampaignGovernorDecision'; path = $governor.path }
            }
        }
    }

    $council = Read-AutonomousAssistJsonArtifact -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_RouteCouncil.json'
    if ($council -and $council.json -and -not [string]::IsNullOrWhiteSpace([string]$council.json.recommendedDestination)) {
        return [pscustomobject]@{ target = [string]$council.json.recommendedDestination; source = 'RouteCouncil'; path = $council.path }
    }

    $regent = Read-AutonomousAssistJsonArtifact -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_RuntimeRegent.json'
    if ($regent -and $regent.json -and -not [string]::IsNullOrWhiteSpace([string]$regent.json.routeCouncilRecommendedDestination)) {
        return [pscustomobject]@{ target = [string]$regent.json.routeCouncilRecommendedDestination; source = 'RuntimeRegent'; path = $regent.path }
    }

    return [pscustomobject]@{ target = $null; source = 'missing_engine_handoff_target'; path = $null }
}

function Invoke-AutonomousAssistEngineHandoffRefresh {
    param(
        [string]$BannerlordRoot,
        [int]$TimeoutSec = 30
    )
    foreach ($commandName in @('RunCampaignGovernorCycleNow', 'ConveneRouteCouncil', 'ShowRuntimeRegentState')) {
        try {
            Send-ForgeCommand -CommandName $commandName -BannerlordRoot $BannerlordRoot -Wait -TimeoutSec $TimeoutSec | Out-Null
            Write-SessionLog "Engine handoff refresh command succeeded: $commandName"
        } catch {
            Write-SessionLog "Engine handoff refresh command failed: $commandName error=$($_.Exception.Message)"
        }
    }
}

function Complete-AssistAutomationFinalization {
    param(
        [hashtable]$Evidence,
        [hashtable]$Summary,
        [switch]$RequireExecuteMovement
    )
    if (-not (Get-Command Complete-AutomationFinalization -ErrorAction SilentlyContinue) -or -not $Evidence) {
        return
    }
    if ([string]$Summary.passFail -eq 'DRY_RUN') {
        return
    }

    $events = $Evidence.checkpointEvents
    if (-not $events) {
        return
    }

    $hasTerminal = [bool](@($events.ToArray() | Where-Object { $_.isTerminal -eq $true }).Count -gt 0)
    if ($hasTerminal) {
        return
    }

    Add-AutomationCheckpointEvent -List $events -CheckpointName 'summary_written' -SessionId $sessionId `
        -Phase $cyclePhase -Runner 'run-autonomous-assist-session.ps1' -Reason 'assist-loop-summary.json prepared' | Out-Null

    $state = switch ([string]$Summary.passFail) {
        'PASS' { 'pass' }
        'FAIL' { 'fail' }
        'cancelled' { 'abort' }
        default { 'abort' }
    }
    $finalReason = [string]$Summary.failureClass
    if ([string]::IsNullOrWhiteSpace($finalReason)) { $finalReason = [string]$Summary.stopReason }
    if ([string]::IsNullOrWhiteSpace($finalReason)) { $finalReason = $state }
    $executionJson = if ($RequireExecuteMovement) { (Get-AssistTravelExecutionSnapshotForRunner -BannerlordRoot $bannerlordRoot).json } else { $null }
    $gameProcessAlive = $null
    if ($Summary.ContainsKey('gameProcessAlive') -and $null -ne $Summary.gameProcessAlive) {
        $gameProcessAlive = [bool]$Summary.gameProcessAlive
    } elseif ([string]$Summary.stopReason -match 'game_process_gone|process_disappeared|game_gone|game_exited') {
        $gameProcessAlive = $false
    }
    $start = Start-AutomationFinalization -List $events -SessionId $sessionId -Phase $cyclePhase `
        -Runner 'run-autonomous-assist-session.ps1' -Reason $finalReason
    $requiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')
    $criteria = Get-AutomationProjectedTerminalCriteria -Events @($events.ToArray()) -State $state `
        -Summary ([pscustomobject]$Summary) -ExecutionJson $executionJson -RequireAssistLoopStarted `
        -RequiredCheckpoints $requiredCheckpoints -RequireExecuteMovement:$RequireExecuteMovement
    Complete-AutomationFinalization -List $events -State $state -SessionId $sessionId -Phase $cyclePhase `
        -Runner 'run-autonomous-assist-session.ps1' -Reason $finalReason `
        -Criteria $criteria -RelatedEventId $start.eventId -SummaryWritten:$true `
        -GameProcessAlive $gameProcessAlive | Out-Null
    $Summary.finalizedEventId = @($events.ToArray() | Where-Object { $_.isTerminal -eq $true } | Select-Object -Last 1).eventId
    $Summary.terminalState = $state
    $Summary.finalizationSequence = @($events.ToArray() | Where-Object { $_.eventType -like 'finalization_*' -or $_.eventType -like 'finalized_*' })
    $Summary.automationPassCriteria = $criteria
    if ($state -eq 'pass' -and -not $criteria.pass) {
        $Summary.passFail = 'FAIL'
        $Summary.failureClass = if ($criteria.failureClass) { [string]$criteria.failureClass } else { 'terminal_criteria_not_met' }
    }
}

function Exit-AssistSession {
    param(
        [int]$Code,
        [hashtable]$Evidence,
        [hashtable]$Summary,
        [object]$LastDecision = $null,
        [object]$RecursiveBranchState = $null,
        [bool]$RecursiveBranchFresh = $false,
        [switch]$RequireExecuteMovement
    )
    Complete-AssistAutomationFinalization -Evidence $Evidence -Summary $Summary -RequireExecuteMovement:$RequireExecuteMovement
    $summaryTargetSettlement = if ($LastDecision -and $LastDecision.target) { [string]$LastDecision.target } else { $TargetSettlement }
    $Summary = Merge-AutonomousAssistCampaignLoopSummary -Summary $Summary -SessionId $sessionId `
        -TargetSettlement $summaryTargetSettlement -LastDecision $LastDecision `
        -CycleId $(if ($Summary.iterationCount) { [int]$Summary.iterationCount } else { 0 }) `
        -RecursiveBranchState $RecursiveBranchState -RecursiveBranchFresh $RecursiveBranchFresh `
        -CurrentTown $(if ($RecursiveBranchState -and $RecursiveBranchState.currentTown) { [string]$RecursiveBranchState.currentTown } else { $null })
    if (Get-Command Write-TbgTerminationDetection -ErrorAction SilentlyContinue) {
        $runtimeLc = Read-Pr11RuntimeLifecycle -BannerlordRoot $bannerlordRoot
        Write-TbgTerminationDetection -BannerlordRoot $bannerlordRoot `
            -OutputPath (Join-Path $checkpointDir 'termination-detection.json') `
            -Extra @{
                CyclePhase = $cyclePhase
                Phase1Path = $phase1Path
                StatusPath = $statusPath
                RuntimeLifecycle = $runtimeLc
                BannerlordRoot = $bannerlordRoot
                TerminalState = $Summary.terminalState
                FinalizedEventId = $Summary.finalizedEventId
            } | Out-Null
    }
    Save-AutonomousAssistSessionEvidence -Evidence $Evidence -Summary $Summary `
        -BannerlordRoot $bannerlordRoot -StatusPath $statusPath -RuntimeLifecyclePath $runtimeLifecyclePath | Out-Null
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
    exit $Code
}

$segmentBudget = $null
if ($CertProfile -eq 'full_campaign_handoff') {
    # Profile-owned targets: movement is mandatory; trade/horse/food/manpower default to 1 unless overridden.
    if ($TradeIterationTarget -lt 1) { $TradeIterationTarget = 1 }
    if ($HorseAcquisitionTarget -lt 1) { $HorseAcquisitionTarget = 1 }
    if ($ProvisionAcquisitionTarget -lt 1) { $ProvisionAcquisitionTarget = 1 }
    if ($ManpowerAcquisitionTarget -lt 1) { $ManpowerAcquisitionTarget = 1 }
    $segmentBudget = Get-FullCampaignHandoffSegmentBudget -CertSegment $CertSegment
    # Segment budgets own the live clock unless the caller explicitly shortened further.
    $segmentMinutes = [Math]::Max(1, [int][Math]::Ceiling([double]$segmentBudget.maxRuntimeSec / 60.0))
    if ($PSBoundParameters.ContainsKey('MaxRuntimeMinutes')) {
        if ($MaxRuntimeMinutes -gt $segmentMinutes) { $MaxRuntimeMinutes = $segmentMinutes }
    } else {
        $MaxRuntimeMinutes = $segmentMinutes
    }
    if (-not $PSBoundParameters.ContainsKey('PollIntervalSec')) {
        $PollIntervalSec = [int]$segmentBudget.pollIntervalSec
    }
    if ($CertSegment -eq 'attach') {
        if (-not $PSBoundParameters.ContainsKey('AttachWaitSec')) {
            $AttachWaitSec = [int]$segmentBudget.attachWaitSec
        }
    } else {
        # Post-attach segments assume an already-live campaign unless the caller forces launch.
        if (-not $SkipLaunch -and -not $PSBoundParameters.ContainsKey('SkipLaunch')) {
            $SkipLaunch = $true
        }
        if (-not $PSBoundParameters.ContainsKey('AttachWaitSec')) {
            $AttachWaitSec = 45
        }
    }
    Write-SessionLog "Full-campaign segment=$CertSegment budgetSec=$($segmentBudget.maxRuntimeSec) successStop=$($segmentBudget.successStopReason) maxRuntimeMin=$MaxRuntimeMinutes"
}

if ($WhatIf) {
    Write-Host "WhatIf: launch=$LaunchIntent profile=$AssistProfile certProfile=$CertProfile certSegment=$CertSegment maxMin=$MaxRuntimeMinutes evidence=$checkpointDir trade=$TradeIterationTarget horse=$HorseAcquisitionTarget provision=$ProvisionAcquisitionTarget manpower=$ManpowerAcquisitionTarget" -ForegroundColor Cyan
    exit 0
}

New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null
Start-Transcript -LiteralPath $certLogPath -Append | Out-Null
$transcriptStarted = $true

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
$statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $bannerlordRoot
$runtimeLifecyclePath = Get-RuntimeLifecycleJsonPath -BannerlordRoot $bannerlordRoot

$evidence = New-AutonomousAssistSessionEvidence -SessionId $sessionId -CheckpointDir $checkpointDir `
    -AssistProfile $AssistProfile -LaunchIntent $LaunchIntent -TargetSettlement $TargetSettlement `
    -CertProfile $CertProfile -TradeIterationTarget $TradeIterationTarget
Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'session_started' `
    -SessionId $sessionId -Phase 'start' -Runner 'run-autonomous-assist-session.ps1' | Out-Null

Initialize-TbgProcessLifecycle -RunId "${sessionId}-assist" -BannerlordRoot $bannerlordRoot `
    -SessionAuthorityMode FreshTestLaunch -Operation 'autonomous_assist_session' `
    -Branch (git branch --show-current).Trim() | Out-Null
$clearedCancel = Clear-TbgStaleCancelRun -BannerlordRoot $bannerlordRoot `
    -RunStartedAtUtc ([datetime]::Parse([string]$evidence.startedAtUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind))
Register-TbgCancelHandler {
    $script:cancelled = $true
    Write-SessionLog 'CancelRun requested — stopping autonomous assist session'
}

Write-SessionLog "Autonomous assist session start branch=$((git branch --show-current)) sha=$startSha profile=$AssistProfile"
foreach ($cancel in @($clearedCancel)) {
    Write-SessionLog "Cleared stale CancelRun before fresh session path=$($cancel.path) reason=$($cancel.reason)"
}

if (-not $SkipBuild) {
    Write-SessionLog 'dotnet build Release...'
    & dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    if ($LASTEXITCODE -ne 0) {
        Exit-AssistSession -Code 1 -Evidence $evidence -Summary @{
            passFail = 'FAIL'; failureClass = 'runner_build_failed'; exitCode = 1
            endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
    Write-SessionLog 'install-mod.ps1 deploy...'
    & (Join-Path $PSScriptRoot 'install-mod.ps1')
    if ($LASTEXITCODE -ne 0) {
        Exit-AssistSession -Code 1 -Evidence $evidence -Summary @{
            passFail = 'FAIL'; failureClass = 'runner_deploy_failed'; exitCode = 1
            endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
}

$handoffCompleted = $false
$gameSeenAfterHandoff = $false
$launchRequestedUtc = $null
$attachReady = $false
$attachResult = 'not_checked'
$windowClassifierResult = 'not_run'

if ($DryRun) {
    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
    $loopReady = Test-AutonomousAssistLoopReadiness -Readiness $ready
    $decision = Get-AutonomousAssistIterationDecision -Readiness $ready -AssistProfile $AssistProfile `
        -TargetSettlement $TargetSettlement -StopOnUnsafeState:$StopOnUnsafeState -CertProfile $CertProfile
    $plannedChain = $null
    if ($CertProfile -eq 'full_campaign_handoff') {
        $plannedChain = @(
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$false -ArrivalObserved:$false -TownEntryObserved:$false -OrdinaryTradeDone:$false -HorseDone:$false -ProvisionDone:$false -ManpowerDone:$false -Surface 'settlement_menu'),
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -OrdinaryTradeDone:$false -HorseDone:$false -ProvisionDone:$false -ManpowerDone:$false -Surface 'trading'),
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -OrdinaryTradeDone:$true -HorseDone:$false -ProvisionDone:$false -ManpowerDone:$false -Surface 'trading'),
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -OrdinaryTradeDone:$true -HorseDone:$true -ProvisionDone:$false -ManpowerDone:$false -Surface 'trading'),
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -OrdinaryTradeDone:$true -HorseDone:$true -ProvisionDone:$true -ManpowerDone:$false -Surface 'settlement_menu'),
            (Get-FullCampaignHandoffNextCommand -MovementObserved:$true -ArrivalObserved:$true -TownEntryObserved:$true -OrdinaryTradeDone:$true -HorseDone:$true -ProvisionDone:$true -ManpowerDone:$true -Surface 'settlement_menu')
        )
    }
    Add-AssistSessionJsonl -List $evidence.timeline -Event ([ordered]@{
        atUtc = (Get-Date).ToUniversalTime().ToString('o'); phase = 'dry_run'; decision = $decision; plannedBranchChain = $plannedChain
    })
    Exit-AssistSession -Code 0 -Evidence $evidence -Summary @{
        passFail = 'DRY_RUN'; failureClass = $null; exitCode = 0
        certProfile = $CertProfile
        loopReadiness = $loopReady; sampleDecision = $decision
        plannedBranchChain = $plannedChain
        tradeIterationTarget = $TradeIterationTarget
        horseAcquisitionTarget = $HorseAcquisitionTarget
        provisionAcquisitionTarget = $ProvisionAcquisitionTarget
        manpowerAcquisitionTarget = $ManpowerAcquisitionTarget
        stateMachineConsumed = $loopReady.stateMachineConsumed
        runtimeLifecycleConsumed = $loopReady.runtimeLifecycleConsumed
        readinessConfidence = $loopReady.readinessConfidence
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    } -LastDecision $decision
}

if (-not $SkipLaunch) {
    $attachCheck = Test-F7AssistiveSessionAttachable -BannerlordRoot $bannerlordRoot `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath
    if (-not $attachCheck.attachable) {
        Write-SessionLog "Launching Bannerlord LaunchIntent=$LaunchIntent"
        Invoke-TbgFreshTestLaunchPreflight -BannerlordRoot $bannerlordRoot -Reason 'autonomous_assist_fresh_launch'
        $launcherRunning = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue
        if (-not $launcherRunning) {
            # LaunchIntent is mandatory on open-bannerlord-launcher.ps1; omitting it hangs on a parameter prompt.
            & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot `
                -LaunchIntent $LaunchIntent -AllowExistingProcess
            Start-Sleep -Seconds 3
        }
        & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $bannerlordRoot
        Write-TbgLaunchRequest -BannerlordRoot $bannerlordRoot -LaunchIntent $LaunchIntent -RequestedBy 'script'
        $launchRequestedUtc = (Get-Date).ToUniversalTime()
        $navScript = Join-Path $PSScriptRoot 'launcher-auto-nav.ps1'
        $timelinePath = Join-Path $checkpointDir 'ExternalStateTimeline.json'
        $navExit = 0
        $navError = $null
        try {
            $navResult = Invoke-TbgLauncherAutoNavChild -ScriptPath $navScript -LaunchIntent $LaunchIntent `
                -BannerlordRoot $bannerlordRoot -TimeoutSec 300 -LauncherSelectionMaxMs 30000 `
                -RespectUserForeground:(-not $AllowFocusSteal) -AllowFocusSteal:$AllowFocusSteal `
                -ExternalStateTimelinePath $timelinePath
            $navExit = $navResult.exitCode
            $navError = $navResult.text
        } catch {
            $navError = $_.Exception.Message
            $navExit = 1
            Write-SessionLog "launcher-auto-nav exception: $navError"
        }
        if ($navExit -ne 0) {
            $failureClass = if ($navError -match 'post-handoff: Bannerlord exited') {
                'process_disappeared_during_post_handoff'
            } elseif ($navError -match 'continue_not_found|launcher_timing_timeout') {
                'continue_not_found'
            } else {
                'launcher_failed'
            }
            $attachFailure = if ($failureClass -eq 'process_disappeared_during_post_handoff') { 'game_gone_before_attach' } else { 'launch_failed' }
            Exit-AssistSession -Code 2 -Evidence $evidence -Summary @{
                passFail = 'FAIL'; failureClass = $failureClass; exitCode = 2
                attachResult = $attachFailure; navError = $navError
                endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            }
        }
        $handoffCompleted = $true
    } else {
        Write-SessionLog 'Existing attachable session detected; skipping launch'
        $readyExisting = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
        $loopReadyExisting = Test-AutonomousAssistLoopReadiness -Readiness $readyExisting
        if ($loopReadyExisting.ready) {
            $attachReady = $true
            $attachResult = 'existing_session'
            Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'attach_ready' `
                -SessionId $sessionId -Phase 'attach' -Runner 'run-autonomous-assist-session.ps1' `
                -Reason 'existing_session' | Out-Null
        } else {
            Write-SessionLog "Existing session not Agent-B attach ready: $($loopReadyExisting.reason)"
        }
    }
} else {
    $handoffCompleted = $true
}

if (-not $attachReady) {
    $null = Start-TbgWaitSegment -WaitReason 'campaign_loading_attach' -TimeoutSec $AttachWaitSec -PollIntervalMs ($PollIntervalSec * 1000)
    $attachDeadline = (Get-Date).AddSeconds($AttachWaitSec)
    while ((Get-Date) -lt $attachDeadline) {
        if (Test-TbgCancelRequested -BannerlordRoot $bannerlordRoot) {
            End-TbgWaitSegment -Result 'cancel_requested' | Out-Null
            Exit-AssistSession -Code 3 -Evidence $evidence -Summary @{
                passFail = 'cancelled'; failureClass = 'cancelled'; exitCode = 3
                attachResult = 'cancelled'
                endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            }
        }

        $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath -CacheSec 0
        if ($det.gameProcessRunning) { $gameSeenAfterHandoff = $true }

        $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
        $loopReadyPoll = Test-AutonomousAssistLoopReadiness -Readiness $ready
        if ($loopReadyPoll.ready) {
            $attachReady = $true
            $attachResult = 'attach_ready'
            Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'attach_ready' `
                -SessionId $sessionId -Phase 'attach' -Runner 'run-autonomous-assist-session.ps1' | Out-Null
            End-TbgWaitSegment -Result 'attach_ready' | Out-Null
            break
        }

        $fastFail = Test-TbgPostHandoffFastFail -Detection $det -HandoffCompleted $handoffCompleted `
            -AttachReady $false -GameProcessEverSeenAfterHandoff $gameSeenAfterHandoff
        if ($fastFail) {
            End-TbgWaitSegment -Result $fastFail.classification | Out-Null
            Write-SessionLog "Post-handoff fast-fail: $($fastFail.classification)"
            Exit-AssistSession -Code 2 -Evidence $evidence -Summary @{
                passFail = 'FAIL'; failureClass = $fastFail.classification; exitCode = 2
                attachResult = 'game_gone_before_attach'; routeAgent = $fastFail.routeAgent
                endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            }
        }

        Update-TbgWaitProgress -ProgressSignal "attach_poll sm=$($ready.stateMachine.hasStateMachine) game=$($det.gameProcessRunning)"
        Start-Sleep -Seconds $PollIntervalSec
    }

    if (-not $attachReady) {
        End-TbgWaitSegment -Result 'attach_not_ready' | Out-Null
        Exit-AssistSession -Code 2 -Evidence $evidence -Summary @{
            passFail = 'FAIL'; failureClass = 'attach_not_ready'; exitCode = 2
            attachResult = 'attach_not_ready'
            endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
}

$readyAtAttach = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
$loopReadiness = Test-AutonomousAssistLoopReadiness -Readiness $readyAtAttach
if ($loopReadiness.stateMachineConsumed) {
    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'state_machine_consumed' `
        -SessionId $sessionId -Phase 'attach' -Runner 'run-autonomous-assist-session.ps1' | Out-Null
}
if ($loopReadiness.runtimeLifecycleConsumed) {
    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'runtime_lifecycle_consumed' `
        -SessionId $sessionId -Phase 'attach' -Runner 'run-autonomous-assist-session.ps1' | Out-Null
}

# Segment attach ends here: campaign load/attach is the long segment; do not continue into travel/trade.
if ($CertProfile -eq 'full_campaign_handoff' -and $CertSegment -eq 'attach') {
    $attachSegmentPass = [bool]$attachReady -or [bool]$loopReadiness.ready
    Exit-AssistSession -Code $(if ($attachSegmentPass) { 0 } else { 2 }) -Evidence $evidence -Summary @{
        passFail = $(if ($attachSegmentPass) { 'PASS' } else { 'FAIL' })
        failureClass = $(if ($attachSegmentPass) { $null } else { 'attach_not_ready' })
        stopReason = $(if ($attachSegmentPass) { 'segment_attach_ready' } else { 'attach_not_ready' })
        exitCode = $(if ($attachSegmentPass) { 0 } else { 2 })
        certProfile = $CertProfile
        certSegment = $CertSegment
        attachResult = $attachResult
        fullChainPass = $false
        highestProofLevel = $(if ($attachSegmentPass) { 'launcher' } else { 'none' })
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

$cyclePhase = 'assist_loop'
if (-not $loopReadiness.ready) {
    Exit-AssistSession -Code 2 -Evidence $evidence -Summary @{
        passFail = 'FAIL'; failureClass = 'assist_loop_not_ready'; exitCode = 2
        attachResult = $attachResult; loopBlockReason = $loopReadiness.reason
        stateMachineConsumed = $loopReadiness.stateMachineConsumed
        runtimeLifecycleConsumed = $loopReadiness.runtimeLifecycleConsumed
        readinessConfidence = $loopReadiness.readinessConfidence
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
}

Write-SessionLog 'Auto-starting assist loop (no hotkey) — writing AssistToggle enabled=true'
Write-TbgAssistToggle -BannerlordRoot $bannerlordRoot -Enabled $true -RequestedBy 'runner' `
    -Reason 'start autonomous assist loop' | Out-Null
Add-AssistSessionJsonl -List $evidence.toggleEvents -Event ([ordered]@{
    atUtc = (Get-Date).ToUniversalTime().ToString('o'); enabled = $true; requestedBy = 'runner'
    reason = 'start autonomous assist loop'
})
$evidence.assistLoopStarted = $true
$evidence.assistLoopStartedWithoutHotkey = $true
Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'assist_loop_started' `
    -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' | Out-Null

$loopDeadline = (Get-Date).AddMinutes($MaxRuntimeMinutes)
$lastTravelCommandUtc = $null
$stopReason = $null
$iteration = 0
$actionsLogged = 0
$travelExecuted = $false
$partyMovementCheckpointEmitted = $false
$movementObservationDeadline = $null
$latestMovementUpdate = [pscustomobject]@{
    checkpointEmitted = $false
    partyMovedDistance = 0.0
    travelClockRunning = $false
    movementIntentSet = $false
    movementProofClassification = $null
    movementMetricDisagreement = $false
    movementCheckpointObserved = $false
    movementProofPath = $null
    movementProof = $null
    executionJson = $null
}
$nonTradeBranchDone = $false
$provenTradeCount = 0
$isEconomicLoop = ($CertProfile -eq 'economic_loop')
$isFullCampaignHandoff = ($CertProfile -eq 'full_campaign_handoff')
$arrivalObserved = $false
$townEntryObserved = $false
$governorHandoffPresent = $false
$ordinaryTradeDone = $false
$horseAcquisitionDone = $false
$provisionAcquisitionDone = $false
$manpowerAcquisitionDone = $false
$latestManpowerEvidence = $null
$latestHandoffChain = @()
$fullCriteria = $null
# Only proven trade rows stamped at/after this moment are attributed to the current run, so a prior
# cert's append-only rows in the game-root trade file cannot trip the target before this session buys.
$tradeScopeSinceUtc = (Get-Date).ToUniversalTime()
# Fail-closed safety valve: economic-loop trade driving only begins once a real non-trade branch has
# executed/blocked (the travel leg). If travel never becomes possible, the run would otherwise spin to
# timeout without ever trading. After this many no-progress cycles, stop with a clear diagnostic instead.
$economicNoBranchCycles = 0
$nonTradeBranchMaxCycles = [Math]::Max(12, [int](180 / [Math]::Max(1, $PollIntervalSec)))
$lastDecision = $null
$lastRecursiveBranchState = $null
$lastRecursiveBranchFresh = $false
$engineHandoffRefreshAttempted = $false
# Safe-idle / no-progress instrumentation: every cycle is classified so a safe-but-idle poll is never
# silent, and a run of no-branch-progress cycles is visible instead of an opaque spin to timeout.
$lastSafeIdleClass = $null
$consecutiveSafeIdleCycles = 0
$maxConsecutiveSafeIdleObserved = 0
$foregroundLossSinceUtc = $null

$null = Start-TbgWaitSegment -WaitReason 'autonomous_assist_loop' -TimeoutSec ($MaxRuntimeMinutes * 60) -PollIntervalMs ($PollIntervalSec * 1000)

while ((Get-Date) -lt $loopDeadline) {
    $iteration++
    $evidence.iterationCount = $iteration

    if (Test-TbgCancelRequested -BannerlordRoot $bannerlordRoot) {
        $stopReason = 'cancel_run'
        break
    }
    if (Test-GovernorStopRequested -RepoRoot $repoRoot) {
        $stopReason = 'operator_stop_forge_stop'
        Write-SessionLog 'ForgeStop sentinel detected — stopping autonomous assist loop cleanly'
        break
    }
    $toggleState = Read-TbgAssistToggle -BannerlordRoot $bannerlordRoot
    $operatorToggleOff = $toggleState.parseOk -and (-not $toggleState.enabled) -and ([string]$toggleState.requestedBy -eq 'forge_stop')
    if (($StopOnUserToggle -or $operatorToggleOff) -and $toggleState.parseOk -and (-not $toggleState.enabled)) {
        Add-AssistSessionJsonl -List $evidence.toggleEvents -Event ([ordered]@{
            atUtc = (Get-Date).ToUniversalTime().ToString('o'); enabled = $false
            requestedBy = $toggleState.requestedBy; reason = $toggleState.reason
        })
        $stopReason = if ($operatorToggleOff) { 'operator_stop_forge_stop' } else { 'user_toggle_off' }
        Write-SessionLog "Assist toggle OFF — stopping loop cleanly reason=$stopReason requestedBy=$($toggleState.requestedBy)"
        break
    }

    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath -CacheSec 0
    if (-not $det.gameProcessRunning) {
        $fastFail = Test-TbgPostHandoffFastFail -Detection $det -HandoffCompleted $true `
            -AttachReady $true -GameProcessEverSeenAfterHandoff $true
        $stopReason = if ($fastFail) { $fastFail.classification } else { 'game_process_gone' }
        break
    }

    $tradeTargetReached = $false
    if ($isEconomicLoop -or $isFullCampaignHandoff) {
        $provenTradeCount = Get-EconomicLoopProvenTradeCount -BannerlordRoot $bannerlordRoot -SinceUtc $tradeScopeSinceUtc
        $evidence.tradeIterationCount = $provenTradeCount
        if ($isEconomicLoop) {
            $tradeTargetReached = ($provenTradeCount -ge $TradeIterationTarget)
            if ($tradeTargetReached) {
                $stopReason = 'trade_iteration_target_reached'
                Write-SessionLog "Economic loop target reached: $provenTradeCount/$TradeIterationTarget proven trades"
                break
            }
            if (-not $nonTradeBranchDone) {
                $economicNoBranchCycles++
                if ($economicNoBranchCycles -ge $nonTradeBranchMaxCycles) {
                    $stopReason = 'non_trade_branch_unavailable'
                    Write-SessionLog "Economic loop stopping: no non-trade branch executed/blocked within $economicNoBranchCycles cycles; cannot establish multi-branch evidence (is the party able to travel to a trade town?)"
                    break
                }
            }
        }
    }

    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
	$targetResolution = Get-AutonomousAssistEngineTravelTarget -Readiness $ready -BannerlordRoot $bannerlordRoot -ExplicitTarget $TargetSettlement
	$plannedBranchForTarget = if ($ready.recursiveBranchState) { [string]$ready.recursiveBranchState.nextPlannedBranch } else { $null }
	$travelSafeNow = [bool]$ready.safeToExecuteTravel
	# Break the cold-start handoff deadlock: the engine only plans the travel branch once a target exists,
	# so a travel-safe surface with an empty target would otherwise never trigger a refresh. Refresh when
	# travel is already planned OR the surface is travel-safe but the engine target is still missing.
	if ((($plannedBranchForTarget -eq 'travel') -or $travelSafeNow) -and [string]::IsNullOrWhiteSpace([string]$targetResolution.target) -and -not $engineHandoffRefreshAttempted) {
		$engineHandoffRefreshAttempted = $true
		Write-SessionLog 'Travel branch requires engine target; refreshing Governor/RouteCouncil/Regent handoff before command.'
		Invoke-AutonomousAssistEngineHandoffRefresh -BannerlordRoot $bannerlordRoot -TimeoutSec 30
		Start-Sleep -Seconds 1
		$ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
		$targetResolution = Get-AutonomousAssistEngineTravelTarget -Readiness $ready -BannerlordRoot $bannerlordRoot -ExplicitTarget $TargetSettlement
	}

    if ($isFullCampaignHandoff) {
        $tradePath = Join-Path $bannerlordRoot 'BlacksmithGuild_TradeIterations.jsonl'
        $tradeRows = @()
        if (Test-Path -LiteralPath $tradePath) {
            $tradeRows = @(Get-Content -LiteralPath $tradePath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
                try { $_ | ConvertFrom-Json } catch { $null }
            } | Where-Object { $null -ne $_ })
        }
        $classified = Get-ProvenTradesByClassification -TradeIterations $tradeRows -SinceUtc $tradeScopeSinceUtc
        $ordinaryTradeDone = (@($classified.ordinary).Count -ge $TradeIterationTarget)
        $horseAcquisitionDone = (@($classified.horse).Count -ge $HorseAcquisitionTarget)
        $provisionAcquisitionDone = (@($classified.food).Count -ge $ProvisionAcquisitionTarget)

        $execSnap = Get-AssistTravelExecutionSnapshotForRunner -BannerlordRoot $bannerlordRoot
        $arrivalTown = Test-FullCampaignArrivalEvidence -Readiness $ready -ExecutionJson $execSnap.json -TargetSettlement $(if ($targetResolution) { $targetResolution.target } else { $TargetSettlement })
        if ($arrivalTown.arrivalObserved) { $arrivalObserved = $true }
        if ($arrivalTown.townEntryObserved) { $townEntryObserved = $true }

        $guildLoopPath = Join-Path $bannerlordRoot 'BlacksmithGuild_AutonomousGuildLoop.json'
        if (Test-Path -LiteralPath $guildLoopPath) {
            try {
                $guildLoopJson = Get-Content -LiteralPath $guildLoopPath -Raw | ConvertFrom-Json
                $handoffEv = Test-FullCampaignGovernorHandoffEvidence -GuildLoopJson $guildLoopJson
                $governorHandoffPresent = [bool]$handoffEv.present
                $latestHandoffChain = @($handoffEv.handoffs)
            } catch { }
        }
        if ($arrivalObserved -and $townEntryObserved -and -not $governorHandoffPresent) {
            Write-SessionLog 'Arrival/town entry observed; refreshing Governor and requesting AutonomousGuildLoop handoff chain.'
            Invoke-AutonomousAssistEngineHandoffRefresh -BannerlordRoot $bannerlordRoot -TimeoutSec 30 | Out-Null
            try {
                Send-ForgeCommand -CommandName RunAutonomousGuildLoopNow -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
            } catch {
                Write-SessionLog "RunAutonomousGuildLoopNow handoff refresh failed: $($_.Exception.Message)"
            }
        }

        $recruitPath = Join-Path $bannerlordRoot 'BlacksmithGuild_TavernHeroRecruitment.json'
        if (Test-Path -LiteralPath $recruitPath) {
            try {
                $recruitJson = Get-Content -LiteralPath $recruitPath -Raw | ConvertFrom-Json
                $latestManpowerEvidence = Test-FullCampaignManpowerEvidence -RecruitmentJson $recruitJson
                if ($latestManpowerEvidence.proven) { $manpowerAcquisitionDone = $true }
            } catch { }
        }

        $segmentState = Test-FullCampaignHandoffSegmentComplete `
            -CertSegment $CertSegment `
            -AttachReady:$true `
            -MovementObserved:$partyMovementCheckpointEmitted `
            -ArrivalObserved:$arrivalObserved `
            -TownEntryObserved:$townEntryObserved `
            -GovernorHandoffPresent:$governorHandoffPresent `
            -OrdinaryTradeDone:$ordinaryTradeDone `
            -HorseDone:$horseAcquisitionDone `
            -ProvisionDone:$provisionAcquisitionDone `
            -ManpowerDone:$manpowerAcquisitionDone
        if ($segmentState.complete) {
            $stopReason = [string]$segmentState.successStopReason
            Write-SessionLog "Full-campaign segment complete segment=$CertSegment stopReason=$stopReason (not full-chain cert)"
            break
        }
    }
    $lastRecursiveBranchState = $ready.recursiveBranchState
    $lastRecursiveBranchFresh = [bool]$ready.recursiveBranchFresh
	$foregroundStatus = Get-AutonomousAssistForegroundStatus -Detection $det
	$foregroundLossSeconds = 0
	if ($foregroundStatus.lossObserved) {
		if (-not $foregroundLossSinceUtc) {
			$foregroundLossSinceUtc = (Get-Date).ToUniversalTime()
		}
		$foregroundLossSeconds = [int][Math]::Floor(((Get-Date).ToUniversalTime() - $foregroundLossSinceUtc).TotalSeconds)
		if ($foregroundLossSeconds -ge $ForegroundLossStopSec) {
			$stopReason = 'operator_interruption_foreground_lost'
			Write-SessionLog "Foreground lost to process=$($foregroundStatus.foreground.processName) title=$($foregroundStatus.foreground.title) for ${foregroundLossSeconds}s — stopping assist loop cleanly"
			Add-AssistSessionJsonl -List $evidence.safetyDecisions -Event ([ordered]@{
				atUtc = (Get-Date).ToUniversalTime().ToString('o')
				iteration = $iteration
				reason = $stopReason
				foregroundProcessName = $foregroundStatus.foreground.processName
				foregroundTitle = $foregroundStatus.foreground.title
				foregroundLossSeconds = $foregroundLossSeconds
			})
			Flush-AutonomousAssistInterimEvidence -Evidence $evidence
			break
		}
	} else {
		$foregroundLossSinceUtc = $null
	}
    $decision = Get-AutonomousAssistIterationDecision -Readiness $ready -AssistProfile $AssistProfile `
		-TargetSettlement $targetResolution.target -StopOnUnsafeState:$StopOnUnsafeState `
        -LastTravelCommandUtc $lastTravelCommandUtc -TravelCommandCooldownSec $TravelCommandCooldownSec `
        -CertProfile $CertProfile -TradeTargetReached:$tradeTargetReached -NonTradeBranchDone:$nonTradeBranchDone `
        -FullCampaignMovementObserved:$partyMovementCheckpointEmitted `
        -FullCampaignArrivalObserved:$arrivalObserved `
        -FullCampaignTownEntryObserved:$townEntryObserved `
        -FullCampaignOrdinaryTradeDone:$ordinaryTradeDone `
        -FullCampaignHorseDone:$horseAcquisitionDone `
        -FullCampaignProvisionDone:$provisionAcquisitionDone `
        -FullCampaignManpowerDone:$manpowerAcquisitionDone
    $lastDecision = $decision

    # Classify every cycle so no poll is ever silent/unclassified, and track consecutive safe-idle cycles
    # so a no-branch-progress spin is observable instead of an opaque wait to timeout.
    $safeIdleClass = Get-AutonomousAssistSafeIdleClass -Decision $decision
    $lastSafeIdleClass = $safeIdleClass
    if ($safeIdleClass -like 'safe_idle_*') {
        $consecutiveSafeIdleCycles++
        if ($consecutiveSafeIdleCycles -gt $maxConsecutiveSafeIdleObserved) {
            $maxConsecutiveSafeIdleObserved = $consecutiveSafeIdleCycles
        }
    } else {
        $consecutiveSafeIdleCycles = 0
    }
    Write-SessionLog "Iteration $iteration classified=$safeIdleClass decision=$($decision.decision) surface=$($decision.surface) consecutiveSafeIdle=$consecutiveSafeIdleCycles reason=$($decision.reason)"

    $iterEvent = [ordered]@{
        atUtc = $decision.atUtc
        iteration = $iteration
        surface = $decision.surface
        lifecycle = $decision.lifecycle
        actionConsidered = $decision.actionConsidered
        decision = $decision.decision
        commandSent = $decision.commandSent
        target = $decision.target
		targetSource = $decision.targetSource
		engineTargetSource = $targetResolution.source
        result = $decision.result
        reason = $decision.reason
        safeIdleClass = $safeIdleClass
        consecutiveSafeIdleCycles = $consecutiveSafeIdleCycles
    }
    Add-AssistSessionJsonl -List $evidence.timeline -Event $iterEvent
    Add-AssistSessionJsonl -List $evidence.stateSnapshots -Event ([ordered]@{
        atUtc = $decision.atUtc; iteration = $iteration
        stateMachine = $ready.stateMachine; heartbeatFresh = $ready.heartbeatFresh
        confidence = $ready.confidence
        recursiveBranchFresh = $ready.recursiveBranchFresh
        nextPlannedBranch = if ($ready.recursiveBranchState) { $ready.recursiveBranchState.nextPlannedBranch } else { $null }
		operatorInterruptionObserved = [bool]$ready.operatorInterruptionObserved
		operatorInterruptionReason = $ready.operatorInterruptionReason
		foregroundProcessName = $foregroundStatus.foreground.processName
		foregroundWindowTitle = $foregroundStatus.foreground.title
		foregroundWindowMatch = [bool]$foregroundStatus.matchesGameProcess
		foregroundLossSeconds = $foregroundLossSeconds
		resolvedTravelTarget = $targetResolution.target
		resolvedTravelTargetSource = $targetResolution.source
    })
    $actionsLogged++

    if ($decision.decision -eq 'stop_unsafe_surface') {
        Add-AssistSessionJsonl -List $evidence.safetyDecisions -Event $iterEvent
        if ($StopOnUnsafeState) {
            $stopReason = $decision.reason
            break
        }
    }
    if ($decision.decision -eq 'block') {
        Add-AssistSessionJsonl -List $evidence.safetyDecisions -Event $iterEvent
        $stopReason = $decision.reason
        break
    }

    if ($decision.decision -eq 'allowed' -and $decision.commandSent) {
        Add-AssistSessionJsonl -List $evidence.travelDecisions -Event $iterEvent
        $cmdResult = 'Skipped'
        try {
            if ($decision.commandSent -eq 'AssistiveLeaveTownAndTravel') {
				$commandTarget = [string]$decision.target
				if ([string]::IsNullOrWhiteSpace($commandTarget)) { throw 'handoff_missing_travel_target' }
				Write-SessionLog "Iteration $iteration sending AssistiveTownToTownProbe then AssistiveLeaveTownAndTravel -> $commandTarget source=$($decision.targetSource)"
                Send-ForgeCommand -CommandName AssistiveTownToTownProbe -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ProbeTimeoutSec | Out-Null
                Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'probe_ack' `
                    -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
					-Reason "probe:$commandTarget" | Out-Null
				Send-ForgeCommand -CommandName AssistiveLeaveTownAndTravel -Execute -TargetSettlement $commandTarget `
                    -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'execute_ack' `
                    -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
					-Reason "execute:$commandTarget" | Out-Null
                $travelExecuted = $true
                $cmdResult = 'Success'
                $lastTravelCommandUtc = (Get-Date).ToUniversalTime()
				$movementObservationDeadline = (Get-Date).AddSeconds($ExecuteTimeoutSec)
					$movementUpdate = Update-AssistTravelMovementCheckpoint -Evidence $evidence `
					-BannerlordRoot $bannerlordRoot -SessionId $sessionId `
					-AlreadyEmitted:$partyMovementCheckpointEmitted
					$latestMovementUpdate = $movementUpdate
				$partyMovementCheckpointEmitted = [bool]$movementUpdate.checkpointEmitted
				if ($partyMovementCheckpointEmitted) {
                    if ($isFullCampaignHandoff) {
                        Write-SessionLog 'Movement checkpoint observed — continuing for arrival/town handoff (not terminal)'
                        Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'party_movement_observed' `
                            -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
                            -Reason 'checkpoint_only_full_campaign_handoff' | Out-Null
                    } else {
                        $stopReason = 'movement_observed'
                    }
                }
                } elseif ($decision.commandSent -eq 'ResumeCampaignClock') {
                    Write-SessionLog "Iteration $iteration sending ResumeCampaignClock (paused campaign_map recovery)"
                    Send-ForgeCommand -CommandName ResumeCampaignClock -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'campaign_clock_resume_ack' `
                        -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
                        -Reason 'ResumeCampaignClock' | Out-Null
                    $cmdResult = 'Success'
            } elseif ($decision.commandSent -eq 'ProbeVanillaTradeExecutionNow') {
                Write-SessionLog "Iteration $iteration sending ProbeVanillaTradeExecutionNow (proven buy) at $TargetSettlement"
                # Send-ForgeCommand returns the command sequence, not the trade verdict. Derive the real
                # outcome from the mod's proven-trade delta on disk so a blocked buy is recorded as blocked.
                $provenBeforeSend = Get-EconomicLoopProvenTradeCount -BannerlordRoot $bannerlordRoot -SinceUtc $tradeScopeSinceUtc
                Send-ForgeCommand -CommandName ProbeVanillaTradeExecutionNow -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                $provenAfterSend = Get-EconomicLoopProvenTradeCount -BannerlordRoot $bannerlordRoot -SinceUtc $tradeScopeSinceUtc
                if ($provenAfterSend -gt $provenBeforeSend) {
                    $cmdResult = 'Success'
                    $provenTradeCount = $provenAfterSend
                    $evidence.tradeIterationCount = $provenAfterSend
                } else {
                    $cmdResult = 'Failed: trade_not_proven'
                }
            } elseif ($decision.commandSent -eq 'ProbePackAnimalBuyNow') {
                Write-SessionLog "Iteration $iteration sending ProbePackAnimalBuyNow"
                Send-ForgeCommand -CommandName ProbePackAnimalBuyNow -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                $cmdResult = 'Success'
            } elseif ($decision.commandSent -eq 'ProbeFoodBuyNow') {
                Write-SessionLog "Iteration $iteration sending ProbeFoodBuyNow"
                Send-ForgeCommand -CommandName ProbeFoodBuyNow -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                $cmdResult = 'Success'
            } elseif ($decision.commandSent -eq 'RecruitTavernHeroVisibleNow') {
                Write-SessionLog "Iteration $iteration sending RecruitTavernHeroVisibleNow"
                Send-ForgeCommand -CommandName RecruitTavernHeroVisibleNow -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                $cmdResult = 'Success'
            }
        } catch {
            $cmdResult = "Failed: $($_.Exception.Message)"
            $stopReason = 'command_failure'
            $iterEvent.result = $cmdResult
            Add-AssistSessionJsonl -List $evidence.commandTimeline -Event $iterEvent
            break
        }
        $iterEvent.result = $cmdResult
        Add-AssistSessionJsonl -List $evidence.commandTimeline -Event $iterEvent
    } elseif ($decision.decision -in @('observe', 'wait')) {
        Add-AssistSessionJsonl -List $evidence.trainingDecisions -Event $iterEvent
    }

    # Record the branch the loop actually considered this cycle as real evidence for the economic-loop
    # certifier's non-trade-branch requirement. Status reflects the observed outcome, never a synthesized one.
    $branchName = if ($decision.actionConsidered) { [string]$decision.actionConsidered } else { 'observe_only' }
    $branchStatus = switch ([string]$decision.decision) {
        'allowed' {
            if ($decision.commandSent -and [string]$iterEvent.result -eq 'Success') { 'executed' }
            elseif ([string]$iterEvent.result -like 'Failed*') { 'blocked' }
            else { 'considered' }
        }
        'block' { 'blocked' }
        'stop_unsafe_surface' { 'blocked' }
        default { 'considered' }
    }
    Add-AssistSessionJsonl -List $evidence.branchConsiderationLog -Event ([ordered]@{
        atUtc = $decision.atUtc; cycleId = $iteration; branch = $branchName; status = $branchStatus
        surface = $decision.surface; reason = $decision.reason
    })

	if ($travelExecuted -and -not $partyMovementCheckpointEmitted) {
		$movementUpdate = Update-AssistTravelMovementCheckpoint -Evidence $evidence `
			-BannerlordRoot $bannerlordRoot -SessionId $sessionId `
			-AlreadyEmitted:$partyMovementCheckpointEmitted
		$latestMovementUpdate = $movementUpdate
		$partyMovementCheckpointEmitted = [bool]$movementUpdate.checkpointEmitted
		if ($partyMovementCheckpointEmitted) {
			$partyMovementCheckpointEmitted = $true
            if ($isFullCampaignHandoff) {
                Write-SessionLog 'Movement checkpoint observed during poll — continuing for arrival/town handoff'
            } else {
			    $stopReason = 'movement_observed'
            }
		} elseif ($movementObservationDeadline -and (Get-Date) -ge $movementObservationDeadline) {
			$stopReason = if ($movementUpdate.travelClockRunning) { 'safe_idle_route_set_no_motion' } else { 'safe_idle_clock_stopped' }
		}
	}
	if ($stopReason) {
		Flush-AutonomousAssistInterimEvidence -Evidence $evidence
		break
	}

    # The economic-loop cert requires at least one non-trade branch to be executed/blocked before trades
    # count as a genuine multi-branch loop. Gate trade-driving on this observed (never synthesized) fact.
    if (-not $nonTradeBranchDone -and ($branchName -notin @('trade', 'observe_only', '')) -and ($branchStatus -in @('executed', 'blocked'))) {
        $nonTradeBranchDone = $true
        Write-SessionLog "Non-trade branch satisfied for economic-loop (branch=$branchName status=$branchStatus)"
    }

    $plannedBranch = Get-AutonomousAssistPlannedBranch -Decision $decision
    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'cycle_completed' `
        -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
        -Reason "iteration=$iteration decision=$($decision.decision)" | Out-Null
    if (-not $stopReason) {
		$cycleTargetSettlement = if ($decision -and $decision.target) { [string]$decision.target } elseif ($targetResolution -and $targetResolution.target) { [string]$targetResolution.target } else { $TargetSettlement }
        Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'next_action_planned' `
            -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
            -Reason "branch=$plannedBranch" | Out-Null
        Write-AutonomousAssistCycleCampaignSummary -Evidence $evidence -LastDecision $decision `
			-SessionId $sessionId -TargetSettlement $cycleTargetSettlement -CycleId $iteration `
            -RecursiveBranchState $lastRecursiveBranchState -RecursiveBranchFresh $lastRecursiveBranchFresh | Out-Null
        Flush-AutonomousAssistInterimEvidence -Evidence $evidence
    }

    Update-TbgWaitProgress -ProgressSignal "iter=$iteration decision=$($decision.decision) surface=$($decision.surface)"
    Start-Sleep -Seconds $PollIntervalSec
}

if (-not $stopReason -and (Get-Date) -ge $loopDeadline) {
    $stopReason = 'timeout'
}
End-TbgWaitSegment -Result $(if ($stopReason) { $stopReason } else { 'loop_complete' }) | Out-Null

Write-TbgAssistToggle -BannerlordRoot $bannerlordRoot -Enabled $false -RequestedBy 'runner' `
    -Reason 'stop autonomous assist loop' | Out-Null
Add-AssistSessionJsonl -List $evidence.toggleEvents -Event ([ordered]@{
    atUtc = (Get-Date).ToUniversalTime().ToString('o'); enabled = $false; requestedBy = 'runner'
    reason = 'stop autonomous assist loop'
})

$endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
$evidence.endedAtUtc = $endedAtUtc
$requiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')
$previewRequiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started')
$executionJsonForCriteria = if ($travelExecuted) { $latestMovementUpdate.executionJson } else { $null }
$criteriaPreview = Test-AutomationPassCriteria -Events @($evidence.checkpointEvents.ToArray()) `
    -Summary ([pscustomobject]@{
        assistLoopStarted = $evidence.assistLoopStarted
        stateMachineConsumed = $loopReadiness.stateMachineConsumed
        runtimeLifecycleConsumed = $loopReadiness.runtimeLifecycleConsumed
    }) -ExecutionJson $executionJsonForCriteria -RequiredCheckpoints $previewRequiredCheckpoints `
    -RequireAssistLoopStarted -RequireExecuteMovement:$travelExecuted
$allowedPassStops = @('timeout', 'trade_iteration_target_reached', 'movement_observed', $null)
if ($isFullCampaignHandoff) {
    # Segment PASS only. movement_observed and full-chain complete are not automatic PASS here.
    $allowedPassStops = @(
        'segment_attach_ready',
        'segment_movement_observed',
        'segment_arrival_town_observed',
        'segment_governor_handoff_observed',
        'segment_ordinary_trade_proven',
        'segment_horse_proven',
        'segment_provision_proven',
        'segment_manpower_proven'
    )
}
$passFail = if ($stopReason -in $allowedPassStops -and $actionsLogged -gt 0 -and $criteriaPreview.pass) { 'PASS' } `
    else { 'FAIL' }

if ($isFullCampaignHandoff) {
    $segmentFinal = Test-FullCampaignHandoffSegmentComplete `
        -CertSegment $CertSegment `
        -AttachReady:([bool]$attachReady) `
        -MovementObserved:$partyMovementCheckpointEmitted `
        -ArrivalObserved:$arrivalObserved `
        -TownEntryObserved:$townEntryObserved `
        -GovernorHandoffPresent:$governorHandoffPresent `
        -OrdinaryTradeDone:$ordinaryTradeDone `
        -HorseDone:$horseAcquisitionDone `
        -ProvisionDone:$provisionAcquisitionDone `
        -ManpowerDone:$manpowerAcquisitionDone
    if ($segmentFinal.complete -and ($stopReason -eq $segmentFinal.successStopReason)) {
        $passFail = 'PASS'
    } else {
        $passFail = 'FAIL'
        if ([string]::IsNullOrWhiteSpace($stopReason) -or $stopReason -eq 'timeout') {
            $stopReason = if ($segmentFinal.failureClass) { $segmentFinal.failureClass } else { 'timeout' }
        }
    }
    # Full-chain criteria are diagnostic only; segment PASS must never collapse into live-runtime-cert.
    $tradePathFinal = Join-Path $bannerlordRoot 'BlacksmithGuild_TradeIterations.jsonl'
    $tradeRowsFinal = @()
    if (Test-Path -LiteralPath $tradePathFinal) {
        $tradeRowsFinal = @(Get-Content -LiteralPath $tradePathFinal | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $null -ne $_ })
    }
    $fullCriteria = Test-FullCampaignHandoffPassCriteria `
        -CertProfile $CertProfile `
        -StopReason $(if ($stopReason -like 'segment_*') { 'timeout' } else { $stopReason }) `
        -MovementObserved:$partyMovementCheckpointEmitted `
        -ArrivalObserved:$arrivalObserved `
        -TownEntryObserved:$townEntryObserved `
        -GovernorHandoffPresent:$governorHandoffPresent `
        -TradeIterations $tradeRowsFinal `
        -TradeScopeSinceUtc $tradeScopeSinceUtc `
        -TradeIterationTarget $TradeIterationTarget `
        -HorseAcquisitionTarget $HorseAcquisitionTarget `
        -ProvisionAcquisitionTarget $ProvisionAcquisitionTarget `
        -ManpowerAcquisitionTarget $ManpowerAcquisitionTarget `
        -ManpowerEvidence $latestManpowerEvidence `
        -RuntimeEvents @($evidence.runtimeEvents.ToArray()) `
        -CheckpointEvents @($evidence.checkpointEvents.ToArray()) `
        -BranchConsiderationLog @($evidence.branchConsiderationLog.ToArray()) `
        -RequireTerminalEvent:$false
    $fullCriteria | Add-Member -NotePropertyName segmentPass -NotePropertyValue ($passFail -eq 'PASS') -Force
    $fullCriteria | Add-Member -NotePropertyName certSegment -NotePropertyValue $CertSegment -Force
    $fullCriteria | Add-Member -NotePropertyName fullChainPass -NotePropertyValue $false -Force
}

# Explicit post-attach proof-mode separation. Attach-ready and read-only reasoning are NOT a visible
# mechanics PASS; only a real observed party-movement delta promotes this run to visible_mechanics_proof.
$visibleMechanicsProven = [bool]$partyMovementCheckpointEmitted
$proofMode = if ($visibleMechanicsProven) { 'visible_mechanics_proof' } `
    elseif ($attachReady) { 'attach_readiness_proof' } `
    else { 'attach_readiness_proof' }

$highestProofLevel = 'none'
if ($attachReady) { $highestProofLevel = 'launcher' }
if ($travelExecuted) { $highestProofLevel = 'command-ack' }
if ($partyMovementCheckpointEmitted) { $highestProofLevel = 'movement' }
if ($arrivalObserved) { $highestProofLevel = 'arrival' }
if ($townEntryObserved) { $highestProofLevel = 'town-entry' }
if ($ordinaryTradeDone) { $highestProofLevel = 'trade' }
if ($horseAcquisitionDone) { $highestProofLevel = 'horse' }
if ($provisionAcquisitionDone) { $highestProofLevel = 'provision' }
if ($manpowerAcquisitionDone) { $highestProofLevel = 'manpower' }
if ($passFail -eq 'PASS' -and $isFullCampaignHandoff) { $highestProofLevel = 'live-runtime-cert' }

$summary = [ordered]@{
    sessionId = $sessionId
    branch = (git branch --show-current).Trim()
    startSha = $startSha
    endSha = (git rev-parse HEAD).Trim()
    passFail = $passFail
    failureClass = if ($passFail -eq 'FAIL') { $stopReason } else { $null }
    stopReason = $stopReason
    exitCode = if ($passFail -eq 'PASS') { 0 } else { 2 }
    attachResult = $attachResult
    assistProfile = $AssistProfile
    certProfile = $CertProfile
    assistLoopStarted = $evidence.assistLoopStarted
    assistLoopStartedWithoutHotkey = $evidence.assistLoopStartedWithoutHotkey
    stateMachineConsumed = $loopReadiness.stateMachineConsumed
    runtimeLifecycleConsumed = $loopReadiness.runtimeLifecycleConsumed
    readinessConfidence = $loopReadiness.readinessConfidence
    iterationCount = $evidence.iterationCount
    actionsLogged = $actionsLogged
    travelExecuted = $travelExecuted
    proofMode = $proofMode
    visibleMechanicsProven = $visibleMechanicsProven
    movementObserved = [bool]$partyMovementCheckpointEmitted
    arrivalObserved = [bool]$arrivalObserved
    townEntryObserved = [bool]$townEntryObserved
    governorHandoffPresent = [bool]$governorHandoffPresent
    handoffChain = $latestHandoffChain
    highestProofLevel = $highestProofLevel
    movementProofClassification = $latestMovementUpdate.movementProofClassification
    movementMetricDisagreement = [bool]$latestMovementUpdate.movementMetricDisagreement
    movementCheckpointObserved = [bool]$latestMovementUpdate.movementCheckpointObserved
    movementProofPath = $latestMovementUpdate.movementProofPath
    lastSafeIdleClass = $lastSafeIdleClass
    maxConsecutiveSafeIdleCycles = $maxConsecutiveSafeIdleObserved
    automationPassCriteria = $criteriaPreview
    fullCampaignHandoffCriteria = $(if ($isFullCampaignHandoff -and $fullCriteria) { $fullCriteria } else { $null })
    gameProcessAlive = $(if ($stopReason -match 'game_process_gone|process_disappeared|game_gone|game_exited') { $false } else { $true })
    endedAtUtc = $endedAtUtc
    checkpointDir = $checkpointDir
}

Write-SessionLog "Session complete passFail=$passFail stopReason=$stopReason iterations=$iteration actionsLogged=$actionsLogged"
Exit-AssistSession -Code $(if ($passFail -eq 'PASS') { 0 } else { 2 }) -Evidence $evidence -Summary $summary `
    -LastDecision $lastDecision -RecursiveBranchState $lastRecursiveBranchState `
    -RecursiveBranchFresh $lastRecursiveBranchFresh -RequireExecuteMovement:$travelExecuted
