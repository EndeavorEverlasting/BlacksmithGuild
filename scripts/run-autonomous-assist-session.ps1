# Autonomous assist session — launch, attach, auto-start assist loop, evidence harvest.
param(
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [string]$AssistProfile = 'training-map',
    [string]$TargetSettlement = 'Ortysia',
    [int]$MaxRuntimeMinutes = 30,
    [switch]$StopOnUnsafeState,
    [switch]$StopOnUserToggle,
    [int]$AttachWaitSec = 600,
    [int]$PollIntervalSec = 5,
    [int]$TravelCommandCooldownSec = 45,
    [int]$ProbeTimeoutSec = 45,
    [int]$ExecuteTimeoutSec = 120,
    [switch]$SkipBuild,
    [switch]$SkipLaunch,
    [switch]$DryRun,
    [switch]$WhatIf
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
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')

$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\${sessionId}-autonomous-assist-session"
$certLogPath = Join-Path $checkpointDir 'cert-run-output.txt'
$transcriptStarted = $false
$cancelled = $false
$cyclePhase = 'loading'
$routeAgent = 'Agent C - External State Classifier / Assistive Runner'

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
    $start = Start-AutomationFinalization -List $events -SessionId $sessionId -Phase $cyclePhase `
        -Runner 'run-autonomous-assist-session.ps1' -Reason ([string]$Summary.failureClass)
    $requiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'assist_loop_started', 'summary_written')
    $criteria = Get-AutomationProjectedTerminalCriteria -Events @($events.ToArray()) -State $state `
        -Summary ([pscustomobject]$Summary) -RequireAssistLoopStarted `
        -RequiredCheckpoints $requiredCheckpoints -RequireExecuteMovement:$RequireExecuteMovement
    Complete-AutomationFinalization -List $events -State $state -SessionId $sessionId -Phase $cyclePhase `
        -Runner 'run-autonomous-assist-session.ps1' -Reason ([string]$Summary.failureClass) `
        -Criteria $criteria -RelatedEventId $start.eventId -SummaryWritten:$true | Out-Null
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
        [switch]$RequireExecuteMovement
    )
    Complete-AssistAutomationFinalization -Evidence $Evidence -Summary $Summary -RequireExecuteMovement:$RequireExecuteMovement
    Merge-AutonomousAssistCampaignLoopSummary -Summary $Summary -SessionId $sessionId `
        -TargetSettlement $TargetSettlement -LastDecision $LastDecision `
        -CycleId $(if ($Summary.iterationCount) { [int]$Summary.iterationCount } else { 0 }) | Out-Null
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

if ($WhatIf) {
    Write-Host "WhatIf: launch=$LaunchIntent profile=$AssistProfile maxMin=$MaxRuntimeMinutes evidence=$checkpointDir" -ForegroundColor Cyan
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
    -AssistProfile $AssistProfile -LaunchIntent $LaunchIntent -TargetSettlement $TargetSettlement
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
        -TargetSettlement $TargetSettlement -StopOnUnsafeState:$StopOnUnsafeState
    Add-AssistSessionJsonl -List $evidence.timeline -Event ([ordered]@{
        atUtc = (Get-Date).ToUniversalTime().ToString('o'); phase = 'dry_run'; decision = $decision
    })
    Exit-AssistSession -Code 0 -Evidence $evidence -Summary @{
        passFail = 'DRY_RUN'; failureClass = $null; exitCode = 0
        loopReadiness = $loopReady; sampleDecision = $decision
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
            & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $bannerlordRoot
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
            $navCertTarget = if ($LaunchIntent -eq 'continue') { 'continue' } else { 'any' }
            $navResult = Invoke-TbgLauncherAutoNavChild -ScriptPath $navScript -LaunchIntent $LaunchIntent `
                -BannerlordRoot $bannerlordRoot -TimeoutSec 300 -LauncherSelectionMaxMs 30000 `
                -RespectUserForeground:$false -CertTarget $navCertTarget -ExternalStateTimelinePath $timelinePath
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

$cyclePhase = 'assist_loop'
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
$lastDecision = $null

$null = Start-TbgWaitSegment -WaitReason 'autonomous_assist_loop' -TimeoutSec ($MaxRuntimeMinutes * 60) -PollIntervalMs ($PollIntervalSec * 1000)

while ((Get-Date) -lt $loopDeadline) {
    $iteration++
    $evidence.iterationCount = $iteration

    if (Test-TbgCancelRequested -BannerlordRoot $bannerlordRoot) {
        $stopReason = 'cancel_run'
        break
    }
    if ($StopOnUserToggle -and (Test-TbgAssistToggleOff -BannerlordRoot $bannerlordRoot)) {
        $toggle = Read-TbgAssistToggle -BannerlordRoot $bannerlordRoot
        Add-AssistSessionJsonl -List $evidence.toggleEvents -Event ([ordered]@{
            atUtc = (Get-Date).ToUniversalTime().ToString('o'); enabled = $false
            requestedBy = $toggle.requestedBy; reason = $toggle.reason
        })
        $stopReason = 'user_toggle_off'
        Write-SessionLog 'Assist toggle OFF — stopping loop cleanly'
        break
    }

    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath -CacheSec 0
    if (-not $det.gameProcessRunning) {
        $fastFail = Test-TbgPostHandoffFastFail -Detection $det -HandoffCompleted $true `
            -AttachReady $true -GameProcessEverSeenAfterHandoff $true
        $stopReason = if ($fastFail) { $fastFail.classification } else { 'game_process_gone' }
        break
    }

    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
    $decision = Get-AutonomousAssistIterationDecision -Readiness $ready -AssistProfile $AssistProfile `
        -TargetSettlement $TargetSettlement -StopOnUnsafeState:$StopOnUnsafeState `
        -LastTravelCommandUtc $lastTravelCommandUtc -TravelCommandCooldownSec $TravelCommandCooldownSec
    $lastDecision = $decision

    $iterEvent = [ordered]@{
        atUtc = $decision.atUtc
        iteration = $iteration
        surface = $decision.surface
        lifecycle = $decision.lifecycle
        actionConsidered = $decision.actionConsidered
        decision = $decision.decision
        commandSent = $decision.commandSent
        target = $decision.target
        result = $decision.result
        reason = $decision.reason
    }
    Add-AssistSessionJsonl -List $evidence.timeline -Event $iterEvent
    Add-AssistSessionJsonl -List $evidence.stateSnapshots -Event ([ordered]@{
        atUtc = $decision.atUtc; iteration = $iteration
        stateMachine = $ready.stateMachine; heartbeatFresh = $ready.heartbeatFresh
        confidence = $ready.confidence
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
                Write-SessionLog "Iteration $iteration sending AssistiveTownToTownProbe then AssistiveLeaveTownAndTravel -> $TargetSettlement"
                Send-ForgeCommand -CommandName AssistiveTownToTownProbe -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ProbeTimeoutSec | Out-Null
                Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'probe_ack' `
                    -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
                    -Reason "probe:$TargetSettlement" | Out-Null
                Send-ForgeCommand -CommandName AssistiveLeaveTownAndTravel -Execute -TargetSettlement $TargetSettlement `
                    -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
                Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'execute_ack' `
                    -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
                    -Reason "execute:$TargetSettlement" | Out-Null
                $travelExecuted = $true
                $cmdResult = 'Success'
                $lastTravelCommandUtc = (Get-Date).ToUniversalTime()
                $execPath = Get-AssistiveTravelExecutionJsonPath -BannerlordRoot $bannerlordRoot
                if ((Test-Path -LiteralPath $execPath) -and -not $partyMovementCheckpointEmitted) {
                    try {
                        $execJson = Get-Content -LiteralPath $execPath -Raw | ConvertFrom-Json
                        $partyMovedDistance = 0.0
                        if ($null -ne $execJson.partyMovedDistance) {
                            [double]::TryParse([string]$execJson.partyMovedDistance, [ref]$partyMovedDistance) | Out-Null
                        }
                        if ($partyMovedDistance -gt 0) {
                            Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'party_movement_observed' `
                                -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
                                -Reason "partyMovedDistance=$partyMovedDistance" | Out-Null
                            $partyMovementCheckpointEmitted = $true
                        }
                    } catch { }
                }
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

    $plannedBranch = Get-AutonomousAssistPlannedBranch -Decision $decision
    Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'cycle_completed' `
        -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
        -Reason "iteration=$iteration decision=$($decision.decision)" | Out-Null
    if (-not $stopReason) {
        Add-AutomationCheckpointEvent -List $evidence.checkpointEvents -CheckpointName 'next_action_planned' `
            -SessionId $sessionId -Phase 'assist_loop' -Runner 'run-autonomous-assist-session.ps1' `
            -Reason "branch=$plannedBranch" | Out-Null
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
$criteriaPreview = Test-AutomationPassCriteria -Events @($evidence.checkpointEvents.ToArray()) `
    -Summary ([pscustomobject]@{
        assistLoopStarted = $evidence.assistLoopStarted
        stateMachineConsumed = $loopReadiness.stateMachineConsumed
        runtimeLifecycleConsumed = $loopReadiness.runtimeLifecycleConsumed
    }) -RequiredCheckpoints $requiredCheckpoints `
    -RequireAssistLoopStarted -RequireExecuteMovement:$travelExecuted
$passFail = if ($stopReason -in @('user_toggle_off', 'timeout', $null) -and $actionsLogged -gt 0 -and $criteriaPreview.pass) { 'PASS' } `
    else { 'FAIL' }

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
    assistLoopStarted = $evidence.assistLoopStarted
    assistLoopStartedWithoutHotkey = $evidence.assistLoopStartedWithoutHotkey
    stateMachineConsumed = $loopReadiness.stateMachineConsumed
    runtimeLifecycleConsumed = $loopReadiness.runtimeLifecycleConsumed
    readinessConfidence = $loopReadiness.readinessConfidence
    iterationCount = $evidence.iterationCount
    actionsLogged = $actionsLogged
    travelExecuted = $travelExecuted
    automationPassCriteria = $criteriaPreview
    endedAtUtc = $endedAtUtc
    checkpointDir = $checkpointDir
}

Write-SessionLog "Session complete passFail=$passFail stopReason=$stopReason iterations=$iteration actionsLogged=$actionsLogged"
Exit-AssistSession -Code $(if ($passFail -eq 'PASS') { 0 } else { 2 }) -Evidence $evidence -Summary $summary `
    -LastDecision $lastDecision -RequireExecuteMovement:$travelExecuted
