# Minimize Cursor/VS Code windows so launcher UIA can obtain hwnd during agent-driven F7 runs.
param()

$ErrorActionPreference = 'SilentlyContinue'

$minimizeSource = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public static class IdeMinimize
{
    private const int SW_MINIMIZE = 6;

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr hWnd);

    public static int MinimizeProcesses(params string[] names)
    {
        var count = 0;
        foreach (var name in names)
        {
            foreach (var proc in Process.GetProcessesByName(name))
            {
                try
                {
                    var hwnd = proc.MainWindowHandle;
                    if (hwnd == IntPtr.Zero || IsIconic(hwnd)) continue;
                    if (ShowWindow(hwnd, SW_MINIMIZE))
                    {
                        count++;
                    }
                }
                catch { }
            }
        }
        return count;
    }
}
'@

try {
    Add-Type -TypeDefinition $minimizeSource -ErrorAction Stop
} catch {
    return 0
}

$minimized = [IdeMinimize]::MinimizeProcesses('Cursor', 'Code', 'WindowsTerminal', 'Notepad', 'chrome')
if ($minimized -gt 0) {
    Start-Sleep -Milliseconds 400
}
return $minimized
