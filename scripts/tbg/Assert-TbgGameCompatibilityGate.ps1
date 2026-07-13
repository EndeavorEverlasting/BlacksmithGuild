[CmdletBinding()]
param(
    [ValidateSet('launcher','runtime-proof')]
    [string]$Gate = 'launcher',
    [string]$RepoRoot,
    [string]$BannerlordRoot,
    [string]$AppManifestPath,
    [string]$UpstreamFixturePath,
    [string]$BuiltDllPath,
    [string]$InstalledDllPath,
    [switch]$NoJournal,
    [switch]$NoEnvelope,
    [switch]$NoExit,
    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$RepoRoot = [IO.Path]::GetFullPath($RepoRoot)
$updaterPath = Join-Path $RepoRoot 'scripts/tbg/Invoke-TbgGameCompatibility.ps1'
if (-not (Test-Path -LiteralPath $updaterPath -PathType Leaf)) {
    throw "Game compatibility updater is missing: $updaterPath"
}

$invoke = @{
    Command = 'check'
    RepoRoot = $RepoRoot
    NoExit = $true
    PassThru = $true
}
if (-not [string]::IsNullOrWhiteSpace($BannerlordRoot)) { $invoke.BannerlordRoot = $BannerlordRoot }
if (-not [string]::IsNullOrWhiteSpace($AppManifestPath)) { $invoke.AppManifestPath = $AppManifestPath }
if (-not [string]::IsNullOrWhiteSpace($UpstreamFixturePath)) { $invoke.UpstreamFixturePath = $UpstreamFixturePath }
if (-not [string]::IsNullOrWhiteSpace($BuiltDllPath)) { $invoke.BuiltDllPath = $BuiltDllPath }
if (-not [string]::IsNullOrWhiteSpace($InstalledDllPath)) { $invoke.InstalledDllPath = $InstalledDllPath }
if ($NoJournal) { $invoke.NoJournal = $true }
if ($NoEnvelope) { $invoke.NoEnvelope = $true }

$result = @(& $updaterPath @invoke | Where-Object { $null -ne $_ } | Select-Object -Last 1)
$result = if ($result.Count -gt 0) { $result[0] } else { $null }
$allowed = $null -ne $result -and [string]$result.terminalState -eq 'PASS_compatibility_metadata_aligned'
$terminalState = if ($result) { [string]$result.terminalState } else { 'BLOCKED_game_compatibility_result_missing' }
$nextCommand = if ($result -and $result.nextCommand) { [string]$result.nextCommand } else { '.\ForgeGameUpdate.cmd check' }

$gateResult = [pscustomobject][ordered]@{
    schema = 'TbgGameCompatibilityGate.v1'
    gate = $Gate
    allowed = [bool]$allowed
    terminalState = $terminalState
    sourceCommit = if ($result) { $result.sourceCommit } else { $null }
    compatibilityResultPath = if ($result) { [string]$result.evidencePaths.result } else { $null }
    nextCommand = $nextCommand
    proofLevel = 'harness'
}

if ($allowed) {
    Write-Host "Game compatibility gate PASS for $Gate: $terminalState" -ForegroundColor Green
}
else {
    Write-Host "BLOCKED_GAME_BUILD_UNVALIDATED for $Gate: $terminalState" -ForegroundColor Red
    Write-Host "Next: $nextCommand" -ForegroundColor Yellow
}

if ($PassThru) { Write-Output $gateResult }
if (-not $NoExit) {
    if ($allowed) { exit 0 }
    exit 42
}
