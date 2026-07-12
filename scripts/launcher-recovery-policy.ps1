# Bounded launcher recovery policy for Forge / ForgeContinue.
# Dot-source from launcher-modal-aware-context-nav.ps1 after bannerlord-paths.ps1.

function Get-TbgLauncherRecoveryArtifactPaths {
    param([Parameter(Mandatory = $true)][string]$BannerlordRoot)

    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add((Join-Path $BannerlordRoot 'BlacksmithGuild_LauncherRecovery.json')) | Out-Null
    try {
        $docsRoot = Get-BannerlordDocsRoot
        if ($docsRoot) {
            $docsPath = Join-Path $docsRoot 'BlacksmithGuild_LauncherRecovery.json'
            if ($paths -notcontains $docsPath) { $paths.Add($docsPath) | Out-Null }
        }
    } catch { }
    return @($paths.ToArray())
}

function Write-TbgLauncherRecoveryState {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][ValidateSet('play', 'continue')][string]$LaunchIntent,
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][int]$Attempt,
        [Parameter(Mandatory = $true)][int]$MaxAttempts,
        [string]$FailureClass = $null,
        [string]$FailureSignature = $null,
        [string]$PreviousFailureSignature = $null,
        [Nullable[bool]]$SameFailureAsPrevious = $null,
        [Nullable[int]]$InnerExitCode = $null,
        [string]$Reason = $null,
        [string[]]$TerminatedProcesses = @(),
        [string]$LauncherContextPath = $null
    )

    $result = [ordered]@{
        schema = 'TbgLauncherRecovery.v1'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        launchIntent = $LaunchIntent
        state = $State
        attempt = $Attempt
        maxAttempts = $MaxAttempts
        retryCount = [Math]::Max(0, $Attempt - 1)
        failureClass = $FailureClass
        failureSignature = $FailureSignature
        previousFailureSignature = $PreviousFailureSignature
        sameFailureAsPrevious = if ($SameFailureAsPrevious.HasValue) { $SameFailureAsPrevious.Value } else { $null }
        innerExitCode = if ($InnerExitCode.HasValue) { $InnerExitCode.Value } else { $null }
        reason = $Reason
        terminatedProcesses = @($TerminatedProcesses)
        launcherContextPath = $LauncherContextPath
        forceCloseScope = @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')
        runtimeProofClaim = $false
    }

    $json = $result | ConvertTo-Json -Depth 8
    foreach ($path in @(Get-TbgLauncherRecoveryArtifactPaths -BannerlordRoot $BannerlordRoot)) {
        try {
            $parent = Split-Path -Parent $path
            if ($parent -and -not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Force -Path $parent | Out-Null
            }
            Set-Content -LiteralPath $path -Value $json -Encoding UTF8
        } catch { }
    }
    return [pscustomobject]$result
}

function Read-TbgLauncherRecoveryState {
    param([Parameter(Mandatory = $true)][string]$BannerlordRoot)

    foreach ($path in @(Get-TbgLauncherRecoveryArtifactPaths -BannerlordRoot $BannerlordRoot)) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($state -and [string]$state.schema -eq 'TbgLauncherRecovery.v1') {
                return $state
            }
        } catch { }
    }
    return $null
}

function ConvertTo-TbgLauncherSignatureToken {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return 'none' }
    $token = $Value.Trim() -replace '[^A-Za-z0-9_.-]+', '_'
    if ($token.Length -gt 80) { $token = $token.Substring(0, 80) }
    return $token
}

