param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [string]$Label = $Pattern
    )

    $full = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $full)) {
        throw "Missing file: $Path"
    }

    $text = Get-Content -LiteralPath $full -Raw
    if ($text -notmatch [regex]::Escape($Pattern)) {
        throw "Missing '$Label' in $Path"
    }
}

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'public static class TickCostProfiler'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'BlacksmithGuild_TickCostProfiler.json'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'public static long Start()'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'public static void Stop(string segmentName, long startedAt)'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'TickCostProfilerSlowThresholdMs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'TickCostProfilerMinWriteIntervalMs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'slowCount'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'averageMs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Reporting/TickCostProfiler.cs' -Pattern 'maxMs'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' -Pattern 'TickCostProfilerEnabled'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' -Pattern 'TickCostProfilerSlowThresholdMs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' -Pattern 'TickCostProfilerMinWriteIntervalMs'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' -Pattern 'TickCostProfilerWritePeriodicSnapshots'

Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Start()'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("GameSessionState.Refresh"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("CampaignMapReadyOrchestrator.OnCampaignTick"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("LaunchPathInference.AreAutonomousDriversBlocked"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("CampaignRuntimeGovernor.OnCampaignTick"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("TreasuryDeltaWatchService.ProcessPendingSnapshot"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("AutoTravelService.OnCampaignTick"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("CohesionExecutionDriver.OnCampaignTick"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("MapTradeAutonomousService.OnCampaignTick"'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'TickCostProfiler.Stop("AutonomousGuildLoopService.OnCampaignTick"'

Write-Host 'Tick cost profiler contract: PASS'
