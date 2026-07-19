<#
.SYNOPSIS
Brings Bannerlord game window to foreground.
Required before any keyboard/mouse input to the game.
#>
param([switch]$PassThru)

Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;using System.Text;
public class FWin {
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWinProc lp, IntPtr lParam);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h, StringBuilder t, int m);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    delegate bool EnumWinProc(IntPtr hWnd, IntPtr lParam);
    public static IntPtr Find() {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, lp) => {
            var s = new StringBuilder(256);
            GetWindowText(h, s, 256);
            if (s.ToString().StartsWith("Mount and Blade II Bannerlord")) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public static bool Focus(IntPtr h) { return h != IntPtr.Zero && SetForegroundWindow(h); }
    public static IntPtr Foreground() { return GetForegroundWindow(); }
}
"@

$hwnd = [FWin]::Find()
if ($hwnd -eq [IntPtr]::Zero) {
    Write-Host "FAIL: Bannerlord window not found" -ForegroundColor Red
    if ($PassThru) { Write-Output ([pscustomobject]@{ focus=$false; error='window not found' }) }
    exit 1
}
$focused = [FWin]::Focus($hwnd)
Start-Sleep -Milliseconds 800
$confirmed = [FWin]::Foreground() -eq $hwnd
Write-Host "Focus: $focused Confirmed: $confirmed HWND: $hwnd" -ForegroundColor $(if($confirmed){'Green'}else{'Yellow'})
if ($PassThru) { Write-Output ([pscustomobject]@{ focus=$focused; confirmed=$confirmed; hwnd=[string]$hwnd; timestamp=[DateTime]::UtcNow.ToString('o') }) }
exit $(if($confirmed){0}else{2})
