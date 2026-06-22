# Refocus Bannerlord game window or launcher after automation steals foreground to terminal.
param()

$ErrorActionPreference = 'Stop'

$focusSource = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;

public static class BannerlordFocus
{
    private const string GameProcessName = "Bannerlord";
    private const string LauncherProcessName = "TaleWorlds.MountAndBlade.Launcher";
    private const int SW_RESTORE = 9;

    public static bool TryFocusGameOrLauncher()
    {
        if (TryFocusProcess(GameProcessName))
        {
            return true;
        }

        return TryFocusProcess(LauncherProcessName);
    }

    private static bool TryFocusProcess(string processName)
    {
        foreach (var process in Process.GetProcessesByName(processName))
        {
            try
            {
                var hwnd = process.MainWindowHandle;
                if (hwnd == IntPtr.Zero) continue;
                ForceForegroundWindow(hwnd);
                return true;
            }
            catch { }
        }

        return false;
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

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

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
}
'@

if (-not ([System.Management.Automation.PSTypeName]'BannerlordFocus').Type) {
    Add-Type -TypeDefinition $focusSource -ErrorAction Stop
}

return [BannerlordFocus]::TryFocusGameOrLauncher()
