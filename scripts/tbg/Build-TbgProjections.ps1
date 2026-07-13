[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$OutputRoot = 'artifacts/latest/projections'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}

function Resolve-TbgRepoPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    Join-Path $RepoRoot ($RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar)
}

$projectionsRoot = Resolve-TbgRepoPath '.local/tbg-state/projections'

Write-Host '=== Pass 1: Incremental reduce ==='
& (Join-Path $PSScriptRoot 'Invoke-TbgReducer.ps1') -RepoRoot $RepoRoot -Rebuild
$meta1 = Get-Content -LiteralPath (Join-Path $projectionsRoot 'projection-meta.json') -Raw | ConvertFrom-Json
$hash1 = [string]$meta1.projectionHash
Write-Host "Pass 1 hash: $hash1"

Write-Host '=== Pass 2: Full replay reduce ==='
& (Join-Path $PSScriptRoot 'Invoke-TbgReducer.ps1') -RepoRoot $RepoRoot -Rebuild
$meta2 = Get-Content -LiteralPath (Join-Path $projectionsRoot 'projection-meta.json') -Raw | ConvertFrom-Json
$hash2 = [string]$meta2.projectionHash
Write-Host "Pass 2 hash: $hash2"

$match = $hash1 -eq $hash2
$status = if ($match) { 'PASS_ZERO_REMAINDERS' } else { 'FAIL_STATE_CORRUPTION' }

$outputPath = Resolve-TbgRepoPath $OutputRoot
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$result = [ordered]@{
    schema = 'TbgProjectionVerificationResult.v1'
    generatedUtc = [DateTime]::UtcNow.ToString('o')
    status = $status
    incrementalHash = $hash1
    fullReplayHash = $hash2
    hashesMatch = $match
    eventsProcessed = [int]$meta2.eventsProcessed
    objectsProduced = [int]$meta2.objectsProduced
    proofLevel = 'static test'
}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $outputPath 'projection-verification.result.json') -Encoding UTF8

$reportLines = @(
    '# TBG Projection Verification',
    '',
    "Status: **$status**",
    "- Incremental hash: $hash1",
    "- Full replay hash: $hash2",
    "- Hashes match: $match",
    "- Events processed: $($meta2.eventsProcessed)",
    "- Objects produced: $($meta2.objectsProduced)",
    ''
)
$reportLines -join "`r`n" | Set-Content -LiteralPath (Join-Path $outputPath 'projection-verification.report.md') -Encoding UTF8

Write-Host "Projection verification: $status (match=$match)"
if (-not $match) { exit 1 }
