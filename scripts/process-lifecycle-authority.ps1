# Process lifecycle authority — session modes, intentional termination, provenance, classification.
# Dot-source after bannerlord-paths.ps1.

$script:TbgProcessLifecycle = $null
$script:TbgWaitTimeline = New-Object System.Collections.Generic.List[object]
$script:TbgCurrentWait = $null
$script:TbgCancelRequested = $false
$script:TbgCancelReason = $null
$script:TbgPreflightCompleted = $false

function Test-TbgSessionAuthorityMode {
    param([string]$Mode)
    return [string]$Mode -in @('AttachOnly', 'FreshTestLaunch', 'UserSession', 'RunnerCleanup')
}

function Get-TbgProcessLifecycleJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_ProcessLifecycle.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_ProcessLifecycle.json')
}

function Get-TbgCancelRunJsonPath {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return Find-NewestExistingPath -Candidates (Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot `
        -FileName 'BlacksmithGuild_CancelRun.json') `
        -Preferred (Join-Path (Get-BannerlordDocsRoot) 'BlacksmithGuild_CancelRun.json')
}

function Get-TbgProcessLifecycleWritePaths {
    param([string]$BannerlordRoot)
    if (-not (Get-Command Get-AssistiveArtifactCandidates -ErrorAction SilentlyContinue)) {
        . (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
    }
    return @(Get-AssistiveArtifactCandidates -BannerlordRoot $BannerlordRoot -FileName 'BlacksmithGuild_ProcessLifecycle.json')
}

function Initialize-TbgProcessLifecycle {
    param(
        [Parameter(Mandatory = $true)][string]$RunId,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [ValidateSet('AttachOnly', 'FreshTestLaunch', 'UserSession', 'RunnerCleanup')]
        [string]$SessionAuthorityMode = 'UserSession',
        [string]$Operation = 'unknown',
        [string]$Actor = 'script',
        [string]$Branch = $null,
        [string]$ProductBranch = $null
    )

    $script:TbgProcessLifecycle = [ordered]@{
        schemaVersion = 1
        runId = [string]$RunId
        branch = $Branch
        productBranch = $ProductBranch
        operation = [string]$Operation
        actor = [string]$Actor
        sessionAuthorityMode = [string]$SessionAuthorityMode
        startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        preExistingProcesses = @()
        intentionalTerminations = @()
        launchRequest = $null
        launchSelection = $null
        ownedProcessIds = @()
        termination = $null
    }
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
    return $script:TbgProcessLifecycle
}

function Read-TbgProcessLifecycle {
    param([string]$BannerlordRoot)
    $path = Get-TbgProcessLifecycleJsonPath -BannerlordRoot $BannerlordRoot
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    try {
        return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Save-TbgProcessLifecycle {
    param([string]$BannerlordRoot)
    if (-not $script:TbgProcessLifecycle) { return $null }
    $json = $script:TbgProcessLifecycle | ConvertTo-Json -Depth 12
    $written = $null
    foreach ($path in @(Get-TbgProcessLifecycleWritePaths -BannerlordRoot $BannerlordRoot)) {
        $dir = Split-Path -Parent $path
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
        }
        Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        $written = $path
    }
    return $written
}

function Get-TbgRunningBannerlordProcessRecords {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($proc in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            try {
                $rec = [ordered]@{
                    pid = [int]$proc.Id
                    processName = [string]$proc.ProcessName
                    parentPid = $null
                    startTime = $null
                    mainWindowHandle = 0
                    mainWindowTitle = ''
                    executablePath = $null
                    commandLine = $null
                }
                try { $rec.startTime = $proc.StartTime.ToUniversalTime().ToString('o') } catch { }
                try {
                    $hwnd = $proc.MainWindowHandle
                    $rec.mainWindowHandle = [int64]$hwnd
                    $rec.mainWindowTitle = [string]$proc.MainWindowTitle
                } catch { }
                if (Get-Command Get-ProcessExecutablePathSafe -ErrorAction SilentlyContinue) {
                    $rec.executablePath = Get-ProcessExecutablePathSafe -Process $proc
                }
                try {
                    $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -ErrorAction Stop
                    $rec.parentPid = [int]$wmi.ParentProcessId
                    $rec.commandLine = [string]$wmi.CommandLine
                    if (-not $rec.executablePath) { $rec.executablePath = [string]$wmi.ExecutablePath }
                } catch { }
                $records.Add([pscustomobject]$rec) | Out-Null
            } catch { }
        }
    }
    return @($records.ToArray())
}

function Test-TbgMayTerminateProcesses {
    param([string]$SessionAuthorityMode)
    return [string]$SessionAuthorityMode -in @('FreshTestLaunch', 'RunnerCleanup')
}

function Request-TbgIntentionalTermination {
    param(
        [Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)][string]$Reason,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [ValidateSet('AttachOnly', 'FreshTestLaunch', 'UserSession', 'RunnerCleanup')]
        [string]$SessionAuthorityMode,
        [int]$GracefulWaitSec = 8
    )

    if (-not (Test-TbgMayTerminateProcesses -SessionAuthorityMode $SessionAuthorityMode)) {
        throw "SessionAuthorityMode '$SessionAuthorityMode' forbids terminating PID $($Process.Id)"
    }
    if ($SessionAuthorityMode -eq 'RunnerCleanup') {
        $owned = @($script:TbgProcessLifecycle.ownedProcessIds)
        if ($owned.Count -gt 0 -and ($owned -notcontains $Process.Id)) {
            throw "RunnerCleanup may not terminate unowned PID $($Process.Id)"
        }
    }

    $requestedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $entry = [ordered]@{
        pid = [int]$Process.Id
        processName = [string]$Process.ProcessName
        reason = [string]$Reason
        requestedAtUtc = $requestedUtc
        method = 'CloseMainWindow'
        forceKilled = $false
        observedExitAtUtc = $null
    }

    if (-not $script:TbgProcessLifecycle) {
        Initialize-TbgProcessLifecycle -RunId (Get-Date).ToString('yyyyMMdd-HHmmss') `
            -BannerlordRoot $BannerlordRoot -SessionAuthorityMode $SessionAuthorityMode -Operation 'ad_hoc_termination'
    }

    $script:TbgProcessLifecycle.intentionalTerminations = @($script:TbgProcessLifecycle.intentionalTerminations) + @($entry)
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null

    $graceful = $false
    try {
        if ($Process.MainWindowHandle -ne [IntPtr]::Zero) {
            $graceful = [bool]$Process.CloseMainWindow()
        }
    } catch { }

    if ($graceful) {
        $deadline = (Get-Date).AddSeconds($GracefulWaitSec)
        while ((Get-Date) -lt $deadline) {
            if ($Process.HasExited) { break }
            Start-Sleep -Milliseconds 250
        }
    }

    if (-not $Process.HasExited) {
        $entry.method = if ($graceful) { 'CloseMainWindow+Force' } else { 'Force' }
        $entry.forceKilled = $true
        Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
    }

    $entry.observedExitAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    $script:TbgProcessLifecycle.intentionalTerminations = @(
        @($script:TbgProcessLifecycle.intentionalTerminations | Where-Object { $_.pid -ne $Process.Id })
    ) + @($entry)
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
    return [pscustomobject]$entry
}

function Invoke-TbgFreshTestLaunchPreflight {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [string]$Reason = 'fresh_test_launch_dll_reload'
    )

    if (-not $script:TbgProcessLifecycle) {
        throw 'Initialize-TbgProcessLifecycle must run before FreshTestLaunch preflight'
    }
    if ($script:TbgProcessLifecycle.sessionAuthorityMode -ne 'FreshTestLaunch') {
        throw "FreshTestLaunch preflight requires FreshTestLaunch mode got $($script:TbgProcessLifecycle.sessionAuthorityMode)"
    }

    $pre = Get-TbgRunningBannerlordProcessRecords
    $script:TbgProcessLifecycle.preExistingProcesses = @($pre)
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null

    foreach ($rec in @($pre)) {
        $proc = Get-Process -Id $rec.pid -ErrorAction SilentlyContinue
        if ($proc) {
            Request-TbgIntentionalTermination -Process $proc -Reason $Reason -BannerlordRoot $BannerlordRoot `
                -SessionAuthorityMode 'FreshTestLaunch' | Out-Null
        }
    }
    Start-Sleep -Seconds 2
    $script:TbgPreflightCompleted = $true
}

