# Frozen-context launcher navigation for Forge/ForgeContinue.
# This script implements the strict S1/S2 doctrine:
# - consume launcher-window-context.json
# - freeze one hwnd/pid through the PLAY/CONTINUE click phase
# - do not promote spawned game windows back into launcher selection
# - stop clicking after game spawn / handoff and emit readiness classification

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
. (Join-Path $PSScriptRoot 'test-duration-policy.ps1')
if (-not (Get-Command Test-Phase1TbgReady -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'dev-command-names.ps1')
}

$logPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
if (-not $LauncherContextPath) {
    $LauncherContextPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
}

$durationArgs = @{ Caller = 'launcher-frozen-context-nav.ps1' }
if ($PSBoundParameters.ContainsKey('TimeoutSec') -and $TimeoutSec -gt 0) {
    $durationArgs.RequestedBudgetSec = $TimeoutSec
}
if ($AllowLongRun) {
    $durationArgs.AllowLongRun = $true
}
if ($LongRunReason) {
    $durationArgs.LongRunReason = $LongRunReason
}
$durationBudget = Resolve-TbgTestDurationBudget @durationArgs
$overallDeadline = New-TbgTestDurationDeadline -Budget $durationBudget

function Write-FrozenLaunchLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = '[{0}] launcher-frozen: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

Write-TbgTestDurationBudget -Budget $durationBudget
Write-FrozenLaunchLog ('BUDGET budgetSec={0} defaultBudgetSec={1} isLongRun={2} source={3}' -f $durationBudget.budgetSec, $durationBudget.defaultBudgetSec, $durationBudget.isLongRun, $durationBudget.source)
if ($LaunchSetup) {
    Write-FrozenLaunchLog 'MODE LaunchSetup=true'
}

function Read-FrozenLauncherContext {
    if (-not (Test-Path -LiteralPath $LauncherContextPath)) {
        throw "launcher context missing: $LauncherContextPath"
    }
    $ctx = Get-Content -LiteralPath $LauncherContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $ctx) { throw "launcher context unreadable: $LauncherContextPath" }
    if ([string]$ctx.schema -ne 'TbgLauncherWindowContext.v1') {
        throw "launcher context schema mismatch: $($ctx.schema)"
    }
    if ([int64]$ctx.hwnd -eq 0) { throw 'launcher context has no hwnd to freeze' }
    if ([int]$ctx.processId -eq 0) { throw 'launcher context has no processId to freeze' }
    return $ctx
}

$native = @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class FrozenLauncherNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X; public int Y; }

    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    public const uint WM_LBUTTONDOWN = 0x0201;
    public const uint WM_LBUTTONUP = 0x0202;
    public const int MK_LBUTTON = 0x0001;
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static IntPtr MakeLParam(int x, int y)
    {
        return new IntPtr((y << 16) | (x & 0xffff));
    }

    public static string WindowTitle(IntPtr hwnd)
    {
        var sb = new StringBuilder(512);
        GetWindowText(hwnd, sb, sb.Capacity);
        return sb.ToString();
    }
}
'@
if (-not ('FrozenLauncherNative' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}

function Test-FrozenHwndValid {
    param([Parameter(Mandatory = $true)][IntPtr]$Hwnd, [Parameter(Mandatory = $true)][int]$ExpectedPid)
    if ($Hwnd -eq [IntPtr]::Zero) { return $false }
    if (-not [FrozenLauncherNative]::IsWindow($Hwnd)) { return $false }
    [uint32]$actualPid = 0
    [void][FrozenLauncherNative]::GetWindowThreadProcessId($Hwnd, [ref]$actualPid)
    return ([int]$actualPid -eq $ExpectedPid)
}

function Test-GameSpawned {
    return [bool](Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue)
}

function Get-FrozenClickPoint {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][int]$Attempt
    )
    $continueFractions = @(0.55, 0.58)
    $playFractions = @(0.34, 0.38)
    $yFractions = @(0.90, 0.88)
    $xFrac = if ($Intent -eq 'continue') { $continueFractions[$Attempt % $continueFractions.Count] } else { $playFractions[$Attempt % $playFractions.Count] }
    $yFrac = $yFractions[$Attempt % $yFractions.Count]

    $rect = New-Object FrozenLauncherNative+RECT
    if (-not [FrozenLauncherNative]::GetClientRect($Hwnd, [ref]$rect)) {
        throw 'GetClientRect failed for frozen launcher hwnd'
    }
    $w = $rect.Right - $rect.Left
    $h = $rect.Bottom - $rect.Top
    if ($w -le 0 -or $h -le 0) { throw "frozen launcher hwnd has invalid client rect ${w}x${h}" }

    $pt = New-Object FrozenLauncherNative+POINT
    $pt.X = [int]($w * $xFrac)
    $pt.Y = [int]($h * $yFrac)
    $clientX = $pt.X
    $clientY = $pt.Y
    if (-not [FrozenLauncherNative]::ClientToScreen($Hwnd, [ref]$pt)) {
        throw 'ClientToScreen failed for frozen launcher hwnd'
    }

    return [pscustomobject][ordered]@{
        clientX = $clientX
        clientY = $clientY
        screenX = $pt.X
        screenY = $pt.Y
        xFraction = $xFrac
        yFraction = $yFrac
        width = $w
        height = $h
    }
}

