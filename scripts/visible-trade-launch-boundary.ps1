Set-StrictMode -Version Latest

function Test-TbgLiveRuntimeAuthorityFacts {
    param(
        [string]$Confidence,
        [int]$ProcessId,
        [bool]$ProcessExists,
        [string]$WindowTitle = ''
    )

    if ($ProcessId -le 0 -or -not $ProcessExists) { return $false }
    if ($Confidence -eq 'definite') { return $true }
    if ($Confidence -eq 'launcher_hosted') {
        return $WindowTitle -like 'Mount and Blade II Bannerlord - Singleplayer*'
    }
    return $false
}

function Test-TbgOwnedLauncherCleanupFacts {
    param(
        [Parameter(Mandatory = $true)]$Context,
        [Parameter(Mandatory = $true)]$Baseline,
        [Parameter(Mandatory = $true)]$Process,
        [Parameter(Mandatory = $true)][string]$BannerlordRoot,
        [Parameter(Mandatory = $true)][datetime]$LaunchStartedAtUtc,
        [Parameter(Mandatory = $true)][bool]$RuntimeLive
    )

    $reasons = New-Object System.Collections.Generic.List[string]
    $expectedLauncherPath = Join-Path $BannerlordRoot 'bin\Win64_Shipping_Client\TaleWorlds.MountAndBlade.Launcher.exe'
    $expectedBaselinePath = Join-Path $BannerlordRoot 'window-snapshot-S1-pre-launch.json'

    if ([string]$Context.schema -ne 'TbgLauncherWindowContext.v1') { $reasons.Add('context_schema') }
    if ($Context.isFreshLaunch -ne $true) { $reasons.Add('context_not_fresh_launch') }
    if ($Context.isExistingLauncherReuse -eq $true) { $reasons.Add('context_reused_launcher') }
    if ([string]$Context.createdBy -ne 'open-bannerlord-launcher.ps1') { $reasons.Add('context_creator') }
    if (-not [string]::Equals([string]$Context.bannerlordRoot, $BannerlordRoot, [System.StringComparison]::OrdinalIgnoreCase)) { $reasons.Add('context_root') }
    if (-not [string]::Equals([string]$Context.baselineSnapshotPath, $expectedBaselinePath, [System.StringComparison]::OrdinalIgnoreCase)) { $reasons.Add('context_baseline_path') }
    if ([string]$Context.baselineSource -ne 'S1_pre_launch') { $reasons.Add('context_baseline_source') }
    if ([int]$Context.processId -le 0 -or [int64]$Context.hwnd -eq 0) { $reasons.Add('context_identity') }
    if ([string]$Context.processName -ne 'TaleWorlds.MountAndBlade.Launcher') { $reasons.Add('context_process_name') }

    $contextCreatedUtc = $null
    try { $contextCreatedUtc = [datetime]::Parse([string]$Context.createdAtUtc).ToUniversalTime() } catch { $reasons.Add('context_created_at') }
    if ($contextCreatedUtc -and $contextCreatedUtc -lt $LaunchStartedAtUtc.AddSeconds(-2)) { $reasons.Add('context_stale') }

    if ([string]$Baseline.label -ne 'S1_pre_launch') { $reasons.Add('baseline_label') }
    if (-not [string]::Equals([string]$Baseline.bannerlordRoot, $BannerlordRoot, [System.StringComparison]::OrdinalIgnoreCase)) { $reasons.Add('baseline_root') }
    $baselineCapturedUtc = $null
    try { $baselineCapturedUtc = [datetime]::Parse([string]$Baseline.capturedAtUtc).ToUniversalTime() } catch { $reasons.Add('baseline_captured_at') }
    if ($baselineCapturedUtc -and $baselineCapturedUtc -lt $LaunchStartedAtUtc.AddSeconds(-2)) { $reasons.Add('baseline_stale') }
    if ($contextCreatedUtc -and $baselineCapturedUtc -and $baselineCapturedUtc -gt $contextCreatedUtc) { $reasons.Add('baseline_after_context') }
    if (@($Baseline.processes | Where-Object { [int]$_.pid -eq [int]$Context.processId }).Count -gt 0) { $reasons.Add('pid_present_in_baseline') }

    if ([int]$Process.pid -ne [int]$Context.processId) { $reasons.Add('process_pid') }
    if ([int64]$Process.hwnd -ne [int64]$Context.hwnd) { $reasons.Add('process_hwnd') }
    if ([string]$Process.name -ne 'TaleWorlds.MountAndBlade.Launcher') { $reasons.Add('process_name') }
    if (-not [string]::Equals([string]$Process.path, $expectedLauncherPath, [System.StringComparison]::OrdinalIgnoreCase)) { $reasons.Add('process_path') }
    if ([string]$Process.windowTitle -like 'Mount and Blade II Bannerlord - Singleplayer*') { $reasons.Add('hosted_runtime_title') }
    if ([string]$Process.windowTitle -notlike 'M&B II: Bannerlord*') { $reasons.Add('not_launcher_menu_title') }
    $processStartedUtc = $null
    try { $processStartedUtc = [datetime]::Parse([string]$Process.startedAtUtc).ToUniversalTime() } catch { $reasons.Add('process_started_at') }
    if ($processStartedUtc -and $processStartedUtc -lt $LaunchStartedAtUtc.AddSeconds(-2)) { $reasons.Add('process_predates_launch') }
    if ($RuntimeLive) { $reasons.Add('runtime_live') }

    return [PSCustomObject][ordered]@{
        eligible = $reasons.Count -eq 0
        reasons = @($reasons)
        launcherPid = [int]$Context.processId
    }
}
