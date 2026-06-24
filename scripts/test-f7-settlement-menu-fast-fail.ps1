# Offline regression: settlement_menu observation + 15s semantic mismatch fail (session 20260623-205925 class).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')

$sessionId = '20260623-205925'
$statusPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\BlacksmithGuild_Status.json"
if (-not (Test-Path -LiteralPath $statusPath)) {
    throw "Missing status artifact: $statusPath"
}

$statusJson = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
if (-not (Test-F7SettlementMenuReadyObserved -StatusJson $statusJson -StatusArtifactState 'fresh')) {
    throw 'Baseline 205925 Status must satisfy settlement_menu ready observation'
}

$mockSignals = [pscustomobject]@{
    mapReadyStatus = $null
    phase1TbgReady = $false
    phase1QuickStartMapReady = $false
}
$gp = [pscustomobject]@{
    available = $true
    mapReadySeen = $false
    tbgReadySeen = $true
    firstMissingStep = 'MainMenu -> MapTransition'
}
if (Test-F7OldGoldenPathSatisfied -GoldenPathCheck $gp -Signals $mockSignals) {
    throw '205925 golden path must NOT satisfy old F7 gate (MapTransition missing)'
}

if ((Get-F7SettlementMenuSemanticMismatchSec) -ne 15) {
    throw 'Semantic mismatch cap must be 15 seconds'
}

$gateText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-f7-gate-continue.ps1') -Raw
foreach ($needle in @(
    'fail_settlement_menu_semantic_mismatch',
    'Test-F7SettlementMenuReadyObserved',
    'Test-F7OldGoldenPathSatisfied',
    'Get-F7SettlementMenuSemanticMismatchSec',
    'settlement_menu_ready_observed',
    'settlement_menu_ready_but_old_gate_requires_map_transition',
    'F7ManifestExtra'
)) {
    if ($gateText -notmatch [regex]::Escape($needle)) {
        throw "run-f7-gate-continue.ps1 missing: $needle"
    }
}

Write-Host "PASS offline settlement-menu fast-fail regression $sessionId"
Write-Host "readinessSurface=$($statusJson.readinessSurface) settlementMenuOpen=$($statusJson.settlementMenuOpen)"
