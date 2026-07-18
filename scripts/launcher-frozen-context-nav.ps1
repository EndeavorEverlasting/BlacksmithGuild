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

$operationMode = if ($LaunchSetup) { 'launcher_setup' } else { 'frozen_navigation' }
$runtimeProofClaim = $false
$clickVerifyBudgetMs = 12000

$durationArgs = @{ Caller = "launcher-frozen-context-nav.ps1:$operationMode" }
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
Write-FrozenLaunchLog ('MODE operationMode={0} launchSetup={1} runtimeProofClaim={2} behavior=launcher_context_navigation_only' -f $operationMode, [bool]$LaunchSetup, $runtimeProofClaim)
Write-FrozenLaunchLog ('BUDGET operationMode={0} budgetSec={1} defaultBudgetSec={2} isLongRun={3} source={4}' -f $operationMode, $durationBudget.budgetSec, $durationBudget.defaultBudgetSec, $durationBudget.isLongRun, $durationBudget.source)

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

function Assert-FrozenLauncherContextIntent {
    param([Parameter(Mandatory = $true)]$Context)
    $contextIntent = [string]$Context.launchIntent
    if ([string]::IsNullOrWhiteSpace($contextIntent)) {
        throw 'LaunchSetup context missing launchIntent; refusing launcher setup navigation without explicit intent.'
    }
    if ($contextIntent -ne $LaunchIntent) {
        throw "LaunchSetup context intent mismatch: context=$contextIntent requested=$LaunchIntent"
    }
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
    if (Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue) {
        return $true
    }

    $singleplayerHost = Get-Process -Name 'TaleWorlds.MountAndBlade.Launcher' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.MainWindowTitle -like 'Mount and Blade II Bannerlord - Singleplayer*'
        } |
        Select-Object -First 1

    return [bool]$singleplayerHost
}

function Get-FrozenLauncherProcessWindow {
    param(
        [Parameter(Mandatory = $true)][int]$ExpectedPid,
        [string]$TitleLike = $null
    )

    $proc = Get-Process -Id $ExpectedPid -ErrorAction SilentlyContinue
    if (-not $proc) { return $null }

    try { $proc.Refresh() } catch { }

    $hwnd = [IntPtr]$proc.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) { return $null }

    $title = [string]$proc.MainWindowTitle
    if ($TitleLike -and $title -notlike $TitleLike) { return $null }

    return [pscustomobject][ordered]@{
        processId = [int]$proc.Id
        hwnd = $hwnd
        title = $title
        processName = [string]$proc.ProcessName
    }
}

function Test-FrozenSafeModeWindow {
    param([Parameter(Mandatory = $true)][int]$ExpectedPid)

    return [bool](Get-FrozenLauncherProcessWindow -ExpectedPid $ExpectedPid -TitleLike '*Safe Mode*')
}
function Invoke-FrozenSafeModeDecline {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][int]$ExpectedPid
    )

    if ($Hwnd -eq [IntPtr]::Zero) {
        throw 'safe mode decline requested without a usable hwnd'
    }

    try {
        & (Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1') | Out-Null
        Start-Sleep -Milliseconds 200
    } catch {}
    [void][FrozenLauncherNative]::SetForegroundWindow($Hwnd)
    Start-Sleep -Milliseconds 200

    $shell = New-Object -ComObject WScript.Shell
    [void]$shell.AppActivate($ExpectedPid)
    Start-Sleep -Milliseconds 150

    $shell.SendKeys('%n')
    Start-Sleep -Milliseconds 500
}
function New-FrozenClickDeadline {
    param(
        [Parameter(Mandatory = $true)][datetime]$OverallDeadline,
        [int]$BudgetMs = 3000
    )

    $now = Get-Date
    $clickDeadline = $now.AddMilliseconds($BudgetMs)
    if ($clickDeadline -gt $OverallDeadline) {
        return $OverallDeadline
    }

    return $clickDeadline
}

