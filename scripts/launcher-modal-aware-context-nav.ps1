# Modal-aware launcher navigation wrapper for Forge/ForgeContinue.
#
# This wrapper delegates the primary PLAY/CONTINUE click to launcher-frozen-context-nav.ps1.
# If that frozen navigator proves the bound launcher target was invalidated but no game handoff
# was observed, this wrapper handles Bannerlord's dependency-mismatch CAUTION modal as a
# first-class launcher handoff state. It confirms only the process/window that came from the
# fresh LauncherWindowContext. It does not claim runtime proof.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [int]$TimeoutSec = 0,
    [int]$PollMs = 250,
    [string]$LauncherContextPath = $null,
    [bool]$RespectUserForeground = $true,
    [switch]$AllowFocusSteal,
    [switch]$LaunchSetup,
    [switch]$AllowLongRun,
    [string]$LongRunReason
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

if (-not $LauncherContextPath) {
    $LauncherContextPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
}

$launchLogPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
$frozenNavPath = Join-Path $PSScriptRoot 'launcher-frozen-context-nav.ps1'

function Write-TbgModalNavLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = '[{0}] launcher-modal: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $launchLogPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

$native = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class ModalAwareLauncherNative
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const int SW_RESTORE = 9;

    public static string WindowTitle(IntPtr hwnd)
    {
        var sb = new StringBuilder(512);
        GetWindowText(hwnd, sb, sb.Capacity);
        return sb.ToString();
    }

    public static bool ForceForegroundWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero || !IsWindow(hwnd)) return false;

        var foreground = GetForegroundWindow();
        uint ignored;
        var foregroundThread = foreground == IntPtr.Zero ? 0 : GetWindowThreadProcessId(foreground, out ignored);
        var targetThread = GetWindowThreadProcessId(hwnd, out ignored);
        var currentThread = GetCurrentThreadId();
        var foregroundAttached = false;
        var targetAttached = false;
        try
        {
            if (foregroundThread != 0 && foregroundThread != currentThread)
                foregroundAttached = AttachThreadInput(currentThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != currentThread)
                targetAttached = AttachThreadInput(currentThread, targetThread, true);

            ShowWindow(hwnd, SW_RESTORE);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
        }
        finally
        {
            if (targetAttached) AttachThreadInput(currentThread, targetThread, false);
            if (foregroundAttached) AttachThreadInput(currentThread, foregroundThread, false);
        }

        return GetForegroundWindow() == hwnd;
    }
}
'@
if (-not ('ModalAwareLauncherNative' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}

function Read-TbgLauncherContext {
    if (-not (Test-Path -LiteralPath $LauncherContextPath)) {
        throw "launcher context missing: $LauncherContextPath"
    }
    $context = Get-Content -LiteralPath $LauncherContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $context) { throw "launcher context unreadable: $LauncherContextPath" }
    if ([string]$context.schema -ne 'TbgLauncherWindowContext.v1') {
        throw "launcher context schema mismatch: $($context.schema)"
    }
    if ([int]$context.processId -eq 0) { throw 'launcher context has no processId' }
    return $context
}

function Test-TbgModalHwndPid {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][int]$ExpectedPid
    )

    if ($Hwnd -eq [IntPtr]::Zero) { return $false }
    if (-not [ModalAwareLauncherNative]::IsWindow($Hwnd)) { return $false }
    [uint32]$actualPid = 0
    [void][ModalAwareLauncherNative]::GetWindowThreadProcessId($Hwnd, [ref]$actualPid)
    return ([int]$actualPid -eq $ExpectedPid)
}

function Test-TbgGameSpawnedFromModal {
    if (Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue) { return $true }
    $singleplayerHost = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -like 'Mount and Blade II Bannerlord - Singleplayer*' } |
        Select-Object -First 1
    return [bool]$singleplayerHost
}

