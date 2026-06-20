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
using System.Text;
using System.Threading;
using System.Windows.Automation;

public static class UIAHelper
{
    private const string LauncherProcessName = "TaleWorlds.MountAndBlade.Launcher";
    private const string GameProcessName = "Bannerlord";
    private const string CrashReporterTitle = "* _*";
    private const string ModuleMismatchTitle = "Module Mismatch";

    public static Action<string> Log;

    private static bool _launcherFocused;
    private static bool _launcherAuditDone;
    private static DateTime _lastLauncherMissLogUtc = DateTime.MinValue;
    private static DateTime _firstLauncherWindowSeenUtc = DateTime.MinValue;
    private static DateTime _lastCoordClickUtc = DateTime.MinValue;
    private static int _coordAttemptIndex = 0;
    private static readonly double[] LauncherPlayXFractions = new double[] { 0.34, 0.38, 0.30 };
    private static readonly double[] LauncherContinueXFractions = new double[] { 0.55, 0.58, 0.52, 0.62 };
    private static readonly double[] LauncherCoordYFractions = new double[] { 0.90, 0.88 };
    private static readonly double[] ModuleMismatchYesXFractions = new double[] { 0.54, 0.56, 0.52 };
    private static readonly double[] ModuleMismatchYesYFractions = new double[] { 0.58, 0.56, 0.60 };
    private const int LauncherStableSecBeforeFallback = 5;
    private const int LauncherCoordClickThrottleSec = 2;
    private const int LauncherMinCoordWindowWidth = 800;
    private const int LauncherMinCoordWindowHeight = 600;
    private static bool _moduleMismatchAuditDone;
    private static int _moduleMismatchCoordAttemptIndex;

    private static void LogLine(string message)
    {
        if (Log == null) return;
        try { Log(message); } catch { }
    }

    // Never click AutomationElement.RootElement — only scoped Bannerlord windows/dialogs.

    public static string ClickButtonByNameInLauncher(string[] names, bool requireEnabled = true)
    {
        if (names == null || names.Length == 0) return null;

        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0)
        {
            LogLauncherMissThrottled("CLICK SKIP launcher buttons — TaleWorlds launcher process has no UIA windows yet (desktop never searched)");
            return null;
        }

        if (_firstLauncherWindowSeenUtc == DateTime.MinValue)
        {
            _firstLauncherWindowSeenUtc = DateTime.UtcNow;
        }

        if (!_launcherFocused)
        {
            var focusTarget = GetBestLauncherWindowForCoords(windows) ?? windows[0];
            FocusScope(focusTarget, "launcher");
            _launcherFocused = true;
        }

        foreach (var window in windows)
        {
            var element = FindClickableInScope(window, names, requireEnabled);
            if (element == null) continue;

            var matchedName = element.Current.Name ?? names[0];
            var scopeDesc = DescribeScope(window);
            LogLine(string.Format("CLICK \"launcher PLAY/CONTINUE\" button=\"{0}\" in {1} | foreground before {2}", matchedName, scopeDesc, DescribeForegroundWindow()));
            if (InvokeElement(element, "launcher PLAY/CONTINUE", matchedName, scopeDesc))
            {
                return matchedName;
            }
        }

        var globalElement = FindNamedElementInLauncherProcess(names, requireEnabled);
        if (globalElement != null)
        {
            var matchedName = globalElement.Current.Name ?? names[0];
            var scopeDesc = string.Format("PID-global process={0} pid={1}", LauncherProcessName, globalElement.Current.ProcessId);
            LogLine(string.Format("CLICK \"launcher PLAY/CONTINUE\" button=\"{0}\" in {1} | foreground before {2}", matchedName, scopeDesc, DescribeForegroundWindow()));
            if (InvokeElement(globalElement, "launcher PLAY/CONTINUE", matchedName, scopeDesc))
            {
                return matchedName;
            }
        }

        var launcherStable = (DateTime.UtcNow - _firstLauncherWindowSeenUtc).TotalSeconds >= LauncherStableSecBeforeFallback;
        if (launcherStable && !IsCoordClickThrottled())
        {
            var coordIntent = NamesIndicateContinue(names) ? "continue" : "play";
            var coordWindow = GetBestLauncherWindowForCoords(windows);
            if (coordWindow != null)
            {
                FocusScope(coordWindow, "launcher coords prep");
                if (TryClickLauncherByCoordinates(coordWindow, coordIntent))
                {
                    _lastCoordClickUtc = DateTime.UtcNow;
                    _coordAttemptIndex++;
                    return names[0];
                }
            }
        }

        if (!_launcherAuditDone && launcherStable)
        {
            _launcherAuditDone = true;
            LogLauncherControlAudit(windows);
            LogLauncherPidNamedElementsAudit();
            LogLine("AUDIT launcher buttons: " + LogVisibleLauncherButtons());
        }

