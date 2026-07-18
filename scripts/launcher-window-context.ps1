# Shared launcher PID/window context helper.
# This script owns the launcher-context baseline for launch-adjacent entry points.
# It does not click PLAY/CONTINUE and it does not claim runtime proof.
# It starts the metadata-first modal watcher so known windows are classified and
# handled before coordinate or image fallbacks are considered.

$ErrorActionPreference = 'Stop'

if (-not (Get-Command Get-Pr11ProcessSnapshot -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')
}

if (-not (Get-Command Resolve-TbgTestDurationBudget -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'test-duration-policy.ps1')
}

function Get-TbgLauncherWindowContextPath {
    param([Parameter(Mandatory = $true)][string]$BannerlordRoot)
    return (Join-Path $BannerlordRoot 'launcher-window-context.json')
}

function Save-TbgLauncherWindowContextJson {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $Context | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}

function Read-TbgLauncherWindowContext {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Test-TbgLauncherWindowContextFresh {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [int]$MaxAgeSeconds = 60
    )
    if (-not $Context -or -not $Context.createdAtUtc) { return $false }
    try {
        $created = [datetime]::Parse([string]$Context.createdAtUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind)
        return (((Get-Date).ToUniversalTime() - $created.ToUniversalTime()).TotalSeconds -le $MaxAgeSeconds)
    } catch {
        return $false
    }
}

function Get-TbgLauncherProcessCandidate {
    param([switch]$PreferVisibleWindow)
    $launchers = @(Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue)
    if ($launchers.Count -eq 0) { return $null }

    foreach ($candidate in $launchers) {
        try { $candidate.Refresh() } catch { }
    }

    $ordered = @($launchers | Sort-Object @{ Expression = { if ($_.MainWindowHandle -ne [IntPtr]::Zero) { 1 } else { 0 } }; Descending = $true }, StartTime -Descending)

    if ($PreferVisibleWindow) {
        $visible = @($ordered | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero })
        if ($visible.Count -gt 0) { return $visible[0] }
    }

    return $ordered[0]
}

function New-TbgLauncherWindowContextObject {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][string]$LaunchIntent,
        [Parameter(Mandatory = $true)][string]$BaselineSnapshotPath,
        [Parameter(Mandatory = $true)]$BaselineSnapshot,
        [string]$BaselineSource,
        [string]$ContextSource,
        [bool]$IsExistingLauncherReuse,
        [bool]$IsFreshLaunch,
        $LauncherProcess = $null,
        [string]$CreatedBy = $null,
        [string]$FallbackClass = $null,
        [string]$FallbackReason = $null
    )

    $launcherProcessId = 0
    $hwnd = 0
    $title = ''
    $processName = $null
    $rect = $null
    if ($LauncherProcess) {
        try { $launcherProcessId = [int]$LauncherProcess.Id } catch { }
        try { $hwnd = [int64]$LauncherProcess.MainWindowHandle } catch { }
        try { $title = [string]$LauncherProcess.MainWindowTitle } catch { }
        try { $processName = [string]$LauncherProcess.ProcessName } catch { }
        if ($hwnd -ne 0) {
            try { $rect = Get-Pr11WindowRectangle -Hwnd ([IntPtr]$hwnd) } catch { }
        }
    }

    return [pscustomobject][ordered]@{
        schema = 'TbgLauncherWindowContext.v1'
        sessionId = (Get-Date).ToString('yyyyMMdd-HHmmss')
        launchIntent = [string]$LaunchIntent
        bannerlordRoot = [string]$BannerlordRoot
        baselineSnapshotPath = [string]$BaselineSnapshotPath
        baselineCapturedUtc = [string]$BaselineSnapshot.capturedAtUtc
        baselineSource = [string]$BaselineSource
        processId = $launcherProcessId
        hwnd = $hwnd
        processName = $processName
        windowTitle = $title
        rect = $rect
        score = if ($hwnd -ne 0) { 70 } elseif ($launcherProcessId -ne 0) { 45 } else { 0 }
        reason = if ($IsExistingLauncherReuse) { 'existing_launcher_reuse_context' } elseif ($IsFreshLaunch) { 'fresh_launcher_context' } else { 'launcher_context' }
        contextSource = [string]$ContextSource
        isExistingLauncherReuse = [bool]$IsExistingLauncherReuse
        isFreshLaunch = [bool]$IsFreshLaunch
        createdBy = if ($CreatedBy) { [string]$CreatedBy } else { [string]$MyInvocation.ScriptName }
        createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        fallbackClass = $FallbackClass
        fallbackReason = $FallbackReason
    }
}

