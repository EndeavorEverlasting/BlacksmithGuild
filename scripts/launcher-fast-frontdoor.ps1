# Fast root-command launcher state machine for Forge.cmd and ForgeContinue.cmd.
# Owns the launcher UI after forge.ps1 -LaunchManual opens a fresh launcher context.
# Budget: 30 seconds total, 5 seconds per attempt phase, one bounded full-close retry.

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$BannerlordRoot,
    [ValidateRange(5, 30)]
    [int]$TotalBudgetSec = 30,
    [ValidateRange(2, 5)]
    [int]$PhaseBudgetSec = 5,
    [ValidateRange(1, 2)]
    [int]$MaxAttempts = 2,
    [ValidateRange(100, 1000)]
    [int]$PollMs = 250
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

if (-not $BannerlordRoot) {
    $BannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

$contextPath = Join-Path $BannerlordRoot 'launcher-window-context.json'
$launchLogPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$evidenceDir = Join-Path $RepoRoot (Join-Path 'artifacts\latest\launcher-frontdoor' $runId)
$latestResultPath = Join-Path $RepoRoot 'artifacts\latest\launcher-frontdoor.result.json'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$frontdoorLogPath = Join-Path $evidenceDir 'frontdoor.log'
$overallStarted = Get-Date
$overallDeadline = $overallStarted.AddSeconds($TotalBudgetSec)
$captures = New-Object System.Collections.Generic.List[string]
$attemptRecords = New-Object System.Collections.Generic.List[object]

$native = @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class TbgFastLauncherNative
{
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int command);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder value, int maxCount);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;
    public const int SW_RESTORE = 9;
    public static string WindowTitle(IntPtr hwnd)
    {
        var value = new StringBuilder(512);
        GetWindowText(hwnd, value, value.Capacity);
        return value.ToString();
    }
}
'@
if (-not ('TbgFastLauncherNative' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}
[void][TbgFastLauncherNative]::SetProcessDPIAware()
Add-Type -AssemblyName System.Drawing -ErrorAction Stop

function Write-FrontdoorLog {
    param([Parameter(Mandatory = $true)][string]$Message)
    $line = '[{0}] launcher-frontdoor: {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
    Add-Content -LiteralPath $frontdoorLogPath -Value $line -Encoding UTF8
    try { Add-Content -LiteralPath $launchLogPath -Value $line -Encoding UTF8 } catch { }
    Write-Host $line -ForegroundColor DarkCyan
}

function Test-OverallExpired {
    return (Get-Date) -ge $overallDeadline
}

function Test-GameSpawned {
    if (Get-Process -Name 'Bannerlord' -ErrorAction SilentlyContinue) { return $true }
    foreach ($name in @('TaleWorlds.MountAndBlade.Launcher', 'TaleWorlds.MountAndBlade')) {
        $match = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -like 'Mount and Blade II Bannerlord - Singleplayer*' } |
            Select-Object -First 1
        if ($match) { return $true }
    }
    return $false
}

function Read-LauncherContext {
    param([int]$WaitSec = 5)
    $deadline = (Get-Date).AddSeconds([Math]::Min($WaitSec, $PhaseBudgetSec))
    do {
        if (Test-Path -LiteralPath $contextPath) {
            try {
                $context = Get-Content -LiteralPath $contextPath -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($context -and [string]$context.schema -eq 'TbgLauncherWindowContext.v1' -and [int]$context.processId -gt 0) {
                    return $context
                }
            } catch { }
        }
        Start-Sleep -Milliseconds $PollMs
    } while ((Get-Date) -lt $deadline -and -not (Test-OverallExpired))
    return $null
}

function Resolve-LauncherWindow {
    param([Parameter(Mandatory = $true)]$Context)
    $pid = [int]$Context.processId
    $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
    if (-not $process) { return $null }
    try { $process.Refresh() } catch { }
    $hwnd = [IntPtr]$process.MainWindowHandle
    if ($hwnd -eq [IntPtr]::Zero -or -not [TbgFastLauncherNative]::IsWindow($hwnd)) { return $null }
    [uint32]$actualPid = 0
    [void][TbgFastLauncherNative]::GetWindowThreadProcessId($hwnd, [ref]$actualPid)
    if ([int]$actualPid -ne $pid) { return $null }
    return [pscustomobject][ordered]@{
        processId = $pid
        processName = [string]$process.ProcessName
        hwnd = $hwnd
        title = [TbgFastLauncherNative]::WindowTitle($hwnd)
    }
}

