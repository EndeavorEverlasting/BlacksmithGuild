param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version Latest
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

$policyPath = Join-Path $RepoRoot '.tbg/operator/worker-cadence.json'
$policy = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json
if ($policy.marketRefreshKnowledge.bannerlordInternalScheduleKnown -ne $false) {
    throw 'Policy must not claim a known Bannerlord market refresh schedule.'
}
if ($policy.marketRefreshKnowledge.automaticContinuousScan -ne $false) {
    throw 'Policy must forbid automatic continuous market scanning.'
}
if ($policy.workers.Count -lt 7) {
    throw 'Policy must enumerate every bounded campaign worker.'
}

Assert-Contains 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' 'GameSessionStateRealtimeRefreshIntervalMs = 100'
Assert-Contains 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' 'CampaignRuntimeGovernorDecisionIntervalMs = 10000'
Assert-Contains 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' 'MapTradeBranchStatePollIntervalMs = 2000'
Assert-Contains 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' 'AssistMovementObservationIntervalMs = 250'
Assert-Contains 'src/BlacksmithGuild/DevTools/DevToolsConfig.cs' 'MovementProofMaxSamples = 64'
Assert-Contains 'src/BlacksmithGuild/DevTools/RuntimeCadenceGate.cs' 'public static bool TryEnter(string worker, int intervalMs, int hardMinimumMs = 25)'
Assert-Contains 'src/BlacksmithGuild/DevTools/RuntimeCadenceGate.cs' 'attemptedCount'
Assert-Contains 'src/BlacksmithGuild/DevTools/RuntimeCadenceGate.cs' 'throttledCount'
Assert-Contains 'src/BlacksmithGuild/DevTools/RuntimeCadenceGate.cs' 'BlacksmithGuild_RuntimeCadence.json'

Assert-Contains 'src/BlacksmithGuild/DevTools/GameSessionState.cs' 'public static void RefreshForRealtimeTick()'
Assert-Contains 'src/BlacksmithGuild/DevTools/RuntimeLifecycleWriter.cs' 'RuntimeLifecycleHeartbeatWriteIntervalMs'
Assert-Contains 'src/BlacksmithGuild/DevTools/DevCommandFileInbox.cs' 'TryGetPendingInboxWrite(out var writeTicks)'
Assert-Contains 'src/BlacksmithGuild/HorseMarket/HorseMarketAtlasService.cs' 'HorseMarketAtlasMaxScanSettlementCount'
Assert-Contains 'src/BlacksmithGuild/HorseMarket/HorseMarketAtlasService.cs' 'campaignAgeHours'
Assert-Contains 'src/BlacksmithGuild/HorseMarket/HerdLedgerService.cs' 'campaignAgeHours'
Assert-Contains 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeStatusReaders.cs' 'return "not_applicable:not_in_town";'
Assert-Contains 'src/BlacksmithGuild/DevTools/AutoTravelService.cs' 'AssistMovementObservationIntervalMs'
Assert-Contains 'src/BlacksmithGuild/DevTools/AutoTravelService.cs' 'AssistMovementEvidenceWriteIntervalMs'
Assert-Contains 'src/BlacksmithGuild/DevTools/Assistive/MovementProofLedgerService.cs' 'MovementProofMaxSamples'
Assert-Contains 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' '_lastBranchBlockEvidenceKey'
Assert-Contains 'src/BlacksmithGuild/GuildLoop/AutonomousGuildLoopService.cs' 'GuildLoopActiveMonitorIntervalMs'
Assert-Contains 'src/BlacksmithGuild/Cohesion/CohesionExecutionDriver.cs' 'CohesionActiveMonitorIntervalMs'
Assert-Contains 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' 'CampaignRuntimeGovernor.Decision'

Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'public static bool EnsureFreshScan(string source)'
Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'public static void OnDailyTick()'
Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'on_demand_event_or_ttl'
Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'MarketIntelligenceService.RunScanNow'
Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'priceLookupCount'
Assert-Contains 'src/BlacksmithGuild/Market/MarketIntelligenceService.cs' 'candidateItemCount'
Assert-Contains 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeStatusReaders.cs' 'Governor status collection is observe-only'
Assert-Contains 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' 'MarketIntelligenceService.OnDailyTick()'
Assert-Contains 'src/BlacksmithGuild/MapTrade/MapTradeVanillaTradeDriver.cs' 'MarketIntelligenceService.InvalidateCache("trade_completed")'
Assert-Contains 'src/BlacksmithGuild/Forge/SmithingSafeActionService.cs' 'MarketIntelligenceService.InvalidateCache("smithing_inventory_changed")'
Assert-Contains 'src/BlacksmithGuild/Forge/SmithingSmeltService.cs' 'MarketIntelligenceService.InvalidateCache("smithing_inventory_changed")'
Assert-Contains 'docs/operator/worker-cadence-and-market-refresh.md' 'does not assume that Bannerlord refreshes markets'

Write-Host 'Worker cadence and market refresh contract: PASS'