        LogLauncherMissThrottled("CLICK SKIP launcher PLAY/CONTINUE — not found in " + windows.Count + " launcher window(s) (scoped + PID-global + coords)");
        return null;
    }

    private static bool NamesIndicateContinue(string[] names)
    {
        if (names == null) return false;
        foreach (var name in names)
        {
            if (NameMatchesTarget(name, "CONTINUE") || NameMatchesTarget(name, "Continue"))
            {
                return true;
            }
        }
        return false;
    }

    private static AutomationElement FindNamedElementInLauncherProcess(string[] names, bool requireEnabled)
    {
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0 || names == null || names.Length == 0) return null;

        foreach (var targetName in names)
        {
            try
            {
                var condition = new PropertyCondition(AutomationElement.NameProperty, targetName);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, condition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                    catch { }
                }
            }
            catch { }
        }

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var target in names)
                        {
                            if (!NameMatchesTarget(name, target)) continue;
                            if (requireEnabled && !element.Current.IsEnabled) continue;
                            return element;
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return null;
    }

    public static void ResetLauncherClickRetryState()
    {
        _lastCoordClickUtc = DateTime.MinValue;
    }

    private static bool IsCoordClickThrottled()
    {
        if (_lastCoordClickUtc == DateTime.MinValue) return false;
        return (DateTime.UtcNow - _lastCoordClickUtc).TotalSeconds < LauncherCoordClickThrottleSec;
    }

    private static AutomationElement GetBestLauncherWindowForCoords(List<AutomationElement> windows)
    {
        if (windows == null || windows.Count == 0) return null;

        AutomationElement best = null;
        double bestScore = -1;

        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    continue;
                }

                var rect = window.Current.BoundingRectangle;
                if (rect.Width < 400 || rect.Height < 300)
                {
                    continue;
                }

                var area = rect.Width * rect.Height;
                var score = area;

                if (title.Equals("MB II: Bannerlord", StringComparison.OrdinalIgnoreCase) ||
                    title.Equals("M&B II: Bannerlord", StringComparison.OrdinalIgnoreCase))
                {
                    score *= 10;
                }
                else if (title.IndexOf("Bannerlord", StringComparison.OrdinalIgnoreCase) >= 0 &&
                         title.IndexOf("Singleplayer", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    score *= 2;
                }

                if (score > bestScore)
                {
                    bestScore = score;
                    best = window;
                }
            }
            catch { }
        }

        if (best != null)
        {
            LogLine("AUDIT coord window pick: " + DescribeScope(best));
            return best;
        }

        LogLine("AUDIT coord window pick: no PLAY/CONTINUE chrome window — falling back to first hwnd");
        return windows[0];
    }

    private static bool TryGetLauncherClientClickPoint(IntPtr hwnd, double xFraction, double yFraction, out int screenX, out int screenY)
    {
        screenX = 0;
        screenY = 0;
        if (hwnd == IntPtr.Zero) return false;

        RECT clientRect;
        if (!GetClientRect(hwnd, out clientRect))
        {
            return false;
        }

        var clientW = clientRect.Right - clientRect.Left;
        var clientH = clientRect.Bottom - clientRect.Top;
        if (clientW <= 0 || clientH <= 0) return false;

        var clientPoint = new POINT
        {
            X = (int)(clientW * xFraction),
            Y = (int)(clientH * yFraction)
        };

        if (!ClientToScreen(hwnd, ref clientPoint))
        {
            return false;
        }

        screenX = clientPoint.X;
        screenY = clientPoint.Y;
        return true;
    }

    private static bool TryClickLauncherByCoordinates(AutomationElement launcherWindow, string intent)
    {
        if (launcherWindow == null || string.IsNullOrWhiteSpace(intent)) return false;

        try
        {
            var hwnd = new IntPtr(launcherWindow.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero)
            {
                LogLine("CLICK SKIP launcher coords — launcher hwnd is zero");
                return false;
            }

            var bounds = launcherWindow.Current.BoundingRectangle;
            if (bounds.Width <= 0 || bounds.Height <= 0)
            {
                LogLine("CLICK SKIP launcher coords — launcher window has zero-size bounds");
                return false;
            }

            var xFractions = intent == "continue" ? LauncherContinueXFractions : LauncherPlayXFractions;
            var xFraction = xFractions[_coordAttemptIndex % xFractions.Length];
            var yFraction = LauncherCoordYFractions[_coordAttemptIndex % LauncherCoordYFractions.Length];
            int x;
            int y;
            if (!TryGetLauncherClientClickPoint(hwnd, xFraction, yFraction, out x, out y))
            {
                x = (int)(bounds.X + bounds.Width * xFraction);
                y = (int)(bounds.Y + bounds.Height * yFraction);
                LogLine("CLICK WARN launcher coords — using UIA bounds fallback for client rect");
            }
            var scopeDesc = DescribeScope(launcherWindow);
            var label = intent == "continue" ? "launcher CONTINUE" : "launcher PLAY";

            ForceForegroundWindow(hwnd);
            Thread.Sleep(250);

            LogHitWindowAtPoint(x, y, label, intent);

            LogLine(string.Format(
                "CLICK \"{0}\" intent={1} attempt={2} method=coords at ({3},{4}) fractions=({5:F2},{6:F2}) bounds=({7:F0},{8:F0},{9:F0},{10:F0}) in {11} | foreground {12}",
                label, intent, _coordAttemptIndex + 1, x, y, xFraction, yFraction, bounds.X, bounds.Y, bounds.Width, bounds.Height, scopeDesc, DescribeForegroundWindow()));

            TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, label);

            SetCursorPos(x, y);
            Thread.Sleep(80);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            Thread.Sleep(40);
            LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method=mouse at ({1},{2}) in {3} | foreground after {4}", intent, x, y, scopeDesc, DescribeForegroundWindow()));
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL launcher coords: " + ex.Message);
            return false;
        }
    }

    private static void LogHitWindowAtPoint(int screenX, int screenY, string label, string intent)
    {
        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            var hit = WindowFromPoint(point);
            if (hit == IntPtr.Zero)
            {
                LogLine(string.Format("AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd=none", intent, label, screenX, screenY));
                return;
            }

            var sb = new StringBuilder(256);
            GetWindowText(hit, sb, sb.Capacity);
            uint hitPid;
            GetWindowThreadProcessId(hit, out hitPid);
            var procName = "?";
            try { procName = Process.GetProcessById((int)hitPid).ProcessName; } catch { }
            LogLine(string.Format(
                "AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd={4} title=\"{5}\" process={6} pid={7}",
                intent, label, screenX, screenY, hit.ToInt64(), sb.ToString(), procName, hitPid));
        }
        catch (Exception ex)
        {
            LogLine("AUDIT hit-test failed: " + ex.Message);
        }
    }

    public static void LogLauncherPidNamedElementsAudit()
    {
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0)
        {
            LogLine("AUDIT launcher PID-named elements: (no launcher PIDs)");
            return;
        }

        var names = new List<string>();
        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name;
                        if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                        {
                            names.Add(name);
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        LogLine(string.Format("AUDIT launcher PID-named elements: {0} (count={1})", names.Count == 0 ? "(none)" : string.Join(", ", names.ToArray()), names.Count));
    }

    private static void LogLauncherMissThrottled(string message)
    {
        var now = DateTime.UtcNow;
        if ((now - _lastLauncherMissLogUtc).TotalSeconds < 10) return;
        _lastLauncherMissLogUtc = now;
        LogLine(message);
    }

    private static bool NameMatchesTarget(string elementName, string targetName)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(targetName)) return false;
        return string.Equals(elementName.Trim(), targetName.Trim(), StringComparison.OrdinalIgnoreCase);
    }

    private static AutomationElement FindClickableInScope(AutomationElement scope, string[] targetNames, bool requireEnabled)
    {
        if (scope == null || targetNames == null || targetNames.Length == 0) return null;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name ?? string.Empty;
                    foreach (var target in targetNames)
                    {
                        if (!NameMatchesTarget(name, target)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                }
            }
            catch { }
        }

        return null;
    }

    private static HashSet<int> GetLauncherProcessIds()
    {
        var ids = new HashSet<int>();
        foreach (var process in Process.GetProcessesByName(LauncherProcessName))
        {
            try { ids.Add(process.Id); } catch { }
        }
        return ids;
    }

    private static bool IsLauncherForegroundHwnd(IntPtr launcherHwnd, HashSet<int> launcherPids)
    {
        try
        {
            var fg = GetForegroundWindow();
            if (fg == IntPtr.Zero) return false;
            if (fg == launcherHwnd) return true;

            var root = GetAncestor(fg, GA_ROOT);
            if (root == launcherHwnd) return true;

            uint pid;
            GetWindowThreadProcessId(fg, out pid);
            return launcherPids.Contains((int)pid);
        }
        catch
        {
            return false;
        }
    }

    private static void ForceForegroundWindow(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return;

        try
        {
            var fg = GetForegroundWindow();
            uint fgPid;
            uint fgThread = GetWindowThreadProcessId(fg, out fgPid);
            uint targetPid;
            uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
            uint currentThread = GetCurrentThreadId();

            if (fgThread != 0 && fgThread != currentThread)
            {
                AttachThreadInput(currentThread, fgThread, true);
            }
            if (targetThread != 0 && targetThread != currentThread)
            {
                AttachThreadInput(currentThread, targetThread, true);
            }

            ShowWindow(hwnd, SW_RESTORE);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
            Thread.Sleep(200);

            if (fgThread != 0 && fgThread != currentThread)
            {
                AttachThreadInput(currentThread, fgThread, false);
            }
            if (targetThread != 0 && targetThread != currentThread)
            {
                AttachThreadInput(currentThread, targetThread, false);
            }
        }
        catch { }
    }

    private static bool TryClickLauncherHwndAtScreenPoint(IntPtr hwnd, int screenX, int screenY, string scopeDesc, string label)
    {
        if (hwnd == IntPtr.Zero) return false;

        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            if (!ScreenToClient(hwnd, ref point))
            {
                LogLine("CLICK SKIP launcher hwnd — ScreenToClient failed for " + scopeDesc);
                return false;
            }

            var lParam = MakeLParam(point.X, point.Y);
            LogLine(string.Format(
                "CLICK \"{0}\" method=hwnd SendMessage at client ({1},{2}) screen ({3},{4}) in {5}",
                label, point.X, point.Y, screenX, screenY, scopeDesc));

            SendMessage(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lParam);
            Thread.Sleep(40);
            SendMessage(hwnd, WM_LBUTTONUP, 0, lParam);
            LogLine(string.Format("CLICK hwnd SendMessage at ({0},{1}) in {2}", screenX, screenY, scopeDesc));
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL launcher hwnd: " + ex.Message);
            return false;
        }
    }

    private static List<AutomationElement> FindAllLauncherWindowRoots()
    {
        var results = new List<AutomationElement>();
        var pids = GetLauncherProcessIds();
        if (pids.Count == 0) return results;

        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                try
                {
                    if (!pids.Contains(window.Current.ProcessId)) continue;
                    if (!ContainsWindow(results, window))
                    {
                        results.Add(window);
                    }
                }
                catch { }
            }
        }
        catch { }

        foreach (var pid in pids)
        {
            try
            {
                CollectLauncherWindowsFromPid(pid, results);
                var process = Process.GetProcessById(pid);
                var hwnd = process.MainWindowHandle;
                if (hwnd == IntPtr.Zero) continue;
                var fromHandle = AutomationElement.FromHandle(hwnd);
                if (fromHandle != null && !ContainsWindow(results, fromHandle))
                {
                    results.Add(fromHandle);
                }
            }
            catch { }
        }

        return results;
    }

    private static void CollectLauncherWindowsFromPid(int pid, List<AutomationElement> results)
    {
        EnumWindows((hwnd, param) =>
        {
            try
            {
                if (!IsWindowVisible(hwnd)) return true;
                uint windowPid;
                GetWindowThreadProcessId(hwnd, out windowPid);
                if ((int)windowPid != pid) return true;
                var fromHandle = AutomationElement.FromHandle(hwnd);
                if (fromHandle != null && !ContainsWindow(results, fromHandle))
                {
                    results.Add(fromHandle);
                }
            }
            catch { }
            return true;
        }, IntPtr.Zero);
    }

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    private static bool ContainsWindow(List<AutomationElement> list, AutomationElement candidate)
    {
        foreach (var existing in list)
        {
            try
            {
                if (existing.Current.NativeWindowHandle == candidate.Current.NativeWindowHandle)
                {
                    return true;
                }
            }
            catch { }
        }
        return false;
    }

    public static void LogLauncherControlAudit(List<AutomationElement> windows)
    {
        var parts = new List<string>();
        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                var controls = new List<string>();
                CollectInteractiveNames(window, controls);
                parts.Add(string.Format("{0}=[{1}]", title, controls.Count == 0 ? "(none)" : string.Join(", ", controls.ToArray())));
            }
            catch (Exception ex)
            {
                parts.Add("audit-error=" + ex.Message);
            }
        }

        LogLine("AUDIT launcher controls: " + string.Join(" | ", parts.ToArray()));
    }

    private static void CollectInteractiveNames(AutomationElement scope, List<string> names)
    {
        if (scope == null) return;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name;
                    if (!string.IsNullOrWhiteSpace(name) && !names.Contains(name))
                    {
                        names.Add(name);
                    }
                }
            }
            catch { }
        }
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
        return FindAllLauncherWindowRoots().Count > 0 || GetLauncherProcessIds().Count > 0;
    }

    public static bool HasLauncherLoadingSurface()
    {
        foreach (var window in FindAllLauncherWindowRoots())
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                if (title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            catch { }
        }

        return false;
    }

    public static bool ClickCrashReporterNo()
    {
        var crashRoot = FindCrashReporterRoot();
        if (crashRoot == null) return false;

        FocusScope(crashRoot, "crash reporter");
        return TryClickButtonInScope(crashRoot, "No", false, "crash reporter No");
    }

    public static string LogVisibleLauncherButtons()
    {
        var names = new List<string>();
        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0) return "launcher window not found";

        foreach (var window in windows)
        {
            CollectButtonNames(window, names);
            CollectInteractiveNames(window, names);
        }

        if (names.Count == 0) return "no launcher buttons visible in " + windows.Count + " window(s)";
        return string.Join(", ", names.ToArray());
    }

    public static bool ClickSafeModeNo()
    {
        var safeModeRoot = FindWindowRootByTitle("Safe Mode");
        if (safeModeRoot == null) return false;

        FocusScope(safeModeRoot, "Safe Mode");
        return TryClickButtonInScope(safeModeRoot, "No", false, "Safe Mode No");
    }

    public static bool HasCautionDialog()
    {
        return FindCautionDialogRoot() != null;
    }

    public static bool ClickCautionConfirm()
    {
        var cautionRoot = FindCautionDialogRoot();
        if (cautionRoot == null) return false;

        FocusScope(cautionRoot, "CAUTION");
        return TryClickButtonInScope(cautionRoot, "Confirm", true, "CAUTION Confirm");
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

        FocusScope(scope, "Module Mismatch");
        foreach (var name in new[] { "Yes", "OK", "Continue" })
        {
            if (TryClickButtonInScope(scope, name, false, "Module Mismatch " + name))
            {
                return true;
            }
        }

        var globalElement = FindNamedElementInGameProcess(new[] { "Yes", "OK", "Continue" }, false);
        if (globalElement != null)
        {
            var matchedName = globalElement.Current.Name ?? "Yes";
            var scopeDesc = string.Format("PID-global process={0} pid={1}", GameProcessName, globalElement.Current.ProcessId);
            if (InvokeElement(globalElement, "Module Mismatch Yes", matchedName, scopeDesc))
            {
                return true;
            }
        }

        var game = FindGameMainWindowRoot();
        if (game != null && TryClickModuleMismatchYesByCoordinates(game))
        {
            return true;
        }

        if (!_moduleMismatchAuditDone)
        {
            _moduleMismatchAuditDone = true;
            LogLine("AUDIT Module Mismatch game elements: " + LogModuleMismatchGameElements());
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

        if (FindModuleMismatchInGameProcess())
        {
            return FindGameMainWindowRoot();
        }

        return null;
    }

    private static bool FindModuleMismatchInGameProcess()
    {
        var pids = GetGameProcessIds();
        if (pids.Count == 0) return false;

        var fragments = new[] { ModuleMismatchTitle, "different modules" };
        var controlTypes = new[] { ControlType.Text, ControlType.Custom, ControlType.Button, ControlType.Group, ControlType.Pane, ControlType.Document };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var fragment in fragments)
                        {
                            if (name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                            {
                                return true;
                            }
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return false;
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
                    LogLine(string.Format("DIALOG MATCH title=\"{0}\" matched=\"{1}\"", title, titleFragment));
                    return window;
                }
            }
        }
        catch { }

        return null;
    }

    private static bool ScopeContainsExactModuleMismatch(AutomationElement scope)
    {
        return ScopeContainsFragment(scope, ModuleMismatchTitle, "different modules");
    }

    private static bool ScopeContainsFragment(AutomationElement scope, params string[] fragments)
    {
        if (scope == null || fragments == null || fragments.Length == 0) return false;

        var controlTypes = new[] { ControlType.Text, ControlType.Custom, ControlType.Button, ControlType.Group, ControlType.Pane, ControlType.Document };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var name = element.Current.Name ?? string.Empty;
                    foreach (var fragment in fragments)
                    {
                        if (!string.IsNullOrWhiteSpace(fragment)
                            && name.IndexOf(fragment, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            return true;
                        }
                    }
                }
            }
            catch { }
        }

        return false;
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

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var buttons = scope.FindAll(TreeScope.Descendants, typeCondition);
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
    }

    private static HashSet<int> GetGameProcessIds()
    {
        var ids = new HashSet<int>();
        foreach (var process in Process.GetProcessesByName(GameProcessName))
        {
            try { ids.Add(process.Id); } catch { }
        }
        return ids;
    }

    private static AutomationElement FindNamedElementInGameProcess(string[] names, bool requireEnabled)
    {
        var pids = GetGameProcessIds();
        if (pids.Count == 0 || names == null || names.Length == 0) return null;

        foreach (var targetName in names)
        {
            try
            {
                var condition = new PropertyCondition(AutomationElement.NameProperty, targetName);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, condition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        if (requireEnabled && !element.Current.IsEnabled) continue;
                        return element;
                    }
                    catch { }
                }
            }
            catch { }
        }

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink, ControlType.Text, ControlType.ListItem };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = AutomationElement.RootElement.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    try
                    {
                        if (!pids.Contains(element.Current.ProcessId)) continue;
                        var name = element.Current.Name ?? string.Empty;
                        foreach (var target in names)
                        {
                            if (!NameMatchesTarget(name, target)) continue;
                            if (requireEnabled && !element.Current.IsEnabled) continue;
                            return element;
                        }
                    }
                    catch { }
                }
            }
            catch { }
        }

        return null;
    }

    private static bool TryClickModuleMismatchYesByCoordinates(AutomationElement gameWindow)
    {
        if (gameWindow == null) return false;

        try
        {
            var hwnd = new IntPtr(gameWindow.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero) return false;

            var bounds = gameWindow.Current.BoundingRectangle;
            var xFraction = ModuleMismatchYesXFractions[_moduleMismatchCoordAttemptIndex % ModuleMismatchYesXFractions.Length];
            var yFraction = ModuleMismatchYesYFractions[_moduleMismatchCoordAttemptIndex % ModuleMismatchYesYFractions.Length];
            int x;
            int y;
            if (!TryGetLauncherClientClickPoint(hwnd, xFraction, yFraction, out x, out y))
            {
                x = (int)(bounds.X + bounds.Width * xFraction);
                y = (int)(bounds.Y + bounds.Height * yFraction);
            }

            var scopeDesc = DescribeScope(gameWindow);
            ForceForegroundWindow(hwnd);
            Thread.Sleep(250);
            LogLine(string.Format(
                "CLICK \"Module Mismatch Yes\" method=coords at ({0},{1}) fractions=({2:F2},{3:F2}) in {4}",
                x, y, xFraction, yFraction, scopeDesc));
            TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Module Mismatch Yes");
            SetCursorPos(x, y);
            Thread.Sleep(80);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            _moduleMismatchCoordAttemptIndex++;
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL Module Mismatch coords: " + ex.Message);
            return false;
        }
    }

    private static string LogModuleMismatchGameElements()
    {
        var names = new List<string>();
        var game = FindGameMainWindowRoot();
        if (game != null)
        {
            CollectButtonNames(game, names);
            CollectInteractiveNames(game, names);
        }

        if (names.Count == 0) return "no named game elements in Bannerlord scope";
        return string.Join(", ", names.ToArray());
    }

    private static void FocusScope(AutomationElement scope, string reason)
    {
        if (scope == null) return;

        LogLine(string.Format("FOCUS request ({0}) target={1} | before {2}", reason, DescribeScope(scope), DescribeForegroundWindow()));

        try
        {
            var hwnd = new IntPtr(scope.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero)
            {
                SetForegroundWindow(hwnd);
                Thread.Sleep(120);
            }
        }
        catch (Exception ex)
        {
            LogLine("FOCUS failed: " + ex.Message);
            return;
        }

        LogLine(string.Format("FOCUS done ({0}) | after {1}", reason, DescribeForegroundWindow()));
    }

    private static bool TryClickButtonInScope(AutomationElement scope, string name, bool requireEnabled, string actionLabel)
    {
        if (scope == null || string.IsNullOrWhiteSpace(name)) return false;

        var scopeDesc = DescribeScope(scope);
        var label = string.IsNullOrWhiteSpace(actionLabel) ? name : actionLabel;

        try
        {
            var condition = new PropertyCondition(AutomationElement.NameProperty, name);
            var element = scope.FindFirst(TreeScope.Descendants, condition);
            if (element == null)
            {
                return false;
            }

            LogLine(string.Format("CLICK \"{0}\" button=\"{1}\" in {2} | foreground before {3}", label, name, scopeDesc, DescribeForegroundWindow()));
            return InvokeElement(element, label, name, scopeDesc);
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK FAIL \"{0}\" button=\"{1}\" in {2}: {3}", label, name, scopeDesc, ex.Message));
            return false;
        }
    }

    private static bool InvokeElement(AutomationElement element, string actionLabel, string buttonName, string scopeDesc)
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
                    LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=InvokePattern in {2} | foreground after {3}", actionLabel, buttonName, scopeDesc, DescribeForegroundWindow()));
                    return true;
                }
            }
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK InvokePattern failed \"{0}\": {1}", actionLabel, ex.Message));
        }

        try
        {
            var rect = element.Current.BoundingRectangle;
            if (rect.Width <= 0 || rect.Height <= 0)
            {
                LogLine(string.Format("CLICK FAIL \"{0}\" — zero-size bounds in {1}", actionLabel, scopeDesc));
                return false;
            }
            var x = (int)(rect.X + rect.Width / 2);
            var y = (int)(rect.Y + rect.Height / 2);
            SetCursorPos(x, y);
            Thread.Sleep(60);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=mouse at ({2},{3}) in {4} | foreground after {5}", actionLabel, buttonName, x, y, scopeDesc, DescribeForegroundWindow()));
            return true;
        }
        catch (Exception ex)
        {
            LogLine(string.Format("CLICK FAIL \"{0}\" mouse click: {1}", actionLabel, ex.Message));
            return false;
        }
    }

    public static string DescribeScope(AutomationElement scope)
    {
        if (scope == null) return "scope=null";
        try
        {
            var name = scope.Current.Name ?? string.Empty;
            var pid = scope.Current.ProcessId;
            var procName = "?";
            try { procName = Process.GetProcessById(pid).ProcessName; } catch { }
            return string.Format("window=\"{0}\" process={1} pid={2}", name, procName, pid);
        }
        catch
        {
            return "scope=unknown";
        }
    }

    public static string DescribeForegroundWindow()
    {
        try
        {
            var hwnd = GetForegroundWindow();
            if (hwnd == IntPtr.Zero) return "foreground=none";

            var sb = new StringBuilder(512);
            GetWindowText(hwnd, sb, sb.Capacity);
            var title = sb.ToString();

            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            var procName = "?";
            try { procName = Process.GetProcessById((int)pid).ProcessName; } catch { }

            return string.Format("foreground=\"{0}\" process={1} pid={2}", title, procName, pid);
        }
        catch
        {
            return "foreground=unknown";
        }
    }

    public static string DescribeEnvironment()
    {
        return string.Format(
            "env launcher={0} game={1} {2}",
            HasLauncherRoot() ? "yes" : "no",
            HasGameMainWindow() ? "yes" : "no",
            DescribeForegroundWindow());
    }

    public static string LogTopLevelWindows()
    {
        var parts = new List<string>();
        try
        {
            var windowCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Window);
            var windows = AutomationElement.RootElement.FindAll(TreeScope.Children, windowCondition);
            foreach (AutomationElement window in windows)
            {
                try
                {
                    var title = window.Current.Name ?? string.Empty;
                    if (string.IsNullOrWhiteSpace(title)) continue;
                    var pid = window.Current.ProcessId;
                    var procName = "?";
                    try { procName = Process.GetProcessById(pid).ProcessName; } catch { }
                    parts.Add(string.Format("\"{0}\"({1})", title, procName));
                }
                catch { }
            }

            var summary = parts.Count == 0
                ? "AUDIT top-level windows: (none with titles)"
                : "AUDIT top-level windows (" + parts.Count + "): " + string.Join("; ", parts.ToArray());
            LogLine(summary);
            return summary;
        }
        catch (Exception ex)
        {
            var msg = "AUDIT top-level windows: scan failed — " + ex.Message;
            LogLine(msg);
            return msg;
        }
    }

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll")]
    private static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, UIntPtr dwExtraInfo);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetAncestor(IntPtr hwnd, uint gaFlags);

    [DllImport("user32.dll")]
    private static extern bool ScreenToClient(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    private static extern bool ClientToScreen(IntPtr hWnd, ref POINT lpPoint);

    [DllImport("user32.dll")]
    private static extern IntPtr WindowFromPoint(POINT point);

    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hWnd, int msg, int wParam, int lParam);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    private static int MakeLParam(int x, int y)
    {
        return (y << 16) | (x & 0xFFFF);
    }

    private const int MOUSEEVENTF_LEFTDOWN = 0x0002;
    private const int MOUSEEVENTF_LEFTUP = 0x0004;
    private const int WM_LBUTTONDOWN = 0x0201;
    private const int WM_LBUTTONUP = 0x0202;
    private const int MK_LBUTTON = 0x0001;
    private const int SW_RESTORE = 9;
    private const uint GA_ROOT = 2;
}
'@
    Add-Type -TypeDefinition $uiaHelperSource -ReferencedAssemblies @(
        'UIAutomationClient',
        'UIAutomationTypes',
        'System.Windows.Forms',
        'WindowsBase'
    ) -ErrorAction Stop
}

