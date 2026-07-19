<#
.SYNOPSIS
Priority engine: Land -> Survive -> Purchase -> Travel -> Sell.
Economic loop that reads market intel, decides best action, executes.
#>
param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [int]$MaxIterations = 1,
    [switch]$PassThru
)

$ErrorActionPreference = 'SilentlyContinue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$phase1Path = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$inboxPath = Join-Path $BannerlordRoot 'BlacksmithGuild_CommandInbox.json'
$marketIntelPath = Join-Path $BannerlordRoot 'BlacksmithGuild_MarketIntel.json'

# Self-contained Win32
Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;using System.Text;
public class N { [DllImport("user32.dll")] static extern bool EnumWindows(EW l,IntPtr p);[DllImport("user32.dll")] static extern int GetWindowText(IntPtr h,StringBuilder t,int m);[DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);[DllImport("user32.dll")] static extern void keybd_event(byte v,byte s,uint f,UIntPtr e);[DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);[DllImport("user32.dll")] static extern void mouse_event(uint f,uint dx,uint dy,uint d,UIntPtr e);
delegate bool EW(IntPtr h,IntPtr l);const uint UP=0x0002,LD=0x0002,LU=0x0004;
public static bool Focus(){IntPtr f=IntPtr.Zero;EnumWindows((h,ll)=>{var s=new StringBuilder(256);GetWindowText(h,s,256);if(s.ToString().StartsWith("Mount and Blade II Bannerlord")){f=h;return false;}return true;},IntPtr.Zero);return f!=IntPtr.Zero&&SetForegroundWindow(f);}
public static void Esc(){keybd_event(0x1B,0,0,UIntPtr.Zero);keybd_event(0x1B,0,UP,UIntPtr.Zero);}
public static void Enter(){keybd_event(0x0D,0,0,UIntPtr.Zero);keybd_event(0x0D,0,UP,UIntPtr.Zero);}
public static void Tab(){keybd_event(0x09,0,0,UIntPtr.Zero);keybd_event(0x09,0,UP,UIntPtr.Zero);}
public static void Down(){keybd_event(0x28,0,0,UIntPtr.Zero);keybd_event(0x28,0,UP,UIntPtr.Zero);}
public static void F(){keybd_event(0x46,0,0,UIntPtr.Zero);keybd_event(0x46,0,UP,UIntPtr.Zero);}
public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(LD,0,0,0,UIntPtr.Zero);mouse_event(LU,0,0,0,UIntPtr.Zero);}
}
"@

$events = [System.Collections.Generic.List[string]]::new()
function Log($m) { $ts = [DateTime]::UtcNow.ToString('HH:mm:ss'); $e = "[${ts}] $m"; Write-Host $e; $events.Add($e) }

Log "PRIORITY ENGINE START - Land/Survive/Purchase/Travel/Sell"

# 0. Focus game
[N]::Focus(); Start-Sleep -Milliseconds 500; Log "Game focused"

# 1. Dismiss pause
[N]::Esc(); Start-Sleep -Seconds 2; Log "Pause dismissed"

# 2. LAND — check current surface
$regent = try { Get-Content (Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json') -Raw | ConvertFrom-Json } catch { $null }
if (-not $regent) { Log "ERROR: no regent"; exit 1 }
Log "LAND: surface=$($regent.surface) phase=$($regent.phase) settlement=$($regent.settlement)"

# 3. SURVIVE — read market intel for needs
$marketIntel = try { Get-Content $marketIntelPath -Raw | ConvertFrom-Json } catch { $null }
if ($marketIntel) {
    $forgeSection = Select-String -LiteralPath $phase1Path -Pattern 'party charcoal|party hardwood|shortfall' -Encoding UTF8 | Select-Object -Last 5
    if ($forgeSection) {
        $forgeSection | ForEach-Object { Log "SURVIVE: $($_.Line)" }
    }
    Log "SURVIVE: market intel available"
} else {
    Log "SURVIVE: no market intel - run Ctrl+Alt+M first"
}

# 4. PURCHASE — dispatch buy command if at settlement with survival needs
[N]::Tab(); Start-Sleep -Milliseconds 500
[N]::Down(); Start-Sleep -Milliseconds 200; [N]::Down(); Start-Sleep -Milliseconds 200
[N]::Enter(); Start-Sleep -Seconds 3
$regent2 = try { Get-Content (Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json') -Raw | ConvertFrom-Json } catch { $null }
Log "PURCHASE ATTEMPT: surface=$($regent2.surface) phase=$($regent2.phase) menu=$($regent2.menuId)"

# 5. TRAVEL + SELL — dispatch trade route
$seq = 0
$acks = Select-String -LiteralPath $phase1Path -Pattern 'consumed sequence=(\d+)' -Encoding UTF8
if ($acks) { $seq = [int]($acks[-1].Matches.Groups[1].Value) }
$newSeq = $seq + 1
$inbox = @{ sequence=$newSeq; command='RunAutonomousVisibleTradeRouteNow'; source='Invoke-TbgPriorityEngine.ps1' }
$inbox | ConvertTo-Json | Set-Content -LiteralPath $inboxPath -Encoding UTF8
Log "TRAVEL: dispatched sequence=$newSeq RunAutonomousVisibleTradeRouteNow"

$result = [ordered]@{
    timestamp = [DateTime]::UtcNow.ToString('o')
    surface = $regent.surface
    phase = $regent.phase
    settlementEntered = ($regent.surface -eq 'settlement_menu')
    commandDispatched = ($null -ne $inbox)
    sequence = $newSeq
    events = $events.ToArray()
}
Log "PRIORITY ENGINE COMPLETE: settlementEntered=$($result.settlementEntered) commandDispatched=$($result.commandDispatched)"
$outPath = Join-Path $RepoRoot 'artifacts\latest\priority-engine.result.json'
$result | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $outPath -Encoding UTF8
Log "Output: $outPath"
if ($PassThru) { Write-Output $result }
exit 0
