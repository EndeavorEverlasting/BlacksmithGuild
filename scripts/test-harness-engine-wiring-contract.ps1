# Targeted regression wrapper for harness to engine wiring.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verify-harness-engine-wiring-contract.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = Get-Content -LiteralPath (Join-Path $repoRoot 'docs\handoff\harness-engine-wiring.manifest.json') -Raw | ConvertFrom-Json
$ids = @($manifest.contracts | ForEach-Object { $_.contractId })
foreach ($id in @('recursive_branch.travel_target', 'runner.engine_target_resolution', 'assistive_travel.movement_proof', 'reboot.repeat_context')) {
    if ($ids -notcontains $id) { throw "missing contract $id" }
}
if ([int]$manifest.normalActionTimeoutSec -gt 30) { throw 'normal timeout cap must be 30 seconds or less' }
if (-not (@($manifest.contracts | Where-Object { $_.longTimeoutReason -eq 'long-distance travel' }).Count -gt 0)) { throw 'long-distance travel exception missing' }

$movement = $manifest.contracts | Where-Object { $_.contractId -eq 'assistive_travel.movement_proof' } | Select-Object -First 1
if ([string]$movement.proofRequired -notmatch 'durable checkpoint evidence') { throw 'movement proof must require checkpoint-based durable evidence' }

$runner = Get-Content -LiteralPath (Join-Path $repoRoot 'scripts\run-autonomous-assist-session.ps1') -Raw
if ($runner -match 'TargetSettlement\s*=\s*[''"]Ortysia[''"]') { throw 'TargetSettlement must not default to Ortysia' }

$rebootCmd = Get-Content -LiteralPath (Join-Path $repoRoot 'ForgeReboot.cmd') -Raw
if ($rebootCmd -notmatch [regex]::Escape('%*')) { throw 'ForgeReboot.cmd must forward args' }
if ($rebootCmd -notmatch 'FORGE_NO_PAUSE') { throw 'ForgeReboot.cmd must support noninteractive tests' }

$stopCmd = Get-Content -LiteralPath (Join-Path $repoRoot 'ForgeStop.cmd') -Raw
if ($stopCmd -notmatch 'FORGE_STOP_CHOICE') { throw 'ForgeStop.cmd must support noninteractive stop choice' }

Write-Host 'PASS harness-engine wiring regression'
exit 0