[UIAHelper]::Log = [Action[string]]{ param($m) Write-LaunchLog "UIA: $m" }

Write-LaunchLog "session pid=$PID log=$logPath intent=$LaunchIntent timeout=${TimeoutSec}s poll=${PollMs}ms"
Write-LaunchLog ([UIAHelper]::DescribeEnvironment())
[UIAHelper]::LogTopLevelWindows() | Out-Null

$clickedPlayContinue = $false
$clickedCaution = $false
$clickedSafeMode = $false
$clickedCrashReporter = $false
$clickedModuleMismatch = $false
$loggedModuleMismatchButtons = $false
$gameStablePolls = 0
$requiredStablePolls = 3
$playClickUtc = $null
$startTime = Get-Date
$effectiveTimeout = $TimeoutSec
$deadline = $startTime.AddSeconds($effectiveTimeout)
$loadStallSec = 180
$phase1LogPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$statusJsonPath = Join-Path $BannerlordRoot 'BlacksmithGuild_Status.json'
$lastHeartbeat = Get-Date
$heartbeatSec = 30
$preHandoffSuppressedLogged = $false
$phase1ReadyBaseline = @{}
if (Test-Path -LiteralPath $phase1LogPath) {
    Get-Content -LiteralPath $phase1LogPath -Tail 40 -ErrorAction SilentlyContinue |
        Where-Object { $_ -match 'TBG READY' } |
        ForEach-Object { $phase1ReadyBaseline[$_] = $true }
}

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

