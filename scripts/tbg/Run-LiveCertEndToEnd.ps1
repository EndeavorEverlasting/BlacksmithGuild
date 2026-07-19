<#
.SYNOPSIS
End-to-end: Launch game, dismiss pause, navigate to campaign map, run priority engine, collect evidence, commit.
#>
param([string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord')

$RepoRoot = 'C:\Users\Cheex\BlacksmithGuild'
$Scripts = Join-Path $RepoRoot 'scripts\tbg'
$Phase1 = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$RegentFile = Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json'
$InboxFile = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandInbox.json'

$Events = [System.Collections.Generic.List[string]]::new()
function Log($m) { $ts = Get-Date -Format HH:mm:ss; $e = "[${ts}] $m"; Write-Host $e; $Events.Add($e) }

Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;using System.Text;
public class API {
    [DllImport("user32.dll")] static extern bool EnumWindows(EW l,IntPtr p);
    [DllImport("user32.dll")] static extern int GetWindowText(IntPtr h,StringBuilder t,int m);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out RECT r);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
    [DllImport("user32.dll")] static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
    [DllImport("user32.dll")] static extern void keybd_event(byte v,byte s,uint f,UIntPtr e);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
    delegate bool EW(IntPtr h,IntPtr l);
    const uint UP=0x0002,LD=0x0002,LU=0x0004;
    public struct RECT{public int l;public int t;public int r;public int b;}
    public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(LD,0,0,0,UIntPtr.Zero);mouse_event(LU,0,0,0,UIntPtr.Zero);}
    public static void Key(byte vk){keybd_event(vk,0,0,UIntPtr.Zero);keybd_event(vk,0,UP,UIntPtr.Zero);}
    public static string FindLauncher(){
        IntPtr f=IntPtr.Zero;
        EnumWindows((h,ll)=>{var s=new StringBuilder(256);GetWindowText(h,s,256);var t=s.ToString();
        if(t.Contains("Bannerlord")&&!t.Contains("Fix")&&!t.Contains("Chrome")){RECT r;GetWindowRect(h,out r);GetWindowThreadProcessId(h,out uint p);System.Console.WriteLine($"LAUNCHER|{h}|{r.l},{r.t},{r.r},{r.b}|{p}");f=h;return false;}
        if(t.Contains("Mount")&&!t.Contains("Chrome")&&!t.Contains("Fix")){RECT r;GetWindowRect(h,out r);GetWindowThreadProcessId(h,out uint p);System.Console.WriteLine($"GAME|{h}|{r.l},{r.t},{r.r},{r.b}|{p}");f=h;return false;}
        return true;},IntPtr.Zero);
        return f!=IntPtr.Zero?"found":"none";
    }
}
"@

# STEP 1: Kill all game processes
Log "Killing stale processes..."
Get-Process -Name "Bannerlord" -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name "TaleWorlds.MountAndBlade.Launcher" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 3
Log "Stale processes killed"

# STEP 2: Write fresh launch intent
$intent = @{ intent="continue"; generatedUtc=([DateTime]::UtcNow.ToString('o')) }
$intent | ConvertTo-Json | Set-Content (Join-Path $BannerlordRoot 'BlacksmithGuild_LaunchIntent.json') -Encoding UTF8 -Force
$docs = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord'
if (!(Test-Path $docs)) { New-Item -ItemType Directory -Path $docs -Force | Out-Null }
$intent | ConvertTo-Json | Set-Content (Join-Path $docs 'BlacksmithGuild_LaunchIntent.json') -Encoding UTF8 -Force
Log "Launch intent written: continue"

# STEP 3: Launch via Steam
Log "Launching via Steam..."
Start-Process "steam://rungameid/261550"
Log "Waiting 20s for launcher..."
Start-Sleep -Seconds 20

# STEP 4: Find and click launcher
$result = [API]::FindLauncher()
Log "Window search: $result"

# Parse the console output to get HWND
# Try clicking repeatedly at the bottom area of the launcher
Log "Sweeping launcher bottom area..."
for ($y = 0; $y -lt 20; $y++) {
    [API]::Click(959, 500 + $y * 15)
    if ($y % 5 -eq 4) { Start-Sleep -Milliseconds 200 }
}

