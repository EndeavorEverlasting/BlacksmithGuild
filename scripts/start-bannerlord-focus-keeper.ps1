# Route proof focus keeper for Bannerlord.
# This script is a harness tool, not gameplay proof by itself.
$ErrorActionPreference = 'Stop'

param(
    [ValidateSet('Observe', 'SyntheticFocusPulse', 'ForegroundLease')]
    [string]$Mode = 'SyntheticFocusPulse',

    [int]$DurationSeconds = 90,

    [int]$PulseMilliseconds = 500,

    [string]$ProcessNamePattern = 'Bannerlord',

    [switch]$SendUnpausePulse,

    [ValidateSet('Space', 'D1', 'D2', 'D3')]
    [string]$UnpauseKey = 'D3',

    [string]$OutputPath = $null,

    [switch]$FailOnNoWindow,

    [switch]$FailOnLostForeground
)

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $repoRoot 'BlacksmithGuild_FocusLease.json'
}

if ($DurationSeconds -lt 1) { throw 'DurationSeconds must be at least 1.' }
if ($PulseMilliseconds -lt 100) { throw 'PulseMilliseconds must be at least 100.' }

$signature = @'
using System;
using System.Text;
using System.Runtime.InteropServices;

public static class TbgUser32 {
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

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
'@

if (-not ('TbgUser32' -as [type])) {
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

function Get-WindowTitle {
    param([IntPtr]$Handle)
    $buffer = New-Object System.Text.StringBuilder 1024
    [void][TbgUser32]::GetWindowText($Handle, $buffer, $buffer.Capacity)
    return $buffer.ToString()
}

function Get-BannerlordWindow {
    $candidates = New-Object System.Collections.Generic.List[object]
    $callback = [TbgUser32+EnumWindowsProc]{
        param([IntPtr]$hWnd, [IntPtr]$lParam)

        if (-not [TbgUser32]::IsWindowVisible($hWnd)) { return $true }

        $pid = 0
        [void][TbgUser32]::GetWindowThreadProcessId($hWnd, [ref]$pid)
        if ($pid -le 0) { return $true }

        $process = $null
        try { $process = Get-Process -Id $pid -ErrorAction Stop } catch { return $true }
        $title = Get-WindowTitle -Handle $hWnd

        $matchesProcess = $process.ProcessName -like "*$ProcessNamePattern*"
        $matchesTitle = $title -like '*Bannerlord*' -or $title -like '*Mount & Blade*'

        if ($matchesProcess -or $matchesTitle) {
            $candidates.Add([pscustomobject]@{
                Hwnd = $hWnd
                HwndInt64 = $hWnd.ToInt64()
                ProcessId = $pid
                ProcessName = $process.ProcessName
                Title = $title
            }) | Out-Null
        }

        return $true
    }

    [void][TbgUser32]::EnumWindows($callback, [IntPtr]::Zero)
    return $candidates | Sort-Object @{ Expression = { if ($_.Title) { 0 } else { 1 } } }, ProcessName | Select-Object -First 1
}

function Invoke-SyntheticFocusPulse {
    param([IntPtr]$Handle)

    $results = New-Object System.Collections.Generic.List[object]
    $results.Add([pscustomobject]@{ message = 'WM_ACTIVATEAPP'; ok = [TbgUser32]::PostMessage($Handle, $WM_ACTIVATEAPP, [IntPtr]1, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_NCACTIVATE'; ok = [TbgUser32]::PostMessage($Handle, $WM_NCACTIVATE, [IntPtr]1, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_ACTIVATE'; ok = [TbgUser32]::PostMessage($Handle, $WM_ACTIVATE, [IntPtr]$WA_ACTIVE, [IntPtr]::Zero) }) | Out-Null
    $results.Add([pscustomobject]@{ message = 'WM_SETFOCUS'; ok = [TbgUser32]::PostMessage($Handle, $WM_SETFOCUS, [IntPtr]::Zero, [IntPtr]::Zero) }) | Out-Null
    return @($results)
}

function Invoke-UnpausePulse {
    param(
        [IntPtr]$Handle,
        [string]$Key
    )

    $vk = [int]$keyMap[$Key]
    $down = [TbgUser32]::PostMessage($Handle, $WM_KEYDOWN, [IntPtr]$vk, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 25
    $up = [TbgUser32]::PostMessage($Handle, $WM_KEYUP, [IntPtr]$vk, [IntPtr]::Zero)

    return [pscustomobject]@{
        key = $Key
        virtualKey = $vk
        keyDownPosted = $down
        keyUpPosted = $up
    }
}

$startedUtc = (Get-Date).ToUniversalTime()
$window = Get-BannerlordWindow

if (-not $window) {
    $result = [pscustomobject]@{
        schema = 'TbgBannerlordFocusLease.v1'
        generatedUtc = $startedUtc.ToString('o')
        mode = $Mode
        durationSeconds = $DurationSeconds
        pulseMilliseconds = $PulseMilliseconds
        processNamePattern = $ProcessNamePattern
        classification = 'bannerlord_window_not_found'
        blocking = $true
        proofBoundary = @(
            'No Bannerlord window was found.',
            'No focus lease was acquired.',
            'No route proof can be inferred from this artifact.'
        )
        samples = @()
    }

    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-Host "FAIL: Bannerlord window not found. Wrote $OutputPath" -ForegroundColor Red
    if ($FailOnNoWindow) { exit 2 }
    exit 0
}

$hwnd = [IntPtr]$window.HwndInt64
$samples = New-Object System.Collections.Generic.List[object]
$focusPulses = New-Object System.Collections.Generic.List[object]
$unpausePulses = New-Object System.Collections.Generic.List[object]
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$iteration = 0

Write-Host "Bannerlord focus keeper started." -ForegroundColor Cyan
Write-Host "  mode: $Mode" -ForegroundColor Cyan
Write-Host "  window: $($window.Title) [$($window.HwndInt64)] pid=$($window.ProcessId)" -ForegroundColor Cyan
Write-Host "  duration: $DurationSeconds second(s)" -ForegroundColor Cyan

while ($stopwatch.Elapsed.TotalSeconds -lt $DurationSeconds) {
    $iteration++
    $beforeForeground = [TbgUser32]::GetForegroundWindow()
    $wasForeground = ($beforeForeground -eq $hwnd)
    $pulseResult = @()
    $unpauseResult = $null
    $foregroundResult = $null

    if ($Mode -eq 'ForegroundLease') {
        [void][TbgUser32]::ShowWindowAsync($hwnd, $SW_RESTORE)
        $foregroundResult = [TbgUser32]::SetForegroundWindow($hwnd)
    }
    elseif ($Mode -eq 'SyntheticFocusPulse') {
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
    $afterForeground = [TbgUser32]::GetForegroundWindow()
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
    processNamePattern = $ProcessNamePattern
    processId = $window.ProcessId
    processName = $window.ProcessName
    windowHandle = $window.HwndInt64
    windowTitle = $window.Title
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
