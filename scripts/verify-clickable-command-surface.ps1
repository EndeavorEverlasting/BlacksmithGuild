param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Exists {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing required clickable command surface file: $Path"
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )

    Assert-Exists -Path $Path
    $full = Join-Path $RepoRoot $Path
    $text = Get-Content -LiteralPath $full -Raw
    if ($text -notmatch [regex]::Escape($Pattern)) {
        throw "Missing '$Label' in $Path"
    }
}

$wrappers = @(
    'Run-MarketIntel.cmd',
    'Run-HorseMarketIntel.cmd',
    'Run-GuildLoopAdvisory.cmd',
    'Run-AutonomousGuildLoop.cmd',
    'Run-CohesionAnalyze.cmd',
    'Run-CohesionMove.cmd',
    'Run-AutoTravelChoices.cmd',
    'Run-TickCostProfilerSmoke.cmd',
    'Run-ExportEvidence.cmd'
)

foreach ($wrapper in $wrappers) {
    Assert-Exists -Path $wrapper
    Assert-Contains -Path $wrapper -Pattern '@echo off'
    Assert-Contains -Path $wrapper -Pattern 'pause'
    Assert-Contains -Path $wrapper -Pattern 'exit /b %TBG_EXIT%'
}

Assert-Contains -Path 'Run-MarketIntel.cmd' -Pattern 'MarketSnapshotNow'
Assert-Contains -Path 'Run-HorseMarketIntel.cmd' -Pattern 'AnalyzeHorseMarket'
Assert-Contains -Path 'Run-GuildLoopAdvisory.cmd' -Pattern 'RunGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'RunAutonomousGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'WARNING:'
Assert-Contains -Path 'Run-CohesionAnalyze.cmd' -Pattern 'AnalyzeCohesionOpportunities'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'RunVisibleCohesionMoveNow'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'WARNING:'
Assert-Contains -Path 'Run-AutoTravelChoices.cmd' -Pattern 'ShowAutoTravelChoices'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ShowForgeStatus'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ExportTbgEvidence.cmd'
Assert-Contains -Path 'Run-ExportEvidence.cmd' -Pattern 'ExportTbgEvidence.cmd'

Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Clickable Command Surface'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'prefer a root-level `.cmd` wrapper'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-MarketIntel.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-AutonomousGuildLoop.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Still not click-clean enough'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Agent checklist'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'clickable-command-surface.md'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'Click:'

Write-Host 'Clickable command surface contract: PASS'
