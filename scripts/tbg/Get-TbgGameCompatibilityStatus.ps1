<#
.SYNOPSIS
    Displays the current game compatibility status.
#>
[CmdletBinding()]
param([string]$RepoRoot = '')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $callerDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    $RepoRoot = (Resolve-Path (Join-Path $callerDir '..\..')).Path
}

$outDir = Join-Path $RepoRoot 'artifacts\latest\game-update'
$resultPath = Join-Path $outDir 'game-compatibility-result.json'
$obsPath = Join-Path $outDir 'game-build-observation.json'

if (-not (Test-Path -LiteralPath $resultPath)) {
    Write-Host "No compatibility result found. Run detection first:"
    Write-Host "  .\ForgeGameUpdate.cmd"
    exit 0
}

$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
$obs = if (Test-Path -LiteralPath $obsPath) {
    Get-Content -LiteralPath $obsPath -Raw | ConvertFrom-Json
} else { $null }

$supportPath = Join-Path $RepoRoot '.tbg\compatibility\bannerlord-support.json'
$support = if (Test-Path -LiteralPath $supportPath) {
    Get-Content -LiteralPath $supportPath -Raw | ConvertFrom-Json
} else { $null }

Write-Host ''
Write-Host '=== Bannerlord Game Compatibility ===' -ForegroundColor Cyan
Write-Host ''

$installed = if ($result.installedIdentity -and $result.installedIdentity.friendlyVersion) {
    "$($result.installedIdentity.friendlyVersion) build $($result.installedIdentity.buildNumber)"
} else { 'NOT DETECTED' }

$upstream = if ($result.upstreamIdentity -and $result.upstreamIdentity.friendlyVersion) {
    "$($result.upstreamIdentity.friendlyVersion) build $($result.upstreamIdentity.buildNumber)"
} else { 'UNKNOWN' }

$supported = if ($result.supportedIdentity -and $result.supportedIdentity.friendlyVersion) {
    $result.supportedIdentity.friendlyVersion
} else { 'UNKNOWN' }

$state = $result.compatibilityState
$color = switch ($state) {
    'SUPPORTED_VALIDATED' { 'Green' }
    'SUPPORTED_BUILD_ONLY' { 'Yellow' }
    'UPDATE_AVAILABLE_NOT_INSTALLED' { 'Yellow' }
    'INSTALLED_UPDATE_UNVALIDATED' { 'Yellow' }
    'COMPATIBILITY_FAILED' { 'Red' }
    'COMPATIBILITY_BLOCKED' { 'Red' }
    'ROLLBACK_RECOMMENDED' { 'Red' }
    default { 'White' }
}

Write-Host "  Installed:  $installed"
Write-Host "  Upstream:   $upstream"
Write-Host "  Supported:  $supported"
Write-Host "  Status:     " -NoNewline; Write-Host $state -ForegroundColor $color
Write-Host ''

Write-Host '  Allowed actions:' -ForegroundColor DarkGray
foreach ($a in $result.allowedActions) { Write-Host "    - $a" -ForegroundColor Green }
Write-Host ''
Write-Host '  Blocked claims:' -ForegroundColor DarkGray
foreach ($c in $result.blockedClaims) { Write-Host "    - $c" -ForegroundColor Red }
Write-Host ''

if ($result.artifacts) {
    Write-Host '  Generated artifacts:' -ForegroundColor DarkGray
    if ($result.artifacts.observation) { Write-Host "    $($result.artifacts.observation)" }
    if ($result.artifacts.handoff) { Write-Host "    $($result.artifacts.handoff)" }
    if ($result.artifacts.progressLog) { Write-Host "    $($result.artifacts.progressLog)" }
}

Write-Host ''
Write-Host '  Next command: .\ForgeGameUpdate-Assess.cmd' -ForegroundColor DarkGray
Write-Host ''
