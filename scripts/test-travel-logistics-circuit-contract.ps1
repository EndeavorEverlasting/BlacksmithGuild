# Regression wrapper for the Travel Logistics Circuit doctrine contract.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-travel-logistics-circuit-contract.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'PASS travel logistics circuit regression' -ForegroundColor Green
exit 0