function Add-TbgOwnedProcessId {
    param([int]$ProcessId, [string]$BannerlordRoot)
    if (-not $script:TbgProcessLifecycle) { return }
    $owned = [System.Collections.Generic.List[int]]::new()
    foreach ($p in @($script:TbgProcessLifecycle.ownedProcessIds)) { $owned.Add([int]$p) | Out-Null }
    if ($owned -notcontains $ProcessId) { $owned.Add($ProcessId) | Out-Null }
    $script:TbgProcessLifecycle.ownedProcessIds = @($owned.ToArray())
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
}

function Write-TbgLaunchRequest {
    param(
        [string]$BannerlordRoot,
        [string]$LaunchIntent,
        [string]$RequestedBy = 'script',
        [string]$LauncherPath = $null
    )
    if (-not $script:TbgProcessLifecycle) { return }
    $script:TbgProcessLifecycle.launchRequest = [ordered]@{
        requestedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        launchIntent = [string]$LaunchIntent
        requestedBy = [string]$RequestedBy
        launcherPath = $LauncherPath
        steamUri = $null
    }
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
}

function Write-TbgLaunchSelection {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [ValidateSet('script', 'user_or_external')]
        [string]$Actor,
        [ValidateSet('play', 'continue')]
        [string]$Intent,
        [string]$ButtonText,
        [ValidateSet('uia', 'pid_global_uia', 'coordinate_fallback', 'user_handoff')]
        [string]$Method,
        [int]$Confidence = 0,
        [int]$ProcessId = 0,
        [int64]$Hwnd = 0,
        [string]$WindowTitle = $null,
        [string]$ProcessName = $null
    )

    if (-not $script:TbgProcessLifecycle) {
        $runId = (Get-Date).ToString('yyyyMMdd-HHmmss')
        Initialize-TbgProcessLifecycle -RunId $runId -BannerlordRoot $BannerlordRoot -SessionAuthorityMode 'FreshTestLaunch' -Operation 'launch_selection_only'
    }

    $script:TbgProcessLifecycle.launchSelection = [ordered]@{
        actor = [string]$Actor
        intent = [string]$Intent
        buttonText = [string]$ButtonText
        method = [string]$Method
        confidence = [int]$Confidence
        pid = [int]$ProcessId
        hwnd = [int64]$Hwnd
        windowTitle = $WindowTitle
        processName = $ProcessName
        selectedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    }
    Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
    if ($ProcessId -gt 0) { Add-TbgOwnedProcessId -ProcessId $ProcessId -BannerlordRoot $BannerlordRoot }
}

