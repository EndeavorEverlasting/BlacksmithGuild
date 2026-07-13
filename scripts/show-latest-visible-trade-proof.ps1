# Show latest visible trade proof status.
# Displays whether a run is active, latest run ID, current stage,
# source/execution heads, last event, elapsed time, and all proof states.

param(
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$latestResultPath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.result.json'
$latestProofPath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.proof.json'
$latestProgressPath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.progress.log'
$latestHandoffPath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.handoff.md'
$latestCapsulePath = Join-Path $RepoRoot 'artifacts\latest\visible-trade-proof.capsule.json'

function Read-SafeJson {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return $null }
}

$result = Read-SafeJson -Path $latestResultPath
$proof = Read-SafeJson -Path $latestProofPath

if (-not $result) {
    Write-Host ''
    Write-Host 'No visible trade proof run found.' -ForegroundColor Yellow
    Write-Host "Expected artifact: $latestResultPath"
    Write-Host ''
    Write-Host 'Run a proof with: Run-VisibleTradeProof.cmd'
    exit 0
}

Write-Host ''
Write-Host '=== Visible Trade Proof Status ===' -ForegroundColor Cyan
Write-Host ''

$passColor = switch ([string]$result.passFail) {
    'PASS' { 'Green' }
    'DIAGNOSTIC' { 'Yellow' }
    default { 'Red' }
}

Write-Host "Terminal State:  $($result.terminalState)" -ForegroundColor $passColor
Write-Host "Highest Proof:   $($result.highestProofReached)"
Write-Host "Run ID:          $($result.runId)"
Write-Host "Mode:            $($result.mode)"
Write-Host "Duration:        $($result.durationSec) seconds"
Write-Host ''

if ([string]$result.terminalState -eq 'running') {
    Write-Host 'Status: ACTIVE - a run is in progress' -ForegroundColor Green
} else {
    Write-Host 'Status: COMPLETED' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '--- Source and Execution ---' -ForegroundColor Cyan
Write-Host "Branch:          $($result.branch)"
Write-Host "Head:            $($result.headSha)"
Write-Host "Source commit:   $($result.provenance.sourceCommit)"
Write-Host "Execution worktree: $($result.provenance.executionWorktree)"
Write-Host ''

Write-Host '--- Proof Stages ---' -ForegroundColor Cyan
Write-Host "Command ACK:     $(if ($result.commandAck.observed) {'YES'} else {'NO'})"
Write-Host "Campaign Time:   $(if ($result.campaignTime.advancing) {'ADVANCING'} else {'NOT PROVEN'})"
Write-Host "Movement:        $(if ($result.movement.observed) {'YES (delta=' + $result.movement.delta + ')'} else {'NO'})"
Write-Host "Checkpoint:      $(if ($result.checkpoint.observed) {'YES'} else {'NO'})"
Write-Host "Arrival:         $(if ($result.arrival.observed) {$result.arrival.settlement} else {'NO'})"
Write-Host "Buy:             $(if ($result.buy.observed) {$result.buy.itemId + ' gold=' + $result.buy.goldDelta} else {'NO'})"
Write-Host "Sell:            $(if ($result.sell.observed) {'YES'} else {'NO'})"
Write-Host ''

Write-Host '--- DLL Hash ---' -ForegroundColor Cyan
Write-Host "Built:     $($result.dll.localSha256)"
Write-Host "Installed: $($result.dll.installedSha256)"
Write-Host "Match:     $(if ([string]::Equals($result.dll.localSha256, $result.dll.installedSha256, [System.StringComparison]::OrdinalIgnoreCase)) {'YES'} else {'NO'})"
Write-Host ''

Write-Host '--- Remote Evidence ---' -ForegroundColor Cyan
if ($result.publication.published) {
    Write-Host "Published:   YES" -ForegroundColor Green
    Write-Host "Branch:      $($result.publication.evidenceBranch)"
    Write-Host "Commit:      $($result.publication.evidenceCommit)"
} else {
    Write-Host "Published:   NO" -ForegroundColor Yellow
    if ($result.publication.error) {
        Write-Host "Error:       $($result.publication.error)"
    }
}
Write-Host ''

Write-Host '--- Artifacts ---' -ForegroundColor Cyan
Write-Host "Result:     $latestResultPath"
Write-Host "Proof:      $latestProofPath"
Write-Host "Progress:   $latestProgressPath"
Write-Host "Handoff:    $latestHandoffPath"
Write-Host "Capsule:    $latestCapsulePath"
Write-Host ''

if (Test-Path -LiteralPath $latestProgressPath) {
    $lastLines = @(Get-Content -LiteralPath $latestProgressPath -Tail 5 -ErrorAction SilentlyContinue)
    if ($lastLines.Count -gt 0) {
        Write-Host '--- Last Events ---' -ForegroundColor Cyan
        foreach ($line in $lastLines) {
            Write-Host "  $line"
        }
    }
}

Write-Host ''
exit 0
