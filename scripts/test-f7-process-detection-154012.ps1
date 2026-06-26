# Offline regression: process detection classification for session 20260622-154012.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')

$sessionId = '20260622-154012'
$launchTailPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\Launch.tail.txt"
if (-not (Test-Path -LiteralPath $launchTailPath)) {
    throw "Missing Launch.tail: $launchTailPath"
}

$hostedTitle = 'Mount and Blade II Bannerlord - Singleplayer PID: 139112'
if (-not (Test-LauncherHostedWindowTitle -Title $hostedTitle)) {
    throw "Test-LauncherHostedWindowTitle failed for canonical 154012 title"
}

$launchLines = Get-Content -LiteralPath $launchTailPath
$pickLine = [string]($launchLines | Where-Object { $_ -match 'falling back to window=' -and $_ -match 'Singleplayer PID:' } | Select-Object -First 1)
if (-not $pickLine) {
    throw 'Launch.tail missing coord window pick line with Singleplayer PID'
}
if ($pickLine -notmatch 'falling back to window="([^"]+)"') {
    throw "Could not parse hosted window title from Launch.tail: $pickLine"
}
$parsedTitle = [string]$Matches[1]
if (-not (Test-LauncherHostedWindowTitle -Title $parsedTitle)) {
    throw "Parsed Launch.tail title not classified as launcher-hosted: $parsedTitle"
}

$bannerlordRoot = Get-BannerlordRootFromRepo -RepoRoot $repoRoot
$tmpPhase1 = Join-Path $env:TEMP "f7-pd-regression-$sessionId-phase1.log"
try {
    Set-Content -LiteralPath $tmpPhase1 -Value '[TBG TRACE] offline regression probe' -Encoding UTF8
    (Get-Item -LiteralPath $tmpPhase1).LastWriteTimeUtc = (Get-Date).ToUniversalTime()

    $script:BannerlordProcessDetectionCache = $null
    $script:BannerlordProcessDetectionCacheUtc = [datetime]::MinValue
    $det = Get-BannerlordProcessDetection -BannerlordRoot $bannerlordRoot `
        -Phase1Path $tmpPhase1 -StatusPath (Join-Path $env:TEMP 'nonexistent-status.json') `
        -CrashContextPath (Join-Path $env:TEMP 'nonexistent-crash.json') -CacheSec 0

    if (-not $det.gameProcessRunning) {
        throw 'Fresh Phase1 should set gameProcessRunning=true (phase1_active or definite if game running locally)'
    }
    if ($det.gameAliveConfidence -eq 'none') {
        throw 'Fresh Phase1 must not yield gameAliveConfidence=none'
    }
    if ($det.gameAliveConfidence -eq 'phase1_active' -and -not $det.phase1LogFresh) {
        throw 'phase1_active detection requires phase1LogFresh=true'
    }
} finally {
    Remove-Item -LiteralPath $tmpPhase1 -Force -ErrorAction SilentlyContinue
}

function Get-TestF7TimeoutFailNotes {
    param(
        $LastSignals,
        $Detection,
        [bool]$EverMapReady,
        $LaunchSignals
    )

    $uncertain = [string]$Detection.gameAliveConfidence -in @(
        'launcher_hosted', 'phase1_active', 'process_detection_uncertain'
    )
    if ($uncertain -or $LastSignals.gameRunning) {
        if (-not $EverMapReady) {
            $method = [string]$Detection.gameProcessDetectionMethod
            $conf = [string]$Detection.gameAliveConfidence
            return "F7 FAIL: timeout in MapTransition (game alive; detection=$conf method=$method; no map-ready signal)"
        }
    }
    if (-not $LastSignals.gameRunning) {
        return 'F7 FAIL: process died before map-ready (timeout boundary)'
    }
    return 'F7 FAIL: timeout still in MapTransition (no map-ready signal)'
}

foreach ($conf in @('launcher_hosted', 'phase1_active', 'process_detection_uncertain')) {
    $mockDet = [ordered]@{
        gameProcessRunning = $true
        gameAliveConfidence = $conf
        gameProcessDetectionMethod = if ($conf -eq 'launcher_hosted') { 'launcher_hosted_window' } else { "${conf}_probe" }
    }
    $mockSignals = [pscustomobject]@{ gameRunning = $true }
    $mockLaunch = [pscustomobject]@{ priorSessionCrashLikely = $false }
    $notes = Get-TestF7TimeoutFailNotes -LastSignals $mockSignals -Detection $mockDet `
        -EverMapReady $false -LaunchSignals $mockLaunch
    if ($notes -match 'process died') {
        throw "Timeout notes must not say 'process died' for $conf; got: $notes"
    }
    if ($notes -notmatch 'MapTransition') {
        throw "Timeout notes must mention MapTransition for $conf; got: $notes"
    }
}

Write-Host "PASS offline process detection regression $sessionId"
Write-Host "hostedTitle=$hostedTitle"
Write-Host "parsedLaunchTailTitle=$parsedTitle"
