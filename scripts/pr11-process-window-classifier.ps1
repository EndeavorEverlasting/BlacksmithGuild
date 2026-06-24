# PR #11 unattended launch/attach classifier — PID/window snapshots + confidence scoring.
# Dot-source after bannerlord-paths.ps1. No game launch on import.

$script:Pr11ClickConfidenceThreshold = 80
$script:Pr11RetryConfidenceThreshold = 50

function Initialize-Pr11Win32WindowHelpers {
    if (Get-Command Get-Pr11WindowRectangle -ErrorAction SilentlyContinue) { return }
    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Drawing;
public static class Pr11Win32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    public static string GetTitle(IntPtr hWnd) {
        var sb = new StringBuilder(512);
        GetWindowText(hWnd, sb, 512);
        return sb.ToString();
    }
}
"@ -ErrorAction SilentlyContinue | Out-Null
}

function Get-Pr11WindowRectangle {
    param([IntPtr]$Hwnd)
    Initialize-Pr11Win32WindowHelpers
    $rect = [Pr11Win32+RECT]::new()
    if ($Hwnd -eq [IntPtr]::Zero) { return $null }
    if (-not [Pr11Win32]::GetWindowRect($Hwnd, [ref]$rect)) { return $null }
    return [ordered]@{
        left = $rect.Left; top = $rect.Top; right = $rect.Right; bottom = $rect.Bottom
        width = $rect.Right - $rect.Left; height = $rect.Bottom - $rect.Top
    }
}

function Test-Pr11ProcessNameRelevant {
    param([string]$ProcessName, [string]$ExecutablePath)
    $name = [string]$ProcessName
    $path = [string]$ExecutablePath
    if ($name -match 'Bannerlord|TaleWorlds|Steam|dotnet|MSBuild|devenv|VBCSCompiler') { return $true }
    if ($path -match 'Mount & Blade II Bannerlord|Mount and Blade II Bannerlord|Steam') { return $true }
    return $false
}

function Get-Pr11ProcessRecord {
    param([System.Diagnostics.Process]$Process)

    $rec = [ordered]@{
        pid = [int]$Process.Id
        processName = [string]$Process.ProcessName
        parentPid = $null
        startTime = $null
        mainWindowHandle = 0
        mainWindowTitle = ''
        executablePath = $null
        commandLine = $null
        windowRectangle = $null
        visible = $false
        uiaProcessId = $null
    }

    try { $rec.startTime = $Process.StartTime.ToUniversalTime().ToString('o') } catch { }
    try {
        $hwnd = $Process.MainWindowHandle
        $rec.mainWindowHandle = [int64]$hwnd
        if ($hwnd -ne [IntPtr]::Zero) {
            Initialize-Pr11Win32WindowHelpers
            $rec.mainWindowTitle = [Pr11Win32]::GetTitle($hwnd)
            $rec.windowRectangle = Get-Pr11WindowRectangle -Hwnd $hwnd
            $rec.visible = [bool][Pr11Win32]::IsWindowVisible($hwnd)
        }
    } catch { }

    if (Get-Command Get-ProcessExecutablePathSafe -ErrorAction SilentlyContinue) {
        $rec.executablePath = Get-ProcessExecutablePathSafe -Process $Process
    }

    try {
        $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($Process.Id)" -ErrorAction Stop
        $rec.parentPid = [int]$wmi.ParentProcessId
        $rec.commandLine = [string]$wmi.CommandLine
        if (-not $rec.executablePath) { $rec.executablePath = [string]$wmi.ExecutablePath }
    } catch { }

    return [pscustomobject]$rec
}

function Get-Pr11ProcessSnapshot {
    param(
        [string]$Label,
        [string]$BannerlordRoot = $null,
        [switch]$AuditAll
    )

    $capturedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue)) {
        try {
            if (-not $AuditAll) {
                $exe = $null
                if (Get-Command Get-ProcessExecutablePathSafe -ErrorAction SilentlyContinue) {
                    $exe = Get-ProcessExecutablePathSafe -Process $proc
                }
                if (-not (Test-Pr11ProcessNameRelevant -ProcessName $proc.ProcessName -ExecutablePath $exe)) {
                    continue
                }
            }
            $records.Add((Get-Pr11ProcessRecord -Process $proc)) | Out-Null
        } catch { }
    }

    return [ordered]@{
        label = [string]$Label
        capturedAtUtc = $capturedUtc
        bannerlordRoot = $BannerlordRoot
        processCount = $records.Count
        processes = @($records.ToArray())
    }
}

