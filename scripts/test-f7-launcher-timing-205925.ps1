# Offline regression: launcher selection cap + LAUNCH_TIMING evidence (session 20260623-205925 class).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$sessionId = '20260623-205925'
$manifestPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\manifest.json"
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.passFail -ne 'FAIL') {
    throw "Baseline $sessionId must be FAIL (MapTransition treadmill)"
}
if ($manifest.campaignReady -ne $true) {
    throw 'Baseline 205925 must show campaignReady=true at fail time'
}
if ($manifest.canPollFileInbox -ne $false) {
    throw 'Baseline 205925 must show canPollFileInbox=false (old gate mismatch)'
}

$navText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'launcher-auto-nav.ps1') -Raw
foreach ($needle in @(
    'LauncherSelectionMaxMs = 45000',
    'ContinueClickVerifySecChrome = 4',
    'Write-LaunchTimingEvidence',
    'LAUNCH_TIMING launcherSelectionMs=',
    'launcher_timing_timeout',
    'fail_launcher_play_only',
    'IsLauncherPlayOnlyVisible',
    'IsLauncherContinueVisible',
    'safeModeBeforeContinue'
)) {
    if ($navText -notmatch [regex]::Escape($needle)) {
        throw "launcher-auto-nav.ps1 missing: $needle"
    }
}

if ($navText -notmatch 'Invoke-Handoff[\s\S]{0,200}Write-LaunchTimingEvidence') {
    throw 'Invoke-Handoff must emit LAUNCH_TIMING ok before handoff'
}

Write-Host "PASS offline launcher timing regression $sessionId"
Write-Host 'baseline: campaignReady=true canPollFileInbox=false; nav has 45s cap + LAUNCH_TIMING'
