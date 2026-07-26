param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'

function Read-RepoText {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Join-Path $RepoRoot $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Missing file: $Path"
    }

    return Get-Content -LiteralPath $fullPath -Raw
}

function Assert-Match {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NoMatch {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Text -match $Pattern) {
        throw $Message
    }
}

$governor = Read-RepoText 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs'
$foodAdapter = Read-RepoText 'src/BlacksmithGuild/CampaignRuntime/Adapters/FoodActivityAdapter.cs'
$mapTrade = Read-RepoText 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs'
$tradeAction = Read-RepoText 'src/BlacksmithGuild/MapTrade/MapTradeTradeActionReflection.cs'

Assert-Match `
    -Text $governor `
    -Pattern '(?s)FoodQuantityLow.*ResolveFoodResupplyTarget\(decision\).*resupplyTargetAvailable.*BranchFoodQuantity.*resupplyTargetAvailable.*food_resupply_target_missing' `
    -Message 'Critical/low food must be executable only when a current or destination settlement is resolved.'
Assert-Match `
    -Text $governor `
    -Pattern '(?s)case CampaignRuntimePolicy\.BranchFoodQuantity:.*CampaignActivityEngine\.Food.*AcquireFoodBeforeRunwayBreach.*foodTarget' `
    -Message 'The selected food priority must remain one Food activity targeted at the resupply settlement.'
Assert-Match `
    -Text $governor `
    -Pattern 'EngineToggleAuthority\.IsBoundedExecutionAllowed\(EngineToggleKey\.Governor\)\s*&& decision\.Allowed' `
    -Message 'Food mutation authority must remain gated by Automation-mode bounded governor authority.'
Assert-Match `
    -Text $governor `
    -Pattern 'one correlated MapTrade route cert from food-priority selection through travel/settlement handoff and a vanilla food buy with positive inventory and negative gold deltas' `
    -Message 'Food activity proof must require the complete correlated route-to-buy lineage.'
Assert-Match `
    -Text $governor `
    -Pattern '(?s)ResolveFoodResupplyTarget.*decision\.CurrentTown.*decision\.RouteCouncilRecommendedDestination.*decision\.DestinationCandidate' `
    -Message 'Food targeting must prefer the current settlement, then the route-council destination, then the observed candidate.'

Assert-Match `
    -Text $foodAdapter `
    -Pattern '(?s)if \(!request\.MutationAuthorized\).*CampaignActivityDispatcher\.Deferred.*if \(!gate\.ReadyForVanillaDriver\).*CampaignActivityDispatcher\.Blocked.*MapTradeAutonomousService\.TryStartGovernorFoodActivity\(request, out var startDetail\)' `
    -Message 'Manual/proposal and proof-gate checks must run before the MapTrade food activity can start.'
Assert-Match `
    -Text $foodAdapter `
    -Pattern '(?s)TryStartGovernorFoodActivity.*CampaignActivityDispatcher\.Started.*MapTrade owns the correlated travel, settlement, and vanilla food-buy phases' `
    -Message 'A successful handoff must remain Started until MapTrade reconciles terminal trade deltas.'
Assert-Match `
    -Text $foodAdapter `
    -Pattern '(?s)map_trade_food_start_blocked.*no travel, purchase, or completion claim was emitted' `
    -Message 'A failed MapTrade start must fail closed without a completion claim.'
Assert-NoMatch `
    -Text $foodAdapter `
    -Pattern 'RunProbeFoodBuyNow|CampaignActivityDispatcher\.Completed\(' `
    -Message 'The Food adapter must not bypass the correlated MapTrade activity or self-certify completion.'
Assert-NoMatch `
    -Text $foodAdapter `
    -Pattern 'food_vanilla_driver_not_wired' `
    -Message 'The obsolete unwired-driver blocker must not remain after the MapTrade handoff is connected.'

Assert-Match `
    -Text $mapTrade `
    -Pattern '(?s)TryStartGovernorFoodActivity.*CanStartGovernorActivity.*StartBranchRouteNow\(request\.TargetTown, source\).*_governorActivity = request.*GovernorActivity:Food:.*FoodProcurementAfterArrival' `
    -Message 'MapTrade must retain the same governor Food activity across the visible route and settlement handoffs.'
Assert-Match `
    -Text $mapTrade `
    -Pattern '(?s)AcquireFoodBeforeRunwayBreach.*RunProbeFoodBuyNow\(_activeReport\.Source\).*TradeExecution = MapTradeVanillaTradeDriver\.LastExecutionResult.*ExecuteFoodBuy:Success.*vanilla_trade_inventory_gold_delta_observed.*Finish\(MapTradeRouteState\.Complete' `
    -Message 'The route may complete only after the vanilla food driver returns a proven execution result.'
Assert-Match `
    -Text $mapTrade `
    -Pattern '(?s)RetrySettlementOrTrade\(\s*"ExecuteFoodBuy".*LastProbeDetail' `
    -Message 'A food-buy attempt without proof must remain in the bounded retry path.'
Assert-Match `
    -Text $mapTrade `
    -Pattern '(?s)ReconcileGovernorActivity.*execution\.InventoryAfter != execution\.InventoryBefore.*execution\.GoldDelta != 0.*CampaignActivityDispatcher\.Completed' `
    -Message 'Terminal MapTrade evidence must reconcile the retained governor activity with observed deltas.'
Assert-Match `
    -Text $tradeAction `
    -Pattern 'inventoryDelta > 0 && goldDelta < 0' `
    -Message 'The vanilla buy chokepoint must require a positive inventory delta and a negative gold delta.'

Write-Host 'Governor food MapTrade handoff contract PASS' -ForegroundColor Green