function Focus-LauncherWindow {
    param([Parameter(Mandatory = $true)]$Window)
    [void][TbgFastLauncherNative]::ShowWindow([IntPtr]$Window.hwnd, [TbgFastLauncherNative]::SW_RESTORE)
    [void][TbgFastLauncherNative]::BringWindowToTop([IntPtr]$Window.hwnd)
    [void][TbgFastLauncherNative]::SetForegroundWindow([IntPtr]$Window.hwnd)
    Start-Sleep -Milliseconds 120
    return [TbgFastLauncherNative]::GetForegroundWindow() -eq [IntPtr]$Window.hwnd
}

function Capture-LauncherWindow {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $rect = New-Object TbgFastLauncherNative+RECT
    if (-not [TbgFastLauncherNative]::GetWindowRect([IntPtr]$Window.hwnd, [ref]$rect)) { return $null }
    $width = [Math]::Max(1, $rect.Right - $rect.Left)
    $height = [Math]::Max(1, $rect.Bottom - $rect.Top)
    $path = Join-Path $evidenceDir ($Name + '.png')
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size($width, $height)))
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        $captures.Add($path) | Out-Null
        $dark = 0
        $sampled = 0
        $xStart = [int]($width * 0.16)
        $xEnd = [int]($width * 0.84)
        $yStart = [int]($height * 0.16)
        $yEnd = [int]($height * 0.73)
        for ($x = $xStart; $x -lt $xEnd; $x += 6) {
            for ($y = $yStart; $y -lt $yEnd; $y += 6) {
                $pixel = $bitmap.GetPixel($x, $y)
                $luma = (0.2126 * $pixel.R) + (0.7152 * $pixel.G) + (0.0722 * $pixel.B)
                if ($luma -lt 45) { $dark++ }
                $sampled++
            }
        }
        $ratio = if ($sampled -gt 0) { [Math]::Round($dark / [double]$sampled, 4) } else { 0.0 }
        return [pscustomobject][ordered]@{
            path = $path
            left = $rect.Left
            top = $rect.Top
            width = $width
            height = $height
            darkRatio = $ratio
        }
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Click-LauncherFraction {
    param(
        [Parameter(Mandatory = $true)]$Window,
        [Parameter(Mandatory = $true)][double]$XFraction,
        [Parameter(Mandatory = $true)][double]$YFraction,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Focus-LauncherWindow -Window $Window)) {
        throw "focus_failed:$Label"
    }
    $rect = New-Object TbgFastLauncherNative+RECT
    if (-not [TbgFastLauncherNative]::GetWindowRect([IntPtr]$Window.hwnd, [ref]$rect)) {
        throw "window_rect_failed:$Label"
    }
    $x = [int]($rect.Left + (($rect.Right - $rect.Left) * $XFraction))
    $y = [int]($rect.Top + (($rect.Bottom - $rect.Top) * $YFraction))
    [void][TbgFastLauncherNative]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 50
    if ([TbgFastLauncherNative]::GetForegroundWindow() -ne [IntPtr]$Window.hwnd) {
        throw "focus_lost_before_click:$Label"
    }
    [TbgFastLauncherNative]::mouse_event([TbgFastLauncherNative]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    [TbgFastLauncherNative]::mouse_event([TbgFastLauncherNative]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    Write-FrontdoorLog ('CLICK label={0} pid={1} hwnd={2} screen=({3},{4}) fractions=({5:F2},{6:F2}) dpiAware=true' -f `
        $Label, $Window.processId, ([IntPtr]$Window.hwnd).ToInt64(), $x, $y, $XFraction, $YFraction)
}

function Wait-GameUntil {
    param([Parameter(Mandatory = $true)][datetime]$Deadline)
    do {
        if (Test-GameSpawned) { return $true }
        Start-Sleep -Milliseconds $PollMs
    } while ((Get-Date) -lt $Deadline -and -not (Test-OverallExpired))
    return $false
}

function Stop-TbgLauncherFamily {
    $terminated = New-Object System.Collections.Generic.List[string]
    foreach ($name in @('Bannerlord', 'TaleWorlds.MountAndBlade.Launcher', 'Watchdog')) {
        foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
                $terminated.Add(('{0}:{1}' -f $name, $process.Id)) | Out-Null
            } catch {
                $terminated.Add(('{0}:{1}:error' -f $name, $process.Id)) | Out-Null
            }
        }
    }
    Start-Sleep -Milliseconds 500
    Write-FrontdoorLog ('LAUNCH_STATE=fast_retry_force_close_complete terminated="{0}"' -f ($terminated -join ','))
    return @($terminated.ToArray())
}

function Open-FreshLauncher {
    Remove-Item -LiteralPath $contextPath -Force -ErrorAction SilentlyContinue
    & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot
    & (Join-Path $PSScriptRoot 'open-bannerlord-launcher.ps1') -BannerlordRoot $BannerlordRoot -LaunchIntent $LaunchIntent
    return Read-LauncherContext -WaitSec $PhaseBudgetSec
}

function Copy-LocalEvidence {
    try {
        if (Test-Path -LiteralPath $contextPath) {
            Copy-Item -LiteralPath $contextPath -Destination (Join-Path $evidenceDir 'launcher-window-context.json') -Force
        }
        if (Test-Path -LiteralPath $launchLogPath) {
            Get-Content -LiteralPath $launchLogPath -Tail 300 -ErrorAction SilentlyContinue |
                Set-Content -LiteralPath (Join-Path $evidenceDir 'launch-tail.log') -Encoding UTF8
        }
    } catch {
        Write-FrontdoorLog ('EVIDENCE_COPY_WARNING message="{0}"' -f ($_.Exception.Message -replace '"', ''''))
    }
}

function Write-TerminalResult {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][string]$Reason,
        [int]$Attempt = 0
    )
    Copy-LocalEvidence
    $result = [ordered]@{
        schema = 'TbgLauncherFastFrontdoor.v1'
        generatedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        launchIntent = $LaunchIntent
        state = $State
        reason = $Reason
        attempt = $Attempt
        maxAttempts = $MaxAttempts
        totalBudgetSec = $TotalBudgetSec
        phaseBudgetSec = $PhaseBudgetSec
        elapsedMs = [int]((Get-Date) - $overallStarted).TotalMilliseconds
        evidenceDir = $evidenceDir
        captures = @($captures.ToArray())
        attempts = @($attemptRecords.ToArray())
        runtimeProofClaim = $false
    }
    $json = $result | ConvertTo-Json -Depth 10
    $json | Set-Content -LiteralPath (Join-Path $evidenceDir 'result.json') -Encoding UTF8
    $json | Set-Content -LiteralPath $latestResultPath -Encoding UTF8
    Write-FrontdoorLog ('LAUNCH_STATE={0} reason="{1}" attempt={2} elapsedMs={3} evidenceDir="{4}" runtimeProofClaim=false' -f `
        $State, ($Reason -replace '"', ''''), $Attempt, $result.elapsedMs, $evidenceDir)
}

function Invoke-LauncherAttempt {
    param(
        [Parameter(Mandatory = $true)][int]$Attempt,
        [Parameter(Mandatory = $true)]$Context
    )
    $attemptStarted = Get-Date
    $attemptDeadline = $attemptStarted.AddSeconds($PhaseBudgetSec)
    if ($attemptDeadline -gt $overallDeadline) { $attemptDeadline = $overallDeadline }
    $window = Resolve-LauncherWindow -Context $Context
    if (-not $window) {
        return [pscustomobject]@{ success = $false; reason = 'launcher_window_unavailable'; cautionDetected = $false }
    }

    Write-FrontdoorLog ('LAUNCH_STATE=fast_attempt_started attempt={0} pid={1} hwnd={2} title="{3}" phaseBudgetSec={4} totalBudgetSec={5}' -f `
        $Attempt, $window.processId, ([IntPtr]$window.hwnd).ToInt64(), $window.title, $PhaseBudgetSec, $TotalBudgetSec)
    $before = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-menu-before' -f $Attempt)
    $xIntent = if ($LaunchIntent -eq 'continue') { 0.55 } else { 0.34 }
    Click-LauncherFraction -Window $window -XFraction $xIntent -YFraction 0.90 -Label ('launcher_' + $LaunchIntent)

    $quickDeadline = (Get-Date).AddMilliseconds(900)
    if ($quickDeadline -gt $attemptDeadline) { $quickDeadline = $attemptDeadline }
    if (Wait-GameUntil -Deadline $quickDeadline) {
        return [pscustomobject]@{ success = $true; reason = 'game_spawned_after_intent'; cautionDetected = $false }
    }

    $postIntent = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-after-intent' -f $Attempt)
    $baselineDark = if ($before) { [double]$before.darkRatio } else { 0.0 }
    $postDark = if ($postIntent) { [double]$postIntent.darkRatio } else { 0.0 }
    $darkDelta = [Math]::Round($postDark - $baselineDark, 4)
    $cautionDetected = ($postDark -ge 0.55) -or ($darkDelta -ge 0.12)
    Write-FrontdoorLog ('LAUNCH_STATE=fast_post_intent_classified attempt={0} baselineDarkRatio={1:F4} postDarkRatio={2:F4} darkDelta={3:F4} cautionDetected={4}' -f `
        $Attempt, $baselineDark, $postDark, $darkDelta, $cautionDetected)

    if (-not $cautionDetected -and (Get-Date) -lt $attemptDeadline) {
        $alternateX = if ($LaunchIntent -eq 'continue') { 0.58 } else { 0.38 }
        Click-LauncherFraction -Window $window -XFraction $alternateX -YFraction 0.88 -Label ('launcher_' + $LaunchIntent + '_alternate')
        Start-Sleep -Milliseconds 450
        if (Test-GameSpawned) {
            return [pscustomobject]@{ success = $true; reason = 'game_spawned_after_alternate_intent'; cautionDetected = $false }
        }
        $postAlternate = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-after-alternate-intent' -f $Attempt)
        if ($postAlternate) {
            $postDark = [double]$postAlternate.darkRatio
            $darkDelta = [Math]::Round($postDark - $baselineDark, 4)
            $cautionDetected = ($postDark -ge 0.55) -or ($darkDelta -ge 0.12)
        }
        Write-FrontdoorLog ('LAUNCH_STATE=fast_alternate_classified attempt={0} postDarkRatio={1:F4} darkDelta={2:F4} cautionDetected={3}' -f `
            $Attempt, $postDark, $darkDelta, $cautionDetected)
    }

    if (-not $cautionDetected) {
        return [pscustomobject]@{ success = $false; reason = 'intent_click_did_not_produce_game_or_caution'; cautionDetected = $false }
    }

    Write-FrontdoorLog ('LAUNCH_STATE=dependency_caution_modal_detected attempt={0} action=confirm defaultAction=confirm cancelAction=forbidden phaseBudgetSec={1}' -f $Attempt, $PhaseBudgetSec)
    Click-LauncherFraction -Window $window -XFraction 0.55 -YFraction 0.88 -Label 'dependency_caution_confirm'
    Start-Sleep -Milliseconds 500
    if (Test-GameSpawned) {
        return [pscustomobject]@{ success = $true; reason = 'game_spawned_after_confirm'; cautionDetected = $true }
    }

    $postConfirm = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-after-confirm' -f $Attempt)
    $postConfirmDark = if ($postConfirm) { [double]$postConfirm.darkRatio } else { 0.0 }
    if ($postConfirmDark -lt 0.45 -and (Get-Date) -lt $attemptDeadline) {
        Write-FrontdoorLog ('LAUNCH_STATE=launcher_menu_returned_after_confirm attempt={0} action=reclick_{1} postConfirmDarkRatio={2:F4}' -f `
            $Attempt, $LaunchIntent, $postConfirmDark)
        Click-LauncherFraction -Window $window -XFraction $xIntent -YFraction 0.90 -Label ('launcher_' + $LaunchIntent + '_menu_returned')
        Start-Sleep -Milliseconds 350
        $reopened = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-menu-return-reopened' -f $Attempt)
        if ($reopened -and [double]$reopened.darkRatio -ge 0.55 -and (Get-Date) -lt $attemptDeadline) {
            Click-LauncherFraction -Window $window -XFraction 0.55 -YFraction 0.88 -Label 'dependency_caution_confirm_after_menu_return'
        }
    }

    if (Wait-GameUntil -Deadline $attemptDeadline) {
        return [pscustomobject]@{ success = $true; reason = 'game_spawned_after_confirm_wait'; cautionDetected = $true }
    }

    $finalCapture = Capture-LauncherWindow -Window $window -Name ('attempt-{0}-terminal' -f $Attempt)
    $finalDark = if ($finalCapture) { [double]$finalCapture.darkRatio } else { 0.0 }
    $reason = if ($finalDark -ge 0.55) { 'caution_still_present_after_confirm' } else { 'launcher_menu_or_window_remained_without_game_spawn' }
    return [pscustomobject]@{ success = $false; reason = $reason; cautionDetected = $true }
}

try {
    Write-FrontdoorLog ('LAUNCH_STATE=fast_frontdoor_started intent={0} totalBudgetSec={1} phaseBudgetSec={2} maxAttempts={3} evidenceDir="{4}"' -f `
        $LaunchIntent, $TotalBudgetSec, $PhaseBudgetSec, $MaxAttempts, $evidenceDir)
    & (Join-Path $PSScriptRoot 'write-launch-intent.ps1') -LaunchIntent $LaunchIntent -BannerlordRoot $BannerlordRoot
    $context = Read-LauncherContext -WaitSec $PhaseBudgetSec

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-OverallExpired) { break }
        if (-not $context) {
            $attemptResult = [pscustomobject]@{ success = $false; reason = 'launcher_context_missing'; cautionDetected = $false }
        } else {
            $attemptResult = Invoke-LauncherAttempt -Attempt $attempt -Context $context
        }
        $attemptRecords.Add([pscustomobject][ordered]@{
            attempt = $attempt
            success = [bool]$attemptResult.success
            reason = [string]$attemptResult.reason
            cautionDetected = [bool]$attemptResult.cautionDetected
            elapsedMs = [int]((Get-Date) - $overallStarted).TotalMilliseconds
        }) | Out-Null

        if ($attemptResult.success) {
            Write-TerminalResult -State 'launcher_setup_handoff_observed' -Reason $attemptResult.reason -Attempt $attempt
            exit 0
        }

        Write-FrontdoorLog ('LAUNCH_STATE=fast_attempt_failed attempt={0} reason={1} cautionDetected={2}' -f `
            $attempt, $attemptResult.reason, $attemptResult.cautionDetected)
        Copy-LocalEvidence
        if ($attempt -ge $MaxAttempts -or (Test-OverallExpired)) { break }

        Write-FrontdoorLog ('LAUNCH_STATE=fast_retry_scheduled attempt={0} nextAttempt={1} action=force_close_and_fresh_launcher' -f $attempt, ($attempt + 1))
        [void](Stop-TbgLauncherFamily)
        $context = Open-FreshLauncher
    }

    $lastReason = if ($attemptRecords.Count -gt 0) { [string]$attemptRecords[$attemptRecords.Count - 1].reason } else { 'no_attempt_completed' }
    Write-TerminalResult -State 'launcher_recovery_dead_end' -Reason $lastReason -Attempt $attemptRecords.Count
    exit 1
} catch {
    Write-FrontdoorLog ('LAUNCH_STATE=fast_frontdoor_exception type="{0}" message="{1}"' -f $_.Exception.GetType().FullName, ($_.Exception.Message -replace '"', ''''))
    Write-TerminalResult -State 'launcher_frontdoor_exception' -Reason $_.Exception.Message -Attempt $attemptRecords.Count
    exit 1
}
