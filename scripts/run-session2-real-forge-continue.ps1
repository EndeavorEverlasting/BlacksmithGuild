# Session 2 remainder — skip ProbeForgeRecipes if already run.
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host ''
Write-Host 'The Blacksmith Guild - Session 2 (continue after ProbeForgeRecipes)' -ForegroundColor Cyan
Write-Host ''

$commands = @(
    'SetForgeCandidateSourceReal',
    'RankForgeCandidates',
    'ShowForgeDoctrine',
    'SetForgeDoctrineRareMetalConservation',
    'RankForgeCandidates',
    'ProbeSmithingAudit'
)

foreach ($command in $commands) {
    Write-Host ">>> $command" -ForegroundColor Yellow
    & (Join-Path $RepoRoot 'forge.ps1') -Command $command -Wait
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Command failed: $command (exit $LASTEXITCODE)" -ForegroundColor Red
        exit 1
    }
}

Write-Host ''
Write-Host 'Done. Check F7, ForgeRecommendations.json, SmithingAudit.json' -ForegroundColor Green
