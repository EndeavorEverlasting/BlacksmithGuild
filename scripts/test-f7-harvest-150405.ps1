# Offline regression: re-harvest session 20260622-150405 without game launch.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')
. (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1')

$sessionId = '20260622-150405'
$sourceCheckpoint = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate"
$manifestPath = Join-Path $sourceCheckpoint 'manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Missing baseline manifest: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$sourcePhase1Tail = Join-Path $sourceCheckpoint 'Phase1.tail.txt'
if (-not (Test-Path -LiteralPath $sourcePhase1Tail)) {
    throw "Missing baseline Phase1.tail: $sourcePhase1Tail"
}
$phase1Path = Join-Path $env:TEMP "f7-harvest-regression-$sessionId-phase1.log"
Copy-Item -LiteralPath $sourcePhase1Tail -Destination $phase1Path -Force
$launchLogPath = Get-LaunchLogPath -BannerlordRoot $bannerlordRoot
$startedDt = [datetime]::Parse([string]$manifest.startedAtUtc, $null, [Globalization.DateTimeStyles]::RoundtripKind)
$sinceLocal = $startedDt.ToLocalTime()

$testDir = Join-Path $env:TEMP "f7-harvest-regression-$sessionId"
if (Test-Path -LiteralPath $testDir) {
    Remove-Item -LiteralPath $testDir -Recurse -Force
}
New-Item -ItemType Directory -Path $testDir | Out-Null

try {
    $result = Invoke-F7EvidenceHarvest `
        -CheckpointDir $testDir `
        -BannerlordRoot $bannerlordRoot `
        -SinceLocal $sinceLocal `
        -StartedAtUtc $startedDt `
        -PassFail 'FAIL' `
        -Phase1Path $phase1Path `
        -LaunchLogPath $launchLogPath `
        -RunnerCommandLine 'offline-regression-150405' `
        -HookMask '0x0F' `
        -ProcessTimestamps @{ gameStartUtc = [string]$manifest.startedAtUtc; gameEndUtc = [string]$manifest.endedAtUtc } `
        -GamePhaseAtEnd 'MapTransition'

    if ($result.harvestError) {
        throw "harvest returned harvestError: $($result.harvestError)"
    }
    if (-not $result.lastTraceMarker) {
        throw 'lastTraceMarker missing'
    }
    if ($result.lastTraceMarker -notmatch 'FlushWrite stage=ok') {
        throw "unexpected lastTraceMarker: $($result.lastTraceMarker)"
    }
    if (-not $result.windowsCrashEventStatus) {
        throw 'windowsCrashEventStatus missing'
    }
    if ($result.windowsCrashEventStatus -notin @('copied', 'none_found', 'query_failed', 'not_available')) {
        throw "invalid windowsCrashEventStatus: $($result.windowsCrashEventStatus)"
    }
    if ($result.evidenceCompleteness.score -eq 'harvest_failed') {
        throw 'evidenceCompleteness.score is harvest_failed'
    }

    $probe = [ordered]@{}
    foreach ($key in $result.Keys) { $probe[$key] = $result[$key] }
    $null = $probe | ConvertTo-Json -Depth 10

    Write-Host "PASS offline harvest regression $sessionId"
    Write-Host "lastTraceMarker=$($result.lastTraceMarker)"
    Write-Host "windowsCrashEventStatus=$($result.windowsCrashEventStatus)"
    Write-Host "evidenceCompleteness=$($result.evidenceCompleteness.score)"
} finally {
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $phase1Path -Force -ErrorAction SilentlyContinue
}