function Test-TbgCancelRequested {
    param([string]$BannerlordRoot)
    if ($script:TbgCancelRequested) { return $true }
    $path = Get-TbgCancelRunJsonPath -BannerlordRoot $BannerlordRoot
    if (-not (Test-Path -LiteralPath $path)) { return $false }
    try {
        $cancel = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        if ($cancel) {
            $script:TbgCancelRequested = $true
            $script:TbgCancelReason = [string]$cancel.reason
            return $true
        }
    } catch { }
    return $false
}

function Register-TbgCancelHandler {
    param([scriptblock]$OnCancel)
    $script:TbgOnCancel = $OnCancel
}

function Invoke-TbgCancelIfRequested {
    param([string]$BannerlordRoot)
    if (-not (Test-TbgCancelRequested -BannerlordRoot $BannerlordRoot)) { return $false }
    if ($script:TbgOnCancel) { & $script:TbgOnCancel }
    return $true
}

function Start-TbgWaitSegment {
    param(
        [Parameter(Mandatory = $true)][string]$WaitReason,
        [int]$TimeoutSec = 300,
        [int]$PollIntervalMs = 500
    )
    $script:TbgCurrentWait = [ordered]@{
        waitReason = $WaitReason
        startedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        timeoutSec = $TimeoutSec
        pollIntervalMs = $PollIntervalMs
        lastProgressSignal = $null
        endedAtUtc = $null
        result = $null
    }
    return $script:TbgCurrentWait
}

