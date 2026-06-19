# Pre-main-menu UI automation: PLAY/CONTINUE, CAUTION Confirm, Safe Mode No (Sprint 006E).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [int]$TimeoutSec = 120,
    [int]$PollMs = 450
)

$ErrorActionPreference = 'Stop'

$logPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Launch.log'
$launcherExeName = 'TaleWorlds.MountAndBlade.Launcher'
$gameExeName = 'Bannerlord'

function Write-LaunchLog {
    param([string]$Message)
    $line = "[{0}] launcher-auto: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

if (-not (Get-Module -Name UIAHelper -ErrorAction SilentlyContinue)) {
    $uiaHelperSource = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Automation;

public static class UIAHelper
{
    private const string LauncherProcessName = "TaleWorlds.MountAndBlade.Launcher";
    private const string GameProcessName = "Bannerlord";
    private const string CrashReporterTitle = "* _*";
    private const string ModuleMismatchTitle = "Module Mismatch";

    // Never click AutomationElement.RootElement — only scoped Bannerlord windows/dialogs.

    public static string ClickButtonByNameInLauncher(string[] names, bool requireEnabled = true)
    {
        if (names == null || names.Length == 0) return null;

        var launcherRoot = FindLauncherRoot();
        if (launcherRoot == null) return null;

        foreach (var name in names)
        {
            if (TryClickButtonInScope(launcherRoot, name, requireEnabled))
            {
                return name;
            }
        }

        return null;
    }

    public static bool HasCrashReporterDialog()
    {
        var crashRoot = FindCrashReporterRoot();
        if (crashRoot == null) return false;

        if (HasGameMainWindow()) return false;

        return ScopeContainsText(crashRoot, "application faced a problem");
    }

    public static bool HasGameMainWindow()
    {
        return FindGameMainWindowRoot() != null;
    }

    public static bool HasLauncherRoot()
    {
        return FindLauncherRoot() != null;
    }

    public static bool ClickCrashReporterNo()
    {
        var crashRoot = FindCrashReporterRoot();
        if (crashRoot == null) return false;

        FocusScope(crashRoot);
        return TryClickButtonInScope(crashRoot, "No", false);
    }

    public static string LogVisibleLauncherButtons()
    {
        var names = new List<string>();
        var launcherRoot = FindLauncherRoot();
        if (launcherRoot == null) return "launcher window not found";

        CollectButtonNames(launcherRoot, names);
        if (names.Count == 0) return "no launcher buttons visible";
        return string.Join(", ", names.ToArray());
    }

    public static bool ClickSafeModeNo()
    {
        var safeModeRoot = FindWindowRootByTitle("Safe Mode");
        if (safeModeRoot == null) return false;

        FocusScope(safeModeRoot);
        return TryClickButtonInScope(safeModeRoot, "No", false);
    }

    public static bool HasCautionDialog()
    {
        return FindCautionDialogRoot() != null;
    }

    public static bool ClickCautionConfirm()
    {
        var cautionRoot = FindCautionDialogRoot();
        if (cautionRoot == null) return false;

        FocusScope(cautionRoot);
        return TryClickButtonInScope(cautionRoot, "Confirm", true);
    }

    public static bool HasModuleMismatchDialog()
    {
        return FindModuleMismatchDialogRoot() != null;
    }

    public static string LogVisibleModuleMismatchButtons()
    {
        var names = new List<string>();
        var scope = FindModuleMismatchDialogRoot();
        if (scope == null) return "Module Mismatch dialog not found";

        CollectButtonNames(scope, names);
        if (names.Count == 0) return "no Module Mismatch buttons visible";
        return string.Join(", ", names.ToArray());
    }

    public static bool ClickModuleMismatchYes()
    {
        var scope = FindModuleMismatchDialogRoot();
        if (scope == null) return false;

        FocusScope(scope);
        foreach (var name in new[] { "Yes", "OK", "Continue" })
        {
            if (TryClickButtonInScope(scope, name, false))
            {
                return true;
            }
        }

        return false;
    }

    private static AutomationElement FindLauncherRoot()
    {
        return FindProcessMainWindowRoot(LauncherProcessName);
    }

    private static AutomationElement FindGameMainWindowRoot()
    {
        return FindProcessMainWindowRoot(GameProcessName);
    }

    private static AutomationElement FindProcessMainWindowRoot(string processName)
    {
        var processes = Process.GetProcessesByName(processName);
        foreach (var process in processes)
        {
            try
            {
                var hwnd = process.MainWindowHandle;
                if (hwnd != IntPtr.Zero)
                {
                    return AutomationElement.FromHandle(hwnd);
                }
            }
            catch { }
        }

        return null;
    }

    private static AutomationElement FindCrashReporterRoot()
    {
        var hwnd = FindWindow(null, CrashReporterTitle);
        if (hwnd != IntPtr.Zero)
        {
            try { return AutomationElement.FromHandle(hwnd); } catch { }
        }

        return FindWindowRootByTitle("* _*");
    }

    private static AutomationElement FindCautionDialogRoot()
    {
        var launcher = FindLauncherRoot();
        if (launcher != null && ScopeContainsNamedElement(launcher, "CAUTION"))
        {
            return launcher;
        }

        return FindWindowRootByTitle("CAUTION");
    }

    private static AutomationElement FindModuleMismatchDialogRoot()
    {
        var byTitle = FindWindowRootByTitle(ModuleMismatchTitle);
        if (byTitle != null) return byTitle;

        var launcher = FindLauncherRoot();
        if (launcher != null && ScopeContainsExactModuleMismatch(launcher))
        {
            return launcher;
        }

        var game = FindGameMainWindowRoot();
        if (game != null && ScopeContainsExactModuleMismatch(game))
        {
            return game;
        }

        return null;
    }

    private static AutomationElement FindWindowRootByTitle(string titleFragment)
    {
        if (string.IsNullOrWhiteSpace(titleFragment)) return null;

        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf(titleFragment, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return window;
                }
            }
        }
        catch { }

        return null;
    }

    private static bool ScopeContainsExactModuleMismatch(AutomationElement scope)
    {
        return ScopeContainsText(scope, ModuleMismatchTitle);
    }

    private static bool ScopeContainsNamedElement(AutomationElement scope, string name)
    {
        if (scope == null || string.IsNullOrWhiteSpace(name)) return false;

        try
        {
            var condition = new PropertyCondition(AutomationElement.NameProperty, name);
            return scope.FindFirst(TreeScope.Descendants, condition) != null;
        }
        catch { return false; }
    }

    private static bool ScopeContainsText(AutomationElement scope, string fragment)
    {
        if (scope == null || string.IsNullOrWhiteSpace(fragment)) return false;

        try
        {
            var textCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text);
            var textElements = scope.FindAll(TreeScope.Descendants, textCondition);
            foreach (AutomationElement element in textElements)
            {
                var name = element.Current.Name ?? string.Empty;
                if (name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
        }
        catch { }

        return false;
    }

    private static void CollectButtonNames(AutomationElement scope, List<string> names)
    {
        if (scope == null) return;

        try
        {
            var buttonCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
            var buttons = scope.FindAll(TreeScope.Descendants, buttonCondition);
            foreach (AutomationElement button in buttons)
            {
                var name = button.Current.Name;
                if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                {
                    names.Add(name);
                }
            }
        }
        catch { }
    }

    private static void FocusScope(AutomationElement scope)
    {
        if (scope == null) return;

        try
        {
            var hwnd = new IntPtr(scope.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero)
            {
                SetForegroundWindow(hwnd);
                Thread.Sleep(120);
            }
        }
        catch { }
    }

    private static bool TryClickButtonInScope(AutomationElement scope, string name, bool requireEnabled)
    {
        if (scope == null || string.IsNullOrWhiteSpace(name)) return false;

        try
        {
            var condition = new PropertyCondition(AutomationElement.NameProperty, name);
            var element = scope.FindFirst(TreeScope.Descendants, condition);
            if (element == null) return false;
            if (requireEnabled && !element.Current.IsEnabled) return false;
            return InvokeElement(element);
        }
        catch
        {
            return false;
        }
    }

    private static bool InvokeElement(AutomationElement element)
    {
        try
        {
            object pattern;
            if (element.TryGetCurrentPattern(InvokePattern.Pattern, out pattern))
            {
                InvokePattern invokePattern = pattern as InvokePattern;
                if (invokePattern != null)
                {
                    invokePattern.Invoke();
                    return true;
                }
            }
        }
        catch { }

        try
        {
            var rect = element.Current.BoundingRectangle;
            if (rect.Width <= 0 || rect.Height <= 0) return false;
            var x = (int)(rect.X + rect.Width / 2);
            var y = (int)(rect.Y + rect.Height / 2);
            SetCursorPos(x, y);
            Thread.Sleep(60);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            return true;
        }
        catch { return false; }
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    private const int MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const int MOUSEEVENTF_LEFTUP = 0x0004;
}
'@
    Add-Type -TypeDefinition $uiaHelperSource -ReferencedAssemblies @(
        'UIAutomationClient',
        'UIAutomationTypes',
        'System.Windows.Forms',
        'WindowsBase'
    ) -ErrorAction Stop
}

Write-LaunchLog "intent=$LaunchIntent"

$clickedPlayContinue = $false
$clickedCaution = $false
$clickedSafeMode = $false
$clickedCrashReporter = $false
$clickedModuleMismatch = $false
$loggedModuleMismatchButtons = $false
$gameStablePolls = 0
$requiredStablePolls = 3
$startTime = Get-Date
$effectiveTimeout = $TimeoutSec
$deadline = $startTime.AddSeconds($effectiveTimeout)
$loadStallSec = 180
$phase1LogPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$statusJsonPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'

function Extend-DeadlineForSlowPath {
    if ($clickedSafeMode -or $clickedCrashReporter) {
        $extended = [Math]::Max($TimeoutSec, 180)
        if ($extended -gt $script:effectiveTimeout) {
            $script:effectiveTimeout = $extended
            $script:deadline = $script:startTime.AddSeconds($extended)
            Write-LaunchLog "extended timeout to ${extended}s (Safe Mode or crash reporter path)"
        }
    }
}

function Test-GameProcessRunning {
    return $null -ne (Get-Process -Name $gameExeName -ErrorAction SilentlyContinue)
}

function Invoke-Handoff {
    param([string]$Reason)
    Write-LaunchLog "handoff: $Reason"
    Wait-PostHandoffWatchdog -Reason $Reason
}

function Test-Phase1ReadyOrStall {
    param([ref]$StallDetected)

    $StallDetected.Value = $false
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 40 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    foreach ($line in $tail) {
        if ($line -match 'TBG READY') {
            return $true
        }
        if ($line -match 'load stall: GameLoadingState exceeded') {
            $StallDetected.Value = $true
            return $false
        }
    }

    return $false
}

function Test-StatusJsonReady {
    if (-not (Test-Path -LiteralPath $statusJsonPath)) {
        return $false
    }

    try {
        $status = Get-Content -LiteralPath $statusJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json
        if ($status.campaignReady -eq $true) {
            return $true
        }
    } catch { }

    return $false
}

function Invoke-ModuleMismatchClick {
    if (-not [UIAHelper]::HasModuleMismatchDialog()) {
        return $false
    }

    if (-not $loggedModuleMismatchButtons) {
        $visible = [UIAHelper]::LogVisibleModuleMismatchButtons()
        Write-LaunchLog "Module Mismatch visible buttons: $visible"
        $script:loggedModuleMismatchButtons = $true
    }

    if (-not [UIAHelper]::ClickModuleMismatchYes()) {
        return $false
    }

    if (-not $clickedModuleMismatch) {
        Write-LaunchLog 'clicked Module Mismatch Yes'
        $script:clickedModuleMismatch = $true
    }

    return $true
}

function Wait-PostHandoffWatchdog {
    param([string]$Reason)

    Write-LaunchLog "post-handoff watch started ($Reason)"
    $watchStart = Get-Date
    $gameLoadingSince = $null
    $stallDetected = $false

    while (((Get-Date) - $watchStart).TotalSeconds -lt $loadStallSec) {
        if (-not (Test-GameProcessRunning)) {
            Write-LaunchLog 'post-handoff: Bannerlord exited'
            return
        }

        if (Invoke-ModuleMismatchClick) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }

        if ((Test-Phase1ReadyOrStall -StallDetected ([ref]$stallDetected)) -or (Test-StatusJsonReady)) {
            Write-LaunchLog 'post-handoff: TBG READY detected'
            return
        }

        if ($stallDetected) {
            Write-LaunchLog "load stall watchdog: C# stall signature in Phase1.log — terminating Bannerlord"
            Stop-Process -Name $gameExeName -Force -ErrorAction SilentlyContinue
            throw "load stall watchdog triggered (C# stall signature)"
        }

        if (Test-Path -LiteralPath $statusJsonPath) {
            try {
                $status = Get-Content -LiteralPath $statusJsonPath -Raw | ConvertFrom-Json
                if ($status.activeState -eq 'GameLoadingState') {
                    if (-not $gameLoadingSince) {
                        $gameLoadingSince = Get-Date
                    } elseif (((Get-Date) - $gameLoadingSince).TotalSeconds -ge $loadStallSec) {
                        Write-LaunchLog "load stall watchdog: GameLoadingState exceeded ${loadStallSec}s — terminating Bannerlord"
                        Stop-Process -Name $gameExeName -Force -ErrorAction SilentlyContinue
                        throw "load stall watchdog triggered after ${loadStallSec}s in GameLoadingState"
                    }
                } else {
                    $gameLoadingSince = $null
                }
            } catch {
                if ($_.Exception.Message -match 'load stall watchdog triggered') {
                    throw
                }
            }
        }

        Start-Sleep -Milliseconds 1000
    }

    Write-LaunchLog "post-handoff watch completed (${loadStallSec}s, no stall kill)"
}

