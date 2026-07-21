<#
.SYNOPSIS
Launch game, escape pause, navigate to campaign map, run priority engine.
#>
$root = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord'

Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;using System.Text;
public class G {
    [DllImport("user32.dll")] static extern bool EnumWindows(EW l,IntPtr p);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h,StringBuilder t,int m);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
    [DllImport("user32.dll")] static extern void keybd_event(byte v,byte s,uint f,UIntPtr e);
    delegate bool EW(IntPtr h,IntPtr l);
    const uint UP=0x0002,LD=0x0002,LU=0x0004;
    public static bool Focus(string prefix){
        IntPtr f=IntPtr.Zero;
        EnumWindows((h,ll)=>{var s=new StringBuilder(256);GetWindowText(h,s,256);if(s.ToString().Contains(prefix)){f=h;return false;}return true;},IntPtr.Zero);
        return f!=IntPtr.Zero&&SetForegroundWindow(f);
    }
    public static void Key(byte vk){keybd_event(vk,0,0,UIntPtr.Zero);keybd_event(vk,0,UP,UIntPtr.Zero);}
    public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(LD,0,0,0,UIntPtr.Zero);mouse_event(LU,0,0,0,UIntPtr.Zero);}
}
"@

$log = @()
function Log($m) { Write-Host "[$(Get-Date -Format HH:mm:ss)] $m"; $global:log += $m }

# Phase 1: Launch game
Log "Launching game via Steam"
Start-Process "steam://rungameid/261550"
Start-Sleep -Seconds 15
Log "Waiting for launcher..."

$launcherFound = $false
for ($i = 0; $i -lt 20; $i++) {
    if ([G]::Focus("Bannerlord")) { $launcherFound = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $launcherFound) { Log "ERROR: launcher not found"; exit 1 }
Log "Launcher focused"

# Click Continue button in launcher (bottom center of launcher window)
[G]::Click(959, 740)
Start-Sleep -Milliseconds 500
[G]::Key(0x0D)  # Enter
Log "Continue clicked in launcher"

# Wait for game to load
Start-Sleep -Seconds 10
for ($i = 0; $i -lt 30; $i++) {
    $p = Get-Process -Name "Bannerlord" -ErrorAction SilentlyContinue
    if ($p) { Log "Game process started (PID $($p.Id))"; break }
    Start-Sleep -Seconds 2
}

# Wait for campaign map ready
Start-Sleep -Seconds 30
Log "Waiting for game to reach campaign map..."

# Phase 2: Find game window, focus, and dismiss pause
for ($i = 0; $i -lt 15; $i++) {
    if ([G]::Focus("Mount and Blade II")) { Log "Game window focused"; break }
    Start-Sleep -Seconds 2
}

# Dismiss pause menu (regent-aware, not blind)
$guardScript = Join-Path $PSScriptRoot 'Assert-TbgGameUnpaused.ps1'
$regent = & $guardScript -PassThru
if (-not $regent) { Log "WARN: pause guard returned null, reading regent directly"; $regent = Get-Content (Join-Path $root 'BlacksmithGuild_RuntimeRegent.json') -Raw | ConvertFrom-Json 2>$null }
Log "After pause guard: Surface=$($regent.surface) Phase=$($regent.phase) Menu=$($regent.menuId)"

# Phase 3: If at settlement_menu, navigate to Leave
if ($regent.surface -eq 'settlement_menu') {
    Log "At settlement menu - navigating to Leave"
    
    # Dismiss ESC menu if open - press Escape
    [G]::Key(0x1B)
    Start-Sleep -Seconds 1
    
    # Navigate down (Leave is last option in town menu)
    1..8 | ForEach-Object { [G]::Key(0x28); Start-Sleep -Milliseconds 200 }
    Log "Down x8 sent"
    
    # Select Leave
    [G]::Enter()
    Start-Sleep -Seconds 4
    
    $regent2 = Get-Content (Join-Path $root 'BlacksmithGuild_RuntimeRegent.json') -Raw | ConvertFrom-Json 2>$null
    Log "After Leave: Surface=$($regent2.surface) Phase=$($regent2.phase)"
}

# Wait a bit
Start-Sleep -Seconds 5
$regent3 = Get-Content (Join-Path $root 'BlacksmithGuild_RuntimeRegent.json') -Raw | ConvertFrom-Json 2>$null
Log "Final surface: $($regent3.surface) Phase: $($regent3.phase)"

$result = [ordered]@{
    timestamp = [DateTime]::UtcNow.ToString('o')
    surface = $regent3.surface
    phase = $regent3.phase
    menuId = $regent3.menuId
    log = $global:log
    escapedPauseMenu = ($regent3.surface -ne $regent.surface)
}
$result | ConvertTo-Json -Depth 3 | Write-Output
