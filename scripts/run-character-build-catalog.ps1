# Sprint 008C — live character choice catalog run (ForgeStop + launch + export).
param(
    [int]$ReadyTimeoutSec = 900,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repoRoot

. (Join-Path $PSScriptRoot 'forge-status.ps1')
. (Join-Path $PSScriptRoot 'dev-command-names.ps1')

function Get-BannerlordRootFromRepoLocal {
    param([string]$RepoRoot)
    return Get-BannerlordRootFromRepo -RepoRoot $RepoRoot
}

function Wait-TbgReadyExtended {
    param(
        [string]$BannerlordRoot,
        [int]$TimeoutSec
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if (Test-Phase1TbgReady -BannerlordRoot $BannerlordRoot) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

$bannerlordRoot = Get-BannerlordRootFromRepoLocal -RepoRoot $repoRoot
$catalogName = 'BlacksmithGuild_CharacterChoiceCatalog.json'
$evidenceRoot = Join-Path $repoRoot 'docs\evidence\latest'

Write-Host ''
Write-Host '=== 008C Character Choice Catalog Run ===' -ForegroundColor Cyan
Write-Host "Repo: $repoRoot"
Write-Host "Game: $bannerlordRoot"
Write-Host ''

if ($WhatIf) {
    Write-Host '[WhatIf] ForgeStop -> write catalog config -> forge.ps1 -Launch play -> wait TBG READY -> export' -ForegroundColor Yellow
    exit 0
}

Write-Host '[1/4] ForgeStop (kill stale processes)' -ForegroundColor Yellow
& (Join-Path $repoRoot 'scripts\forge-stop.ps1')

Write-Host '[2/4] Write AgentHeadless catalog variant config' -ForegroundColor Yellow
$configPath = & (Join-Path $repoRoot 'scripts\write-character-build-launch-config.ps1') `
    -Mode AgentHeadless `
    -AgentSubMode catalog `
    -BannerlordRoot $bannerlordRoot
Write-Host "  $configPath"

Write-Host '[3/4] Launch new game (visible off, VanillaLegit)' -ForegroundColor Yellow
& (Join-Path $repoRoot 'forge.ps1') -Launch -LaunchIntent play -SkipSaveBackup

Write-Host "[4/4] Wait for TBG READY (timeout ${ReadyTimeoutSec}s)" -ForegroundColor Yellow
if (-not (Wait-TbgReadyExtended -BannerlordRoot $bannerlordRoot -TimeoutSec $ReadyTimeoutSec)) {
    Write-Host 'BLOCKED - TBG READY not observed within timeout. Export partial evidence and review Phase1.' -ForegroundColor Red
    & (Join-Path $repoRoot 'scripts\export-tbg-evidence.ps1')
    exit 2
}

& (Join-Path $repoRoot 'scripts\export-tbg-evidence.ps1')

Write-Host '[5/5] Generate candidate matrix (map inbox)' -ForegroundColor Yellow
try {
    Send-ForgeCommand -CommandName 'GenerateCharacterBuildCandidatesNow' -BannerlordRoot $bannerlordRoot -Wait -TimeoutSec 60 | Out-Null
} catch {
    Write-Host "Candidate generation inbox failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host 'Fallback: copy catalog to game root and re-run GenerateCharacterBuildCandidatesNow on map.' -ForegroundColor Yellow
}

$matrixName = 'BlacksmithGuild_CharacterBuildCandidateMatrix.json'
$catalogSrc = Join-Path $bannerlordRoot $catalogName
if (Test-Path -LiteralPath $catalogSrc) {
    New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
    Copy-Item -LiteralPath $catalogSrc -Destination (Join-Path $evidenceRoot $catalogName) -Force
    Write-Host "Copied catalog to docs/evidence/latest/$catalogName" -ForegroundColor Green
} else {
    Write-Host "Missing runtime catalog $catalogName" -ForegroundColor Yellow
}

$matrixSrc = Join-Path $bannerlordRoot $matrixName
if (Test-Path -LiteralPath $matrixSrc) {
    Copy-Item -LiteralPath $matrixSrc -Destination (Join-Path $evidenceRoot $matrixName) -Force
    Write-Host "Copied matrix to docs/evidence/latest/$matrixName" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Catalog run complete. Review extractionErrors before matrix generation.' -ForegroundColor Green