function Update-TbgWaitProgress {
    param([string]$ProgressSignal)
    if ($script:TbgCurrentWait) {
        $script:TbgCurrentWait.lastProgressSignal = [string]$ProgressSignal
    }
}

function End-TbgWaitSegment {
    param([string]$Result)
    if (-not $script:TbgCurrentWait) { return $null }
    $script:TbgCurrentWait.endedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    $script:TbgCurrentWait.result = [string]$Result
    $script:TbgWaitTimeline.Add([pscustomobject]$script:TbgCurrentWait.Clone()) | Out-Null
    $ended = $script:TbgCurrentWait
    $script:TbgCurrentWait = $null
    return $ended
}

function Save-TbgWaitTimeline {
    param([string]$OutputPath)
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    @($script:TbgWaitTimeline.ToArray()) | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    return $OutputPath
}

function Copy-TbgLifecycleArtifacts {
    param(
        [string]$BannerlordRoot,
        [string]$CheckpointDir
    )
    if (-not (Test-Path -LiteralPath $CheckpointDir)) {
        New-Item -ItemType Directory -Force -Path $CheckpointDir | Out-Null
    }
    $lifecyclePath = Get-TbgProcessLifecycleJsonPath -BannerlordRoot $BannerlordRoot
    if (Test-Path -LiteralPath $lifecyclePath) {
        Copy-Item -LiteralPath $lifecyclePath -Destination (Join-Path $CheckpointDir 'process-lifecycle.json') -Force
        $lc = Get-Content -LiteralPath $lifecyclePath -Raw | ConvertFrom-Json
        if ($lc.launchSelection) {
            $lc.launchSelection | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $CheckpointDir 'launch-selection.json') -Encoding UTF8
        }
    }
    Save-TbgWaitTimeline -OutputPath (Join-Path $CheckpointDir 'wait-timeline.json') | Out-Null
    $cancelPath = Get-TbgCancelRunJsonPath -BannerlordRoot $BannerlordRoot
    if (Test-Path -LiteralPath $cancelPath) {
        Copy-Item -LiteralPath $cancelPath -Destination (Join-Path $CheckpointDir 'cancel-state.json') -Force
    } elseif ($script:TbgCancelRequested) {
        @{ cancelled = $true; reason = $script:TbgCancelReason } | ConvertTo-Json | Set-Content `
            -LiteralPath (Join-Path $CheckpointDir 'cancel-state.json') -Encoding UTF8
    }
}

function Invoke-TbgTerminationClassification {
    param(
        [string]$BannerlordRoot,
        [string]$CyclePhase = 'unknown',
        [object]$Detection = $null,
        [bool]$CertCompleted = $false,
        [string]$Phase1Path = $null,
        [string]$StatusPath = $null,
        [object]$RuntimeLifecycle = $null,
        [int]$HeartbeatFreshSec = 30
    )

    $lifecycle = if ($script:TbgProcessLifecycle) { $script:TbgProcessLifecycle } else { Read-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot }
    $signals = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]

    if (-not $RuntimeLifecycle -and $BannerlordRoot -and (Get-Command Read-Pr11RuntimeLifecycle -ErrorAction SilentlyContinue)) {
        $RuntimeLifecycle = Read-Pr11RuntimeLifecycle -BannerlordRoot $BannerlordRoot
    }

    $heartbeatFresh = $false
    if ($RuntimeLifecycle -and $RuntimeLifecycle.parseOk -and $RuntimeLifecycle.lastHeartbeatUtc) {
        if (Get-Command Test-Pr11RuntimeHeartbeatFresh -ErrorAction SilentlyContinue) {
            $heartbeatFresh = Test-Pr11RuntimeHeartbeatFresh -RuntimeLifecycle $RuntimeLifecycle -MaxAgeSec $HeartbeatFreshSec
        } else {
            $ageSec = ((Get-Date).ToUniversalTime() - $RuntimeLifecycle.lastHeartbeatUtc).TotalSeconds
            $heartbeatFresh = ($ageSec -ge 0 -and $ageSec -le $HeartbeatFreshSec)
        }
        $signals.Add('runtime_lifecycle_present') | Out-Null
    }

    if ($script:TbgCancelRequested) {
        return [ordered]@{
            classification = 'cancelled'
            routeAgent = 'Agent C - External State Classifier / Assistive Runner'
            evidenceSignals = @('cancel_requested')
            missingSignals = @()
        }
    }

    if (-not $Detection -and $BannerlordRoot) {
        if (Get-Command Get-BannerlordProcessDetection -ErrorAction SilentlyContinue) {
            $Detection = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot -Phase1Path $Phase1Path -StatusPath $StatusPath -CacheSec 0
        }
    }

    $crashReporter = $false
    $safeMode = $false
    if (('UIAHelper' -as [type])) {
        try { $crashReporter = [UIAHelper]::HasCrashReporterDialog() } catch { }
        try { $safeMode = [UIAHelper]::HasSafeModeDialog() } catch { }
    }
    if ($crashReporter) {
        return [ordered]@{
            classification = 'crash_reporter'
            routeAgent = 'Agent C - External State Classifier / Assistive Runner'
            evidenceSignals = @('crash_reporter_visible')
            missingSignals = @()
        }
    }

    $gameRunning = $Detection -and $Detection.gameProcessRunning
    $intentionalPids = @()
    if ($lifecycle -and $lifecycle.intentionalTerminations) {
        $intentionalPids = @($lifecycle.intentionalTerminations | ForEach-Object { [int]$_.pid })
        $signals.Add('intentional_termination_recorded') | Out-Null
    }

    if (-not $gameRunning) {
        if ($safeMode) {
            return [ordered]@{
                classification = 'safe_mode_after_crash'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('safe_mode_prompt')
                missingSignals = @()
            }
        }

        $launcher = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($launcher) {
            return [ordered]@{
                classification = 'launcher_returned_after_game_exit'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('launcher_process_alive')
                missingSignals = @('game_process')
            }
        }

        if ($lifecycle -and $lifecycle.sessionAuthorityMode -eq 'FreshTestLaunch' -and $intentionalPids.Count -gt 0) {
            return [ordered]@{
                classification = 'intentional_forge_stop'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('intentional_termination_recorded', 'fresh_test_launch')
                missingSignals = @()
            }
        }

        if ($lifecycle -and $lifecycle.sessionAuthorityMode -eq 'RunnerCleanup') {
            return [ordered]@{
                classification = 'intentional_runner_cleanup'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('runner_cleanup_mode')
                missingSignals = @()
            }
        }

        if ($RuntimeLifecycle -and $RuntimeLifecycle.parseOk) {
            if ($RuntimeLifecycle.gracefulShutdownObserved) {
                return [ordered]@{
                    classification = 'clean_shutdown'
                    routeAgent = 'Agent A - Cert / Evidence / Git / PR'
                    evidenceSignals = @('gracefulShutdownObserved')
                    missingSignals = @()
                }
            }
            if ($RuntimeLifecycle.lastCommandStartedAtUtc -and -not $RuntimeLifecycle.lastCommandFinishedAtUtc) {
                return [ordered]@{
                    classification = 'command_in_flight_exit'
                    routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
                    evidenceSignals = @('lastCommandStartedAtUtc', 'lastCommandFinishedAtUtc_missing')
                    missingSignals = @('command_finish_recorded')
                }
            }
            if (-not $RuntimeLifecycle.gracefulShutdownObserved -and -not $heartbeatFresh) {
                return [ordered]@{
                    classification = 'crash_or_unexpected_exit'
                    routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
                    evidenceSignals = @('runtime_heartbeat_stale', 'no_graceful_shutdown')
                    missingSignals = @('gracefulShutdownObserved')
                }
            }
        }

        if ($CertCompleted) {
            return [ordered]@{
                classification = 'game_exited_cleanly_after_cert'
                routeAgent = 'Agent A - Cert / Evidence / Git / PR'
                evidenceSignals = @('cert_completed')
                missingSignals = @()
            }
        }

        if ($CyclePhase -eq 'loading') {
            return [ordered]@{
                classification = 'process_disappeared_during_loading'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @()
                missingSignals = @('intentional_termination_recorded')
            }
        }
        if ($CyclePhase -eq 'cert') {
            return [ordered]@{
                classification = 'process_disappeared_during_cert'
                routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
                evidenceSignals = @()
                missingSignals = @('intentional_termination_recorded')
            }
        }

        $phase1Fresh = $false
        $statusFresh = $false
        if (Get-Command Test-BannerlordLogFresh -ErrorAction SilentlyContinue) {
            $phase1Fresh = Test-BannerlordLogFresh -Path $Phase1Path -MaxAgeSec 15
            $statusFresh = Test-BannerlordLogFresh -Path $StatusPath -MaxAgeSec 15
        }
        if ($statusFresh -and -not $gameRunning) {
            return [ordered]@{
                classification = 'status_stale_process_gone'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('status_was_fresh')
                missingSignals = @('game_process')
            }
        }

        if ($lifecycle -and $lifecycle.launchSelection -and $lifecycle.launchSelection.actor -eq 'user_or_external') {
            return [ordered]@{
                classification = 'user_closed_game'
                routeAgent = 'Agent C - External State Classifier / Assistive Runner'
                evidenceSignals = @('user_or_external_launch_selection')
                missingSignals = @('script_ownership')
            }
        }

        return [ordered]@{
            classification = 'unknown_unowned_exit'
            routeAgent = 'Agent C - External State Classifier / Assistive Runner'
            evidenceSignals = @($signals.ToArray())
            missingSignals = @('intentional_termination_recorded', 'crash_reporter', 'owned_process')
        }
    }

    $statusFresh = $false
    if (Get-Command Test-BannerlordLogFresh -ErrorAction SilentlyContinue) {
        $statusFresh = Test-BannerlordLogFresh -Path $StatusPath -MaxAgeSec 60
    }
    if (-not $statusFresh -and $gameRunning) {
        if ($RuntimeLifecycle -and $RuntimeLifecycle.parseOk -and -not $heartbeatFresh) {
            return [ordered]@{
                classification = 'status_stale_process_alive'
                routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
                evidenceSignals = @('game_process_alive', 'status_stale', 'runtime_heartbeat_stale')
                missingSignals = @('fresh_status', 'fresh_heartbeat')
            }
        }
        return [ordered]@{
            classification = 'status_stale_process_alive'
            routeAgent = 'Agent B - Runtime / Readiness / Gameplay safety'
            evidenceSignals = @('game_process_alive')
            missingSignals = @('fresh_status')
        }
    }

    return [ordered]@{
        classification = 'game_process_running'
        routeAgent = $null
        evidenceSignals = @('game_process_alive')
        missingSignals = @()
    }
}

function Write-TbgTerminationDetection {
    param(
        [string]$BannerlordRoot,
        [string]$OutputPath,
        [hashtable]$Extra = @{}
    )
    $cls = Invoke-TbgTerminationClassification @Extra
    if ($script:TbgProcessLifecycle) {
        $script:TbgProcessLifecycle.termination = [ordered]@{
            observed = $true
            classification = $cls.classification
            observedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
            routeAgent = $cls.routeAgent
            evidenceSignals = @($cls.evidenceSignals)
        }
        Save-TbgProcessLifecycle -BannerlordRoot $BannerlordRoot | Out-Null
    }
    $out = [ordered]@{}
    foreach ($k in $cls.Keys) { $out[$k] = $cls[$k] }
    foreach ($k in $Extra.Keys) { if ($k -ne 'BannerlordRoot') { $out[$k] = $Extra[$k] } }
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $out | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    return [pscustomobject]$out
}

function Test-TbgPreflightCompleted { return [bool]$script:TbgPreflightCompleted }
