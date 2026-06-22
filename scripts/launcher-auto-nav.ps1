# Pre-main-menu UI automation: PLAY/CONTINUE, CAUTION Confirm, Safe Mode No (Sprint 006E).
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('play', 'continue')]
    [string]$LaunchIntent,

    [Parameter(Mandatory = $true)]
    [string]$BannerlordRoot,

    [int]$TimeoutSec = 300,
    [int]$PollMs = 180,
    [bool]$RespectUserForeground = $true,
    [ValidateSet('continue', 'play', 'any')]
    [string]$CertTarget = 'any'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
$lockPath = Get-NavLockPath -BannerlordRoot $BannerlordRoot
$lockMaxAgeMin = 10
$script:navLockHeld = $false

function Test-NavLockActive {
    if (-not (Test-Path -LiteralPath $lockPath)) { return $false }
    $age = (Get-Date) - (Get-Item -LiteralPath $lockPath).LastWriteTime
    if ($age.TotalMinutes -ge $lockMaxAgeMin) {
        Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        return $false
    }
    return $true
}

function Acquire-NavLock {
    if (Test-NavLockActive) {
        throw "launcher nav already running (lock $lockPath age < ${lockMaxAgeMin} min) — stop ForgeContinue/F7/Run-LauncherNavNow first"
    }
    $lockBody = "pid=$PID`nstarted=$(Get-Date -Format o)`nintent=$LaunchIntent"
    Set-Content -LiteralPath $lockPath -Value $lockBody -Encoding UTF8
    $script:navLockHeld = $true
}

function Release-NavLock {
    if (-not $script:navLockHeld) { return }
    Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    $script:navLockHeld = $false
}

Acquire-NavLock

$logPath = Get-LaunchLogPath -BannerlordRoot $BannerlordRoot
$launcherExeName = 'TaleWorlds.MountAndBlade.Launcher'
$gameExeName = 'Bannerlord'

function Write-LaunchLog {
    param([string]$Message)
    $line = "[{0}] launcher-auto: {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    Write-Host $line -ForegroundColor DarkGray
}