function Get-TbgWindowIntelligencePowerShell {
    $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if ($pwsh) { return [string]$pwsh.Source }
    $windowsPowerShell = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if ($windowsPowerShell) { return [string]$windowsPowerShell.Source }
    return $null
}

function Start-TbgWindowIntelligenceWatcher {
    param(
        [Parameter(Mandatory = $true)][int]$LauncherProcessId,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][string]$ContextPath
    )

    if ($env:TBG_WINDOW_INTELLIGENCE_DISABLE -eq '1') {
        return [pscustomobject][ordered]@{
            started = $false
            reason = 'disabled_by_environment'
            watcherProcessId = 0
        }
    }

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $watcherScript = Join-Path $repoRoot 'scripts\tbg\Invoke-TbgWindowIntelligence.ps1'
    if (-not (Test-Path -LiteralPath $watcherScript -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            started = $false
            reason = 'window_intelligence_script_missing'
            watcherProcessId = 0
        }
    }

    $localRoot = Join-Path $repoRoot '.local\tbg-window-intelligence'
    $leasePath = Join-Path $localRoot 'watcher.json'
    if (Test-Path -LiteralPath $leasePath -PathType Leaf) {
        try {
            $lease = Get-Content -LiteralPath $leasePath -Raw -Encoding UTF8 | ConvertFrom-Json
            $existingWatcher = Get-Process -Id ([int]$lease.processId) -ErrorAction SilentlyContinue
            if ($existingWatcher) {
                return [pscustomobject][ordered]@{
                    started = $false
                    reason = 'existing_window_intelligence_watcher_alive'
                    watcherProcessId = [int]$lease.processId
                    leasePath = $leasePath
                }
            }
        } catch { }
        Remove-Item -LiteralPath $leasePath -Force -ErrorAction SilentlyContinue
    }

    $powerShellExe = Get-TbgWindowIntelligencePowerShell
    if ([string]::IsNullOrWhiteSpace($powerShellExe)) {
        return [pscustomobject][ordered]@{
            started = $false
            reason = 'powershell_executable_not_found'
            watcherProcessId = 0
        }
    }

    $lifecycleRunId = 'wl-{0}-{1}' -f ([DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')), ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    $lifecycleCorrelationId = 'wl-corr-{0}' -f ([Guid]::NewGuid().ToString('N').Substring(0, 12))
    $argumentLine = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Command watch -Mode auto -ProcessId {1} -BannerlordRoot "{2}" -ContextPath "{3}" -LifecycleRunId "{4}" -LifecycleCorrelationId "{5}" -DurationSeconds 90 -PollMilliseconds 100 -AllowKnownActions' -f `
        $watcherScript, $LauncherProcessId, $BannerlordRoot, $ContextPath, $lifecycleRunId, $lifecycleCorrelationId

    try {
        $watcher = Start-Process -FilePath $powerShellExe -ArgumentList $argumentLine -WindowStyle Hidden -PassThru
        return [pscustomobject][ordered]@{
            started = $true
            reason = 'metadata_first_modal_watcher_started'
            watcherProcessId = [int]$watcher.Id
            targetProcessId = $LauncherProcessId
            leasePath = $leasePath
            lifecycleRunId = $lifecycleRunId
            lifecycleCorrelationId = $lifecycleCorrelationId
            resultPath = Join-Path $repoRoot 'artifacts\latest\window-intelligence\window-intelligence.result.json'
            reportPath = Join-Path $repoRoot 'artifacts\latest\window-intelligence\window-intelligence.report.md'
            lifecycleResultPath = Join-Path $repoRoot 'artifacts\latest\window-lifecycle\window-lifecycle.result.json'
            lifecycleReportPath = Join-Path $repoRoot 'artifacts\latest\window-lifecycle\window-lifecycle.report.md'
        }
    } catch {
        return [pscustomobject][ordered]@{
            started = $false
            reason = 'window_intelligence_watcher_start_failed'
            watcherProcessId = 0
            error = $_.Exception.Message
        }
    }
}

function Ensure-TbgLauncherWindowContext {
    param(
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet('play', 'continue')]
        [string]$LaunchIntent,
        [ValidateSet('LaunchSetup', 'OpenOnly')]
        [string]$Mode = 'LaunchSetup',
        [switch]$AllowExistingProcess,
        [string]$CreatedBy = $null
    )

    $launcherExe = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'
    if (-not (Test-Path -LiteralPath $launcherExe)) {
        throw "Launcher not found: $launcherExe"
    }

    $contextPath = Get-TbgLauncherWindowContextPath -BannerlordRoot $BannerlordRoot
    $baselinePath = Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json'
    $gameRunning = [bool](Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)
    $launcher = Get-TbgLauncherProcessCandidate -PreferVisibleWindow
    $existingLauncherReuse = [bool]($launcher -and -not $gameRunning)

    $preflightOk = $false
    if (Get-Command Test-TbgPreflightCompleted -ErrorAction SilentlyContinue) { $preflightOk = Test-TbgPreflightCompleted }
    if ($gameRunning -and -not $AllowExistingProcess -and -not $preflightOk) {
        throw 'Bannerlord game is already running (Bannerlord.exe). Forge Stop approval is required before opening or reusing launcher context.'
    }

    $baselineLabel = if ($existingLauncherReuse) { 'S1_existing_launcher_reuse' } else { 'S1_pre_launch' }
    $baseline = Get-Pr11ProcessSnapshot -Label $baselineLabel -BannerlordRoot $BannerlordRoot
    Save-Pr11ProcessSnapshot -Snapshot $baseline -OutputPath $baselinePath | Out-Null

    $freshLaunch = $false
    if (-not $launcher -and $Mode -eq 'LaunchSetup') {
        $durationBudget = Resolve-TbgTestDurationBudget -Caller 'launcher-window-context.ps1'
        Write-TbgTestDurationBudget -Budget $durationBudget
        $deadline = New-TbgTestDurationDeadline -Budget $durationBudget
        $startedLauncher = Start-Process -FilePath $launcherExe -WorkingDirectory (Split-Path -Parent $launcherExe) -PassThru
        $freshLaunch = $true
        do {
            Start-Sleep -Milliseconds 250
            $launcher = Get-TbgLauncherProcessCandidate -PreferVisibleWindow

            if (-not $launcher -and $startedLauncher) {
                $launcher = Get-Process -Id $startedLauncher.Id -ErrorAction SilentlyContinue
            }

            if ($launcher) {
                try { $launcher.Refresh() } catch { }
            }

            $hasUsableLauncherHwnd = [bool]($launcher -and $launcher.MainWindowHandle -ne [IntPtr]::Zero)
        } while (-not $hasUsableLauncherHwnd -and -not (Test-TbgTestDurationExpired -Deadline $deadline))

        if (-not $launcher) {
            throw 'Launcher was started, but no launcher process could be bound for context.'
        }

        if ($launcher.MainWindowHandle -eq [IntPtr]::Zero) {
            throw 'Launcher was started, but no launcher hwnd could be bound for frozen context.'
        }
    }

    $context = New-TbgLauncherWindowContextObject -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent `
        -BaselineSnapshotPath $baselinePath -BaselineSnapshot $baseline `
        -BaselineSource $baselineLabel -ContextSource 'Ensure-TbgLauncherWindowContext' `
        -IsExistingLauncherReuse:$existingLauncherReuse -IsFreshLaunch:$freshLaunch `
        -LauncherProcess $launcher -CreatedBy $CreatedBy

    Save-TbgLauncherWindowContextJson -Context $context -Path $contextPath | Out-Null

    if ($Mode -eq 'LaunchSetup' -and [int]$context.processId -gt 0) {
        $windowIntelligence = Start-TbgWindowIntelligenceWatcher -LauncherProcessId ([int]$context.processId) `
            -BannerlordRoot $BannerlordRoot -ContextPath $contextPath
        $context | Add-Member -NotePropertyName windowIntelligence -NotePropertyValue $windowIntelligence -Force
        Save-TbgLauncherWindowContextJson -Context $context -Path $contextPath | Out-Null
    }

    return [pscustomobject][ordered]@{
        path = $contextPath
        context = $context
        baselineSnapshotPath = $baselinePath
    }
}
