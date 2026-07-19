<#
.SYNOPSIS
Campaign map → settlement entry → trade menu navigation trigger.
Detects campaign map, enters nearest settlement, navigates to trade menu.
#>
param(
    [string]$BannerlordRoot = 'C:\Program Files (x86)\Steam\steamapps\common\Mount & Blade II Bannerlord',
    [int]$MapReadyTimeoutSec = 120,
    [int]$StepPauseMs = 3000
)

$ErrorActionPreference = 'SilentlyContinue'
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

# Step 0: focus game window before any input
Write-Host "=== Settlement -> Trade Trigger ==="
$focusResult = & "$PSScriptRoot\Focus-TbgGameWindow.ps1" -PassThru
if (-not $focusResult.confirmed) {
    Write-Host "WARN: Game window not focused. Input may go to wrong window."
}

$phase1Path = Join-Path $BannerlordRoot 'BlacksmithGuild_Phase1.log'
$regentPath = Join-Path $BannerlordRoot 'BlacksmithGuild_RuntimeRegent.json'

Add-Type -TypeDefinition @"
using System;using System.Runtime.InteropServices;
public class NavKeys {
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] static extern void mouse_event(uint flags, uint dx, uint dy, uint dw, UIntPtr extra);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    const uint MOUSEEVENTF_LEFTDOWN=0x0002,MOUSEEVENTF_LEFTUP=0x0004;
    const uint KEYEVENTF_KEYUP=0x0002;
    public static void Click(int x,int y){SetCursorPos(x,y);mouse_event(MOUSEEVENTF_LEFTDOWN,0,0,0,UIntPtr.Zero);mouse_event(MOUSEEVENTF_LEFTUP,0,0,0,UIntPtr.Zero);}
    public static void Press(byte vk){keybd_event(vk,0,0,UIntPtr.Zero);keybd_event(vk,0,KEYEVENTF_KEYUP,UIntPtr.Zero);}
}
"@

Write-Host "=== Settlement → Trade Trigger ==="
Write-Host "Waiting for campaign map readiness ($MapReadyTimeoutSec`s)..."

$deadline = (Get-Date).AddSeconds($MapReadyTimeoutSec)
$mapReady = $false

while ((Get-Date) -lt $deadline) {
    if (-not (Test-Path $phase1Path)) { Start-Sleep -Seconds 2; continue }
    $tail = Get-Content -LiteralPath $phase1Path -Tail 10 -Encoding UTF8
    if ($tail -match 'surface=map_surface.*mapReady=true.*sessionReady=true') {
        $mapReady = $true
        Write-Host "MAP READY: entering settlement..."
        break
    }
    Start-Sleep -Seconds 2
}

if (-not $mapReady) {
    # Check if already in settlement — skip to trade navigation
    if (Test-Path $regentPath) {
        $regent = Get-Content -LiteralPath $regentPath -Raw | ConvertFrom-Json
        if ($regent.surface -eq 'settlement_menu') {
            Write-Host "Already in settlement: $($regent.phase). Skipping to trade navigation..."
            $mapReady = $true
        }
    }
        if (-not $mapReady) { Write-Host "TIMEOUT - not on campaign map"; exit 1 }
}

# Step 1: Click center to select settlement
[NavKeys]::Click(960, 540)
Start-Sleep -Milliseconds $StepPauseMs

# Verify we entered settlement
$regent = Get-Content -LiteralPath $regentPath -Raw | ConvertFrom-Json
if ($regent.surface -ne 'settlement_menu') {
    # Try clicking again
    [NavKeys]::Click(960, 540); Start-Sleep -Milliseconds $StepPauseMs
    $regent = Get-Content -LiteralPath $regentPath -Raw | ConvertFrom-Json
}
Write-Host "Surface: $($regent.surface) Phase: $($regent.phase)"

if ($regent.surface -ne 'settlement_menu') { Write-Host "Failed to enter settlement"; exit 2 }

# Step 2: Navigate settlement overlay menu to Trade
# Tab opens overlay, Down 2x to Trade, Enter selects
[NavKeys]::Press(0x09); Start-Sleep -Milliseconds 500  # Tab
[NavKeys]::Press(0x28); Start-Sleep -Milliseconds 200  # Down
[NavKeys]::Press(0x28); Start-Sleep -Milliseconds 200  # Down
[NavKeys]::Press(0x0D); Start-Sleep -Milliseconds $StepPauseMs  # Enter

$regent = Get-Content -LiteralPath $regentPath -Raw | ConvertFrom-Json
Write-Host "After Trade nav: $($regent.surface) $($regent.phase) $($regent.menuId)"

# Step 3: If still in settlement_menu, try clicking trade area directly (left-center)
if ($regent.surface -eq 'settlement_menu') {
    # Try clicking trade district positions
    [NavKeys]::Click(400, 500); Start-Sleep -Seconds 2
    [NavKeys]::Click(300, 550); Start-Sleep -Seconds 2
    [NavKeys]::Press(0x0D); Start-Sleep -Seconds 2  # Enter to interact
    [NavKeys]::Press(0x0D); Start-Sleep -Seconds 2  # Enter again
    $regent = Get-Content -LiteralPath $regentPath -Raw | ConvertFrom-Json
    Write-Host "Final surface: $($regent.surface) $($regent.phase) MenuId: $($regent.menuId)"
}

$result = [ordered]@{
    surface = $regent.surface
    phase = $regent.phase
    menuId = $regent.menuId
    timestamp = [DateTime]::UtcNow.ToString('o')
    settlementEntered = ($regent.surface -eq 'settlement_menu')
    tradeMenuReached = ($regent.phase -ne '' -and $regent.menuId -ne 'MenuContext_1')
}
$result | ConvertTo-Json | Write-Host
exit $(if ($result.tradeMenuReached) { 0 } else { 3 })
