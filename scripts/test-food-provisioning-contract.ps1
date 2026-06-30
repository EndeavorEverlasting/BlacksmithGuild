# Regression wrapper for Food Provisioning doctrine and manifest.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-food-provisioning-contract.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\handoff\food-provisioning.manifest.json') -Raw | ConvertFrom-Json
if (-not $manifest.tradeIntegration.tradeProfitCannotOverrideFoodSafety) { throw 'trade profit cannot override food safety' }
if (@($manifest.decisionNames | ForEach-Object { [string]$_ }) -notcontains 'block_departure_insufficient_capacity') { throw 'food capacity blocker missing' }
if (@($manifest.executionOutcomes | ForEach-Object { [string]$_ }) -notcontains 'food_bought_and_verified') { throw 'verified food buy outcome missing' }

Write-Host 'PASS food provisioning regression' -ForegroundColor Green
exit 0
