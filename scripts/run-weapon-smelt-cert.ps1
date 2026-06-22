# 006C-3 weapon smelt cert — probe + optional mutation with delta proof.
param(
    [switch]$WhatIf,
    [switch]$ProbeOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$probePath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSmeltProbe.json'
$execPath = Join-Path $bannerlordRoot 'BlacksmithGuild_SmithingSmeltExecution.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'

Write-Host ''
Write-Host '=== 006C-3 Weapon Smelt Cert ===' -ForegroundColor Cyan
Write-Host "Game: $bannerlordRoot"
Write-Host ''

if ($WhatIf) {
    Write-Host '[WhatIf] Would run ProbeWeaponSmeltNow' + $(if (-not $ProbeOnly) { ' + RunWeaponSmeltNow' })
    exit 0
}

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

Write-Host '[1/2] ProbeWeaponSmeltNow' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'ProbeWeaponSmeltNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 120

if (-not $ProbeOnly) {
    Write-Host ''
    Write-Host '[2/2] RunWeaponSmeltNow' -ForegroundColor Yellow
    Send-ForgeCommand -CommandName 'RunWeaponSmeltNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 120
}

$verdict = 'INDETERMINATE'
$detail = 'No smelt JSON found.'

if (Test-Path -LiteralPath $execPath) {
    try {
        $exec = Get-Content -LiteralPath $execPath -Raw | ConvertFrom-Json
        if ($exec.attemptSuccess -eq $true) {
            $verdict = 'PASS'
            $detail = "weapon $($exec.weaponName): $($exec.weaponsBefore)->$($exec.weaponsAfter) iron $($exec.ironBefore)->$($exec.ironAfter)"
        } elseif ($exec.detail -match 'no smeltable') {
            $verdict = 'BLOCKED'
            $detail = $exec.detail
        } else {
            $verdict = 'BLOCKED'
            $detail = $exec.detail
        }
    } catch {
        $detail = $_.Exception.Message
    }
} elseif (Test-Path -LiteralPath $probePath) {
    try {
        $probe = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
        if ($probe.attemptSuccess -eq $true) {
            $verdict = 'PROBE_PASS'
            $detail = 'API mapped and canSmeltWeapon=true'
        } else {
            $verdict = 'PROBE_BLOCKED'
            $detail = $probe.detail
        }
    } catch {
        $detail = $_.Exception.Message
    }
}

if ($phase1Path -and (Test-Path -LiteralPath $phase1Path)) {
    $smeltLine = Select-String -LiteralPath $phase1Path -Pattern '\[TBG FORGE\] action=SmeltWeapon' | Select-Object -Last 1
    if ($smeltLine -and $verdict -ne 'PASS') {
        Write-Host "Phase1 hint: $($smeltLine.Line.Trim())" -ForegroundColor DarkGreen
    }
}

Write-Host ''
Write-Host "Verdict: $verdict" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } elseif ($verdict -match 'BLOCKED') { 'Yellow' } else { 'Gray' })
Write-Host "Detail:  $detail"
Write-Host ''
Write-Host 'Evidence:' -ForegroundColor Cyan
Write-Host "  $probePath"
Write-Host "  $execPath"
Write-Host "  $phase1Path"

if ($verdict -eq 'BLOCKED' -and $detail -match 'no smeltable') {
    Write-Host ''
    Write-Host 'Tip: seed a tier-1 loot weapon in party (town buy) then rerun.' -ForegroundColor Yellow
    exit 2
}

if ($verdict -eq 'PASS' -or $verdict -eq 'PROBE_PASS') { exit 0 }
exit 1