function Get-FrozenClickPoint {
    param(
        [Parameter(Mandatory = $true)][IntPtr]$Hwnd,
        [Parameter(Mandatory = $true)][string]$Intent,
        [Parameter(Mandatory = $true)][int]$Attempt
    )
    $continueFractions = @(0.25, 0.55, 0.58)
    $playFractions = @(0.11, 0.34, 0.38)
    $yFractions = @(0.92, 0.90, 0.88)
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
    $useRealInput = ($foregroundMatches -or $AllowFocusSteal -or -not $RespectUserForeground)

    Write-FrozenLaunchLog ('CLICK "{0}" frozen attempt={1} hwnd={2} pid={3} title="{4}" client=({5},{6}) screen=({7},{8}) fractions=({9:F2},{10:F2}) foregroundMatches={11} operationMode={12}' -f `
        $label, ($Attempt + 1), $Hwnd.ToInt64(), $ExpectedPid, $title, $point.clientX, $point.clientY, $point.screenX, $point.screenY, $point.xFraction, $point.yFraction, $foregroundMatches, $operationMode)

    if ($useRealInput) {
        if (-not $foregroundMatches) {
            try {
                & (Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1') | Out-Null
                Start-Sleep -Milliseconds 200
            } catch {}
            [void][FrozenLauncherNative]::SetForegroundWindow($Hwnd)
            Start-Sleep -Milliseconds 150
            $foreground = [FrozenLauncherNative]::GetForegroundWindow()
            $foregroundMatches = $foreground -eq $Hwnd
        }
        [void][FrozenLauncherNative]::SetCursorPos($point.screenX, $point.screenY)
        Start-Sleep -Milliseconds 40
        [FrozenLauncherNative]::mouse_event([FrozenLauncherNative]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
        [FrozenLauncherNative]::mouse_event([FrozenLauncherNative]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
        Write-FrozenLaunchLog ('CLICK "{0}" frozen method=real-input dispatched reason={1} operationMode={2}' -f $label, $(if ($foregroundMatches) { 'target_already_foreground' } elseif ($AllowFocusSteal) { 'AllowFocusSteal' } else { 'RespectUserForeground_false' }), $operationMode)
    } else {
        $lParam = [FrozenLauncherNative]::MakeLParam($point.clientX, $point.clientY)
        [void][FrozenLauncherNative]::SendMessage($Hwnd, [FrozenLauncherNative]::WM_LBUTTONDOWN, [IntPtr][FrozenLauncherNative]::MK_LBUTTON, $lParam)
        Start-Sleep -Milliseconds 40
        [void][FrozenLauncherNative]::SendMessage($Hwnd, [FrozenLauncherNative]::WM_LBUTTONUP, [IntPtr]::Zero, $lParam)
        Write-FrozenLaunchLog ('CLICK "{0}" frozen method=hwnd SendMessage dispatched hwnd={1} reason=real_input_not_viable operationMode={2}' -f $label, $Hwnd.ToInt64(), $operationMode)
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
            Write-FrozenLaunchLog ('LAUNCH_STATE=hotkeys_ready classification=hotkeys_ready source=Phase1Log operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
            Write-Host 'TBG ready: Ctrl+Alt+T cycles engine mode.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+G runs GuildLoop.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+M writes Market Intel.' -ForegroundColor Cyan
            Write-Host 'TBG ready: Ctrl+Alt+B aborts active autonomous movement.' -ForegroundColor Cyan
            return 'hotkeys_ready'
        }
        if (((Get-Date) - $lastProgress).TotalSeconds -ge 10) {
            $lastProgress = Get-Date
            Write-FrozenLaunchLog ('LAUNCH_STATE=loading_still_in_progress classification=loading_still_in_progress waiting_for=Phase1TbgReady operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
        }
        Start-Sleep -Milliseconds 1000
    }
    Write-FrozenLaunchLog ('LAUNCH_STATE=post_handoff_idle_unactionable classification=post_handoff_idle_unactionable reason=no Phase1 ready signal or operator guidance after game spawn operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
    return 'post_handoff_idle_unactionable'
}

try {
    $context = Read-FrozenLauncherContext
    if ($LaunchSetup) {
        Assert-FrozenLauncherContextIntent -Context $context
    }
    $targetHwnd = [IntPtr]([int64]$context.hwnd)
    $targetPid = [int]$context.processId
    $targetTitle = [string]$context.windowTitle
    Write-FrozenLaunchLog ('LAUNCH_STATE=launcher_target_selected selectionFrozen=true hwnd={0} pid={1} title="{2}" context={3} operationMode={4} runtimeProofClaim={5}' -f $targetHwnd.ToInt64(), $targetPid, $targetTitle, $LauncherContextPath, $operationMode, $runtimeProofClaim)

    if (-not (Test-FrozenHwndValid -Hwnd $targetHwnd -ExpectedPid $targetPid)) {
        throw 'frozen launcher context target is invalid before click phase'
    }

    $alreadyRunningProcess = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
    if ($alreadyRunningProcess) { try { $alreadyRunningProcess.Refresh() } catch { } }
    $alreadyRunningTitle = if ($alreadyRunningProcess) { [string]$alreadyRunningProcess.MainWindowTitle } else { '' }
    if ($alreadyRunningTitle -like 'Mount and Blade II Bannerlord - Singleplayer*') {
        $alreadyRunningHwnd = if ($alreadyRunningProcess) { [IntPtr]$alreadyRunningProcess.MainWindowHandle } else { [IntPtr]::Zero }
        $safeAlreadyRunningTitle = $alreadyRunningTitle -replace '"', ''''
        Write-FrozenLaunchLog ('LAUNCH_STATE=already_running_game classification=already_running_game hwnd={0} pid={1} title="{2}" reason=continue_target_is_live_singleplayer_host operationMode={3} runtimeProofClaim={4}' -f $alreadyRunningHwnd.ToInt64(), $targetPid, $safeAlreadyRunningTitle, $operationMode, $runtimeProofClaim)
        throw 'operator_action_required: Bannerlord Singleplayer is already running; close it before ForgeContinue.'
    }

    if (Test-GameSpawned) {
        Write-FrozenLaunchLog ('LAUNCH_STATE=game_spawned classification=game_spawned before_click=true operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
        if ($LaunchSetup) {
            Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed runtimeProofClaim=false'
        }
        $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
        if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
        exit 0
    }

    Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_load_wait waiting_for_ui_ready sleepSec=6'
    Start-Sleep -Seconds 6

    Write-FrozenLaunchLog ('LAUNCH_STATE=launcher_click_phase selectionFrozen=true rescoring=disabled operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
    $maxAttempts = 2
    for ($attempt = 0; $attempt -lt $maxAttempts; $attempt++) {
        if (Test-TbgTestDurationExpired -Deadline $overallDeadline) { break }
        Invoke-FrozenLauncherClick -Hwnd $targetHwnd -ExpectedPid $targetPid -Intent $LaunchIntent -Attempt $attempt
        $clickDeadline = New-FrozenClickDeadline -OverallDeadline $overallDeadline -BudgetMs $clickVerifyBudgetMs
        Write-FrozenLaunchLog ('CLICK_VERIFY_STARTED attempt={0} budgetMs={1} operationMode={2} runtimeProofClaim={3}' -f ($attempt + 1), $clickVerifyBudgetMs, $operationMode, $runtimeProofClaim)
        $result = Wait-FrozenGameSpawnOrInvalidation -Hwnd $targetHwnd -ExpectedPid $targetPid -Deadline $clickDeadline
        Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} result={1} operationMode={2} runtimeProofClaim={3}' -f ($attempt + 1), $result, $operationMode, $runtimeProofClaim)
        if ($result -eq 'game_spawned') {
            Write-FrozenLaunchLog ('LAUNCH_STATE={0}_clicked selectedBy=frozen_context attempts={1} operationMode={2} runtimeProofClaim={3}' -f $LaunchIntent, ($attempt + 1), $operationMode, $runtimeProofClaim)
            Write-FrozenLaunchLog ('LAUNCH_STATE=game_spawned classification=game_spawned operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
            if ($LaunchSetup) {
                Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed runtimeProofClaim=false'
            }
            Write-FrozenLaunchLog ('LAUNCH_STATE=post_handoff_watch operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
            $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
            if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
            exit 0
        }
        if ($result -eq 'frozen_target_invalidated') {
            Write-FrozenLaunchLog ('LAUNCH_STATE=frozen_target_invalidated classification=frozen_target_invalidated rescoring=disabled operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
            if (Test-GameSpawned) {
                Write-FrozenLaunchLog ('LAUNCH_STATE=game_spawned classification=game_spawned after_invalidation=true operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
                if ($LaunchSetup) {
                    Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed runtimeProofClaim=false'
                }
                $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
                if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
                exit 0
            }
            $postInvalidationHandoffBudgetMs = 5000
            Write-FrozenLaunchLog ('LAUNCH_STATE=post_invalidation_handoff_watch classification=frozen_target_invalidated waiting_for=game_spawned_or_safe_mode budgetMs={0} operationMode={1} runtimeProofClaim={2}' -f $postInvalidationHandoffBudgetMs, $operationMode, $runtimeProofClaim)
            $safeModeWindow = $null
            $postInvalidationResult = $null
            $handoffStop = (Get-Date).AddMilliseconds($postInvalidationHandoffBudgetMs)
            do {
                if (Test-GameSpawned) {
                    $postInvalidationResult = 'game_spawned'
                    break
                }

                $safeModeWindow = Get-FrozenLauncherProcessWindow -ExpectedPid $targetPid -TitleLike '*Safe Mode*'
                if ($safeModeWindow) {
                    $postInvalidationResult = 'safe_mode_detected'
                    break
                }

                Start-Sleep -Milliseconds 250
            } while ((Get-Date) -lt $handoffStop)

            if ($postInvalidationResult) {
                Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} postInvalidationResult={1} operationMode={2} runtimeProofClaim={3}' -f ($attempt + 1), $postInvalidationResult, $operationMode, $runtimeProofClaim)
            } else {
                Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} postInvalidationResult=handoff_not_observed_after_invalidation operationMode={1} runtimeProofClaim={2}' -f ($attempt + 1), $operationMode, $runtimeProofClaim)
            }

            if ($postInvalidationResult -eq 'game_spawned') {
                Write-FrozenLaunchLog ('LAUNCH_STATE=game_spawned classification=game_spawned evidence=frozen_target_invalidated_then_game_spawned operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
                $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
                if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
                exit 0
            }
            if ($safeModeWindow) {
                $safeModeHwnd = [IntPtr]$safeModeWindow.hwnd
                Write-FrozenLaunchLog ('LAUNCH_STATE=safe_mode_detected classification=safe_mode_modal hwnd={0} pid={1} title="{2}" action=decline_safe_mode_required operationMode={3} runtimeProofClaim={4}' -f `
                    $safeModeHwnd.ToInt64(), $targetPid, $safeModeWindow.title, $operationMode, $runtimeProofClaim)

                Invoke-FrozenSafeModeDecline -Hwnd $safeModeHwnd -ExpectedPid $targetPid
                Write-FrozenLaunchLog ('CLICK_SAFE_MODE_RESULT attempt={0} result=decline_dispatched method=alt_n hwnd={1} pid={2} operationMode={3} runtimeProofClaim={4}' -f ($attempt + 1), $safeModeHwnd.ToInt64(), $targetPid, $operationMode, $runtimeProofClaim)

                $safeModeDeclineHandoffBudgetMs = 60000
                Write-FrozenLaunchLog ('LAUNCH_STATE=post_safe_mode_decline_handoff_watch classification=safe_mode_declined waiting_for=game_spawned budgetMs={0} operationMode={1} runtimeProofClaim={2}' -f $safeModeDeclineHandoffBudgetMs, $operationMode, $runtimeProofClaim)

                $safeModeDeclineStop = (Get-Date).AddMilliseconds($safeModeDeclineHandoffBudgetMs)
                do {
                    if (Test-GameSpawned) {
                        Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} postSafeModeDeclineResult=game_spawned operationMode={1} runtimeProofClaim={2}' -f ($attempt + 1), $operationMode, $runtimeProofClaim)
                        Write-FrozenLaunchLog ('LAUNCH_STATE=game_spawned classification=game_spawned evidence=safe_mode_declined_then_game_spawned operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
                        if ($LaunchSetup) {
                            Write-FrozenLaunchLog 'LAUNCH_STATE=launcher_setup_handoff_observed classification=launcher_setup_handoff_observed runtimeProofClaim=false'
                        }
                        $classification = Emit-PostHandoffReadiness -Deadline $overallDeadline
                        if ($classification -eq 'post_handoff_idle_unactionable') { exit 2 }
                        exit 0
                    }

                    Start-Sleep -Milliseconds 250
                } while (((Get-Date) -lt $safeModeDeclineStop) -and (-not (Test-TbgTestDurationExpired -Deadline $overallDeadline)))

                $postDeclineSafeModeWindow = Get-FrozenLauncherProcessWindow -ExpectedPid $targetPid -TitleLike '*Safe Mode*'
                if ($postDeclineSafeModeWindow) {
                    Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} postSafeModeDeclineResult=safe_mode_still_present operationMode={1} runtimeProofClaim={2}' -f ($attempt + 1), $operationMode, $runtimeProofClaim)
                    Write-FrozenLaunchLog ('LAUNCH_STATE=operator_action_required classification=operator_action_required reason=safe_mode_still_present_after_alt_n operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
                    throw 'operator_action_required: Safe Mode still present after Alt+N decline'
                }

                Write-FrozenLaunchLog ('CLICK_VERIFY_RESULT attempt={0} postSafeModeDeclineResult=game_not_spawned operationMode={1} runtimeProofClaim={2}' -f ($attempt + 1), $operationMode, $runtimeProofClaim)
                Write-FrozenLaunchLog ('LAUNCH_STATE=operator_action_required classification=operator_action_required reason=safe_mode_declined_but_game_not_spawned operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
                throw 'operator_action_required: Safe Mode declined but game did not spawn'
            }

            throw 'frozen launcher target invalidated before game spawned'
        }
        Write-FrozenLaunchLog ('LAUNCH_STATE=click_unverified_timeout attempt={0} selectionFrozen=true rescoring=disabled operationMode={1} runtimeProofClaim={2}' -f ($attempt + 1), $operationMode, $runtimeProofClaim)
    }

    Write-FrozenLaunchLog ('LAUNCH_STATE=operator_action_required classification=operator_action_required reason=frozen CONTINUE/PLAY click did not spawn game; target was not replaced by heuristic search operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
    throw 'operator_action_required: frozen launcher click did not spawn game; no heuristic reselection performed'
} finally {
    Write-FrozenLaunchLog ('LAUNCH_STATE=frozen_nav_complete operationMode={0} runtimeProofClaim={1}' -f $operationMode, $runtimeProofClaim)
}