function Invoke-FrozenLauncherClick {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][int]$ExpectedPid,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][int]$Attempt
    )

    if (-not (Test-FrozenHwndValid -Hwnd $Hwnd -ExpectedPid $ExpectedPid)) {
        throw 'frozen launcher target invalidated before click'
    }

    $point = Get-FrozenClickPoint -Hwnd $Hwnd -Intent $Intent -Attempt $Attempt
    $title = [FrozenLauncherNative]::WindowTitle($Hwnd)
    $label = if ($Intent -eq 'continue') { 'launcher CONTINUE' } else { 'launcher PLAY' }
    $foreground = [FrozenLauncherNative]::GetForegroundWindow()
    $foregroundMatches = $foreground -eq $Hwnd

    Write-FrozenLaunchLog ('CLICK "{0}" frozen attempt={1} hwnd={2} pid={3} title="{4}" client=({5},{6}) screen=({7},{8}) fractions=({9:F2},{10:F2}) foregroundMatches={11}' -f `
        $label, ($Attempt + 1), $Hwnd.ToInt64(), $ExpectedPid, $title, $point.clientX, $point.clientY, $point.screenX, $point.screenY, $point.xFraction, $point.yFraction, $foregroundMatches)

    $lParam = [FrozenLauncherNative]::MakeLParam($point.clientX, $point.clientY)
    [void][FrozenLauncherNative]::SendMessage($Hwnd, [FrozenLauncherNative]::WM_LBUTTONDOWN, [IntPtr][FrozenLauncherNative]::MK_LBUTTON, $lParam)
    Start-Sleep -Milliseconds 40
    [void][FrozenLauncherNative]::SendMessage($Hwnd, [FrozenLauncherNative]::WM_LBUTTONUP, [IntPtr]::Zero, $lParam)
    Write-FrozenLaunchLog ('CLICK "{0}" frozen method=hwnd SendMessage dispatched hwnd={1}' -f $label, $Hwnd.ToInt64())

    if ($foregroundMatches -or $AllowFocusSteal -or -not $RespectUserForeground) {
        if (-not $foregroundMatches) {
            [void][FrozenLauncherNative]::SetForegroundWindow($Hwnd)
            Start-Sleep -Milliseconds 120
        }
        [void][FrozenLauncherNative]::SetCursorPos($point.screenX, $point.screenY)
        Start-Sleep -Milliseconds 40
        [FrozenLauncherNative]::mouse_event([FrozenLauncherNative]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        [FrozenLauncherNative]::mouse_event([FrozenLauncherNative]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        Write-FrozenLaunchLog ('CLICK "{0}" frozen method=real-input dispatched reason={1}' -f $label, $(if ($foregroundMatches) { 'target_already_foreground' } elseif ($AllowFocusSteal) { 'AllowFocusSteal' } else { 'RespectUserForeground_false' }))
    } else {
        Write-FrozenLaunchLog ('CLICK "{0}" frozen real-input skipped reason=RespectUserForeground target_not_foreground' -f $label)
    }
}

function Wait-FrozenGameSpawnOrInvalidation {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][int]$ExpectedPid,
        [Parameter(Mandatory = $true)][datetime]$Deadline
    )
    while (-not (Test-TbgTestDurationExpired -Deadline $Deadline)) {
        if (Test-GameSpawned) { return 'game_spawned' }
        if (-not (Test-FrozenHwndValid -Hwnd $Hwnd -ExpectedPid $ExpectedPid)) { return 'frozen_target_invalidated' }
        Start-Sleep -Milliseconds $PollMs
    }
    return 'click_unverified_timeout'
}

function Emit-PostHandoffReadiness {
    param([Parameter(Mandatory = $true)][datetime]$Deadline)
    $lastProgress = [datetime]::MinValue
    while (-not (Test-TbgTestDurationExpired -Deadline $Deadline)) {
        if (Test-Phase1TbgReady -BannerlordRoot $BannerlordRoot) {
            Write-FrozenLaunchLog 'LAUNCH_STATE=hotkeys_ready classification=hotkeys_ready source=Phase1Log'
            Write-Host 'TBG ready: Ctrl+Alt+T cycles engine mode.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+G runs GuildLoop.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+M writes Market Intel.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+B aborts active autonomous movement.' -ForegroundColor Cyan
            return 'hotkeys_ready'
        }
        if (((Get-Date) - $lastProgress).TotalSeconds -ge 10) {
            $lastProgress = Get-Date
            Write-FrozenLaunchLog 'LAUNCH_STATE=loading_still_in_progress classification=loading_still_in_progress waiting_for=Phase1TbgReady'
        }
        Start-Sleep -Milliseconds 1000
    }
    Write-FrozenLaunchLog 'LAUNCH_STATE=post_handoff_idle_unactionable classification=post_handoff_idle_unactionable reason=no Phase1 ready signal or operator guidance after game spawn'
    return 'post_handoff_idle_unactionable'
}

try {
    $context = Read-FrozenLauncherContext
    $targetHwnd = [IntPtr]([int64]$context.hwnd)
    $targetPid = [int]$context.processId
    $targetTitle = [string]$context.windowTitle
    Write-FrozenLaunchLog ('LAUNCH_STATE=launcher_target_selected selectionFrozen=true hwnd={0} pid={1} title="{2}" context={3}' -f $targetHwnd.ToInt64(), $targetPid, $targetTitle, $LauncherContextPath)

    if (-not (Test-FrozenHwndValid -Hwnd $targetHwnd -ExpectedPid $targetPid)) {
        throw 'frozen launcher context target is invalid before click phase'
    }

    if (Test-GameSpawned) {
        Write-FrozenLaunchLog 'LAUNCH_STATE=game_spawned classification=game_spawned before_click=true'
        $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
        if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
        exit 0
    }

    Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_click_phase selectionFrozen=true rescoring=disabled'
    $maxAttempts = 2
    for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
        if (Test-TbgTestDurationExpired -Deadline $overallDeadline) { break }
        Invoke-FrozenLauncherClick -Hwnd $targetHwnd -ExpectedPid $targetPid -Intent $LaunchIntent -Attempt $attempt
        $result = Wait-FrozenGameSpawnOrInvalidation -Hwnd $targetHwnd -ExpectedPid $targetPid -Deadline $overallDeadline
        if ($result -eq 'game_spawned') {
            Write-FrozenLaunchLog ('LAUNCH_STATE={0}_clicked selectedBy=frozen_context attempts={1}' -f $LaunchIntent, ($attempt + 1))
            Write-FrozenLaunchLog 'LAUNCH_STATE=game_spawned classification=game_spawned'
            Write-FrozenLaunchLog 'LAUNCH_STATE=post_handoff_watch'
            $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
            if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
            exit 0
        }
        if ($result -eq 'frozen_target_invalidated') {
            Write-FrozenLaunchLog 'LAUNCH_STATE=frozen_target_invalidated classification=frozen_target_invalidated rescoring=disabled'
            if (Test-GameSpawned) {
                Write-FrozenLaunchLog 'LAUNCH_STATE=game_spawned classification=game_spawned after_invalidation=true'
                $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
                if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
                exit 0
            }
            throw 'frozen launcher target invalidated before game spawned'
        }
        Write-FrozenLaunchLog ('LAUNCH_STATE=click_unverified_timeout attempt={0} selectionFrozen=true rescoring=disabled' -f ($attempt + 1))
    }

    Write-FrozenLaunchLog 'LAUNCH_STATE=operator_action_required classification=operator_action_required reason=frozen CONTINUE/PLAY click did not spawn game; target was not replaced by heuristic search'
    throw 'operator_action_required: frozen launcher click did not spawn game; no heuristic reselection performed'
} finally {
    Write-FrozenLaunchLog 'LAUNCH_STATE=frozen_nav_complete'
}
