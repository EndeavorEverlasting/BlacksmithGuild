# Sprint 008C — sequential variant matrix runs (ForgeStop loop per candidate).
param(
    [int]$MaxCandidates = 16,
    [int]$MinSuccessfulRuns = 3,
    [int]$ReadyTimeoutSec = 900,
    [switch]$KeepTestSaves,
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

function Write-VariantConfig {
    param(
        [string]$BannerlordRoot,
        [object]$Candidate
    )

    $config = [ordered]@{
        mode = 'variant'
        candidateId = $Candidate.candidateId
        selectedBuildMode = $Candidate.profile
        visibleMode = $false
        decisionPauseMs = 0
        score = [double]$Candidate.score
        testSavePrefix = 'BSG_ASR_TEST_'
        testSaveName = "BSG_ASR_TEST_$($Candidate.candidateId)"
        route = @($Candidate.route)
    }

    $path = Join-Path $BannerlordRoot 'BlacksmithGuild_CharacterBuildVariantConfig.json'
    ($config | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
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

function Copy-RunEvidence {
    param(
        [string]$BannerlordRoot,
        [string]$CandidateId,
        [string]$DestRoot
    )

    $runsSrc = Join-Path $BannerlordRoot 'character_runs'
    $runsDest = Join-Path $DestRoot 'character_runs'
    New-Item -ItemType Directory -Force -Path $runsDest | Out-Null

    $runName = "BlacksmithGuild_CharacterBuildRun_$CandidateId.json"
    $src = Join-Path $runsSrc $runName
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $runsDest $runName) -Force
        return $true
    }

    return $false
}

$bannerlordRoot = Get-BannerlordRootFromRepoLocal -RepoRoot $repoRoot
$evidenceRoot = Join-Path $repoRoot 'docs\evidence\latest'
$matrixPath = Join-Path $evidenceRoot 'BlacksmithGuild_CharacterBuildCandidateMatrix.json'
if (-not (Test-Path -LiteralPath $matrixPath)) {
    $matrixPath = Join-Path $bannerlordRoot 'BlacksmithGuild_CharacterBuildCandidateMatrix.json'
}

if (-not (Test-Path -LiteralPath $matrixPath)) {
    throw "Matrix JSON missing. Run catalog + GenerateCharacterBuildCandidatesNow first."
}

$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json
if ($matrix.blockedReason) {
    throw "Matrix blocked: $($matrix.blockedReason)"
}

$candidates = @($matrix.candidates | Select-Object -First $MaxCandidates)
if ($candidates.Count -eq 0) {
    throw 'Matrix has zero candidates.'
}

$report = [ordered]@{
    generatedUtc = (Get-Date).ToUniversalTime().ToString('o')
    matrixSource = $matrixPath
    runsAttempted = 0
    runsSucceeded = 0
    runsBlocked = 0
    runs = @()
}

Write-Host ''
Write-Host '=== 008C Character Build Variant Matrix ===' -ForegroundColor Cyan
Write-Host "Candidates: $($candidates.Count) (cap $MaxCandidates)"
Write-Host ''

if ($WhatIf) {
    foreach ($candidate in $candidates) {
        Write-Host "[WhatIf] $($candidate.candidateId) score=$($candidate.score)" -ForegroundColor Yellow
    }
    exit 0
}

foreach ($candidate in $candidates) {
    $report.runsAttempted++
    $started = Get-Date

    Write-Host "--- Candidate $($candidate.candidateId) ($($report.runsAttempted)/$($candidates.Count)) ---" -ForegroundColor Cyan

    & (Join-Path $repoRoot 'scripts\forge-stop.ps1')
    Write-VariantConfig -BannerlordRoot $bannerlordRoot -Candidate $candidate | Out-Null

    try {
        & (Join-Path $repoRoot 'forge.ps1') -Launch -LaunchIntent play -SkipSaveBackup
    } catch {
        $report.runs += [ordered]@{
            candidateId = $candidate.candidateId
            verdict = 'Failed'
            blockedReason = $_.Exception.Message
            durationSec = [int]((Get-Date) - $started).TotalSeconds
        }
        $report.runsBlocked++
        continue
    }

    if (-not (Wait-TbgReadyExtended -BannerlordRoot $bannerlordRoot -TimeoutSec $ReadyTimeoutSec)) {
        $report.runs += [ordered]@{
            candidateId = $candidate.candidateId
            verdict = 'Failed'
            blockedReason = 'TBG READY timeout'
            durationSec = [int]((Get-Date) - $started).TotalSeconds
        }
        $report.runsBlocked++
        & (Join-Path $repoRoot 'scripts\forge-stop.ps1')
        continue
    }

    $copied = Copy-RunEvidence -BannerlordRoot $bannerlordRoot -CandidateId $candidate.candidateId -DestRoot $evidenceRoot
    $report.runs += [ordered]@{
        candidateId = $candidate.candidateId
        verdict = if ($copied) { 'VanillaLegit' } else { 'Failed' }
        blockedReason = if ($copied) { '' } else { 'run JSON missing' }
        durationSec = [int]((Get-Date) - $started).TotalSeconds
    }

    if ($copied) {
        $report.runsSucceeded++
    } else {
        $report.runsBlocked++
    }

    if (-not $KeepTestSaves) {
        $docsSaves = Join-Path $env:USERPROFILE 'Documents\Mount and Blade II Bannerlord\Game Saves\Native'
        if (Test-Path -LiteralPath $docsSaves) {
            Get-ChildItem -LiteralPath $docsSaves -Filter 'BSG_ASR_TEST_*' -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    & (Join-Path $repoRoot 'scripts\forge-stop.ps1')

    if ($report.runsSucceeded -ge $MinSuccessfulRuns -and $report.runsAttempted -ge $MinSuccessfulRuns) {
        Write-Host "Minimum acceptance reached ($($report.runsSucceeded) successful runs)." -ForegroundColor Green
        break
    }
}

$reportPath = Join-Path $evidenceRoot 'BlacksmithGuild_CharacterBuildVariantMatrixReport.json'
New-Item -ItemType Directory -Force -Path $evidenceRoot | Out-Null
($report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $reportPath -Encoding UTF8

& (Join-Path $repoRoot 'scripts\export-tbg-evidence.ps1')

Write-Host ''
Write-Host "Matrix report: $reportPath" -ForegroundColor Cyan
Write-Host "Succeeded: $($report.runsSucceeded) / Attempted: $($report.runsAttempted)" -ForegroundColor Green

if ($report.runsSucceeded -lt $MinSuccessfulRuns) {
    Write-Host "BLOCKED - fewer than $MinSuccessfulRuns successful runs." -ForegroundColor Yellow
    exit 2
}

exit 0
