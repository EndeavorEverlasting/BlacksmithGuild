# Route proof focus keeper for Bannerlord.
# This script is a harness tool, not gameplay proof by itself.
# PID/window ownership must flow through repo runtime detection before falling back to title scans.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('Observe', 'SyntheticFocusPulse', 'ForegroundLease')]
    [string]$Mode = 'SyntheticFocusPulse',

    [int]$DurationSeconds = 90,

    [int]$PulseMilliseconds = 500,

    [int]$WaitForWindowSeconds = 0,

    [string]$BannerlordRoot = $null,

    [int]$ProcessIdHint = 0,

    [Int64]$WindowHandleHint = 0,

    [switch]$SendUnpausePulse,

    [ValidateSet('Space', 'D1', 'D2', 'D3')]
    [string]$UnpauseKey = 'D3',

    [string]$OutputPath = $null,

    [switch]$FailOnNoWindow,

    [switch]$FailOnLostForeground
)

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'pr11-process-window-classifier.ps1')

if (-not $BannerlordRoot) {
    $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
}

if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_FocusLease.json'
}

if ($DurationSeconds -lt 1) { throw 'DurationSeconds must be at least 1.' }
if ($PulseMilliseconds -lt 100) { throw 'PulseMilliseconds must be at least 100.' }
if ($WaitForWindowSeconds -lt 0) { throw 'WaitForWindowSeconds must be >= 0.' }