function Get-TbgLauncherFailureSignature {
    param(
        [Parameter(Mandatory = $true)][string]$FailureClass,
        $Snapshot = $null,
        [string]$Detail = $null
    )

    $processExists = if ($Snapshot) { [bool]$Snapshot.processExists } else { $false }
    $processName = if ($Snapshot) { ConvertTo-TbgLauncherSignatureToken ([string]$Snapshot.processName) } else { 'none' }
    $title = if ($Snapshot) { ConvertTo-TbgLauncherSignatureToken ([string]$Snapshot.title) } else { 'none' }
    $sameHwnd = if ($Snapshot) { [bool]$Snapshot.sameHwnd } else { $false }
    $width = if ($Snapshot) { [int]$Snapshot.width } else { 0 }
    $height = if ($Snapshot) { [int]$Snapshot.height } else { 0 }
    $detailToken = ConvertTo-TbgLauncherSignatureToken $Detail
    return 'class={0};processExists={1};process={2};title={3};sameHwnd={4};size={5}x{6};detail={7}' -f `
        (ConvertTo-TbgLauncherSignatureToken $FailureClass), $processExists, $processName, $title, $sameHwnd, $width, $height, $detailToken
}

function Stop-TbgLauncherProcessFamilyForRetry {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [int]$WaitSec = 8
    )

    $terminated = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
                $terminated.Add(('{0}:pid={1}' -f $name, $process.Id)) | Out-Null
            } catch {
                $terminated.Add(('{0}:pid={1}:stop_error={2}' -f $name, $process.Id, (ConvertTo-TbgLauncherSignatureToken $_.Exception.Message))) | Out-Null
            }
        }
    }

    $deadline = (Get-Date).AddSeconds([Math]::Max(1, $WaitSec))
    do {
        $remaining = @()
        foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
            $remaining += @(Get-Process -Name $name -ErrorAction SilentlyContinue)
        }
        if ($remaining.Count -eq 0) { break }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)

    $stillRunning = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            $stillRunning.Add(('{0}:pid={1}' -f $name, $process.Id)) | Out-Null
        }
    }
    if ($stillRunning.Count -gt 0) {
        throw ('launcher_recovery_force_close_incomplete: {0}' -f (($stillRunning.ToArray()) -join ','))
    }

    return @($terminated.ToArray())
}

function Invoke-TbgLauncherRecoveryRetry {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][ValidateSet('play', 'continue')][string]$LaunchIntent,
        [Parameter(Mandatory = $true)][string]$LauncherContextPath,
        [Parameter(Mandatory = $true)][string]$RetryScriptPath,
        [Parameter(Mandatory = $true)][string]$FailureClass,
        [Parameter(Mandatory = $true)][string]$FailureSignature,
        [int]$RecoveryAttempt = 0,
        [ValidateRange(0, 2)][int]$MaxRecoveryRetries = 1,
        [string]$PreviousFailureSignature = $null,
        [int]$InnerExitCode = 1,
        [int]$TimeoutSec = 0,
        [int]$PollMs = 250,
        [bool]$RespectUserForeground = $true,
        [switch]$AllowFocusSteal,
        [switch]$LaunchSetup,
        [switch]$AllowLongRun,
        [string]$LongRunReason,
        [Parameter(Mandatory = $true)][scriptblock]$Log
    )

    $attempt = $RecoveryAttempt + 1
    $maxAttempts = $MaxRecoveryRetries + 1
    $sameFailure = -not [string]::IsNullOrWhiteSpace($PreviousFailureSignature) -and `
        [string]::Equals($PreviousFailureSignature, $FailureSignature, [StringComparison]::Ordinal)

    if (-not $LaunchSetup -or $RecoveryAttempt -ge $MaxRecoveryRetries) {
        & $Log ('LAUNCH_STATE=launcher_recovery_dead_end classification=launcher_recovery_dead_end attempt={0} maxAttempts={1} sameFailureAsPrevious={2} failureClass={3} failureSignature="{4}" previousFailureSignature="{5}" innerExitCode={6} launchSetup={7} runtimeProofClaim=false' -f `
            $attempt, $maxAttempts, $sameFailure, $FailureClass, $FailureSignature, ([string]$PreviousFailureSignature), $InnerExitCode, $LaunchSetup.IsPresent)
        Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
            -State 'dead_end' -Attempt $attempt -MaxAttempts $maxAttempts -FailureClass $FailureClass `
            -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
            -SameFailureAsPrevious $sameFailure -InnerExitCode $InnerExitCode `
            -Reason $(if (-not $LaunchSetup) { 'launch_setup_required_for_retry' } else { 'retry_budget_exhausted' }) `
            -LauncherContextPath $LauncherContextPath | Out-Null
        throw ('operator_action_required: launcher recovery dead end after {0}/{1} attempt(s); sameFailureAsPrevious={2}; failureClass={3}; see BlacksmithGuild_LauncherRecovery.json' -f `
            $attempt, $maxAttempts, $sameFailure, $FailureClass)
    }

    $nextAttempt = $attempt + 1
    & $Log ('LAUNCH_STATE=launcher_recovery_retry_scheduled classification=bounded_launcher_retry currentAttempt={0} nextAttempt={1} maxAttempts={2} action=force_close_launcher_family_and_retry failureClass={3} failureSignature="{4}" runtimeProofClaim=false' -f `
        $attempt, $nextAttempt, $maxAttempts, $FailureClass, $FailureSignature)
    Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
        -State 'retry_scheduled' -Attempt $attempt -MaxAttempts $maxAttempts -FailureClass $FailureClass `
        -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
        -SameFailureAsPrevious $sameFailure -InnerExitCode $InnerExitCode -Reason 'bounded_retry_available' `
        -LauncherContextPath $LauncherContextPath | Out-Null

    $terminated = @()
    try {
        & $Log ('LAUNCH_STATE=launcher_recovery_force_close_started attempt={0} scope=Bannerlord|TaleWorlds.MountAndBlade.Launcher|Watchdog runtimeProofClaim=false' -f $attempt)
        $terminated = @(Stop-TbgLauncherProcessFamilyForRetry -BannerlordRoot $BannerlordRoot)
        if (Test-Path -LiteralPath $LauncherContextPath) {
            Remove-Item -LiteralPath $LauncherContextPath -Force -ErrorAction SilentlyContinue
        }
        & $Log ('LAUNCH_STATE=launcher_recovery_force_close_complete attempt={0} terminatedCount={1} terminated="{2}" staleContextRemoved=true runtimeProofClaim=false' -f `
            $attempt, $terminated.Count, ($terminated -join ','))
        Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
            -State 'force_close_complete' -Attempt $attempt -MaxAttempts $maxAttempts -FailureClass $FailureClass `
            -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
            -SameFailureAsPrevious $sameFailure -InnerExitCode $InnerExitCode -Reason 'launcher_process_family_closed' `
            -TerminatedProcesses $terminated -LauncherContextPath $LauncherContextPath | Out-Null

        & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent
    } catch {
        $restartReason = ConvertTo-TbgLauncherSignatureToken $_.Exception.Message
        & $Log ('LAUNCH_STATE=launcher_recovery_dead_end classification=launcher_recovery_restart_failed attempt={0} maxAttempts={1} sameFailureAsPrevious={2} failureClass={3} restartReason="{4}" runtimeProofClaim=false' -f `
            $attempt, $maxAttempts, $sameFailure, $FailureClass, $restartReason)
        Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
            -State 'dead_end' -Attempt $attempt -MaxAttempts $maxAttempts -FailureClass 'launcher_recovery_restart_failed' `
            -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
            -SameFailureAsPrevious $sameFailure -InnerExitCode $InnerExitCode -Reason $restartReason `
            -TerminatedProcesses $terminated -LauncherContextPath $LauncherContextPath | Out-Null
        throw
    }

    $retryArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $RetryScriptPath,
        '-LaunchIntent', $LaunchIntent,
        '-BannerlordRoot', $BannerlordRoot,
        '-PollMs', ([string]$PollMs),
        '-LauncherContextPath', $LauncherContextPath,
        '-RespectUserForeground', ([string]([bool]$RespectUserForeground)),
        '-RecoveryAttempt', ([string]($RecoveryAttempt + 1)),
        '-MaxRecoveryRetries', ([string]$MaxRecoveryRetries),
        '-PreviousFailureSignature', $FailureSignature
    )
    if ($TimeoutSec -gt 0) { $retryArgs += @('-TimeoutSec', ([string]$TimeoutSec)) }
    if ($AllowFocusSteal) { $retryArgs += '-AllowFocusSteal' }
    if ($LaunchSetup) { $retryArgs += '-LaunchSetup' }
    if ($AllowLongRun) { $retryArgs += '-AllowLongRun' }
    if ($LongRunReason) { $retryArgs += @('-LongRunReason', $LongRunReason) }

    & $Log ('LAUNCH_STATE=launcher_recovery_retry_started attempt={0} maxAttempts={1} freshContextExpected=true previousFailureSignature="{2}" runtimeProofClaim=false' -f `
        $nextAttempt, $maxAttempts, $FailureSignature)
    Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
        -State 'retry_started' -Attempt $nextAttempt -MaxAttempts $maxAttempts -FailureClass $FailureClass `
        -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
        -SameFailureAsPrevious $sameFailure -InnerExitCode $InnerExitCode -Reason 'fresh_launcher_context_retry_started' `
        -TerminatedProcesses $terminated -LauncherContextPath $LauncherContextPath | Out-Null

    & powershell.exe @retryArgs
    $retryExit = $LASTEXITCODE
    if ($retryExit -eq 0) {
        & $Log ('LAUNCH_STATE=launcher_recovery_recovered classification=launcher_recovery_recovered attempt={0} maxAttempts={1} recoveredAfterForceClose=true runtimeProofClaim=false' -f `
            $nextAttempt, $maxAttempts)
        Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
            -State 'recovered' -Attempt $nextAttempt -MaxAttempts $maxAttempts -FailureClass $FailureClass `
            -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
            -SameFailureAsPrevious $sameFailure -InnerExitCode 0 -Reason 'retry_succeeded' `
            -TerminatedProcesses $terminated -LauncherContextPath $LauncherContextPath | Out-Null
        return 0
    }

    $childState = Read-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot
    if ($childState -and [string]$childState.state -eq 'dead_end') {
        & $Log ('LAUNCH_STATE=launcher_recovery_retry_child_failed attempt={0} maxAttempts={1} childExitCode={2} sameFailureAsPrevious={3} finalFailureClass={4} finalFailureSignature="{5}" terminalEvidence=BlacksmithGuild_LauncherRecovery.json runtimeProofClaim=false' -f `
            $nextAttempt, $maxAttempts, $retryExit, $childState.sameFailureAsPrevious, ([string]$childState.failureClass), ([string]$childState.failureSignature))
    } else {
        & $Log ('LAUNCH_STATE=launcher_recovery_retry_child_failed attempt={0} maxAttempts={1} childExitCode={2} terminalEvidence=BlacksmithGuild_LauncherRecovery.json runtimeProofClaim=false' -f `
            $nextAttempt, $maxAttempts, $retryExit)
        Write-TbgLauncherRecoveryState -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
            -State 'dead_end' -Attempt $nextAttempt -MaxAttempts $maxAttempts -FailureClass 'launcher_retry_child_failed_without_terminal_state' `
            -FailureSignature $FailureSignature -PreviousFailureSignature $PreviousFailureSignature `
            -SameFailureAsPrevious $sameFailure -InnerExitCode $retryExit -Reason 'retry_child_failed_without_terminal_state' `
            -TerminatedProcesses $terminated -LauncherContextPath $LauncherContextPath | Out-Null
    }
    throw ('operator_action_required: launcher retry attempt {0}/{1} failed with exit {2}; see launcher_recovery_dead_end and BlacksmithGuild_LauncherRecovery.json' -f `
        $nextAttempt, $maxAttempts, $retryExit)
}