function Save-Pr11ProcessSnapshot {
    param(
        [Parameter(Mandatory = $true)]$Snapshot,
        [Parameter(Mandatory = $true)][string]$OutputPath
    )
    $dir = Split-Path -Parent $OutputPath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $Snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    return $OutputPath
}

function Compare-Pr11ProcessSnapshots {
    param(
        [Parameter(Mandatory = $true)]$BaselineSnapshot,
        [Parameter(Mandatory = $true)]$AfterSnapshot
    )

    $basePids = @{}
    foreach ($p in @($BaselineSnapshot.processes)) { $basePids[[int]$p.pid] = $p }

    $afterPids = @{}
    foreach ($p in @($AfterSnapshot.processes)) { $afterPids[[int]$p.pid] = $p }

    $newPids = New-Object System.Collections.Generic.List[object]
    $changedWindows = New-Object System.Collections.Generic.List[object]

    foreach ($procId in @($afterPids.Keys)) {
        if (-not $basePids.ContainsKey($procId)) {
            $newPids.Add($afterPids[$procId]) | Out-Null
            continue
        }
        $before = $basePids[$procId]
        $after = $afterPids[$procId]
        if ([int64]$before.mainWindowHandle -ne [int64]$after.mainWindowHandle `
                -or [string]$before.mainWindowTitle -ne [string]$after.mainWindowTitle) {
            $changedWindows.Add([ordered]@{
                pid = $procId
                before = $before
                after = $after
            }) | Out-Null
        }
    }

    return [ordered]@{
        baselineLabel = $BaselineSnapshot.label
        afterLabel = $AfterSnapshot.label
        newPids = @($newPids.ToArray())
        changedWindows = @($changedWindows.ToArray())
    }
}

function Get-Pr11BannerlordPathScore {
    param([string]$ExecutablePath, [string]$BannerlordRoot)
    if ([string]::IsNullOrWhiteSpace($ExecutablePath)) { return 0 }
    $path = $ExecutablePath.ToLowerInvariant()
    if ($BannerlordRoot -and $path.StartsWith($BannerlordRoot.ToLowerInvariant())) { return 25 }
    if ($path -match 'mount.+blade.+bannerlord|taleworlds') { return 20 }
    if ($path -match 'steam') { return 5 }
    return 0
}

function Get-Pr11WindowCandidateScore {
    param(
        [Parameter(Mandatory = $true)]$ProcessRecord,
        [string]$BannerlordRoot,
        [Nullable[datetime]]$LaunchRequestedUtc = $null,
        [bool]$IsNewAfterBaseline = $false,
        [bool]$Phase1Fresh = $false,
        [bool]$StatusFresh = $false,
        [bool]$UiaPlayVisible = $false,
        [bool]$UiaContinueVisible = $false,
        [hashtable]$StableRectSeconds = @{}
    )

    $signals = New-Object System.Collections.Generic.List[string]
    $missing = New-Object System.Collections.Generic.List[string]
    $score = 0

    if ($IsNewAfterBaseline) { $score += 30; $signals.Add('new_pid_after_baseline') | Out-Null }
    else { $missing.Add('not_new_after_baseline') | Out-Null }

    $pathScore = Get-Pr11BannerlordPathScore -ExecutablePath $ProcessRecord.executablePath -BannerlordRoot $BannerlordRoot
    if ($pathScore -ge 20) { $score += $pathScore; $signals.Add('bannerlord_executable_path') | Out-Null }
    elseif ($pathScore -gt 0) { $score += $pathScore; $signals.Add('steam_related_path') | Out-Null }
    else { $missing.Add('bannerlord_path_unverified') | Out-Null }

    $name = [string]$ProcessRecord.processName
    if ($name -match 'Bannerlord|TaleWorlds') { $score += 15; $signals.Add('known_process_name') | Out-Null }
    else { $missing.Add('unknown_process_name') | Out-Null }

    if ([int64]$ProcessRecord.mainWindowHandle -ne 0 -and $ProcessRecord.visible) {
        $score += 10; $signals.Add('visible_top_level_window') | Out-Null
    } else {
        $missing.Add('no_visible_window') | Out-Null
    }

    $pidKey = [string]$ProcessRecord.pid
    if ($StableRectSeconds.ContainsKey($pidKey) -and [double]$StableRectSeconds[$pidKey] -ge 1.5) {
        $score += 10; $signals.Add('stable_window_rectangle') | Out-Null
    } else {
        $missing.Add('window_rectangle_unstable') | Out-Null
    }

    if ($LaunchRequestedUtc -and $ProcessRecord.startTime) {
        try {
            $start = [datetime]::Parse([string]$ProcessRecord.startTime, $null, [Globalization.DateTimeStyles]::RoundtripKind)
            if ($start -ge $LaunchRequestedUtc.AddSeconds(-5)) {
                $score += 10; $signals.Add('started_after_launch_request') | Out-Null
            }
        } catch { }
    }

    if ($UiaPlayVisible) { $score += 15; $signals.Add('uia_play_control') | Out-Null }
    if ($UiaContinueVisible) { $score += 15; $signals.Add('uia_continue_control') | Out-Null }
    if ($Phase1Fresh) { $score += 10; $signals.Add('phase1_log_updating') | Out-Null }
    if ($StatusFresh) { $score += 10; $signals.Add('status_json_updating') | Out-Null }

    return [ordered]@{
        pid = [int]$ProcessRecord.pid
        processName = [string]$ProcessRecord.processName
        hwnd = [int64]$ProcessRecord.mainWindowHandle
        windowTitle = [string]$ProcessRecord.mainWindowTitle
        executablePath = [string]$ProcessRecord.executablePath
        score = [int][Math]::Min(100, $score)
        evidenceSignals = @($signals.ToArray())
        missingSignals = @($missing.ToArray())
    }
}

function Get-Pr11WindowCandidates {
    param(
        [Parameter(Mandatory = $true)]$Delta,
        [string]$BannerlordRoot,
        [Nullable[datetime]]$LaunchRequestedUtc = $null,
        [bool]$Phase1Fresh = $false,
        [bool]$StatusFresh = $false,
        [bool]$UiaPlayVisible = $false,
        [bool]$UiaContinueVisible = $false,
        [hashtable]$StableRectSeconds = @{}
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($proc in @($Delta.newPids) + @($Delta.changedWindows | ForEach-Object { $_.after })) {
        $candidates.Add((Get-Pr11WindowCandidateScore -ProcessRecord $proc `
            -BannerlordRoot $BannerlordRoot `
            -LaunchRequestedUtc $LaunchRequestedUtc `
            -IsNewAfterBaseline ($Delta.newPids.pid -contains $proc.pid) `
            -Phase1Fresh $Phase1Fresh -StatusFresh $StatusFresh `
            -UiaPlayVisible $UiaPlayVisible -UiaContinueVisible $UiaContinueVisible `
            -StableRectSeconds $StableRectSeconds)) | Out-Null
    }

    if (Get-Command Get-BannerlordProcessCandidates -ErrorAction SilentlyContinue) {
        foreach ($c in @(Get-BannerlordProcessCandidates -BannerlordRoot $BannerlordRoot)) {
            if (@($candidates | ForEach-Object { $_.pid }) -contains $c.pid) { continue }
            $fake = [pscustomobject][ordered]@{
                pid = [int]$c.pid; processName = [string]$c.name; parentPid = $null; startTime = $null
                mainWindowHandle = 0; mainWindowTitle = [string]$c.windowTitle
                executablePath = [string]$c.path; commandLine = $null; windowRectangle = $null
                visible = -not [string]::IsNullOrWhiteSpace($c.windowTitle); uiaProcessId = $null
            }
            $candidates.Add((Get-Pr11WindowCandidateScore -ProcessRecord $fake -BannerlordRoot $BannerlordRoot `
                -LaunchRequestedUtc $LaunchRequestedUtc -IsNewAfterBaseline $false `
                -Phase1Fresh $Phase1Fresh -StatusFresh $StatusFresh `
                -UiaPlayVisible $UiaPlayVisible -UiaContinueVisible $UiaContinueVisible `
                -StableRectSeconds $StableRectSeconds)) | Out-Null
        }
    }

    return @($candidates | Sort-Object { [int]$_.score } -Descending)
}

function Test-Pr11ClickAllowed {
    param([array]$Candidates)

    if (-not $Candidates -or $Candidates.Count -eq 0) {
        return [ordered]@{ allowed = $false; reason = 'no_candidates'; winner = $null; tied = @() }
    }
    $top = @($Candidates | Where-Object { $_.score -ge $script:Pr11ClickConfidenceThreshold })
    if ($top.Count -eq 0) {
        return [ordered]@{ allowed = $false; reason = 'below_confidence_threshold'; winner = $null; tied = @() }
    }
    $maxScore = ($top | ForEach-Object { [int]$_.score } | Measure-Object -Maximum).Maximum
    $winners = @($top | Where-Object { [int]$_.score -eq $maxScore })
    if ($winners.Count -gt 1) {
        return [ordered]@{ allowed = $false; reason = 'multiple_tied_candidates'; winner = $null; tied = $winners }
    }
    return [ordered]@{ allowed = $true; reason = 'confidence_ok'; winner = $winners[0]; tied = @() }
}

function Invoke-Pr11UiStateClassification {
    param(
        [string]$BannerlordRoot,
        [array]$Candidates = @(),
        [object]$Readiness = $null,
        [object]$Detection = $null,
        [bool]$UiaPlayVisible = $false,
        [bool]$UiaContinueVisible = $false,
        [bool]$CrashReporterVisible = $false,
        [bool]$SafeModeVisible = $false,
        [string]$LaunchPhase = 'unknown'
    )

    $best = if ($Candidates.Count -gt 0) { $Candidates[0] } else { $null }
    $confidence = if ($best) { [int]$best.score } else { 0 }
    $state = 'unknown_blocked'
    $nextAction = 'harvest_and_fail'

    if ($CrashReporterVisible) {
        $state = 'crash_reporter'; $nextAction = 'stop_classify_crash'
    } elseif ($SafeModeVisible) {
        $state = 'safe_mode_prompt'; $nextAction = 'use_guarded_safe_mode_path'
    } elseif ($Readiness -and $Readiness.canPollFileInbox -and $Readiness.inGameAssistReady -and $Readiness.canAcceptAssistiveCommand) {
        $state = 'in_game_attach_ready'; $confidence = [Math]::Max($confidence, 90); $nextAction = 'run_assistive_cert_commands'
        if ($Readiness.readinessSurface -eq 'settlement_menu') { $state = 'settlement_menu' }
        elseif ($Readiness.readinessSurface -eq 'map_surface') { $state = 'map_surface' }
    } elseif ($Readiness -and $Readiness.parseOk -and -not $Readiness.campaignReady) {
        $state = if ($Readiness.readinessSurface -eq 'unknown') { 'game_loading' } else { 'campaign_loading' }
        $nextAction = 'wait_attach_readiness'
    } elseif ($UiaContinueVisible) {
        $state = 'continue_ready'; $nextAction = 'click_continue_if_allowed'
    } elseif ($UiaPlayVisible) {
        $state = 'launcher_play_ready'; $nextAction = 'click_play_if_allowed'
    } elseif ($Detection -and $Detection.gameProcessRunning) {
        $state = 'game_process_started'; $nextAction = 'wait_game_surface'
    } elseif ($best -and $best.processName -match 'Launcher') {
        $state = 'launcher_candidate_found'; $nextAction = 'wait_launcher_ui'
    } elseif ($LaunchPhase -eq 'not_started') {
        $state = 'not_launched'; $nextAction = 'launch_bannerlord'
    }

    $signals = @()
    $missing = @()
    if ($best) {
        $signals = @($best.evidenceSignals)
        $missing = @($best.missingSignals)
    }

    return [ordered]@{
        state = $state
        confidence = [int]$confidence
        pid = if ($best) { [int]$best.pid } else { $null }
        hwnd = if ($best) { [int64]$best.hwnd } else { $null }
        windowTitle = if ($best) { [string]$best.windowTitle } else { $null }
        processName = if ($best) { [string]$best.processName } else { $null }
        evidenceSignals = $signals
        missingSignals = $missing
        nextAction = $nextAction
        launchPhase = $LaunchPhase
    }
}

function Save-Pr11JsonArtifact {
    param([Parameter(Mandatory = $true)]$Object, [Parameter(Mandatory = $true)][string]$Path)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    $Object | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
    return $Path
}
