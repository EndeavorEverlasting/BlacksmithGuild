param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Exists {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Missing required clickable command surface file: $Path" }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )
    Assert-Exists -Path $Path
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    if ($text -notmatch [regex]::Escape($Pattern)) { throw "Missing '$Label' in $Path" }
}

function Assert-NotContains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )
    Assert-Exists -Path $Path
    $text = Get-Content -LiteralPath (Join-Path $RepoRoot $Path) -Raw
    if ($text -match [regex]::Escape($Pattern)) { throw "Unexpected '$Label' in $Path" }
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

Assert-Exists -Path 'Run-LauncherValidationWorkhorse.cmd'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern '@echo off'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'Launcher Validation Workhorse'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'run-launcher-validation-supervisor.ps1'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'Workspace modes: current synced, current local commits, isolated remote, and isolated local snapshot.'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-supervisor.progress.log'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-supervisor.handoff.md'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-supervisor.result.json'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-workhorse.progress.log'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-workhorse.handoff.md'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'launcher-validation-workhorse.result.json'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'if not defined TBG_NO_PAUSE pause'
Assert-Contains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'exit /b %WORKHORSE_EXIT%'
Assert-NotContains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern '-RepoRoot "%~dp0"' -Label 'malformed trailing-slash RepoRoot argument'
Assert-NotContains -Path 'Run-LauncherValidationWorkhorse.cmd' -Pattern 'run-launcher-validation-workhorse.ps1" %*' -Label 'root wrapper bypasses multimodal supervisor'

Assert-Contains -Path 'Run-MarketIntel.cmd' -Pattern 'MarketSnapshotNow'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'AnalyzeFood'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'This does NOT buy food'
Assert-Contains -Path 'Run-FoodAdvisory.cmd' -Pattern 'BlacksmithGuild_FoodAdvisory.json'
Assert-Contains -Path 'Run-FoodGovernorCheck.cmd' -Pattern 'compatibility alias'
Assert-Contains -Path 'Run-FoodGovernorCheck.cmd' -Pattern 'Run-FoodAdvisory.cmd'
Assert-Contains -Path 'Run-HorseMarketIntel.cmd' -Pattern 'AnalyzeHorseMarket'
Assert-Contains -Path 'Run-GuildLoopAdvisory.cmd' -Pattern 'RunGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'run-autonomous-guild-loop-immediate.ps1'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'run-autonomous-guild-loop-operator.ps1'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'RunAutonomousGuildLoopNow'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'Default: run immediately'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'pass 3, 4, or 5'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern '-QuitGraceSec %~1'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'ForgeStop.cmd'
Assert-Contains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'autonomous-guild-loop-operator.json'
Assert-NotContains -Path 'Run-AutonomousGuildLoop.cmd' -Pattern 'alt-tab OK'
Assert-Contains -Path 'Run-CohesionAnalyze.cmd' -Pattern 'AnalyzeCohesionOpportunities'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'RunVisibleCohesionMoveNow'
Assert-Contains -Path 'Run-CohesionMove.cmd' -Pattern 'WARNING:'
Assert-Contains -Path 'Run-AutoTravelChoices.cmd' -Pattern 'ShowAutoTravelChoices'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ShowForgeStatus'
Assert-Contains -Path 'Run-TickCostProfilerSmoke.cmd' -Pattern 'ExportTbgEvidence.cmd'
Assert-Contains -Path 'Run-ExportEvidence.cmd' -Pattern 'ExportTbgEvidence.cmd'

Assert-Exists -Path 'scripts/run-autonomous-guild-loop-immediate.ps1'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'quitGraceSec = 0'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'SetEngineToggleAutomation'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'ResumeCampaignClock'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'RunAutonomousGuildLoopNow'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'FAILED_game_disappeared_during_command'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'BLOCKED_loop_not_terminal'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern '[System.Collections.Generic.List[object]]::new()'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern '$transitions.ToArray()'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'contextTransitions = $transitionSnapshot'
Assert-NotContains -Path 'scripts/run-autonomous-guild-loop-immediate.ps1' -Pattern 'contextTransitions = @($transitions)' -Label 'PowerShell 5.1 generic-list array coercion crash'
Assert-Exists -Path 'scripts/run-autonomous-guild-loop-operator.ps1'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern '[ValidateRange(3, 5)]'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'USER_QUIT_HONORED'
Assert-Contains -Path 'scripts/run-autonomous-guild-loop-operator.ps1' -Pattern 'USER_QUIT_REQUESTED'

Assert-Exists -Path 'scripts/run-launcher-validation-supervisor.ps1'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'TbgLauncherValidationSupervisorEvent.v1'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'TbgLauncherValidationSupervisor.v1'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'current_synced'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'current_local_commits'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'isolated_remote'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'isolated_local_snapshot'
Assert-Contains -Path 'scripts/run-launcher-validation-supervisor.ps1' -Pattern 'workspace_modes_exhausted'
Assert-Exists -Path 'scripts/run-launcher-validation-workhorse.ps1'
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern 'TbgSyntacticEnglishProgressEvent.v1'
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern 'TbgLauncherValidationWorkhorse.v1'
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern 'Write-EnglishEvent'
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern "@('merge', '--ff-only', `$remoteRef)"
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern 'ForgeContinue.cmd'
Assert-Contains -Path 'scripts/run-launcher-validation-workhorse.ps1' -Pattern 'launcher_handoff_observed'
Assert-Contains -Path 'docs/handoff/launcher-validation-workhorse.md' -Pattern 'Launcher Validation Workhorse'
Assert-Contains -Path 'docs/handoff/launcher-validation-workhorse.md' -Pattern 'Multimodal persistence'
Assert-Contains -Path 'docs/handoff/launcher-validation-workhorse.md' -Pattern 'Syntactic-English progress'
Assert-Contains -Path 'docs/handoff/launcher-validation-workhorse.md' -Pattern 'concurrent worktrees'

Assert-Exists -Path 'src/BlacksmithGuild/DevTools/OperatorAutomationContextController.cs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/OperatorAutomationContextController.cs' -Pattern 'ResumeCampaignClockCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/OperatorAutomationContextController.cs' -Pattern 'RunAutonomousGuildLoopNowCommand'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/OperatorAutomationContextController.cs' -Pattern 'BlacksmithGuild_OperatorAutomationContext.json'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevHotkeyHandler.cs' -Pattern 'OperatorAutomationContextController.HandleGlobalModeChanged(label)'

Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'public const string AnalyzeFoodCommand = "AnalyzeFood"'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'BlacksmithGuild_FoodAdvisory.json'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodAdvisoryService.cs' -Pattern 'BuyFoodSupported = false'
Assert-Contains -Path 'scripts/dev-command-names.ps1' -Pattern "'AnalyzeFood'"

Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Clickable Command Surface'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'prefer a root-level `.cmd` wrapper'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Run-AutonomousGuildLoop.cmd'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'Context-aware Autonomous Guild Loop'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'SetEngineToggleAutomation'
Assert-Contains -Path 'docs/clickable-command-surface.md' -Pattern 'ResumeCampaignClock'
Assert-Contains -Path 'docs/launch-and-doc-index.md' -Pattern 'clickable-command-surface.md'

Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'operator_context_controller'
Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'autonomous-guild-loop-operator.json'
Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'SetEngineToggleAutomation'
Assert-Contains -Path '.tbg/operator/control-surface.json' -Pattern 'ResumeCampaignClock'

Write-Host 'Clickable command surface contract: PASS'