function Get-TbgDependencyCautionCandidate {
    param(
        [Parameter(Mandatory = $true)][int]$ExpectedPid,
        [Parameter(Mandatory = $true)][IntPtr]$OriginalHwnd
    )

    $process = Get-Process -Id $ExpectedPid -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try { $process.Refresh() } catch { return $null }

    $hwnd = [IntPtr]$process.MainWindowHandle
    if (-not (Test-TbgModalHwndPid -Hwnd $hwnd -ExpectedPid $ExpectedPid)) { return $null }

    $title = [string]$process.MainWindowTitle
    if ($title -like '*Safe Mode*') { return $null }
    if ($title -like 'Mount and Blade II Bannerlord - Singleplayer*') { return $null }

    $rect = New-Object ModalAwareLauncherNative+RECT
    if (-not [ModalAwareLauncherNative]::GetClientRect($hwnd, [ref]$rect)) { return $null }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -lt 500 -or $height -lt 300) { return $null }

    return [pscustomobject][ordered]@{
        processId = [int]$process.Id
        hwnd = $hwnd
        title = $title
        processName = [string]$process.ProcessName
        width = [int]$width
        height = [int]$height
        originalHwnd = $OriginalHwnd.ToInt64()
    }
}

function Invoke-TbgDependencyCautionConfirm {
    param(
        [Parameter(Mandatory = $true)]$Candidate,
        [Parameter(Mandatory = $true)][int]$ExpectedPid
    )

    $hwnd = [IntPtr]$Candidate.hwnd
    if (-not (Test-TbgModalHwndPid -Hwnd $hwnd -ExpectedPid $ExpectedPid)) {
        throw 'dependency caution confirm requested after modal target invalidated'
    }

    $focusAcquired = [ModalAwareLauncherNative]::ForceForegroundWindow($hwnd)
    Start-Sleep -Milliseconds 150
    $foregroundMatches = [ModalAwareLauncherNative]::GetForegroundWindow() -eq $hwnd
    Write-TbgModalNavLog ('FOCUS dependency_caution pid={0} hwnd={1} acquired={2} foregroundMatches={3} runtimeProofClaim=false' -f $ExpectedPid, $hwnd.ToInt64(), $focusAcquired, $foregroundMatches)
    if (-not $foregroundMatches) {
        throw 'dependency_caution_focus_failed: refusing Confirm click without the caution window in foreground'
    }

    $rect = New-Object ModalAwareLauncherNative+RECT
    if (-not [ModalAwareLauncherNative]::GetClientRect($hwnd, [ref]$rect)) {
        throw 'dependency caution client rectangle unavailable'
    }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($width -le 0 -or $height -le 0) { throw "dependency caution invalid client rect ${width}x${height}" }

    $point = New-Object ModalAwareLauncherNative+POINT
    $point.X = [int]($width * 0.55)
    $point.Y = [int]($height * 0.88)
    $clientX = $point.X
    $clientY = $point.Y
    if (-not [ModalAwareLauncherNative]::ClientToScreen($hwnd, [ref]$point)) {
        throw 'dependency caution ClientToScreen failed'
    }

    [void][ModalAwareLauncherNative]::SetCursorPos($point.X, $point.Y)
    Start-Sleep -Milliseconds 40
    if (-not (Test-TbgModalHwndPid -Hwnd $hwnd -ExpectedPid $ExpectedPid) -or
            [ModalAwareLauncherNative]::GetForegroundWindow() -ne $hwnd) {
        throw 'dependency_caution_focus_lost_before_confirm: refusing real input after target changed'
    }

    [ModalAwareLauncherNative]::mouse_event([ModalAwareLauncherNative]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    [ModalAwareLauncherNative]::mouse_event([ModalAwareLauncherNative]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    Write-TbgModalNavLog ('CLICK_DEPENDENCY_CAUTION_RESULT result=confirm_dispatched method=real-input defaultAction=confirm hwnd={0} pid={1} client=({2},{3}) screen=({4},{5}) dependencyMismatchHandled=true runtimeProofClaim=false' -f `
        $hwnd.ToInt64(), $ExpectedPid, $clientX, $clientY, $point.X, $point.Y)
}

function Wait-TbgModalGameHandoff {
    param([int]$TimeoutSec = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    do {
        if (Test-TbgGameSpawnedFromModal) { return $true }
        Start-Sleep -Milliseconds 250
    } while ((Get-Date) -lt $deadline)
    return $false
}

$navArgs = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $frozenNavPath,
    '-LaunchIntent', $LaunchIntent,
    '-BannerlordRoot', $BannerlordRoot,
    '-PollMs', ([string]$PollMs),
    '-LauncherContextPath', $LauncherContextPath,
    ('-RespectUserForeground:{0}' -f ([bool]$RespectUserForeground).ToString().ToLowerInvariant())
)
if ($TimeoutSec -gt 0) { $navArgs += @('-TimeoutSec', ([string]$TimeoutSec)) }
if ($AllowFocusSteal) { $navArgs += '-AllowFocusSteal' }
if ($LaunchSetup) { $navArgs += '-LaunchSetup' }
if ($AllowLongRun) { $navArgs += '-AllowLongRun' }
if ($LongRunReason) { $navArgs += @('-LongRunReason', $LongRunReason) }

& powershell.exe @navArgs
$navExit = $LASTEXITCODE
if ($navExit -eq 0) { exit 0 }

$tailText = ''
if (Test-Path -LiteralPath $launchLogPath) {
    $tailText = ((Get-Content -LiteralPath $launchLogPath -Tail 160 -ErrorAction SilentlyContinue) -join [Environment]::NewLine)
}

$wasFrozenInvalidation = ($tailText -match 'frozen_target_invalidated') -or
    ($tailText -match 'frozen launcher target invalidated before game spawned')
if (-not $wasFrozenInvalidation) {
    exit $navExit
}

$context = Read-TbgLauncherContext
$expectedPid = [int]$context.processId
$originalHwnd = [IntPtr]([int64]$context.hwnd)
$candidate = Get-TbgDependencyCautionCandidate -ExpectedPid $expectedPid -OriginalHwnd $originalHwnd
if (-not $candidate) {
    Write-TbgModalNavLog ('LAUNCH_STATE=dependency_caution_not_detected classification=no_dependency_caution_candidate after=frozen_target_invalidated pid={0} runtimeProofClaim=false' -f $expectedPid)
    exit $navExit
}

Write-TbgModalNavLog ('LAUNCH_STATE=dependency_caution_detected classification=dependency_mismatch_caution_modal hwnd={0} pid={1} title="{2}" size={3}x{4} action=confirm_dependency_caution_required defaultAction=confirm runtimeProofClaim=false' -f `
    ([IntPtr]$candidate.hwnd).ToInt64(), $expectedPid, ([string]$candidate.title), $candidate.width, $candidate.height)

Invoke-TbgDependencyCautionConfirm -Candidate $candidate -ExpectedPid $expectedPid
$handoffObserved = Wait-TbgModalGameHandoff -TimeoutSec 60
if ($handoffObserved) {
    Write-TbgModalNavLog 'LAUNCH_STATE=game_spawned classification=game_spawned evidence=dependency_caution_confirmed_then_game_spawned dependencyMismatchHandled=true runtimeProofClaim=false'
    Write-TbgModalNavLog 'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed source=dependency_caution_confirmed runtimeProofClaim=false'
    exit 0
}

$stillPresent = Get-TbgDependencyCautionCandidate -ExpectedPid $expectedPid -OriginalHwnd $originalHwnd
if ($stillPresent) {
    Write-TbgModalNavLog ('CLICK_DEPENDENCY_CAUTION_RESULT result=caution_still_present hwnd={0} pid={1} dependencyMismatchHandled=false runtimeProofClaim=false' -f ([IntPtr]$stillPresent.hwnd).ToInt64(), $expectedPid)
    throw 'operator_action_required: dependency mismatch caution still present after Confirm click'
}

Write-TbgModalNavLog ('CLICK_DEPENDENCY_CAUTION_RESULT result=game_not_spawned pid={0} dependencyMismatchHandled=false runtimeProofClaim=false' -f $expectedPid)
throw 'operator_action_required: dependency mismatch caution confirmed but game did not spawn'
