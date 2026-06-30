# 006C-4 vanilla sell cert — probe with gold/inventory delta proof.
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$probePath = Join-Path $bannerlordRoot 'BlacksmithGuild_MapTradeSellProbe.json'
$phase1Path = Join-Path $bannerlordRoot 'BlacksmithGuild_Phase1.log'

Write-Host ''
Write-Host '=== 006C-4 Vanilla Sell Cert ===' -ForegroundColor Cyan
Write-Host "Game: $bannerlordRoot"
Write-Host ''

if ($WhatIf) {
    Write-Host '[WhatIf] Would run ProbeVanillaSellExecutionNow (party at town with trade goods)'
    exit 0
}

Clear-StaleMutationCommandInbox -BannerlordRoot $bannerlordRoot | Out-Null

Write-Host '[1/1] ProbeVanillaSellExecutionNow' -ForegroundColor Yellow
Send-ForgeCommand -CommandName 'ProbeVanillaSellExecutionNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 120

$verdict = 'INDETERMINATE'
$detail = 'No sell probe JSON found.'

if (Test-Path -LiteralPath $probePath) {
    try {
        $probe = Get-Content -LiteralPath $probePath -Raw | ConvertFrom-Json
        $goldDelta = 0
        $qtySold = 0
        if ($probe.tradeExecution) {
            $goldDelta = [int]$probe.tradeExecution.goldDelta
            $qtySold = [int]$probe.tradeExecution.quantitySold
        }

        if ($probe.attemptSuccess -eq $true -and $goldDelta -gt 0 -and $qtySold -gt 0) {
            $verdict = 'PASS'
            $detail = "gold +$goldDelta, sold $qtySold x $($probe.itemName)"
        } elseif ($probe.attemptDetail -match 'not at settlement|no sellable') {
            $verdict = 'BLOCKED'
            $detail = $probe.attemptDetail
        } else {
            $verdict = 'BLOCKED'
            $detail = $probe.attemptDetail
            if ($probe.tradeExecution) {
                $detail = "$detail (goldDelta=$goldDelta quantitySold=$qtySold)"
            }
        }
    } catch {
        $detail = $_.Exception.Message
    }
}

if ($phase1Path -and (Test-Path -LiteralPath $phase1Path)) {
    $line = Select-String -LiteralPath $phase1Path -Pattern 'TBG MAP TRADE SELL PROBE' | Select-Object -Last 1
    if ($line) {
        Write-Host "Phase1 hint: $($line.Line.Trim())" -ForegroundColor DarkGreen
    }
}

Write-Host ''
Write-Host "Verdict: $verdict" -ForegroundColor $(if ($verdict -eq 'PASS') { 'Green' } elseif ($verdict -match 'BLOCKED') { 'Yellow' } else { 'Gray' })
Write-Host "Detail:  $detail"
Write-Host ''
Write-Host 'Evidence:' -ForegroundColor Cyan
Write-Host "  $probePath"
Write-Host "  $phase1Path"

if ($verdict -eq 'BLOCKED' -and $detail -match 'not at settlement|no sellable') {
    Write-Host ''
    Write-Host 'Tip: ForgeContinue to a town; carry trade goods (not smithing reserves); rerun.' -ForegroundColor Yellow
    exit 2
}

if ($verdict -eq 'PASS') { exit 0 }
exit 1
