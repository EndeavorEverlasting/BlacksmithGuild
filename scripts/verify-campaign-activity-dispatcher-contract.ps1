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

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'interface ICampaignActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'bool CanHandle(CampaignActivityRequest request)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/ICampaignActivityAdapter.cs' -Pattern 'CampaignActivityResult TryHandle(CampaignActivityRequest request)'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'public sealed class CampaignActivityNarrativeDetail'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'public List<CampaignActivityNarrativeDetail> NarrativeDetails'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityNarrativeFactory.cs' -Pattern 'public static class CampaignActivityNarrativeFactory'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityNarrativeFactory.cs' -Pattern 'AttachDefault'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityNarrativeFactory.cs' -Pattern 'Activity result captured for downstream engine analysis.'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static class CampaignActivityEngineNarratives'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail Market'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail Trade'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail Smithing'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail Travel'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail HorseMarket'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityEngineNarratives.cs' -Pattern 'public static CampaignActivityNarrativeDetail Companion'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'narrativeDetails'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'AppendNarrativeDetails'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'AppendStringList(sb, "inputs"'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'AppendStringList(sb, "expectedOutputs"'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'public static CampaignActivityResult Dispatch(CampaignActivityRequest request)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'ICampaignActivityAdapter[] Adapters'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new FoodActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new MarketActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new TradeActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new SmithingActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new TravelActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new HorseMarketActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new CompanionActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'new DeferredActivityAdapter()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'request.MutationAuthorized'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityDispatcher.cs' -Pattern 'CampaignActivityNarrativeFactory.AttachDefault'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'public sealed class FoodActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'AcquireFoodBeforeRunwayBreach'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodInventoryAnalyzer.Analyze'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodProcurementPlanner.Plan'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodProcurementCandidatePlanner.Plan'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodMarketStockScanner.ScanCurrentSettlement'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodMarketCandidateMatcher.Match'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'AddFoodNarrative'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'Food engine evaluated runway, procurement candidates, read-only market stock, and execution proof readiness.'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'FoodProcurementExecutionGate.Evaluate'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs' -Pattern 'food_vanilla_driver_not_wired'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/MarketActivityAdapter.cs' -Pattern 'public sealed class MarketActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/MarketActivityAdapter.cs' -Pattern 'RefreshMarketScan'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/MarketActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.Market'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TradeActivityAdapter.cs' -Pattern 'public sealed class TradeActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TradeActivityAdapter.cs' -Pattern 'EvaluateOrExecuteTradeRoute'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TradeActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.Trade'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/SmithingActivityAdapter.cs' -Pattern 'public sealed class SmithingActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/SmithingActivityAdapter.cs' -Pattern 'PrepareOrExecuteSafeSmithing'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/SmithingActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.Smithing'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TravelActivityAdapter.cs' -Pattern 'public sealed class TravelActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TravelActivityAdapter.cs' -Pattern 'TravelToBestKnownOpportunity'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/TravelActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.Travel'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/HorseMarketActivityAdapter.cs' -Pattern 'public sealed class HorseMarketActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/HorseMarketActivityAdapter.cs' -Pattern 'AcquirePackAnimalForCapacity'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/HorseMarketActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.HorseMarket'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/CompanionActivityAdapter.cs' -Pattern 'public sealed class CompanionActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/CompanionActivityAdapter.cs' -Pattern 'EvaluateTavernRecruitment'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/CompanionActivityAdapter.cs' -Pattern 'CampaignActivityEngineNarratives.Companion'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/DeferredActivityAdapter.cs' -Pattern 'public sealed class DeferredActivityAdapter'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/Adapters/DeferredActivityAdapter.cs' -Pattern 'engine_adapter_not_implemented'

Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementPlan.cs' -Pattern 'public sealed class FoodProcurementPlan'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementPlan.cs' -Pattern 'public static class FoodProcurementPlanner'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementPlan.cs' -Pattern 'FoodShortfall'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementPlan.cs' -Pattern 'UniqueFoodTypeShortfall'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementPlan.cs' -Pattern 'TargetFoodBufferDays'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementCandidatePlan.cs' -Pattern 'public sealed class FoodProcurementCandidate'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementCandidatePlan.cs' -Pattern 'public sealed class FoodProcurementCandidatePlan'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementCandidatePlan.cs' -Pattern 'public static class FoodProcurementCandidatePlanner'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementCandidatePlan.cs' -Pattern 'diverse_food'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementCandidatePlan.cs' -Pattern 'any_food'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodMarketStockScan.cs' -Pattern 'public static class FoodMarketStockScanner'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodMarketStockScan.cs' -Pattern 'ScanCurrentSettlement'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodMarketStockScan.cs' -Pattern 'FindItemRoster'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodMarketStockScan.cs' -Pattern 'public static class FoodMarketCandidateMatcher'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodMarketStockScan.cs' -Pattern 'candidate matching completed against read-only market stock snapshot'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementExecutionGate.cs' -Pattern 'public static class FoodProcurementExecutionGate'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementExecutionGate.cs' -Pattern 'ProofRulesSatisfied'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementExecutionGate.cs' -Pattern 'ReadyForVanillaDriver'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProcurementExecutionGate.cs' -Pattern 'ready_for_vanilla_driver'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public CampaignActivityResult LatestActivityResult'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignActivityDispatcher.Dispatch(decision.ProposedActivity)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecisionWriter.cs' -Pattern 'latestActivityResult'

Write-Host 'Campaign activity dispatcher contract: PASS'
