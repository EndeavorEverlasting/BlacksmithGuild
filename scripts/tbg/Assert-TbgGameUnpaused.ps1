<#
.SYNOPSIS
Ensures the Bannerlord game is unpaused before any external script sends input.
Reads the runtime regent, detects pause/menu state, sends ESC if needed, verifies dismissal.
Returns the post-dismissal regent state.
#>
param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [int]$MaxDismissAttempts = 3,
    [int]$VerifyDelayMs = 1500,
    [switch]$PassThru
)

$ErrorActionPreference = 'SilentlyContinue'

# Win32 focus + ESC
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;using System.Text;
public class PauseGuard {
    [DllImport("user32.dll")] static extern bool EnumWindows(EW l,IntPtr p);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h,StringBuilder t,int m);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern void keybd_event(byte v,byte s,uint f,UIntPtr e);
    delegate bool EW(IntPtr h,IntPtr l);
    const uint UP=0x0002;
    public static bool FocusGame(){
        IntPtr f=IntPtr.Zero;
        EnumWindows((h,ll)=>{var s=new StringBuilder(256);GetWindowText(h,s,256);
        if(s.ToString().StartsWith("Mount and Blade II Bannerlord")){f=h;return false;}return true;},IntPtr.Zero);
        return f!=IntPtr.Zero&&SetForegroundWindow(f);
    }
    public static void Esc(){keybd_event(0x1B,0,0,UIntPtr.Zero);keybd_event(0x1B,0,UP,UIntPtr.Zero);}
}
"@

function Read-Regent {
    $p = Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json'
    if (-not (Test-Path $p)) { return $null }
    try { Get-Content $p -Raw | ConvertFrom-Json } catch { $null }
}

function Test-PausedOrInMenu {
    param([object]$Regent)
    if (-not $Regent) { return $true }  # no regent = assume paused
    if ($Regent.sessionTimePaused -eq $true) { return $true }
    if ($Regent.surface -eq 'settlement_menu') { return $true }
    if ($Regent.surface -eq 'settlement_interior') { return $true }
    if ($Regent.surface -match 'escape') { return $true }
    if ($Regent.menuId -match 'escape') { return $true }
    return $false
}

$events = [System.Collections.Generic.List[string]]::new()
function Log($m) { $ts = [DateTime]::UtcNow.ToString('HH:mm:ss'); $e = "[PAUSE-GUARD ${ts}] $m"; Write-Host $e; $events.Add($e) }

# Step 1: Focus game window
$focused = [PauseGuard]::FocusGame()
if (-not $focused) { Log "WARN: game window not found"; return $null }
Start-Sleep -Milliseconds 500
Log "Game window focused"

# Step 2: Read regent and check pause state
$regent = Read-Regent
if (-not $regent) { Log "ERROR: no runtime regent found"; return $null }
Log "Initial state: surface=$($regent.surface) phase=$($regent.phase) paused=$($regent.sessionTimePaused)"

# Step 3: Dismiss pause menu if needed
$attempts = 0
while ((Test-PausedOrInMenu -Regent $regent) -and $attempts -lt $MaxDismissAttempts) {
    $attempts++
    Log "Dismiss attempt $attempts/$MaxDismissAttempts (surface=$($regent.surface) paused=$($regent.sessionTimePaused))"
    
    # Send ESC to dismiss
    [PauseGuard]::Esc()
    Start-Sleep -Milliseconds $VerifyDelayMs
    
    # Re-read regent
    $regent = Read-Regent
    if ($regent) {
        Log "After ESC: surface=$($regent.surface) phase=$($regent.phase) paused=$($regent.sessionTimePaused)"
    }
}

# Step 4: Final verification
if (Test-PausedOrInMenu -Regent $regent) {
    Log "WARN: still paused/in menu after $MaxDismissAttempts attempts"
    Log "Final state: surface=$($regent.surface) paused=$($regent.sessionTimePaused)"
} else {
    Log "Game unpaused: surface=$($regent.surface) phase=$($regent.phase)"
}

if ($PassThru) { Write-Output $regent }
return $regent