$signature = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class TbgFocusKeeperUser32 {
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
'@

if (-not ('TbgFocusKeeperUser32' -as [type])) {
    Add-Type -TypeDefinition $signature -Language CSharp
}

$WM_ACTIVATE = 0x0006
$WM_SETFOCUS = 0x0007
$WM_NCACTIVATE = 0x0086
$WM_ACTIVATEAPP = 0x001C
$WM_KEYDOWN = 0x0100
$WM_KEYUP = 0x0101
$WA_ACTIVE = 1
$SW_RESTORE = 9

$keyMap = @{
    Space = 0x20
    D1 = 0x31
    D2 = 0x32
    D3 = 0x33
}

function Get-TbgFocusKeeperWindowTitle {
    param([IntPtr]$Handle)
    $buffer = New-Object System.Text.StringBuilder 1024
    [void][TbgFocusKeeperUser32]::GetWindowText($Handle, $buffer, $buffer.Capacity)
    return $buffer.ToString()
}

function Find-TbgTopLevelWindowForPid {
    param([int]$TargetPid)

    if ($TargetPid -le 0) { return $null }

    $matches = New-Object System.Collections.Generic.List[object]
    $callback = [TbgFocusKeeperUser32+EnumWindowsProc]{
        param([IntPtr]$hWnd, [IntPtr]$lParam)

        if (-not [TbgFocusKeeperUser32]::IsWindowVisible($hWnd)) { return $true }
        $pid = 0
        [void][TbgFocusKeeperUser32]::GetWindowThreadProcessId($hWnd, [ref]$pid)
        if ($pid -ne $TargetPid) { return $true }

        $title = Get-TbgFocusKeeperWindowTitle -Handle $hWnd
        $matches.Add([pscustomobject]@{
            hwnd = $hWnd
            hwndInt64 = $hWnd.ToInt64()
            processId = $pid
            title = $title
        }) | Out-Null
        return $true
    }

    [void][TbgFocusKeeperUser32]::EnumWindows($callback, [IntPtr]::Zero)
    return $matches | Sort-Object @{ Expression = { if ($_.title) { 0 } else { 1 } } } | Select-Object -First 1
}

function Get-TbgFocusKeeperTargetWindow {
    param(
        [int]$PidHint,
        [Int64]$HwndHint
    )

    $detection = Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
        -Phase1Path (Get-Phase1LogPath -BannerlordRoot $BannerlordRoot) `
        -StatusPath (Get-StatusJsonPath -BannerlordRoot $BannerlordRoot) `
        -CrashContextPath (Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot) `
        -CacheSec 0

    $pid = if ($PidHint -gt 0) { $PidHint } elseif ($detection.gameProcessPid) { [int]$detection.gameProcessPid } else { 0 }
    $source = if ($PidHint -gt 0) { 'ProcessIdHint' } elseif ($detection.gameProcessPid) { 'Get-BannerlordProcessDetection' } else { 'none' }

    if ($HwndHint -gt 0) {
        return [pscustomobject]@{
            hwnd = [IntPtr]$HwndHint
            hwndInt64 = $HwndHint
            processId = $pid
            processName = $detection.gameProcessName
            title = Get-TbgFocusKeeperWindowTitle -Handle ([IntPtr]$HwndHint)
            detection = $detection
            source = 'WindowHandleHint'
        }
    }

    if ($pid -le 0) {
        return [pscustomobject]@{
            hwnd = [IntPtr]::Zero
            hwndInt64 = 0
            processId = 0
            processName = $detection.gameProcessName
            title = $null
            detection = $detection
            source = $source
        }
    }

    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
    if ($proc -and $proc.MainWindowHandle -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
        return [pscustomobject]@{
            hwnd = $proc.MainWindowHandle
            hwndInt64 = $proc.MainWindowHandle.ToInt64()
            processId = $pid
            processName = $proc.ProcessName
            title = [string]$proc.MainWindowTitle
            detection = $detection
            source = $source + '+MainWindowHandle'
        }
    }

    $topLevel = Find-TbgTopLevelWindowForPid -TargetPid $pid
    if ($topLevel) {
        return [pscustomobject]@{
            hwnd = $topLevel.hwnd
            hwndInt64 = $topLevel.hwndInt64
            processId = $pid
            processName = if ($proc) { $proc.ProcessName } else { $detection.gameProcessName }
            title = $topLevel.title
            detection = $detection
            source = $source + '+EnumWindowsForPid'
        }
    }

    return [pscustomobject]@{
        hwnd = [IntPtr]::Zero
        hwndInt64 = 0
        processId = $pid
        processName = if ($proc) { $proc.ProcessName } else { $detection.gameProcessName }
        title = $null
        detection = $detection
        source = $source + '+no_visible_window'
    }
}

function Invoke-SyntheticFocusPulse {
    param([IntPtr]$Handle)

    $results = New-Object System.Collections.Generic.List[object]
    $results.Add([pscustomobject]@{ message = 'WM_ACTIVATEAPP'; ok = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_ACTIVATEAPP, [IntPtr]1, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_NCACTIVATE'; ok = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_NCACTIVATE, [IntPtr]1, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_ACTIVATE'; ok = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_ACTIVATE, [IntPtr]$WA_ACTIVE, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_SETFOCUS'; ok = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_SETFOCUS, [IntPtr]::Zero, [IntPtr]::Zero) }) | Out-Null
    return @($results)
}

function Invoke-UnpausePulse {
    param(
        [IntPtr]$Handle,
        [string]$Key
    )

    $vk = [int]$keyMap[$Key]
    $down = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 25
    $up = [TbgFocusKeeperUser32]::PostMessage($Handle, $WM_KEYUP, [IntPtr]$vk, [IntPtr]::Zero)

    return [pscustomobject]@{
        key = $Key
        virtualKey = $vk
        keyDownPosted = $down
        keyUpPosted = $up
    }
}

function Write-FocusKeeperNoWindowResult {
    param(
        [datetime]$StartedUtc,
        [object]$Target
    )

    $result = [pscustomobject]@{
        schema = 'TbgBannerlordFocusLease.v1'
        generatedUtc = $StartedUtc.ToString('o')
        mode = $Mode
        durationSeconds = $DurationSeconds
        pulseMilliseconds = $PulseMilliseconds
        waitForWindowSeconds = $WaitForWindowSeconds
        bannerlordRoot = $BannerlordRoot
        processIdHint = $ProcessIdHint
        windowHandleHint = $WindowHandleHint
        detection = if ($Target) { $Target.detection } else { $null }
        classification = 'bannerlord_window_not_found'
        blocking = $true
        proofBoundary = @(
            'No Bannerlord window was found through repo process detection.',
            'No focus lease was acquired.',
            'No route proof can be inferred from this artifact.'
        )
        samples = @()
    }

    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host "FAIL: Bannerlord window not found. Wrote $OutputPath" -ForegroundColor Red
}

$startedUtc = (Get-Date).ToUniversalTime()
$target = $null
$waitDeadline = (Get-Date).AddSeconds($WaitForWindowSeconds)
do {
    $target = Get-TbgFocusKeeperTargetWindow -PidHint $ProcessIdHint -HwndHint $WindowHandleHint
    if ($target -and $target.hwndInt64 -gt 0) { break }
    if ($WaitForWindowSeconds -le 0) { break }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $waitDeadline)

if (-not $target -or $target.hwndInt64 -le 0) {
    Write-FocusKeeperNoWindowResult -StartedUtc $startedUtc -Target $target
    if ($FailOnNoWindow) { exit 2 }
    exit 0
}

$hwnd = [IntPtr]$target.hwndInt64
$samples = New-Object System.Collections.Generic.List[object]
$focusPulses = New-Object System.Collections.Generic.List[object]
$unpausePulses = New-Object System.Collections.Generic.List[object]
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$iteration = 0

Write-Host "Bannerlord focus keeper started." -ForegroundColor Cyan
Write-Host "  mode: $Mode" -ForegroundColor Cyan
Write-Host "  pid/window source: $($target.source)" -ForegroundColor Cyan
Write-Host "  window: $($target.title) [$($target.hwndInt64)] pid=$($target.processId)" -ForegroundColor Cyan
Write-Host "  duration: $DurationSeconds second(s)" -ForegroundColor Cyan

while ($stopwatch.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $iteration++
    $beforeForeground = [TbgFocusKeeperUser32]::GetForegroundWindow()
    $wasForeground = ($beforeForeground -eq $hwnd)
    $pulseResult = @()
    $unpauseResult = $null
    $foregroundResult = $null

    if ($Mode -eq 'ForegroundLease') {
        [void][TbgFocusKeeperUser32]::ShowWindowAsync($hwnd, $SW_RESTORE)
        $foregroundResult = [TbgFocusKeeperUser32]::SetForegroundWindow($hwnd)
    } elseif ($Mode -eq 'SyntheticFocusPulse') {
        $pulseResult = Invoke-SyntheticFocusPulse -Handle $hwnd
        $focusPulses.Add([pscustomobject]@{
            utc = (Get-Date).ToUniversalTime().ToString('o')
            iteration = $iteration
            messages = $pulseResult
        }) | Out-Null
    }

    if ($SendUnpausePulse) {
        $unpauseResult = Invoke-UnpausePulse -Handle $hwnd -Key $UnpauseKey
        $unpausePulses.Add([pscustomobject]@{
            utc = (Get-Date).ToUniversalTime().ToString('o')
            iteration = $iteration
            result = $unpauseResult
        }) | Out-Null
    }

    Start-Sleep -Milliseconds ([Math]::Max(1, [Math]::Min($PulseMilliseconds, 250)))
    $afterForeground = [TbgFocusKeeperUser32]::GetForegroundWindow()
    $isForeground = ($afterForeground -eq $hwnd)

    $samples.Add([pscustomobject]@{
        utc = (Get-Date).ToUniversalTime().ToString('o')
        iteration = $iteration
        elapsedMilliseconds = [int]$stopwatch.ElapsedMilliseconds
        foregroundBeforePulse = $wasForeground
        foregroundAfterPulse = $isForeground
        foregroundLeaseRequested = ($Mode -eq 'ForegroundLease')
        foregroundLeaseResult = $foregroundResult
        syntheticPulseRequested = ($Mode -eq 'SyntheticFocusPulse')
        unpausePulseRequested = [bool]$SendUnpausePulse
    }) | Out-Null

    $remaining = [int]($PulseMilliseconds - 250)
    if ($remaining -gt 0) { Start-Sleep -Milliseconds $remaining }
}

$stopwatch.Stop()
$lostForegroundSamples = @($samples | Where-Object { -not $_.foregroundAfterPulse })

$classification = switch ($Mode) {
    'Observe' { if ($lostForegroundSamples.Count -gt 0) { 'observed_lost_foreground' } else { 'observed_foreground' } }
    'SyntheticFocusPulse' { if ($lostForegroundSamples.Count -gt 0) { 'focus_attempted_not_proven' } else { 'synthetic_focus_pulse_no_loss_observed' } }
    'ForegroundLease' { if ($lostForegroundSamples.Count -gt 0) { 'focus_lease_contested' } else { 'focus_lease_held' } }
}

$blocking = ($classification -in @('observed_lost_foreground', 'focus_attempted_not_proven', 'focus_lease_contested'))

$result = [pscustomobject]@{
    schema = 'TbgBannerlordFocusLease.v1'
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    mode = $Mode
    durationSeconds = $DurationSeconds
    pulseMilliseconds = $PulseMilliseconds
    waitForWindowSeconds = $WaitForWindowSeconds
    bannerlordRoot = $BannerlordRoot
    processIdHint = $ProcessIdHint
    windowHandleHint = $WindowHandleHint
    processId = $target.processId
    processName = $target.processName
    windowHandle = $target.hwndInt64
    windowTitle = $target.title
    targetSource = $target.source
    detection = $target.detection
    sendUnpausePulse = [bool]$SendUnpausePulse
    unpauseKey = if ($SendUnpausePulse) { $UnpauseKey } else { $null }
    classification = $classification
    blocking = $blocking
    foregroundSamples = $samples.Count
    lostForegroundSamples = $lostForegroundSamples.Count
    focusPulseSamples = $focusPulses.Count
    unpausePulseSamples = $unpausePulses.Count
    samples = @($samples)
    focusPulses = @($focusPulses)
    unpausePulses = @($unpausePulses)
    proofBoundary = @(
        'This artifact proves only the focus keeper attempt and observed foreground samples.',
        'PID/window selection reuses Get-BannerlordProcessDetection before any window fallback.',
        'SyntheticFocusPulse is experimental and does not prove Bannerlord engine focus acceptance.',
        'ForegroundLease may steal user focus because Windows has one real foreground window.',
        'Movement proof still requires fresh route cert, position/checkpoint, and time evidence after the route execution window.'
    )
}

$result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Host "Focus keeper wrote $OutputPath" -ForegroundColor Green
Write-Host "classification: $classification" -ForegroundColor Green
Write-Host "lostForegroundSamples: $($lostForegroundSamples.Count)" -ForegroundColor Green

if ($FailOnLostForeground -and $lostForegroundSamples.Count -gt 0) { exit 3 }
exit 0