function Extend-DeadlineAfterPlayClick {
    if (-not $script:clickedPlayContinue -or -not $script:playClickUtc) {
        return
    }

    $extendedDeadline = $script:playClickUtc.AddSeconds(240)
    if ($extendedDeadline -gt $script:deadline) {
        $script:deadline = $extendedDeadline
        $script:effectiveTimeout = [int][Math]::Ceiling(($script:deadline - $script:startTime).TotalSeconds)
        Write-LaunchLog "extended timeout to $($script:effectiveTimeout)s (post-PLAY spawn wait)"
    }
}

function Test-PreHandoffReadyAllowed {
    if ($script:clickedPlayContinue) { return $true }
    if (Test-GameProcessRunning) { return $true }
    if (-not [UIAHelper]::HasLauncherRoot()) { return $true }
    return $false
}

function Test-LaunchReadyNow {
    param([ref]$StallDetected)

    if (-not (Test-PreHandoffReadyAllowed)) {
        if (-not $script:preHandoffSuppressedLogged) {
            Write-LaunchLog 'pre-handoff ready suppressed — launcher idle, PLAY/CONTINUE not clicked yet'
            $script:preHandoffSuppressedLogged = $true
        }
        return $false
    }

    if ((Test-Phase1ReadyOrStall -StallDetected $StallDetected) -or (Test-StatusJsonReady)) {
        return $true
    }

    return $false
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
            if (-not $script:phase1ReadyBaseline.ContainsKey($line)) {
                return $true
            }
        }
        if ($line -match 'load stall: GameLoadingState exceeded') {
            if ((Get-Item -LiteralPath $phase1LogPath).LastWriteTime -gt $script:startTime) {
                $StallDetected.Value = $true
            }
            return $false
        }
    }

    return $false
}

