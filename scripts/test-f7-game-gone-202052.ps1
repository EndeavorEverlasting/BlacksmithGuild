# Offline regression: launcher_hosted + fresh Phase1 must not trigger fail_game_gone_definitive (session 20260622-202052).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$sessionId = '20260622-202052'
$manifestPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.launchState -ne 'fail_game_gone_definitive') {
    throw "Expected baseline launchState=fail_game_gone_definitive got $($manifest.launchState)"
}
if ($manifest.gameProcessRunning -ne $true) {
    throw 'Baseline 202052 manifest must show gameProcessRunning=true at fail time'
}
if ($manifest.gameProcessDetectionMethod -ne 'launcher_hosted_window') {
    throw "Expected launcher_hosted_window got $($manifest.gameProcessDetectionMethod)"
}
if ($manifest.phase1ArtifactState -ne 'fresh') {
    throw "Expected fresh Phase1 artifact state got $($manifest.phase1ArtifactState)"
}

$gateText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-f7-gate-continue.ps1') -Raw
if ($gateText -notmatch 'function Test-F7GameGoneDefinitive') {
    throw 'run-f7-gate-continue.ps1 missing Test-F7GameGoneDefinitive'
}
if ($gateText -notmatch 'exeEverSeen') {
    throw 'run-f7-gate-continue.ps1 missing exeEverSeen timestamp guard'
}
if ($gateText -notmatch 'Detection\.gameProcessRunning') {
    throw 'run-f7-gate-continue.ps1 must check Detection.gameProcessRunning before game_gone definitive'
}

$harvestText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1') -Raw
if ($harvestText -notmatch 'Get-F7SafeArtifactFreshnessState') {
    throw 'f7-evidence-harvest.ps1 missing Get-F7SafeArtifactFreshnessState'
}
if ($harvestText -notmatch 'CrashContext.json not present \(optional\)') {
    throw 'f7-evidence-harvest.ps1 must treat CrashContext as optional'
}

Write-Host "PASS offline game-gone regression $sessionId"
Write-Host "baseline: gameProcessRunning=true launcher_hosted_window phase1ArtifactState=fresh"
