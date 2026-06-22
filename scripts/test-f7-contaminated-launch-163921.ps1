# Offline regression: contaminated Continue cert launch path (session 20260622-163921).
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot
. (Join-Path $PSScriptRoot 'f7-launch-contract.ps1')

$sessionId = '20260622-163921'
$launchTailPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\Launch.tail.txt"
if (-not (Test-Path -LiteralPath $launchTailPath)) {
    throw "Missing Launch.tail: $launchTailPath"
}

$launchLines = Get-Content -LiteralPath $launchTailPath
$playUserLine = [string]($launchLines | Where-Object { $_ -match 'LAUNCH_STATE=play_clicked selectedBy=user' } | Select-Object -First 1)
if (-not $playUserLine) {
    throw 'Launch.tail missing play_clicked selectedBy=user'
}

$contaminated = Get-F7LaunchContaminationResult `
    -CertTarget 'continue' `
    -LaunchPath 'play' `
    -LaunchSelectedBy 'user' `
    -AutomationContinueSuccess $false

if (-not $contaminated.contaminated) {
    throw 'Expected contaminated=true for certTarget=continue launchPath=play launchSelectedBy=user'
}
if ($contaminated.failureReason -ne 'contaminated_launch_path') {
    throw "Expected failureReason=contaminated_launch_path got $($contaminated.failureReason)"
}
if (-not $contaminated.targetMismatch) {
    throw 'Expected targetMismatch=true'
}
if ($contaminated.gameSpawnAccepted) {
    throw 'Expected gameSpawnAccepted=false'
}
if ($contaminated.readinessJudged) {
    throw 'Expected readinessJudged=false'
}
if ($contaminated.targetMismatchReason -notmatch 'launchPath=play') {
    throw "Unexpected targetMismatchReason: $($contaminated.targetMismatchReason)"
}

$eligible = Get-F7LaunchContaminationResult `
    -CertTarget 'continue' `
    -LaunchPath 'continue' `
    -LaunchSelectedBy 'automation' `
    -AutomationContinueSuccess $true
if ($eligible.contaminated) {
    throw 'Automation Continue should be eligible for certTarget=continue'
}
if (-not $eligible.gameSpawnAccepted) {
    throw 'Eligible automation Continue should set gameSpawnAccepted=true'
}

$autoPlay = Get-F7LaunchContaminationResult `
    -CertTarget 'continue' `
    -LaunchPath 'play' `
    -LaunchSelectedBy 'automation' `
    -AutomationContinueSuccess $false
if (-not $autoPlay.contaminated) {
    throw 'Automation Play must contaminate certTarget=continue'
}

$userContinue = Get-F7LaunchContaminationResult `
    -CertTarget 'continue' `
    -LaunchPath 'continue' `
    -LaunchSelectedBy 'user' `
    -AutomationContinueSuccess $false
if (-not $userContinue.contaminated) {
    throw 'User Continue must contaminate certTarget=continue'
}

$playCert = Get-F7LaunchContaminationResult `
    -CertTarget 'play' `
    -LaunchPath 'play' `
    -LaunchSelectedBy 'automation' `
    -AutomationContinueSuccess $false
if ($playCert.contaminated) {
    throw 'Automation Play should be eligible for certTarget=play'
}

$startedUtc = [datetime]::Parse('2026-06-22T20:39:21.6842631Z', $null, [Globalization.DateTimeStyles]::RoundtripKind)
$manifestPath = Join-Path $repoRoot "docs\evidence\live-cert\$sessionId\checkpoint-01-f7-gate\manifest.json"
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$statusPath = [string]$manifest.artifactMeta[0].sourcePath
if ((Get-F7ArtifactFreshnessState -Path $statusPath -CertStartedUtc $startedUtc) -ne 'stale') {
    throw 'Session 163921 Status artifact should classify as stale relative to cert start'
}

Write-Host "PASS offline contaminated launch regression $sessionId"
Write-Host "playUserLine=$playUserLine"