function Test-StatusJsonReady {
    if (-not (Test-Path -LiteralPath $statusJsonPath)) {
        return $false
    }

    $statusMtime = (Get-Item -LiteralPath $statusJsonPath).LastWriteTime
    if ($statusMtime -le $script:startTime) {
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

function Test-PostHandoffReadyAllowed {
    if ($LaunchIntent -ne 'continue') {
        return $true
    }

    if ($script:clickedModuleMismatch) {
        return $true
    }

    if ([UIAHelper]::HasModuleMismatchDialog()) {
        return $false
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

        if ((Test-PostHandoffReadyAllowed) -and
            ((Test-Phase1ReadyOrStall -StallDetected ([ref]$stallDetected)) -or (Test-StatusJsonReady))) {
            Write-LaunchLog 'post-handoff: TBG READY detected'
            return
        }

        if (-not (Test-PostHandoffReadyAllowed)) {
            Start-Sleep -Milliseconds $PollMs
            continue
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

function Test-LaunchClickVerified {
    param([int]$WaitSec = 18)

    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-GameProcessRunning) { return $true }
        if (-not [UIAHelper]::HasLauncherRoot()) { return $true }
        if ([UIAHelper]::HasLauncherLoadingSurface()) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return $false
}

if ($LaunchIntent -eq 'continue') {
    $targetButtonNames = @('CONTINUE', 'Continue')
} else {
    $targetButtonNames = @('PLAY', 'Play')
}

while ((Get-Date) -lt $deadline) {
    if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSec) {
        Write-LaunchLog ([UIAHelper]::DescribeEnvironment())
        $lastHeartbeat = Get-Date
    }

    if ($clickedPlayContinue) {
        Extend-DeadlineAfterPlayClick
    }

    $preHandoffStall = $false
    if (Test-LaunchReadyNow -StallDetected ([ref]$preHandoffStall)) {
        Write-LaunchLog 'TBG READY detected (pre-handoff) — launch success'
        return
    }

    if ($preHandoffStall) {
        Write-LaunchLog 'load stall signature detected before handoff — waiting for watchdog path'
    }

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
            if (Test-LaunchClickVerified -WaitSec 8) {
                Write-LaunchLog "clicked $displayName ($matchedName) — launch verified (game or launcher handoff)"
                $clickedPlayContinue = $true
                $script:playClickUtc = Get-Date
                Extend-DeadlineAfterPlayClick
            } else {
                Write-LaunchLog "click $displayName ($matchedName) NOT verified — PLAY/CONTINUE still on screen; will retry"
                [UIAHelper]::ResetLauncherClickRetryState()
            }
        }
    }

    Start-Sleep -Milliseconds $PollMs
}

$boundaryStall = $false
if (Test-LaunchReadyNow -StallDetected ([ref]$boundaryStall)) {
    Write-LaunchLog 'TBG READY detected at timeout boundary — treating as success'
    return
}

$visibleButtons = [UIAHelper]::LogVisibleLauncherButtons()
Write-LaunchLog "timeout: visible launcher buttons: $visibleButtons"
throw "launcher-auto-nav timed out after ${effectiveTimeout}s (see $logPath)"
