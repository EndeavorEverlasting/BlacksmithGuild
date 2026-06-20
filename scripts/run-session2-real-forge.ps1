# Session 2: switch forge ranking from stub to real recipe candidates (campaign must be loaded).
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host ''
Write-Host 'The Blacksmith Guild - Session 2 (real forge rank)' -ForegroundColor Cyan
Write-Host 'Precondition: TBG READY on campaign map (Forge.cmd or loaded save).' -ForegroundColor DarkGray
Write-Host ''

$commands = @(
    'ProbeForgeRecipes',
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
        exit $LASTEXITCODE
    }
}

Write-Host ''
Write-Host 'Done. Check F7, BlacksmithGuild_ForgeRecommendations.json, BlacksmithGuild_RecipeProbe.json, BlacksmithGuild_SmithingAudit.json' -ForegroundColor Green