# Also try Tab+Enter
[API]::Key(0x09); Start-Sleep -Milliseconds 100
[API]::Key(0x09); Start-Sleep -Milliseconds 100
[API]::Key(0x09); Start-Sleep -Milliseconds 100
[API]::Key(0x0D)
Log "Tabx3+Enter sent"

# STEP 5: Wait for game to start
Log "Waiting 60s for game to start..."
$started = $false
for ($i = 0; $i -lt 60; $i++) {
    $p = Get-Process -Name "Bannerlord" -ErrorAction SilentlyContinue
    if ($p) {
        Log "Game started (PID $($p.Id)) at second $i"
        $started = $true
        break
    }
    if ($i -eq 15 -or $i -eq 30 -or $i -eq 45) {
        # Click again in case the first click missed
        for ($y = 0; $y -lt 10; $y++) { [API]::Click(959, 500 + $y * 20) }
        Log "Re-clicked launcher at second $i"
    }
    Start-Sleep -Seconds 1
}

if (-not $started) {
    Log "ERROR: Game did not start"
    Get-Process | Where-Object { $_.ProcessName -like "*TaleWorlds*" } | Select-Object ProcessName, Id
    exit 1
}

# STEP 6: Wait for campaign map ready
Log "Waiting 90s for game to load campaign map..."
for ($i = 0; $i -lt 90; $i++) {
    $p = Get-Process -Name "Bannerlord" -ErrorAction SilentlyContinue
    if (-not $p) { Log "Game exited at second $i"; break }
    Start-Sleep -Seconds 1
    if ($i -eq 30 -or $i -eq 60) {
        $age = (Get-Date) - (Get-Item $Phase1).LastWriteTime
        Log "Still loading... seq from Phase1"
        Get-Content $Phase1 -Tail 1
    }
}

# STEP 7: Focus game window
[API]::FindLauncher()
Log "Searching for game window..."

# STEP 8: Read regent state
$r = Get-Content $RegentFile -Raw | ConvertFrom-Json 2>$null
if ($r) {
    Log "Surface=$($r.surface) Phase=$($r.phase) Menu=$($r.menuId) Paused=$($r.sessionTimePaused)"
    
    # STEP 9: Dismiss pause if needed
    if ($r.sessionTimePaused -eq $true) {
        Log "Game paused - dismissing..."
        [API]::Key(0x1B)
        Start-Sleep -Seconds 2
        Log "ESC sent to dismiss pause"
    }
    
    # STEP 10: If at settlement menu, navigate to Leave
    if ($r.surface -eq 'settlement_menu') {
        Log "At settlement menu - navigating to Leave"
        1..10 | ForEach-Object { [API]::Key(0x28); Start-Sleep -Milliseconds 150 }
        Start-Sleep -Milliseconds 300
        [API]::Key(0x0D)
        Start-Sleep -Seconds 3
        $r2 = Get-Content $RegentFile -Raw | ConvertFrom-Json 2>$null
        if ($r2) { Log "After Leave: Surface=$($r2.surface) Phase=$($r2.phase)" }
    }
}

# STEP 11: Run priority engine
Log "Running priority engine..."
$engineScript = Join-Path $Scripts 'Invoke-TbgPriorityEngine.ps1'
if (Test-Path $engineScript) {
    & powershell.exe -NoProfile -Exec Bypass -File $engineScript -PassThru 2>&1
} else {
    Log "Priority engine script not found at $engineScript"
}

# STEP 12: Collect output
$result = [ordered]@{
    timestamp = [DateTime]::UtcNow.ToString('o')
    events = $Events.ToArray()
    surfaceAfterInteraction = if ($r) { $r.surface } else { "unknown" }
    gameLaunched = $started
}
$outPath = Join-Path $RepoRoot 'artifacts\latest\live-cert-result.json'
$result | ConvertTo-Json -Depth 3 | Set-Content $outPath -Encoding UTF8
Log "Output: $outPath"
exit 0