if (-not ('UIAHelper' -as [type])) {
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
    public static bool RespectUserForeground = true;

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
    private const int LauncherStableSecBeforeFallback = 1;
    private const int LauncherCoordClickThrottleSec = 1;
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

        if (!_launcherFocused && !RespectUserForeground)
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
                            if (!NameMatchesTargetLoose(name, target)) continue;
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

        foreach (var window in windows)
        {
            try
            {
                var title = window.Current.Name ?? string.Empty;
                var rect = window.Current.BoundingRectangle;
                var minW = title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0
                    ? 400
                    : LauncherMinCoordWindowWidth;
                var minH = title.IndexOf("Singleplayer PID", StringComparison.OrdinalIgnoreCase) >= 0
                    ? 300
                    : LauncherMinCoordWindowHeight;
                if (rect.Width < minW || rect.Height < minH)
                {
                    continue;
                }

                LogLine("AUDIT coord window pick: no PLAY/CONTINUE chrome window — falling back to " + DescribeScope(window));
                return window;
            }
            catch { }
        }

        LogLine("AUDIT coord window pick: no suitable launcher window for coords");
        return null;
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

            LogHitWindowAtPoint(x, y, label, intent);
            var visuallyObscured = !IsScreenPointOnLauncherHwnd(hwnd, x, y);
            if (visuallyObscured)
            {
                LogLine(string.Format(
                    "CLICK NOTE launcher coords — visual hit-test not {0} at ({1},{2}); proceeding with hwnd-target SendMessage (background-safe per doctrine)",
                    LauncherProcessName, x, y));
            }

            LogLine(string.Format(
                "CLICK \"{0}\" intent={1} attempt={2} method=coords at ({3},{4}) fractions=({5:F2},{6:F2}) bounds=({7:F0},{8:F0},{9:F0},{10:F0}) in {11} | foreground {12}",
                label, intent, _coordAttemptIndex + 1, x, y, xFraction, yFraction, bounds.X, bounds.Y, bounds.Width, bounds.Height, scopeDesc, DescribeForegroundWindow()));

            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, label))
            {
                Thread.Sleep(200);
                var method = visuallyObscured ? "hwnd SendMessage-background" : "hwnd SendMessage-first";
                LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method={1} at ({2},{3}) in {4}", intent, method, x, y, scopeDesc));
                if (!RespectUserForeground)
                {
                    TryFocusGameOrLauncher();
                }
                return true;
            }

            var savedUserForeground = GetForegroundWindow();
            ForceForegroundWindow(hwnd);
            Thread.Sleep(100);
            var clicked = TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, label);
            if (!clicked)
            {
                SetCursorPos(x, y);
                Thread.Sleep(40);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                clicked = true;
            }
            if (clicked)
            {
                LogLine(string.Format("CLICK OK \"launcher PLAY/CONTINUE\" intent={0} method=brief-focus+restore at ({1},{2}) in {3}", intent, x, y, scopeDesc));
            }
            if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
            {
                ForceForegroundWindow(savedUserForeground);
                LogLine("FOCUS restored user foreground after brief launcher click");
            }
            return clicked;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL launcher coords: " + ex.Message);
            return false;
        }
    }

    private static bool IsHwndOwnedByLauncher(IntPtr hwnd)
    {
        if (hwnd == IntPtr.Zero) return false;
        try
        {
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            return GetLauncherProcessIds().Contains((int)pid);
        }
        catch
        {
            return false;
        }
    }

    private static bool IsScreenPointOnLauncherHwnd(IntPtr launcherHwnd, int screenX, int screenY)
    {
        if (launcherHwnd == IntPtr.Zero) return false;

        try
        {
            var point = new POINT { X = screenX, Y = screenY };
            var hit = WindowFromPoint(point);
            if (hit == IntPtr.Zero) return false;

            if (hit == launcherHwnd) return true;

            var root = GetAncestor(hit, GA_ROOT);
            if (root == launcherHwnd) return true;

            return IsHwndOwnedByLauncher(hit);
        }
        catch
        {
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
                LogLine(string.Format("AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd=none launcher_ok=false", intent, label, screenX, screenY));
                return;
            }

            var sb = new StringBuilder(256);
            GetWindowText(hit, sb, sb.Capacity);
            uint hitPid;
            GetWindowThreadProcessId(hit, out hitPid);
            var procName = "?";
            try { procName = Process.GetProcessById((int)hitPid).ProcessName; } catch { }
            var launcherOk = string.Equals(procName, LauncherProcessName, StringComparison.OrdinalIgnoreCase);
            LogLine(string.Format(
                "AUDIT hit-test intent={0} label={1} at ({2},{3}) hwnd={4} title=\"{5}\" process={6} pid={7} launcher_ok={8}",
                intent, label, screenX, screenY, hit.ToInt64(), sb.ToString(), procName, hitPid, launcherOk ? "true" : "false"));
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

    private static string NormalizeButtonName(string elementName)
    {
        if (string.IsNullOrWhiteSpace(elementName)) return string.Empty;
        return elementName.Trim().TrimStart('&');
    }

    private static bool NameMatchesTargetLoose(string elementName, string targetName)
    {
        if (string.IsNullOrWhiteSpace(elementName) || string.IsNullOrWhiteSpace(targetName)) return false;
        if (NameMatchesTarget(elementName, targetName)) return true;

        var normalized = NormalizeButtonName(elementName);
        var target = NormalizeButtonName(targetName);
        if (string.Equals(normalized, target, StringComparison.OrdinalIgnoreCase)) return true;

        if (target.Equals("CONTINUE", StringComparison.OrdinalIgnoreCase))
        {
            return normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0
                && normalized.IndexOf("Play", StringComparison.OrdinalIgnoreCase) < 0;
        }

        if (target.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
        {
            return normalized.Equals("Play", StringComparison.OrdinalIgnoreCase)
                || normalized.Equals("PLAY", StringComparison.OrdinalIgnoreCase);
        }

        return false;
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
                        if (!NameMatchesTargetLoose(name, target)) continue;
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

        if (!IsHwndOwnedByLauncher(hwnd))
        {
            LogLine("CLICK SKIP launcher hwnd — target hwnd is not owned by " + LauncherProcessName + " (" + scopeDesc + ")");
            return false;
        }

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

    private static DateTime _lastLauncherRestoreUtc = DateTime.MinValue;

    public static int TryRestoreLauncherWindows()
    {
        var now = DateTime.UtcNow;
        if ((now - _lastLauncherRestoreUtc).TotalSeconds < 2) return 0;
        _lastLauncherRestoreUtc = now;

        var restored = 0;
        foreach (var pid in GetLauncherProcessIds())
        {
            EnumWindows((hwnd, param) =>
            {
                try
                {
                    uint windowPid;
                    GetWindowThreadProcessId(hwnd, out windowPid);
                    if ((int)windowPid != pid) return true;

                    var sb = new StringBuilder(256);
                    GetWindowText(hwnd, sb, sb.Capacity);
                    if (sb.Length == 0) return true;

                    if (!IsIconic(hwnd)) return true;

                    ShowWindow(hwnd, SW_RESTORE);
                    restored++;
                }
                catch { }
                return true;
            }, IntPtr.Zero);
        }

        if (restored > 0)
        {
            Thread.Sleep(400);
        }

        return restored;
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

        if (results.Count == 0)
        {
            TryRestoreLauncherWindows();
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
        }

        return results;
    }

    private static void CollectLauncherWindowsFromPid(int pid, List<AutomationElement> results)
    {
        EnumWindows((hwnd, param) =>
        {
            try
            {
                uint windowPid;
                GetWindowThreadProcessId(hwnd, out windowPid);
                if ((int)windowPid != pid) return true;
                if (!IsWindowVisible(hwnd)) return true;
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

    public static bool TryFocusGameOrLauncher()
    {
        var game = FindGameMainWindowRoot();
        if (game != null)
        {
            try
            {
                var hwnd = new IntPtr(game.Current.NativeWindowHandle);
                if (hwnd != IntPtr.Zero)
                {
                    ForceForegroundWindow(hwnd);
                    LogLine("FOCUS refocus game/launcher after click target=game | " + DescribeForegroundWindow());
                    return true;
                }
            }
            catch { }
        }

        var launcher = FindLauncherRoot();
        if (launcher != null)
        {
            try
            {
                var hwnd = new IntPtr(launcher.Current.NativeWindowHandle);
                if (hwnd != IntPtr.Zero)
                {
                    ForceForegroundWindow(hwnd);
                    LogLine("FOCUS refocus game/launcher after click target=launcher | " + DescribeForegroundWindow());
                    return true;
                }
            }
            catch { }
        }

        LogLine("FOCUS refocus game/launcher after click — no game or launcher hwnd");
        return false;
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

    public static bool HasSafeModeDialog()
    {
        return FindWindowRootByTitle("Safe Mode") != null;
    }

    public static bool IsLauncherPlayContinueVisible()
    {
        var names = new List<string>();
        var windows = FindAllLauncherWindowRoots();
        if (windows.Count == 0) return false;

        foreach (var window in windows)
        {
            CollectButtonNames(window, names);
            CollectInteractiveNames(window, names);
        }

        foreach (var name in names)
        {
            var normalized = NormalizeButtonName(name);
            if (normalized.IndexOf("Continue", StringComparison.OrdinalIgnoreCase) >= 0
                && normalized.IndexOf("Custom", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return true;
            }

            if (normalized.Equals("Play", StringComparison.OrdinalIgnoreCase)
                || normalized.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
        }

        return false;
    }

    public static bool ClickSafeModeNo()
    {
        var safeModeRoot = FindWindowRootByTitle("Safe Mode");
        if (safeModeRoot == null) return false;

        FocusScope(safeModeRoot, "Safe Mode");
        foreach (var name in new[] { "No", "&No", "NO" })
        {
            if (TryClickButtonInScope(safeModeRoot, name, false, "Safe Mode No"))
            {
                return true;
            }
        }

        var noButton = FindNoButtonInScope(safeModeRoot);
        if (noButton != null)
        {
            var scopeDesc = DescribeScope(safeModeRoot);
            if (InvokeElement(noButton, "Safe Mode No", NormalizeButtonName(noButton.Current.Name), scopeDesc))
            {
                return true;
            }
        }

        return TryClickSafeModeNoByCoords(safeModeRoot);
    }

    private static AutomationElement FindNoButtonInScope(AutomationElement scope)
    {
        if (scope == null) return null;

        var controlTypes = new[] { ControlType.Button, ControlType.Custom, ControlType.Hyperlink };
        foreach (var controlType in controlTypes)
        {
            try
            {
                var typeCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, controlType);
                var elements = scope.FindAll(TreeScope.Descendants, typeCondition);
                foreach (AutomationElement element in elements)
                {
                    var normalized = NormalizeButtonName(element.Current.Name ?? string.Empty);
                    if (normalized.Equals("No", StringComparison.OrdinalIgnoreCase))
                    {
                        return element;
                    }
                }
            }
            catch { }
        }

        return null;
    }

    private static bool TryClickSafeModeNoByCoords(AutomationElement safeModeRoot)
    {
        if (safeModeRoot == null) return false;

        try
        {
            var hwnd = new IntPtr(safeModeRoot.Current.NativeWindowHandle);
            if (hwnd == IntPtr.Zero) return false;

            var bounds = safeModeRoot.Current.BoundingRectangle;
            if (bounds.Width <= 0 || bounds.Height <= 0) return false;

            var x = (int)(bounds.X + bounds.Width * 0.32);
            var y = (int)(bounds.Y + bounds.Height * 0.72);
            var scopeDesc = DescribeScope(safeModeRoot);

            LogLine(string.Format("CLICK \"Safe Mode No\" method=coords at ({0},{1}) in {2}", x, y, scopeDesc));
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Safe Mode No"))
            {
                LogLine("CLICK OK \"Safe Mode No\" method=hwnd-only");
                return true;
            }
            var savedUserForeground = GetForegroundWindow();
            ForceForegroundWindow(hwnd);
            Thread.Sleep(80);
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Safe Mode No"))
            {
                if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
                {
                    ForceForegroundWindow(savedUserForeground);
                    LogLine("FOCUS restored user foreground after Safe Mode click");
                }
                LogLine("CLICK OK \"Safe Mode No\" method=brief-focus+restore");
                return true;
            }
            SetCursorPos(x, y);
            Thread.Sleep(40);
            mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
            mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
            if (savedUserForeground != IntPtr.Zero && savedUserForeground != hwnd)
            {
                ForceForegroundWindow(savedUserForeground);
                LogLine("FOCUS restored user foreground after Safe Mode click");
            }
            return true;
        }
        catch (Exception ex)
        {
            LogLine("CLICK FAIL Safe Mode coords: " + ex.Message);
            return false;
        }
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

    public static bool ClickModuleMismatchYesByGameCoords()
    {
        var game = FindGameMainWindowRoot();
        if (game == null) return false;

        FocusScope(game, "Module Mismatch coord fallback");
        return TryClickModuleMismatchYesByCoordinates(game);
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
                            if (!NameMatchesTargetLoose(name, target)) continue;
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
            LogLine(string.Format(
                "CLICK \"Module Mismatch Yes\" method=coords at ({0},{1}) fractions=({2:F2},{3:F2}) in {4}",
                x, y, xFraction, yFraction, scopeDesc));
            if (TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Module Mismatch Yes"))
            {
                LogLine("CLICK OK \"Module Mismatch Yes\" method=hwnd-only");
                _moduleMismatchCoordAttemptIndex++;
                return true;
            }
            if (!RespectUserForeground)
            {
                ForceForegroundWindow(hwnd);
                Thread.Sleep(250);
                TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, "Module Mismatch Yes");
                SetCursorPos(x, y);
                Thread.Sleep(80);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                _moduleMismatchCoordAttemptIndex++;
                return true;
            }
            return false;
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

        if (RespectUserForeground)
        {
            LogLine(string.Format("FOCUS skipped ({0}) — RespectUserForeground", reason));
            return;
        }

        try
        {
            var hwnd = new IntPtr(scope.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero)
            {
                SetForegroundWindow(hwnd);
                Thread.Sleep(60);
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
            var hwnd = new IntPtr(element.Current.NativeWindowHandle);
            if (hwnd != IntPtr.Zero && TryClickLauncherHwndAtScreenPoint(hwnd, x, y, scopeDesc, actionLabel))
            {
                LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=hwnd-only in {2} | foreground after {3}", actionLabel, buttonName, scopeDesc, DescribeForegroundWindow()));
                if (!RespectUserForeground)
                {
                    TryFocusGameOrLauncher();
                }
                return true;
            }
            if (!RespectUserForeground)
            {
                SetCursorPos(x, y);
                Thread.Sleep(60);
                mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
                mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
                LogLine(string.Format("CLICK OK \"{0}\" button=\"{1}\" method=mouse at ({2},{3}) in {4} | foreground after {5}", actionLabel, buttonName, x, y, scopeDesc, DescribeForegroundWindow()));
                TryFocusGameOrLauncher();
                return true;
            }
            LogLine(string.Format("CLICK FAIL \"{0}\" — SendMessage failed and RespectUserForeground=true", actionLabel));
            return false;
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
    private static extern bool IsIconic(IntPtr hWnd);

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
    try {
        Add-Type -TypeDefinition $uiaHelperSource -ReferencedAssemblies @(
            'UIAutomationClient',
            'UIAutomationTypes',
            'System.Windows.Forms',
            'WindowsBase'
        ) -ErrorAction Stop
    } catch {
        if (-not ('UIAHelper' -as [type])) { throw }
    }
}

[UIAHelper]::Log = [Action[string]]{ param($m) Write-LaunchLog "UIA: $m" }
[UIAHelper]::RespectUserForeground = $RespectUserForeground

Write-LaunchLog "session pid=$PID log=$logPath intent=$LaunchIntent timeout=${TimeoutSec}s poll=${PollMs}ms respectUserForeground=$RespectUserForeground"
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
$playEscalated = $false
$continueEscalated = $false
$script:automationClickedPlayContinue = $false
$script:launchPathAdopted = $false
$script:adoptedLaunchPath = $null
$script:adoptedSelectedBy = $null
$script:contaminatedLaunchPath = $false
$script:contaminatedLaunchReason = $null
$startTime = Get-Date
$effectiveTimeout = $TimeoutSec
$deadline = $startTime.AddSeconds($effectiveTimeout)
$loadStallSec = 180
$phase1LogPath = Get-Phase1LogPath -BannerlordRoot $BannerlordRoot
$statusJsonPath = Get-StatusJsonPath -BannerlordRoot $BannerlordRoot
$crashContextPath = Get-CrashContextJsonPath -BannerlordRoot $BannerlordRoot
$lastHeartbeat = Get-Date
$heartbeatSec = 30
$preHandoffSuppressedLogged = $false
$preHandoffMismatchSuppressedLogged = $false
$handoffStarted = $false
$lastRefocusUtc = $null
$gameSpawnLogged = $false
$mismatchCoordAttemptMain = 0
$phase1ReadyBaseline = @{}
$focusHelperPath = Join-Path $PSScriptRoot 'focus-bannerlord-window.ps1'
if (Test-Path -LiteralPath $phase1LogPath) {
    Get-Content -LiteralPath $phase1LogPath -Tail 40 -ErrorAction SilentlyContinue |
        Where-Object { Test-Phase1ReadyLine -Line $_ } |
        ForEach-Object { $phase1ReadyBaseline[$_] = $true }
}

function Invoke-BannerlordFocusHelper {
    param([string]$Context = 'post-handoff')

    if (-not (Test-Path -LiteralPath $focusHelperPath)) {
        Write-LaunchLog 'post-handoff: refocus skipped; focus helper missing'
        return $false
    }

    Write-LaunchLog "post-handoff: refocus game/launcher attempted ($Context)"
    try {
        $focused = & $focusHelperPath
        if ($focused) {
            Write-LaunchLog "post-handoff: refocus game/launcher succeeded ($Context)"
        }
        return [bool]$focused
    } catch {
        Write-LaunchLog "post-handoff: refocus game/launcher failed ($Context): $($_.Exception.Message)"
        return $false
    }
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
        if ($LaunchIntent -eq 'continue' -and -not (Test-PostHandoffReadyAllowed)) {
            if (-not $script:preHandoffMismatchSuppressedLogged) {
                Write-LaunchLog 'pre-handoff ready suppressed — Module Mismatch inquiry not cleared'
                $script:preHandoffMismatchSuppressedLogged = $true
            }
            return $false
        }
        return $true
    }

    return $false
}

function Get-LaunchNavProcessDetection {
    return Get-BannerlordProcessDetection -BannerlordRoot $BannerlordRoot `
        -Phase1Path $phase1LogPath -StatusPath $statusJsonPath -CrashContextPath $crashContextPath
}

function Test-GameProcessRunning {
    return [bool](Get-LaunchNavProcessDetection).gameProcessRunning
}

function Get-LaunchNavEnvironmentLine {
    $base = [UIAHelper]::DescribeEnvironment()
    $det = Get-LaunchNavProcessDetection
    if ($det.gameProcessRunning) {
        $tag = switch ([string]$det.gameAliveConfidence) {
            'definite' { 'yes' }
            'launcher_hosted' { 'hosted' }
            'phase1_active' { 'phase1' }
            'process_detection_uncertain' { 'uncertain' }
            default { 'yes' }
        }
        return ($base -replace 'game=(yes|no)', "game=$tag")
    }
    return $base
}

function Test-F7ContinueCertStrict {
    return ($CertTarget -eq 'continue')
}

function Write-ContaminatedLaunchPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Reason,
        [string]$SelectedBy = 'unknown'
    )

    $script:contaminatedLaunchPath = $true
    $script:contaminatedLaunchReason = [string]$Reason
    Write-LaunchLog "LAUNCH_STATE=contaminated_launch_path reason=$Reason certTarget=$CertTarget selectedBy=$SelectedBy"
}

function Invoke-AdoptLaunchPath {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('play', 'continue')]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [ValidateSet('user', 'automation', 'unknown')]
        [string]$SelectedBy
    )

    if ($script:launchPathAdopted) { return }

    if (Test-F7ContinueCertStrict) {
        if ($Path -eq 'play') {
            Write-ContaminatedLaunchPath -Reason 'user_or_observed_play' -SelectedBy $SelectedBy
            return
        }
        if ($SelectedBy -eq 'user') {
            Write-ContaminatedLaunchPath -Reason 'user_handoff' -SelectedBy $SelectedBy
            return
        }
    }

    $script:launchPathAdopted = $true
    $script:adoptedLaunchPath = $Path
    $script:adoptedSelectedBy = $SelectedBy
    $script:clickedPlayContinue = $true
    $script:playClickUtc = Get-Date
    if ($Path -eq 'continue') {
        Write-LaunchLog "LAUNCH_STATE=continue_clicked selectedBy=$SelectedBy"
    } else {
        Write-LaunchLog "LAUNCH_STATE=play_clicked selectedBy=$SelectedBy"
    }
}

function Test-UserLaunchPathAdopted {
    if (Test-F7ContinueCertStrict) {
        if ($script:contaminatedLaunchPath) { return $false }
        if ((Test-GameProcessRunning) -and -not $script:automationClickedPlayContinue) {
            Write-ContaminatedLaunchPath -Reason 'game_running_before_automation_continue' -SelectedBy 'user'
        }
        return $false
    }

    if ($script:launchPathAdopted -or $script:automationClickedPlayContinue) {
        return $false
    }

    $gameRunning = Test-GameProcessRunning
    $loading = [UIAHelper]::HasLauncherLoadingSurface()
    $launcherGone = -not [UIAHelper]::HasLauncherRoot()
    $buttonsVisible = [UIAHelper]::IsLauncherPlayContinueVisible()

    if (-not ($gameRunning -or $loading -or ($launcherGone -and -not $buttonsVisible))) {
        return $false
    }

    if ($LaunchIntent -eq 'continue' -and $gameRunning -and -not $script:automationClickedPlayContinue) {
        if (-not [UIAHelper]::IsLauncherPlayContinueVisible() -and -not [UIAHelper]::HasLauncherLoadingSurface()) {
            Invoke-AdoptLaunchPath -Path 'play' -SelectedBy 'user'
            return $true
        }
        Invoke-AdoptLaunchPath -Path 'continue' -SelectedBy 'user'
        return $true
    }

    if ($LaunchIntent -eq 'play' -and ($gameRunning -or $loading)) {
        Invoke-AdoptLaunchPath -Path 'play' -SelectedBy 'user'
        return $true
    }

    if ($LaunchIntent -eq 'continue' -and ($loading -or $launcherGone)) {
        Invoke-AdoptLaunchPath -Path 'continue' -SelectedBy 'user'
        return $true
    }

    return $false
}

function Invoke-Handoff {
    param([string]$Reason)
    $script:handoffStarted = $true
    Write-LaunchLog "handoff: $Reason"
    Write-LaunchLog 'LAUNCH_STATE=handoff'
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
        if (Test-Phase1ReadyLine -Line $line) {
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

function Test-Phase1ModuleMismatchPending {
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 60 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    $queued = $false
    $confirmed = $false
    foreach ($line in $tail) {
        if ($line -match 'Module Mismatch inquiry queued') {
            $queued = $true
        }
        if ($line -match 'Module Mismatch auto-Yes confirmed \(inquiry cleared\)') {
            $confirmed = $true
        }
    }

    return $queued -and -not $confirmed
}

function Test-Phase1ModuleMismatchCleared {
    if (-not (Test-Path -LiteralPath $phase1LogPath)) {
        return $false
    }

    $tail = Get-Content -LiteralPath $phase1LogPath -Tail 60 -ErrorAction SilentlyContinue
    if (-not $tail) {
        return $false
    }

    foreach ($line in $tail) {
        if ($line -match 'Module Mismatch auto-Yes confirmed \(inquiry cleared\)') {
            return $true
        }
    }

    return $false
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

    if (Test-Phase1ModuleMismatchPending) {
        return $false
    }

    return $true
}

function Invoke-ModuleMismatchCoordFallback {
    param([int]$AttemptNumber = 0)

    if (-not (Test-GameProcessRunning)) {
        return $false
    }

    if (-not [UIAHelper]::ClickModuleMismatchYesByGameCoords()) {
        return $false
    }

    Write-LaunchLog "post-handoff: Module Mismatch coord-click attempt $AttemptNumber"
    return $true
}

function Wait-PostHandoffWatchdog {
    param([string]$Reason)

    Write-LaunchLog "post-handoff watch started ($Reason)"
    $watchStart = Get-Date
    $gameLoadingSince = $null
    $stallDetected = $false
    $mismatchCoordAttempt = 0
    $mismatchWatchSec = 30
    $lastPostHandoffRefocusUtc = $null

    while (((Get-Date) - $watchStart).TotalSeconds -lt $loadStallSec) {
        $nowPostHandoffRefocusUtc = [DateTime]::UtcNow
        if (-not $lastPostHandoffRefocusUtc -or ($nowPostHandoffRefocusUtc - $lastPostHandoffRefocusUtc).TotalSeconds -ge 2) {
            if (-not $RespectUserForeground -and ((Test-GameProcessRunning) -or [UIAHelper]::HasLauncherRoot())) {
                Invoke-BannerlordFocusHelper -Context 'watchdog' | Out-Null
            }
            $lastPostHandoffRefocusUtc = $nowPostHandoffRefocusUtc
        }

        if (-not (Test-GameProcessRunning)) {
            Write-LaunchLog 'post-handoff: Bannerlord exited'
            return
        }

        if (Invoke-ModuleMismatchClick) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }

        if ($LaunchIntent -eq 'continue' -and
            ((Get-Date) - $watchStart).TotalSeconds -lt $mismatchWatchSec -and
            (Test-Phase1ModuleMismatchPending)) {
            $mismatchCoordAttempt++
            if (Invoke-ModuleMismatchCoordFallback -AttemptNumber $mismatchCoordAttempt) {
                Start-Sleep -Milliseconds $PollMs
                continue
            }
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
    param(
        [int]$WaitSec = 4,
        [string]$Intent = 'continue'
    )

    if ($Intent -eq 'play' -or $Intent -eq 'continue') {
        $WaitSec = [Math]::Max($WaitSec, 30)
    }

    $deadline = (Get-Date).AddSeconds($WaitSec)
    while ((Get-Date) -lt $deadline) {
        $det = Get-LaunchNavProcessDetection
        if ($det.gameProcessRunning) { return $true }

        if ($Intent -eq 'continue') {
            if ($det.gameAliveConfidence -eq 'launcher_hosted') { return $true }
            if ([UIAHelper]::HasLauncherLoadingSurface()) { return $true }
            if (-not [UIAHelper]::HasLauncherRoot()) { return $true }
        }

        if ($Intent -eq 'play') {
            if ([UIAHelper]::HasLauncherLoadingSurface()) { return $true }
            if (-not [UIAHelper]::HasLauncherRoot()) { return $true }
            if (-not [UIAHelper]::HasSafeModeDialog() -and -not [UIAHelper]::IsLauncherPlayContinueVisible()) {
                return $true
            }
        }

        Start-Sleep -Milliseconds 150
    }
    return $false
}

if ($LaunchIntent -eq 'continue') {
    $targetButtonNames = @('CONTINUE', 'Continue', 'Continue Campaign', 'Resume', 'Resume Game')
} else {
    $targetButtonNames = @('PLAY', 'Play', 'Play Game')
}

try {
while ((Get-Date) -lt $deadline) {
    if ($script:contaminatedLaunchPath -and (Test-F7ContinueCertStrict)) {
        Write-LaunchLog 'LAUNCH_STATE=fail_contaminated_launch_path'
        return
    }

    if (((Get-Date) - $lastHeartbeat).TotalSeconds -ge $heartbeatSec) {
        $envDesc = Get-LaunchNavEnvironmentLine
        Write-LaunchLog $envDesc
        if ($envDesc -match 'launcher=no' -and (Get-Process -Name $launcherExeName -ErrorAction SilentlyContinue)) {
            Write-LaunchLog 'LAUNCH_STATE=waiting_launcher_hwnd'
        }
        $lastHeartbeat = Get-Date
    }

    if ((Test-GameProcessRunning) -and -not $script:gameSpawnLogged) {
        Write-LaunchLog 'LAUNCH_STATE=game_spawned'
        $script:gameSpawnLogged = $true
        if (Test-Path -LiteralPath $focusHelperPath) {
            try {
                $raised = & $focusHelperPath
                if ($raised) {
                    Write-LaunchLog 'raised Bannerlord window on game spawn'
                }
            } catch { }
        }
    }

    if ($LaunchIntent -eq 'play' -and $clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 15 -and -not $script:playEscalated -and -not $script:launchPathAdopted) {
            Write-LaunchLog 'LAUNCH_STATE=play_escalate — hwnd-only PLAY did not spawn Bannerlord.exe; retry with foreground clicks'
            $script:playEscalated = $true
            $clickedPlayContinue = $false
            $script:playClickUtc = $null
            $RespectUserForeground = $false
            [UIAHelper]::RespectUserForeground = $false
            [UIAHelper]::ResetLauncherClickRetryState()
        }
    }

    if ($LaunchIntent -eq 'continue' -and $clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 15 -and -not $script:continueEscalated -and -not $script:launchPathAdopted) {
            Write-LaunchLog 'LAUNCH_STATE=continue_escalate — hwnd-only CONTINUE did not spawn Bannerlord.exe; retry with foreground clicks'
            $script:continueEscalated = $true
            $clickedPlayContinue = $false
            $script:playClickUtc = $null
            $RespectUserForeground = $false
            [UIAHelper]::RespectUserForeground = $false
            [UIAHelper]::ResetLauncherClickRetryState()
        }
    }

    if ($clickedPlayContinue -and -not (Test-GameProcessRunning) -and $script:playClickUtc -and -not $script:launchPathAdopted) {
        $sinceClick = ((Get-Date) - $script:playClickUtc).TotalSeconds
        if ($sinceClick -ge 12 -and ([UIAHelper]::IsLauncherPlayContinueVisible() -or [UIAHelper]::HasSafeModeDialog())) {
            $retryLabel = if ($LaunchIntent -eq 'continue') { 'continue_retry' } else { 'play_retry' }
            Write-LaunchLog "LAUNCH_STATE=$retryLabel — game never spawned; resetting clickedPlayContinue"
            $clickedPlayContinue = $false
            $script:playClickUtc = $null
            [UIAHelper]::ResetLauncherClickRetryState()
        }
    }

    if ($clickedPlayContinue) {
        Extend-DeadlineAfterPlayClick
    }

    if ($clickedPlayContinue -and -not $handoffStarted -and -not $RespectUserForeground) {
        $refocusIntervalSec = if ([UIAHelper]::HasLauncherLoadingSurface()) { 5 } else { 2 }
        $nowRefocusUtc = [DateTime]::UtcNow
        if (-not $lastRefocusUtc -or ($nowRefocusUtc - $lastRefocusUtc).TotalSeconds -ge $refocusIntervalSec) {
            [UIAHelper]::TryFocusGameOrLauncher() | Out-Null
            $lastRefocusUtc = $nowRefocusUtc
        }
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

    if ($LaunchIntent -eq 'continue' -and (Test-GameProcessRunning) -and (Test-Phase1ModuleMismatchPending)) {
        $mismatchCoordAttemptMain++
        if (Invoke-ModuleMismatchCoordFallback -AttemptNumber $mismatchCoordAttemptMain) {
            Start-Sleep -Milliseconds $PollMs
            continue
        }
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

    if ($clickedSafeMode -and -not $clickedPlayContinue) {
        [UIAHelper]::ResetLauncherClickRetryState()
    }

    if ([UIAHelper]::ClickSafeModeNo()) {
        if (-not $clickedSafeMode) {
            Write-LaunchLog 'clicked Safe Mode No'
            Write-LaunchLog 'LAUNCH_STATE=safe_mode_no_clicked'
            Write-LaunchLog 'Safe Mode: No selected — prior session unexpected shutdown; crash on last run suspected (full mod load retained)'
            $clickedSafeMode = $true
            Extend-DeadlineForSlowPath
            if (-not $RespectUserForeground) {
                Invoke-BannerlordFocusHelper -Context 'after-safe-mode-no' | Out-Null
            }
        }
    } elseif ([UIAHelper]::HasSafeModeDialog()) {
        Start-Sleep -Milliseconds 120
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

    if (Test-UserLaunchPathAdopted) {
        if (Test-GameProcessRunning) {
            Invoke-Handoff 'user launch path adopted — game running'
            return
        }
        if ([UIAHelper]::HasLauncherLoadingSurface() -or -not [UIAHelper]::HasLauncherRoot()) {
            Invoke-Handoff 'user launch path adopted — loading or launcher gone'
            return
        }
    }

    if (-not $clickedPlayContinue) {
        $matchedName = [UIAHelper]::ClickButtonByNameInLauncher($targetButtonNames)
        if ($matchedName) {
            $displayName = if ($LaunchIntent -eq 'continue') { 'CONTINUE' } else { 'PLAY' }
            if (Test-LaunchClickVerified -WaitSec 4 -Intent $LaunchIntent) {
                $script:automationClickedPlayContinue = $true
                Write-LaunchLog "clicked $displayName ($matchedName) — launch verified (game or launcher handoff)"
                if ($LaunchIntent -eq 'continue') {
                    Write-LaunchLog 'LAUNCH_STATE=continue_clicked selectedBy=automation'
                } else {
                    Write-LaunchLog 'LAUNCH_STATE=play_clicked selectedBy=automation'
                }
                $clickedPlayContinue = $true
                $script:playClickUtc = Get-Date
                Extend-DeadlineAfterPlayClick
                if (-not $RespectUserForeground) {
                    Invoke-BannerlordFocusHelper -Context 'after-play-continue-click' | Out-Null
                }
            } else {
                Write-LaunchLog "click $displayName ($matchedName) NOT verified — PLAY/CONTINUE still on screen; will retry"
                [UIAHelper]::ResetLauncherClickRetryState()
            }
        }
    }

    $loopPollMs = if ([UIAHelper]::HasSafeModeDialog() -or (-not $clickedPlayContinue -and [UIAHelper]::IsLauncherPlayContinueVisible())) {
        120
    } else {
        $PollMs
    }
    Start-Sleep -Milliseconds $loopPollMs
}

$boundaryStall = $false
if (Test-LaunchReadyNow -StallDetected ([ref]$boundaryStall)) {
    Write-LaunchLog 'TBG READY detected at timeout boundary — treating as success'
    return
}

$visibleButtons = [UIAHelper]::LogVisibleLauncherButtons()
Write-LaunchLog "timeout: visible launcher buttons: $visibleButtons"
throw "launcher-auto-nav timed out after ${effectiveTimeout}s (see $logPath)"
} finally {
    Release-NavLock
}