function Test-HandoffWhenGameStable {
    if (-not (Test-GameProcessRunning)) {
        $script:gameStablePolls = 0
        return $false
    }

    $script:gameStablePolls++
    if ($script:gameStablePolls -lt $requiredStablePolls) {
        return $false
    }

    $launcherGone = -not [UIAHelper]::HasLauncherRoot()
    $playPathSkipped = $clickedPlayContinue -or $clickedSafeMode

    if (-not ($launcherGone -or $playPathSkipped)) {
        return $false
    }

    if (-not [UIAHelper]::HasCrashReporterDialog()) {
        if ($clickedPlayContinue) {
            Invoke-Handoff 'Bannerlord.exe stable — PLAY clicked'
        } elseif ($clickedSafeMode) {
            Invoke-Handoff 'Bannerlord.exe stable — Safe Mode path'
        } else {
            Invoke-Handoff 'Bannerlord.exe stable — launcher gone'
        }
        return $true
    }

    if ($clickedCrashReporter) {
        Invoke-Handoff 'Bannerlord.exe stable — crash reporter dismissed'
        return $true
    }

    Write-LaunchLog 'Bannerlord.exe stable but crash reporter heuristic still true — waiting'
    return $false
}

if ($LaunchIntent -eq 'continue') {
    $targetButtonNames = @('CONTINUE', 'Continue')
} else {
    $targetButtonNames = @('PLAY', 'Play')
}

