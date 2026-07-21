<#
.SYNOPSIS
Pre-flight cleanup for Bannerlord launches.
Closes stale crash reporter / assertion / safe mode dialogs and kills zombie processes.
.DESCRIPTION
Detects and closes stale crash reporter dialogs (class #32770, title "* _*" or containing "application faced a problem")
and safe mode dialogs (title containing "Safe Mode") that persist across game restarts and block new launches.
Also kills zombie TaleWorlds/Bannerlord processes.
Three detection points: before initial launch, before restarting, and whenever a crash is caught.
#>

Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes -ErrorAction SilentlyContinue

# Native helpers for crash dialog detection/close + EnumWindows for scanning all dialogs
$native = @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;

public static class PreflightCleanup
{
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("user32.dll")]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool DestroyWindow(IntPtr hWnd);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentProcessId();

    private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    public const uint WM_CLOSE = 0x0010;
    public const uint WM_COMMAND = 0x0111;
    public const int IDNO = 7;

    public static readonly string[] CrashTitleIndicators = new[]
    {
        "*_*",
        "* _*",
        "application faced a problem",
        "faced a problem",
        "crash",
        "assertion",
        "error",
        "problem"
    };

    public static readonly string[] SafeModeTitleIndicators = new[]
    {
        "Safe Mode",
        "safe mode",
        "SAFE MODE"
    };

    public static bool IsCrashDialogTitle(string title)
    {
        if (string.IsNullOrEmpty(title)) return false;
        foreach (var ind in CrashTitleIndicators)
        {
            if (title.IndexOf(ind, StringComparison.OrdinalIgnoreCase) >= 0)
                return true;
        }
        return false;
    }

    public static bool IsSafeModeDialogTitle(string title)
    {
        if (string.IsNullOrEmpty(title)) return false;
        foreach (var ind in SafeModeTitleIndicators)
        {
            if (title.IndexOf(ind, StringComparison.Ordinal) >= 0)
                return true;
        }
        return false;
    }

    public static bool IsStaleDialog(string title)
    {
        return IsCrashDialogTitle(title) || IsSafeModeDialogTitle(title);
    }

    public static int CloseAllStaleDialogs()
    {
        var closed = 0;
        var toClose = new List<IntPtr>();

        EnumWindows((hWnd, lParam) =>
        {
            if (!IsWindowVisible(hWnd)) return true;

            var classSb = new StringBuilder(256);
            GetClassName(hWnd, classSb, classSb.Capacity);
            var cls = classSb.ToString();

            bool isDialogClass = false;
            foreach (var tc in new[] { "#32770", "TApplication", "Dialog" })
            {
                if (cls.IndexOf(tc, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    isDialogClass = true;
                    break;
                }
            }
            if (!isDialogClass) return true;

            var titleSb = new StringBuilder(512);
            GetWindowText(hWnd, titleSb, titleSb.Capacity);
            var title = titleSb.ToString();

            if (IsStaleDialog(title))
            {
                toClose.Add(hWnd);
            }
            return true;
        }, IntPtr.Zero);

        foreach (var hWnd in toClose)
        {
            // Crash reporter dialogs ignore simple WM_CLOSE.
            // Use aggressive multi-method close: foreground + WM_COMMAND IDNO + SendMessage + DestroyWindow.
            SetForegroundWindow(hWnd);
            System.Threading.Thread.Sleep(100);
            SendMessage(hWnd, WM_COMMAND, (IntPtr)IDNO, IntPtr.Zero);
            SendMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
            DestroyWindow(hWnd);
            closed++;
        }
        return closed;
    }
}
'@

if (-not ('PreflightCleanup' -as [type])) {
    Add-Type -TypeDefinition $native -ErrorAction Stop
}

function CloseStaleDialogs {
    $closed = 0
    Write-Host "PREFLIGHT: Scanning for stale crash reporter / safe mode dialogs..."

    # Layer 1: UIA scan of all top-level windows
    $auto = [System.Windows.Automation.AutomationElement]::RootElement
    $cond = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElementIdentifiers]::ControlTypeProperty,
        [System.Windows.Automation.ControlType]::Window)
    $windows = $auto.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)

    foreach ($w in $windows) {
        try {
            $name = $w.Current.Name
            $class = $w.Current.ClassName
            $pid = $w.Current.ProcessId

            if (-not $name -and -not $class) { continue }

            $isStaleDialog = $false
            if ($class -eq "#32770" -or $class -like "Dialog*" -or $class -like "TApplication*") {
                if ([PreflightCleanup]::IsStaleDialog($name)) {
                    $isStaleDialog = $true
                }
            }

            if ($isStaleDialog) {
                Write-Host "PREFLIGHT: Found stale dialog - PID=$pid Class=$class Name='$name'"
                try {
                    $pattern = $w.GetCurrentPattern([System.Windows.Automation.WindowPatternIdentifiers]::Pattern)
                    if ($pattern) {
                        $pattern.Close()
                        Write-Host "PREFLIGHT: Closed via UIA WindowPattern.Close()"
                        $closed++
                        continue
                    }
                } catch {}

                try {
                    $hwnd = $w.Current.NativeWindowHandle
                    if ($hwnd -ne 0) {
                        # Aggressive close: crash reporters ignore simple WM_CLOSE
                        [PreflightCleanup]::SetForegroundWindow([IntPtr]$hwnd)
                        Start-Sleep -Milliseconds 100
                        [PreflightCleanup]::SendMessage([IntPtr]$hwnd, [PreflightCleanup]::WM_COMMAND, [IntPtr]7, [IntPtr]::Zero)
                        [PreflightCleanup]::SendMessage([IntPtr]$hwnd, [PreflightCleanup]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
                        [PreflightCleanup]::PostMessage([IntPtr]$hwnd, [PreflightCleanup]::WM_CLOSE, [IntPtr]::Zero, [IntPtr]::Zero)
                        [PreflightCleanup]::DestroyWindow([IntPtr]$hwnd)
                        Write-Host "PREFLIGHT: Aggressively closed hwnd=$hwnd"
                        $closed++
                    }
                } catch {}
            }
        } catch {}
    }

    # Layer 2: Native EnumWindows scan — catches dialogs UIA may miss
    try {
        $nativeClosed = [PreflightCleanup]::CloseAllStaleDialogs()
        if ($nativeClosed -gt 0) {
            Write-Host "PREFLIGHT: Native EnumWindows closed $nativeClosed additional stale dialog(s)"
            $closed += $nativeClosed
        }
    } catch {}

    Write-Host "PREFLIGHT: Closed $closed stale dialog(s)"
    return $closed
}

# Kill zombie Bannerlord/launcher processes
function CleanZombieProcesses {
    $killed = 0
    $processNames = @("TaleWorlds.MountAndBlade.Launcher", "Bannerlord")
    foreach ($name in $processNames) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "PREFLIGHT: Killing zombie $($_.ProcessName) PID=$($_.Id)"
            try { $_.Kill(); $_.WaitForExit(5000); $killed++ } catch {}
        }
    }
    Write-Host "PREFLIGHT: Killed $killed zombie process(es)"
    return $killed
}

# Main
Write-Host "=== PREFLIGHT CLEANUP START ===" -ForegroundColor Cyan
CleanZombieProcesses
CloseStaleDialogs
Write-Host "=== PREFLIGHT CLEANUP COMPLETE ===" -ForegroundColor Cyan