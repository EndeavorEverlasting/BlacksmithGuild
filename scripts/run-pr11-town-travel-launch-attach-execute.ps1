# PR #11 unattended launch -> attach -> execute cert runner (Agent C harness).
param(
    [string]$TargetSettlement = 'Ortysia',
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent = 'continue',
    [switch]$SkipBuild,
    [switch]$SkipLaunch,
    [switch]$AttachOnly,
    [int]$AttachWaitSec = 600,
    [int]$ProbeTimeoutSec = 45,
    [int]$ExecuteTimeoutSec = 120,
    [int]$MovementObserveSec = 90,
    [switch]$DryRun,
    [switch]$WhatIf,
    # Focus policy: respects the user's foreground window by default; pass -AllowFocusSteal to permit
    # aggressive foreground-click escalation during launcher navigation.
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
. (Join-Path $PSScriptRoot 'autonomous-assist-session.ps1')

$sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
$checkpointDir = Join-Path $repoRoot "docs\evidence\live-cert\${sessionId}-pr11-launch-attach-execute"
$certLogPath = Join-Path $checkpointDir 'cert-run-output.txt'
$cycleResultPath = Join-Path $checkpointDir 'cycle-result.json'
$classifications = New-Object System.Collections.Generic.List[object]
$transcriptStarted = $false
$cyclePhase = 'loading'
$cancelled = $false
$script:AutomationExecutionJson = $null

function Write-CertLog {
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

function Add-Classification {
    param($Classification)
    $classifications.Add($Classification) | Out-Null
    Save-Pr11JsonArtifact -Object @($classifications.ToArray()) -Path (Join-Path $checkpointDir 'state-classifications.json') | Out-Null
}

function Copy-LifecycleEvidence {
    $runtimeLc = Read-Pr11RuntimeLifecycle -BannerlordRoot $bannerlordRoot
    Write-TbgTerminationDetection -BannerlordRoot $bannerlordRoot `
        -OutputPath (Join-Path $checkpointDir 'termination-detection.json') `
        -Extra @{
            CyclePhase = $cyclePhase; Phase1Path = $phase1Path; StatusPath = $statusPath
            RuntimeLifecycle = $runtimeLc; BannerlordRoot = $bannerlordRoot
        } | Out-Null
    Copy-TbgLifecycleArtifacts -BannerlordRoot $bannerlordRoot -CheckpointDir $checkpointDir | Out-Null
}

function Exit-Pr11Cycle {
    param(
        [int]$Code,
        [hashtable]$Extra = @{}
    )
    Copy-LifecycleEvidence
    Complete-CycleResult $Extra | Out-Null
    exit $Code
}

function Complete-CycleResult {
    param([hashtable]$Extra = @{})

    if (Get-Command Complete-AutomationFinalization -ErrorAction SilentlyContinue) {
        $hasTerminal = [bool](@($script:AutomationCheckpointEvents.ToArray() | Where-Object { $_.isTerminal -eq $true }).Count -gt 0)
        if (-not $hasTerminal) {
            Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'summary_written' `
                -SessionId $sessionId -Phase $cyclePhase -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' `
                -Reason 'cycle-result.json prepared' | Out-Null
            $state = switch ([string]$Extra.passFail) {
                'PASS' { 'pass' }
                'PASS_ATTACH' { 'pass' }
                'FAIL' { 'fail' }
                default { 'abort' }
            }
            $start = Start-AutomationFinalization -List $script:AutomationCheckpointEvents -SessionId $sessionId `
                -Phase $cyclePhase -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' -Reason ([string]$Extra.failureClass)
            $criteriaArgs = @{
                Events = @($script:AutomationCheckpointEvents.ToArray())
                Summary = ([pscustomobject]$Extra)
                RequiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'summary_written')
            }
            if ($Extra.certAttempted -eq $true) {
                $criteriaArgs.RequiredCheckpoints = @('attach_ready', 'state_machine_consumed', 'runtime_lifecycle_consumed', 'travel_gate_ready', 'probe_ack', 'execute_ack', 'party_movement_observed', 'summary_written')
                $criteriaArgs.RequireExecuteMovement = $true
                $criteriaArgs.ExecutionJson = $script:AutomationExecutionJson
            }
            $criteriaArgs.State = $state
            $criteria = Get-AutomationProjectedTerminalCriteria @criteriaArgs
            $terminal = Complete-AutomationFinalization -List $script:AutomationCheckpointEvents -State $state `
                -SessionId $sessionId -Phase $cyclePhase -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' `
                -Reason ([string]$Extra.failureClass) -Criteria $criteria -RelatedEventId $start.eventId -SummaryWritten:$true
            $Extra.finalizedEventId = $terminal.eventId
            $Extra.terminalState = $state
            $Extra.finalizationSequence = @($script:AutomationCheckpointEvents.ToArray() | Where-Object { $_.eventType -like 'finalization_*' -or $_.eventType -like 'finalized_*' })
            $events = Merge-AutomationCheckpointEvents -RunnerEvents @($script:AutomationCheckpointEvents.ToArray()) `
                -ModEventPaths (Get-AutomationModEventPaths -BannerlordRoot $bannerlordRoot)
            Write-AutomationCheckpointEventsFile -Events $events -Path (Join-Path $checkpointDir 'checkpoint-events.jsonl') | Out-Null
        }
    }

    $result = [ordered]@{
        sessionId = $sessionId
        checkpointDir = $checkpointDir
        branch = (git branch --show-current).Trim()
        startSha = $startSha
        endSha = (git rev-parse HEAD).Trim()
        targetSettlement = $TargetSettlement
        launchIntent = $LaunchIntent
        dryRun = [bool]$DryRun
        attachOnly = [bool]$AttachOnly
        startedAtUtc = $startedAtUtc
        endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    foreach ($k in $Extra.Keys) { $result[$k] = $Extra[$k] }
    Save-Pr11JsonArtifact -Object $result -Path $cycleResultPath | Out-Null
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
    return $result
}

if ($WhatIf) {
    Write-Host "WhatIf: launch=$LaunchIntent attachWait=${AttachWaitSec}s execute=$TargetSettlement evidence=$checkpointDir" -ForegroundColor Cyan
    exit 0
}

New-Item -ItemType Directory -Force -Path $checkpointDir | Out-Null
Start-Transcript -LiteralPath $certLogPath -Append | Out-Null
$transcriptStarted = $true
$startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'session_started' `
    -SessionId $sessionId -Phase 'start' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$phase1Path = Get-Phase1LogPath -BannerlordRoot $bannerlordRoot
$statusPath = Get-StatusJsonPath -BannerlordRoot $bannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $bannerlordRoot
$launchLogPath = Get-LaunchLogPath -BannerlordRoot $bannerlordRoot
$runtimeLifecyclePath = Get-RuntimeLifecycleJsonPath -BannerlordRoot $bannerlordRoot

$sessionAuthorityMode = if ($AttachOnly -or $SkipLaunch) { 'AttachOnly' } else { 'FreshTestLaunch' }
Initialize-TbgProcessLifecycle -RunId "${sessionId}-pr11" -BannerlordRoot $bannerlordRoot `
    -SessionAuthorityMode $sessionAuthorityMode -Operation 'pr11_launch_attach_execute' `
    -Branch (git branch --show-current).Trim() | Out-Null
$clearedCancel = Clear-TbgStaleCancelRun -BannerlordRoot $bannerlordRoot `
    -RunStartedAtUtc ([datetime]::Parse([string]$startedAtUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind))
Register-TbgCancelHandler {
    $script:cancelled = $true
    Write-CertLog 'Cancel requested — stopping PR11 cycle'
}

$passFail = 'BLOCKED'
$failureClass = $null
$routeAgent = 'Agent C - External State Classifier / Assistive Runner'
$certAttempted = $false
$attachResult = 'not_checked'
$windowClassifierResult = 'not_run'
$exitCode = 2

Write-CertLog "PR11 launch/attach/execute runner start branch=$((git branch --show-current)) sha=$startSha"
foreach ($cancel in @($clearedCancel)) {
    Write-CertLog "Cleared stale CancelRun before fresh session path=$($cancel.path) reason=$($cancel.reason)"
}

# S0 audit snapshot (filtered; full-machine audit is too slow for live runs)
$s0 = Get-Pr11ProcessSnapshot -Label 'S0_before_repo_commands' -BannerlordRoot $bannerlordRoot
Save-Pr11ProcessSnapshot -Snapshot $s0 -OutputPath (Join-Path $checkpointDir 'process-snapshot-S0.json') | Out-Null

if (-not $SkipBuild) {
    Write-CertLog 'dotnet build Release...'
    & dotnet build (Join-Path $repoRoot 'src\BlacksmithGuild\BlacksmithGuild.csproj') -c Release
    if ($LASTEXITCODE -ne 0) {
        $failureClass = 'runner_build_failed'
        Complete-CycleResult @{ passFail = 'FAIL'; failureClass = $failureClass; routeAgent = $routeAgent; exitCode = 1 } | Out-Null
        exit 1
    }
    Write-CertLog 'install-mod.ps1 deploy...'
    & (Join-Path $PSScriptRoot 'install-mod.ps1')
    if ($LASTEXITCODE -ne 0) {
        $failureClass = 'runner_deploy_failed'
        Complete-CycleResult @{ passFail = 'FAIL'; failureClass = $failureClass; routeAgent = $routeAgent; exitCode = 1 } | Out-Null
        exit 1
    }
}

$s1 = Get-Pr11ProcessSnapshot -Label 'S1_after_build_deploy' -BannerlordRoot $bannerlordRoot
Save-Pr11ProcessSnapshot -Snapshot $s1 -OutputPath (Join-Path $checkpointDir 'process-snapshot-S1.json') | Out-Null

if ($DryRun) {
    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath
    $delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot $s1
    $candidates = Get-Pr11WindowCandidates -Delta $delta -BannerlordRoot $bannerlordRoot
    $cls = Invoke-Pr11UiStateClassification -BannerlordRoot $bannerlordRoot -Candidates $candidates -Readiness $ready -Detection $det -LaunchPhase 'dry_run'
    Add-Classification $cls
    $windowClassifierResult = $cls.state
    $travelGate = Test-Pr11TravelExecuteAllowed -Readiness $ready
    $attachResult = if ($ready.canPollFileInbox -and $ready.inGameAssistReady -and $ready.canAcceptAssistiveCommand) { 'attach_ready' } else { 'attach_not_ready' }
    Copy-LifecycleEvidence
    Complete-CycleResult @{
        passFail = 'DRY_RUN'; failureClass = $null; routeAgent = $routeAgent; exitCode = 0
        windowClassifierResult = $windowClassifierResult; attachResult = $attachResult; certAttempted = $false
        sessionAuthorityMode = $sessionAuthorityMode
        stateMachineConsumed = $ready.stateMachine.hasStateMachine
        runtimeLifecycleConsumed = [bool]$ready.runtimeLifecycle.parseOk
        travelGateAllowed = [bool]$travelGate.allowed
        travelGateReason = $travelGate.reason
        readinessConfidence = $ready.confidence
    } | Out-Null
    Write-CertLog "DryRun complete classifier=$windowClassifierResult attach=$attachResult travelGate=$($travelGate.reason) confidence=$($ready.confidence)"
    exit 0
}

$launchRequestedUtc = $null
$handoffCompleted = $false
$gameSeenAfterHandoff = $false
if (-not $SkipLaunch) {
    $attachCheck = Test-F7AssistiveSessionAttachable -BannerlordRoot $bannerlordRoot `
        -Phase1Path $phase1Path -StatusPath $statusPath -CrashContextPath $crashContextPath
    if (-not $attachCheck.attachable) {
        Write-CertLog "Attach not ready ($($attachCheck.reason)); launching with guarded nav LaunchIntent=$LaunchIntent"
        if ($sessionAuthorityMode -eq 'FreshTestLaunch') {
            Write-CertLog 'FreshTestLaunch preflight: intentional close before launch'
            Invoke-TbgFreshTestLaunchPreflight -BannerlordRoot $bannerlordRoot -Reason 'pr11_runner_fresh_launch'
        }

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
            $navResult = Invoke-TbgLauncherAutoNavChild -ScriptPath $navScript -LaunchIntent $LaunchIntent `
                -BannerlordRoot $bannerlordRoot -TimeoutSec 300 -LauncherSelectionMaxMs 30000 `
                -RespectUserForeground:(-not $AllowFocusSteal) -AllowFocusSteal:$AllowFocusSteal `
                -ExternalStateTimelinePath $timelinePath
            $navExit = $navResult.exitCode
            $navError = $navResult.text
        } catch {
            $navError = $_.Exception.Message
            $navExit = 1
            Write-CertLog "launcher-auto-nav exception: $navError"
        }
        $s2 = Get-Pr11ProcessSnapshot -Label 'S2_after_launch_request' -BannerlordRoot $bannerlordRoot
        Save-Pr11ProcessSnapshot -Snapshot $s2 -OutputPath (Join-Path $checkpointDir 'process-snapshot-S2.json') | Out-Null
        $delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot $s2
        Save-Pr11JsonArtifact -Object $delta -Path (Join-Path $checkpointDir 'window-candidates.json') | Out-Null

        if ($navExit -ne 0) {
            $failureClass = 'runner_window_identification_failed'
            if ($navError -match 'post-handoff: Bannerlord exited') {
                $failureClass = 'process_disappeared_during_post_handoff'
            } elseif ($navError -match 'launcher_timing_timeout|CONTINUE.*NOT verified|continue_not_found') {
                $failureClass = 'continue_not_found'
            } elseif ($navError -match 'already running') {
                $failureClass = 'launcher_failed'
            }
            $windowClassifierResult = if ($failureClass -eq 'continue_not_found') { 'continue_not_verified' } else { 'launcher_nav_failed' }
            Copy-LifecycleEvidence
            $attachFailure = if ($failureClass -eq 'process_disappeared_during_post_handoff') { 'game_gone_before_attach' } else { 'launch_failed' }
            Complete-CycleResult @{
                passFail = 'FAIL'; failureClass = $failureClass; routeAgent = $routeAgent; exitCode = 2
                windowClassifierResult = $windowClassifierResult; attachResult = $attachFailure; certAttempted = $false
                navError = $navError
            } | Out-Null
            Write-CertLog "FAIL launcher-auto-nav exit=$navExit failureClass=$failureClass"
            exit 2
        }
        $handoffCompleted = $true
    } else {
        Write-CertLog 'Existing attachable session detected; skipping launch'
        $s2 = Get-Pr11ProcessSnapshot -Label 'S2_existing_session' -BannerlordRoot $bannerlordRoot
        Save-Pr11ProcessSnapshot -Snapshot $s2 -OutputPath (Join-Path $checkpointDir 'process-snapshot-S2.json') | Out-Null
    }
} else {
    $s2 = Get-Pr11ProcessSnapshot -Label 'S2_skip_launch' -BannerlordRoot $bannerlordRoot
    Save-Pr11ProcessSnapshot -Snapshot $s2 -OutputPath (Join-Path $checkpointDir 'process-snapshot-S2.json') | Out-Null
    $handoffCompleted = $true
}

# Poll attach readiness with classifier timeline
$null = Start-TbgWaitSegment -WaitReason 'campaign_loading_attach' -TimeoutSec $AttachWaitSec -PollIntervalMs 2000
$attachDeadline = (Get-Date).AddSeconds($AttachWaitSec)
$attachReady = $false
while ((Get-Date) -lt $attachDeadline) {
    if (Test-TbgCancelRequested -BannerlordRoot $bannerlordRoot) {
        $cancelled = $true
        End-TbgWaitSegment -Result 'cancel_requested' | Out-Null
        Exit-Pr11Cycle -Code 3 @{
            passFail = 'cancelled'; failureClass = 'cancelled'; routeAgent = $routeAgent; exitCode = 3
            windowClassifierResult = $windowClassifierResult; attachResult = 'cancelled'; certAttempted = $false
        }
    }
    $ready = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot -Phase1Path $phase1Path -StatusPath $statusPath -CacheSec 0
    if ($det.gameProcessRunning) { $gameSeenAfterHandoff = $true }
    $fastFail = Test-TbgPostHandoffFastFail -Detection $det -HandoffCompleted $handoffCompleted `
        -AttachReady $false -GameProcessEverSeenAfterHandoff $gameSeenAfterHandoff
    if ($fastFail) {
        End-TbgWaitSegment -Result $fastFail.classification | Out-Null
        Write-CertLog "Post-handoff fast-fail: $($fastFail.classification)"
        Exit-Pr11Cycle -Code 2 @{
            passFail = 'FAIL'; failureClass = $fastFail.classification; routeAgent = $fastFail.routeAgent; exitCode = 2
            windowClassifierResult = $windowClassifierResult; attachResult = 'game_gone_before_attach'; certAttempted = $false
        }
    }
    $delta = Compare-Pr11ProcessSnapshots -BaselineSnapshot $s1 -AfterSnapshot (Get-Pr11ProcessSnapshot -Label 'poll' -BannerlordRoot $bannerlordRoot)
    $phase1Fresh = Test-BannerlordLogFresh -Path $phase1Path -MaxAgeSec 15
    $statusFresh = Test-BannerlordLogFresh -Path $statusPath -MaxAgeSec 15
    $candidates = @(Get-Pr11WindowCandidates -Delta $delta -BannerlordRoot $bannerlordRoot `
        -LaunchRequestedUtc $launchRequestedUtc -Phase1Fresh $phase1Fresh -StatusFresh $statusFresh)
    Save-Pr11JsonArtifact -Object $candidates -Path (Join-Path $checkpointDir 'window-candidates.json') | Out-Null
    $cls = Invoke-Pr11UiStateClassification -BannerlordRoot $bannerlordRoot -Candidates $candidates `
        -Readiness $ready -Detection $det -LaunchPhase $(if ($SkipLaunch) { 'skip_launch' } else { 'after_launch' })
    Add-Classification $cls
    $windowClassifierResult = $cls.state

    if ($ready.canPollFileInbox -and $ready.inGameAssistReady -and $ready.canAcceptAssistiveCommand -and $ready.statusFresh) {
        $attachReady = $true
        $attachResult = 'attach_ready'
        Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'attach_ready' `
            -SessionId $sessionId -Phase 'attach' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null
        Update-TbgWaitProgress -ProgressSignal "assistive_attach_ready confidence=$($ready.confidence)"
        break
    }
    Update-TbgWaitProgress -ProgressSignal "classifier=$($cls.state) phase1Fresh=$phase1Fresh statusFresh=$statusFresh sm=$($ready.stateMachine.hasStateMachine) hb=$($ready.heartbeatFresh)"
    Start-Sleep -Seconds 2
}

if (-not $attachReady) {
    End-TbgWaitSegment -Result 'attach_not_ready' | Out-Null
    $failureClass = 'attach_not_ready'
    $attachResult = 'attach_not_ready'
    Copy-Pr11EvidenceArtifact -SourcePath $statusPath -CheckpointDir $checkpointDir -DestName 'BlacksmithGuild_Status.json' | Out-Null
    Copy-Pr11EvidenceArtifact -SourcePath $phase1Path -CheckpointDir $checkpointDir -DestName 'BlacksmithGuild_Phase1.log' | Out-Null
    Write-CertLog "FAIL attach_not_ready after ${AttachWaitSec}s classifier=$windowClassifierResult"
    Exit-Pr11Cycle -Code 2 @{
        passFail = 'FAIL'; failureClass = $failureClass; routeAgent = $routeAgent; exitCode = 2
        windowClassifierResult = $windowClassifierResult; attachResult = $attachResult; certAttempted = $false
    }
}

End-TbgWaitSegment -Result 'attach_ready' | Out-Null
$cyclePhase = 'cert'

if ($AttachOnly) {
    $passFail = 'PASS_ATTACH'
    Exit-Pr11Cycle -Code 0 @{
        passFail = $passFail; failureClass = $null; routeAgent = $routeAgent; exitCode = 0
        windowClassifierResult = $windowClassifierResult; attachResult = $attachResult; certAttempted = $false
    }
}

# PR #11 cert sequence
$certAttempted = $true
$probeOk = $false
$executeOk = $false
$readyAtExecute = Get-Pr11AssistiveReadiness -StatusPath $statusPath -BannerlordRoot $bannerlordRoot
$travelGateAtExecute = Test-Pr11TravelExecuteAllowed -Readiness $readyAtExecute
if ($readyAtExecute.stateMachine.hasStateMachine) {
    Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'state_machine_consumed' `
        -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null
}
if ($readyAtExecute.runtimeLifecycle -and $readyAtExecute.runtimeLifecycle.parseOk) {
    Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'runtime_lifecycle_consumed' `
        -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null
}

if (-not $travelGateAtExecute.allowed) {
    $failureClass = 'travel_execute_blocked'
    $routeAgent = $travelGateAtExecute.routeAgent
    Write-CertLog "Travel execute blocked: $($travelGateAtExecute.reason) confidence=$($travelGateAtExecute.confidence)"
} else {
    Write-CertLog "Travel execute gate PASS reason=$($travelGateAtExecute.reason) confidence=$($travelGateAtExecute.confidence)"
    Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'travel_gate_ready' `
        -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' `
        -Reason $travelGateAtExecute.reason | Out-Null
}

if ($travelGateAtExecute.allowed) {
try {
    Write-CertLog 'Send-ForgeCommand AssistiveTownToTownProbe -Wait'
    Send-ForgeCommand -CommandName AssistiveTownToTownProbe -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ProbeTimeoutSec | Out-Null
    $probeOk = $true
    Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'probe_ack' `
        -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null
} catch {
    $failureClass = 'probe_failed'
    $routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
    Write-CertLog "Probe failed: $($_.Exception.Message)"
}

if ($probeOk) {
    try {
        Write-CertLog "Send-ForgeCommand AssistiveLeaveTownAndTravel -Execute -TargetSettlement $TargetSettlement -Wait"
        Send-ForgeCommand -CommandName AssistiveLeaveTownAndTravel -Execute -TargetSettlement $TargetSettlement `
            -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec $ExecuteTimeoutSec | Out-Null
        $executeOk = $true
        Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'execute_ack' `
            -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' | Out-Null
    } catch {
        $failureClass = 'inbox_command_failed'
        $routeAgent = 'Agent C - External State Classifier / Assistive Runner'
        Write-CertLog "Execute command failed: $($_.Exception.Message)"
    }

    # Real-movement observation window: the mod resumes the campaign clock and the party
    # actually travels. Poll the live execution evidence until genuine party movement is
    # observed (position delta > 0), not merely route intent. This is what makes PASS honest.
    Write-CertLog "Observing real party movement up to ${MovementObserveSec}s (alt-tab OK; campaign clock running)..."
    $movementDeadline = (Get-Date).AddSeconds($MovementObserveSec)
    $movementObservedLive = $false
    while ((Get-Date) -lt $movementDeadline) {
        Start-Sleep -Seconds 3
        $liveExecPath = Get-AssistiveTravelExecutionJsonPath -BannerlordRoot $bannerlordRoot
        if ($liveExecPath -and (Test-Path -LiteralPath $liveExecPath)) {
            $live = $null
            try { $live = Get-Content -LiteralPath $liveExecPath -Raw | ConvertFrom-Json } catch { $live = $null }
            if ($live) {
                $dist = 0.0
                if ($null -ne $live.partyMovedDistance) { [double]::TryParse([string]$live.partyMovedDistance, [ref]$dist) | Out-Null }
                if ($live.actualExecutionObserved -eq $true -and $dist -gt 0) {
                    $movementObservedLive = $true
                    Add-AutomationCheckpointEvent -List $script:AutomationCheckpointEvents -CheckpointName 'party_movement_observed' `
                        -SessionId $sessionId -Phase 'cert' -Runner 'run-pr11-town-travel-launch-attach-execute.ps1' `
                        -Details ([ordered]@{ partyMovedDistance = $dist; travelClockRunning = $live.travelClockRunning; fakeGameplayDelta = $live.fakeGameplayDelta }) | Out-Null
                    Write-CertLog "Real movement observed: partyMovedDistance=$dist arrived=$($live.arrived) clockRunning=$($live.travelClockRunning)"
                    break
                }
            }
        }
    }
    if (-not $movementObservedLive) {
        Write-CertLog "No real party movement observed within ${MovementObserveSec}s (will FAIL honestly if evidence lacks movement)."
    }
}
}

# Harvest evidence
foreach ($pair in @(
    @{ src = (Get-AssistiveTravelExecutionJsonPath -BannerlordRoot $bannerlordRoot); dest = 'BlacksmithGuild_AssistiveTravelExecution.json' },
    @{ src = (Get-TownToTownTradeProbeJsonPath -BannerlordRoot $bannerlordRoot); dest = 'BlacksmithGuild_TownToTownTradeProbe.json' },
    @{ src = (Get-AssistiveSessionJsonPath -BannerlordRoot $bannerlordRoot); dest = 'BlacksmithGuild_AssistiveSession.json' },
    @{ src = $statusPath; dest = 'BlacksmithGuild_Status.json' },
    @{ src = $phase1Path; dest = 'BlacksmithGuild_Phase1.log' },
    @{ src = $runtimeLifecyclePath; dest = 'BlacksmithGuild_RuntimeLifecycle.json' }
)) {
    Copy-Pr11EvidenceArtifact -SourcePath $pair.src -CheckpointDir $checkpointDir -DestName $pair.dest | Out-Null
}

$executionJson = $null
$execPath = Join-Path $checkpointDir 'BlacksmithGuild_AssistiveTravelExecution.json'
if (Test-Path -LiteralPath $execPath) {
    try { $executionJson = Get-Content -LiteralPath $execPath -Raw | ConvertFrom-Json } catch { }
}
$script:AutomationExecutionJson = $executionJson

$executePass = Test-Pr11AssistiveTravelExecutePass -ExecutionJson $executionJson -Readiness $readyAtExecute -RequireLeaveTown
if ($executePass.pass -and (Test-Pr11ExecutePassBlockedByRuntime -Readiness $readyAtExecute)) {
    $executePass = [ordered]@{
        pass = $false
        failureClass = 'runtime_heartbeat_stale'
        routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
        checks = $executePass.checks
    }
}
if ($executePass.pass) {
    $passFail = 'PASS'
    $exitCode = 0
    $failureClass = $null
    $routeAgent = 'Agent A - Cert / Evidence / Git / PR (evidence ready for review)'
    if (-not $executeOk) {
        $failureClass = 'inbox_ack_timeout_execute_evidence_pass'
        Write-CertLog 'NOTE: execute inbox ack timed out, but evidence shows verified real party movement (partyMovedDistance>0) so PASS stands'
    }
} else {
    $passFail = 'FAIL'
    $exitCode = 2
    if (-not $failureClass) {
        $failureClass = $executePass.failureClass
        $routeAgent = $executePass.routeAgent
    }
}

$cyclePhase = 'cleanup'
Copy-LifecycleEvidence
Complete-CycleResult @{
    passFail = $passFail; failureClass = $failureClass; routeAgent = $routeAgent; exitCode = $exitCode
    windowClassifierResult = $windowClassifierResult; attachResult = $attachResult; certAttempted = $certAttempted
    probeOk = $probeOk; executeOk = $executeOk; executeChecks = $executePass.checks
    sessionAuthorityMode = $sessionAuthorityMode
    stateMachineConsumed = $readyAtExecute.stateMachine.hasStateMachine
    runtimeLifecycleConsumed = [bool]$readyAtExecute.runtimeLifecycle.parseOk
    travelGateAllowed = [bool]$travelGateAtExecute.allowed
    travelGateReason = $travelGateAtExecute.reason
    readinessConfidence = $readyAtExecute.confidence
} | Out-Null

Write-CertLog "$passFail PR11 execute cert exit=$exitCode failureClass=$failureClass evidence=$checkpointDir"
exit $exitCode
