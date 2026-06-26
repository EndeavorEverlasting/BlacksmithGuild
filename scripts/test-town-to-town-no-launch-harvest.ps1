# Offline regression: attach-only assist harvest does not require Launch.tail.txt.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'bannerlord-paths.ps1')
. (Join-Path $PSScriptRoot 'f7-evidence-harvest.ps1')

$complete = Get-F7AssistiveEvidenceCompleteness `
    -StatusJsonCopied $true `
    -AssistiveSessionCopied $true `
    -ProbeJsonCopied $true `
    -CrashContextCopied $false `
    -Phase1TailLineCount 100 `
    -LaunchTailLineCount 0 `
    -PassFail 'PASS' `
    -LaunchUsed $false

if ($complete.score -ne 'sufficient') {
    throw "Expected sufficient without Launch.tail got $($complete.score) missing=$($complete.missing -join ',')"
}
foreach ($req in $complete.required) {
    if ($req.name -eq 'Launch.tail.txt') {
        throw 'Launch.tail must not be required when launchUsed=false'
    }
}

$withLaunch = Get-F7AssistiveEvidenceCompleteness `
    -StatusJsonCopied $true -AssistiveSessionCopied $true -ProbeJsonCopied $true `
    -CrashContextCopied $false -Phase1TailLineCount 100 -LaunchTailLineCount 0 `
    -PassFail 'PASS' -LaunchUsed $true
if ($withLaunch.score -eq 'sufficient') {
    throw 'LaunchUsed=true without Launch.tail should not be sufficient'
}

$fixtureProbe = Join-Path $repoRoot 'docs\evidence\live-cert\20260624-004036\checkpoint-01-assistive-town-trade\BlacksmithGuild_TownToTownTradeProbe.json'
$fixtureStatus = Join-Path $repoRoot 'docs\evidence\live-cert\20260624-004036\checkpoint-01-assistive-town-trade\BlacksmithGuild_Status.json'
if (-not (Test-Path -LiteralPath $fixtureProbe)) { throw "Missing fixture probe: $fixtureProbe" }

$probe = Get-Content -LiteralPath $fixtureProbe -Raw | ConvertFrom-Json
. (Join-Path $PSScriptRoot 'f7-external-state-classifier.ps1')
$ready = Get-F7AssistiveReadinessFromStatus -StatusPath $fixtureStatus
if (-not (Test-F7AssistiveTownTradeCertPass -Readiness $ready -ProbeJson $probe -ProbeAckOk $true)) {
    throw 'Fixture 004036 must satisfy assist PASS criteria offline'
}

Write-Host 'PASS offline town-to-town no-launch harvest regression'
