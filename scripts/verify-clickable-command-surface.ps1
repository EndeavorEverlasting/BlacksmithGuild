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

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )

    Assert-Exists -Path $Path
    $full = Join-Path $RepoRoot $Path
    $text = Get-Content -LiteralPath $full -Raw
    if ($text -match [regex]::Escape($Pattern)) {
        throw "Unexpected '$Label' in $Path"
    }
}

$wrappers = @(
    'Run-MarketIntel.cmd',
    'Run-FoodAdvisory.cmd',
    'Run-FoodGovernorCheck.cmd',
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
    Assert-Contains -Path $wrapper -Pattern 'exit /b %TBG_EXIT%'
}

foreach ($wrapper in $wrappers | Where-Object { $_ -ne 'Run-FoodGovernorCheck.cmd' }) {
    Assert-Contains -Path $wrapper -Pattern 'pause'
}

Assert-Contains -Path 'Run-MarketIntel.cmd' -Pattern 'MarketSnapshotNow'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'AnalyzeFood'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'This does NOT buy food'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'BlacksmithGuild_FoodAdvisory.json'
Assert-Contains -Path 'Run-FoodGovernorCheck.cmd' -Pattern 'compatibility alias'
Assert-Contains -Path 'Run-FoodGovernorCheck.cmd' -Pattern 'Run-FoodAdvisory.cmd'
Assert-Contains -Path 'Run-HorseMarketIntel.cmd' -Pattern 'AnalyzeHorseMarket'
Assert-Contains -Path 'Run-GuildLoopAdvisory.cmd' -Pattern 'RunGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'run-autonomous-guild-loop-operator.ps1'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'RunAutonomousGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'WARNING:'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'foreground/unpaused'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'autonomous-guild-loop-operator.json'
Assert-NotContains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'alt-tab OK'
Assert-Contains -Path 'Run-CohesionAnalyze.cmd' -Pattern 'AnalyzeCohesionOpportunities'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'RunVisibleCohesionMoveNow'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'WARNING:'
Assert-Contains -Path 'Run-AutoTravelChoices.cmd' -Pattern 'ShowAutoTravelChoices'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ShowForgeStatus'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ExportTbgEvidence.cmd'
Assert-Contains -Path 'Run-ExportEvidence.cmd' -Pattern 'ExportTbgEvidence.cmd'

Assert-Exists -Path 'scripts/run-autonomous-guild-loop-operator.ps1'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'TbgAutonomousGuildLoopOperatorResult.v1'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'FAILED_game_disappeared_during_command'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'BLOCKED_no_ack'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'Keep Bannerlord foreground and unpaused'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'BlacksmithGuild_AutonomousGuildLoop.json'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'BlacksmithGuild_Phase1.log'

Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'public const string AnalyzeFoodCommand = "AnalyzeFood"'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'BlacksmithGuild_FoodAdvisory.json'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'BuyFoodSupported = false'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'FoodProcurementCandidatePlanner.Plan'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'FoodMarketStockScanner.ScanCurrentSettlement'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'FoodMarketCandidateMatcher.Match'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'FoodProcurementExecutionGate.Evaluate'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandRegistry.cs' -Pattern 'FoodAdvisoryService.AnalyzeFoodCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevCommandBus.cs' -Pattern 'FoodAdvisoryService.RunAnalyzeNow'
Assert-Contains -Path 'scripts/dev-command-names.ps1' -Pattern "'AnalyzeFood'"

Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Clickable Command Surface'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'prefer a root-level `.cmd` wrapper'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-MarketIntel.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-FoodAdvisory.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'AnalyzeFood'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Food-specific note'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'buyFoodSupported'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-AutonomousGuildLoop.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Autonomous Guild Loop operator note'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'FAILED_game_disappeared_during_command'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'foreground and unpaused'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Still not click-clean enough'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Agent checklist'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'clickable-command-surface.md'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'Run-FoodAdvisory.cmd'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'AnalyzeFood'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'Food check'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'Click:'

Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'operator_play_diagnostic'
Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'autonomous-guild-loop-operator.json'
Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'FAILED_game_disappeared_during_command'

Write-Host 'Clickable command surface contract: PASS'
