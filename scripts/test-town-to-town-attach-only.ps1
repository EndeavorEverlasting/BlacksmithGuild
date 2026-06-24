# Offline regression: attach-only town-to-town cert never invokes launcher/F7.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

$runnerText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-town-to-town-trade-assist-cert.ps1') -Raw
foreach ($needle in @(
    'AttachOnly', 'NoLaunch', 'LaunchIfNeeded',
    'launchUsed', 'launchPath = ''existing_session''', 'manualLaunchAccepted',
    'mode = ''assistive_attach''', 'Test-F7AssistiveSessionAttachable',
    'Invoke-F7AssistiveEvidenceHarvest'
)) {
    if ($runnerText -notmatch [regex]::Escape($needle)) {
        throw "run-town-to-town-trade-assist-cert.ps1 missing: $needle"
    }
}

if ($runnerText -match 'run-f7-gate-continue') {
    throw 'Assist cert must not reference run-f7-gate-continue'
}
if ($runnerText -match 'launcher-auto-nav\.ps1' -and $runnerText -notmatch '-LaunchSetup') {
    throw 'launcher-auto-nav must only be invoked with -LaunchSetup'
}

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')

$fixtureStatus = Join-Path $repoRoot 'docs\evidence\live-cert\20260624-004036\checkpoint-01-assistive-town-trade\BlacksmithGuild_Status.json'
if (-not (Test-Path -LiteralPath $fixtureStatus)) {
    throw "Missing fixture: $fixtureStatus"
}

if (-not (Test-F7AssistiveStatusFreshForAttach -StatusPath $fixtureStatus)) {
    throw 'Fixture 004036 Status must pass live-ready attach freshness'
}
$ready = Get-F7AssistiveReadinessFromStatus -StatusPath $fixtureStatus
if ($ready.readinessSurface -ne 'settlement_menu') {
    throw "Expected settlement_menu got $($ready.readinessSurface)"
}
if (-not $ready.canPollFileInbox -or -not $ready.inGameAssistReady) {
    throw 'Fixture must show inbox + assist ready'
}

Write-Host 'PASS offline town-to-town attach-only regression'