while ((Get-Date) -lt $deadline) {
    if (Test-HandoffWhenGameStable) {
        return
    }

    if (Get-Process -Name $gameExeName -ErrorAction SilentlyContinue) {
        if (-not [UIAHelper]::HasCrashReporterDialog()) {
            Invoke-Handoff 'Bannerlord.exe detected — handoff to in-game mod'
            return
        }
        Write-LaunchLog 'Bannerlord.exe running but crash reporter visible — waiting'
    }

    if (Invoke-ModuleMismatchClick) {
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if ([UIAHelper]::HasCrashReporterDialog()) {
        if ([UIAHelper]::ClickCrashReporterNo()) {
            if (-not $clickedCrashReporter) {
                Write-LaunchLog 'clicked crash reporter No'
                $clickedCrashReporter = $true
                Extend-DeadlineForSlowPath
            }
            if (Test-GameProcessRunning) {
                Invoke-Handoff 'Bannerlord.exe running after crash reporter No'
                return
            }
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if ([UIAHelper]::ClickSafeModeNo()) {
        if (-not $clickedSafeMode) {
            Write-LaunchLog 'clicked Safe Mode No'
            $clickedSafeMode = $true
            Extend-DeadlineForSlowPath
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if ([UIAHelper]::HasCautionDialog()) {
        if ([UIAHelper]::ClickCautionConfirm()) {
            if (-not $clickedCaution) {
                Write-LaunchLog 'clicked CAUTION Confirm'
                $clickedCaution = $true
            }
        } else {
            Write-LaunchLog 'CAUTION visible but Confirm not clicked (scoped only — no global Enter)'
        }
        Start-Sleep -Milliseconds $PollMs
        continue
    }

    if (-not $clickedPlayContinue) {
        $matchedName = [UIAHelper]::ClickButtonByNameInLauncher($targetButtonNames)
        if ($matchedName) {
            $displayName = if ($LaunchIntent -eq 'continue') { 'CONTINUE' } else { 'PLAY' }
            Write-LaunchLog "clicked $displayName ($matchedName)"
            $clickedPlayContinue = $true
        }
    }

    Start-Sleep -Milliseconds $PollMs
}

$visibleButtons = [UIAHelper]::LogVisibleLauncherButtons()
Write-LaunchLog "timeout: visible launcher buttons: $visibleButtons"
throw "launcher-auto-nav timed out after ${effectiveTimeout}s (see $logPath)"
