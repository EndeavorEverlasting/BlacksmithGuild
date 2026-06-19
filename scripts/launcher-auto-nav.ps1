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
    private const string CrashReporterTitle = "* _*";

    public static bool ClickButtonByName(string name, bool requireEnabled = true)
    {
        if (string.IsNullOrWhiteSpace(name)) return false;
        var condition = new PropertyCondition(AutomationElement.NameProperty, name);
        var element = AutomationElement.RootElement.FindFirst(TreeScope.Descendants, condition);
        if (element == null) return false;
        if (requireEnabled && !element.Current.IsEnabled) return false;
        return InvokeElement(element);
    }

    public static string ClickButtonByNameInLauncher(string[] names, bool requireEnabled = true)
    {
        if (names == null || names.Length == 0) return null;

        var launcherRoot = FindLauncherRoot();
        if (launcherRoot != null)
        {
            foreach (var name in names)
            {
                if (TryClickButtonInScope(launcherRoot, name, requireEnabled))
                {
                    return name;
                }
            }
        }

        foreach (var name in names)
        {
            if (ClickButtonByName(name, requireEnabled))
            {
                return name;
            }
        }

        return null;
    }

    public static bool HasCrashReporterDialog()
    {
        var hwnd = FindWindow(null, CrashReporterTitle);
        if (hwnd != IntPtr.Zero)
        {
            return true;
        }

        if (HasGameMainWindow())
        {
            return false;
        }

        try
        {
            var textCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Text);
            var textElements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, textCondition);
            foreach (AutomationElement element in textElements)
            {
                var name = element.Current.Name ?? string.Empty;
                if (name.IndexOf("application faced a problem", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
        }
        catch { }

        return false;
    }

    public static bool HasGameMainWindow()
    {
        var processes = Process.GetProcessesByName("Bannerlord");
        foreach (var process in processes)
        {
            try
            {
                if (process.MainWindowHandle != IntPtr.Zero)
                {
                    return true;
                }
            }
            catch { }
        }

        return false;
    }

    public static bool HasLauncherRoot()
    {
        return FindLauncherRoot() != null;
    }

    public static bool ClickCrashReporterNo()
    {
        var hwnd = FindWindow(null, CrashReporterTitle);
        if (hwnd != IntPtr.Zero)
        {
            SetForegroundWindow(hwnd);
            Thread.Sleep(120);
            if (ClickButtonByName("No", false)) return true;
        }

        try
        {
            var buttonCondition = new AndCondition(
                new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button),
                new PropertyCondition(AutomationElement.NameProperty, "No"));
            var button = AutomationElement.RootElement.FindFirst(TreeScope.Descendants, buttonCondition);
            if (button != null && InvokeElement(button)) return true;
        }
        catch { }

        return false;
    }

    public static string LogVisibleLauncherButtons()
    {
        var names = new List<string>();
        var launcherRoot = FindLauncherRoot();
        if (launcherRoot == null) return "launcher window not found";

        try
        {
            var buttonCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Button);
            var buttons = launcherRoot.FindAll(TreeScope.Descendants, buttonCondition);
            foreach (AutomationElement button in buttons)
            {
                var name = button.Current.Name;
                if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                {
                    names.Add(name);
                }
            }
        }
        catch (Exception ex)
        {
            return "button scan failed: " + ex.Message;
        }

        if (names.Count == 0) return "no launcher buttons visible";
        return string.Join(", ", names.ToArray());
    }

    public static bool ClickSafeModeNo()
    {
        var hwnd = FindWindow(null, "Safe Mode");
        if (hwnd == IntPtr.Zero) return false;
        SetForegroundWindow(hwnd);
        Thread.Sleep(120);
        return ClickButtonByName("No", false);
    }

    public static bool HasCautionDialog()
    {
        var caution = AutomationElement.RootElement.FindFirst(
            TreeScope.Descendants,
            new PropertyCondition(AutomationElement.NameProperty, "CAUTION"));
        return caution != null;
    }

    private static AutomationElement FindLauncherRoot()
    {
        var processes = Process.GetProcessesByName(LauncherProcessName);
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
$gameStablePolls = 0
$requiredStablePolls = 3
$startTime = Get-Date
$effectiveTimeout = $TimeoutSec
$deadline = $startTime.AddSeconds($effectiveTimeout)

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
        if ([UIAHelper]::ClickButtonByName('Confirm')) {
            if (-not $clickedCaution) {
                Write-LaunchLog 'clicked CAUTION Confirm'
                $clickedCaution = $true
            }
        } else {
            # GPU overlay fallback — Enter often activates focused Confirm
            Add-Type -AssemblyName System.Windows.Forms
            [System.Windows.Forms.SendKeys]::SendWait('{ENTER}')
            Write-LaunchLog 'CAUTION Confirm fallback (Enter)'
            $clickedCaution = $true
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
