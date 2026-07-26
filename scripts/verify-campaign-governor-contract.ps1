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

function Assert-NotContains {
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
    if ($text -match [regex]::Escape($Pattern)) {
        throw "Forbidden '$Label' in $Path"
    }
}

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public sealed class CampaignRuntimeDecision'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public string SelectedBranch'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public bool ReportInsufficient'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public bool MapScanRequired'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public bool Allowed'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public string FoodForecastStatus'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeDecision.cs' -Pattern 'public CampaignActivityRequest ProposedActivity'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'public enum CampaignActivityMode'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'public sealed class CampaignActivityRequest'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'MutationAuthorized'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'RequiresInventoryDelta'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignActivityContract.cs' -Pattern 'ExpectedProof'

Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'RunCampaignGovernorCycleNow'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'MapTransitionGuard.ShouldDeferHeavyCampaignTouch()'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchFoodQuantity'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchFoodDiversity'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchCapacityPressure'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchReportInsufficient'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'AttachProposedActivity'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'AcquireFoodBeforeRunwayBreach'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern '_paused = true'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.Governor)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'EngineToggleAuthority.IsBoundedExecutionAllowed(EngineToggleKey.Governor)'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'MapTradeAutonomousService.IsRunning'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'public static void ReconcileActivityResult'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'Activity completed; select the next priority.'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchProfitableTrade, decision.TradeStatus, true'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'CampaignRuntimePolicy.BranchTravelOpportunity, decision.DestinationCandidate, true'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'ReadDecisionStage(source, "ReadDiplomacy"'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'ReadDecisionStage(source, "ReadThreat"'
Assert-Contains -Path 'src/BlacksmithGuild/CampaignRuntime/CampaignRuntimeGovernor.cs' -Pattern 'return false;'

Assert-Contains -Path 'src/BlacksmithGuild/Cohesion/CohesionPartyClassifier.cs' -Pattern 'return (party?.Party?.NumberOfAllMembers ?? 0) >= 80;'
Assert-NotContains -Path 'src/BlacksmithGuild/Cohesion/CohesionPartyClassifier.cs' `
    -Pattern 'var relation = ClassifyRelation(party, MobileParty.MainParty);' `
    -Label 'recursive neutral-party classification'

Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodInventoryAnalyzer.cs' -Pattern 'public static FoodInventoryStatus Analyze'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodInventoryAnalyzer.cs' -Pattern 'EstimatedDaysRemaining'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodInventoryAnalyzer.cs' -Pattern 'EstimatedDaysUntilFloor'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodInventoryAnalyzer.cs' -Pattern 'NeedsFoodProcurement'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodDemandPolicy.cs' -Pattern 'EstimatedFoodItemsPerTroopPerDay'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodDemandPolicy.cs' -Pattern 'TargetFoodBufferDays'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProtectionPolicy.cs' -Pattern 'MinimumFoodDiversityFloor'
Assert-Contains -Path 'src/BlacksmithGuild/Food/FoodProtectionPolicy.cs' -Pattern 'IsProtectedFood'

Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Automation/AutomationRuntimeEventEmitter.cs' -Pattern 'governor.decision.started'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Automation/AutomationRuntimeEventEmitter.cs' -Pattern 'governor.failsafe_pause'
Assert-Contains -Path 'src/BlacksmithGuild/DevTools/Automation/AutomationRuntimeEventEmitter.cs' -Pattern 'food.quantity.low'
Assert-Contains -Path 'src/BlacksmithGuild/Behaviors/BlacksmithGuildCampaignBehavior.cs' -Pattern 'CampaignRuntimeGovernor.OnCampaignTick();'

Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.MapTrade)'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'TryStartGovernorTradeActivity'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'TryStartGovernorTravelActivity'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'MaxSettlementTradeAttempts'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'TargetSettlementConfirmed'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'BlockedAfterBoundedRetry'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'no executable trade mission selected; travel-only fallback is not trade proof'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'ReconcileGovernorActivity(state, verdict, reason)'
Assert-Contains -Path 'src/BlacksmithGuild/MapTrade/MapTradeAutonomousService.cs' -Pattern 'Retain the terminal report in memory'

Write-Host 'Campaign governor contract: PASS'
