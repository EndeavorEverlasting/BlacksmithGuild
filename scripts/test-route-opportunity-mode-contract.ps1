# Regression wrapper for route opportunity mode CMD/state contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-route-opportunity-mode-contract.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\handoff\route-opportunity-mode.manifest.json') -Raw | ConvertFrom-Json
if ([string]$manifest.defaultMode -ne 'direct') { throw 'route opportunity default must be direct' }
if (@($manifest.supportedModes | ForEach-Object { [string]$_ }) -notcontains 'exploring') { throw 'exploring mode missing' }
if (@($manifest.integrityRules | ForEach-Object { [string]$_ }) -notcontains 'routeModeMustBeExplicitForExploration') { throw 'exploration opt-in rule missing' }

Write-Host 'PASS route opportunity mode regression' -ForegroundColor Green
exit 0
