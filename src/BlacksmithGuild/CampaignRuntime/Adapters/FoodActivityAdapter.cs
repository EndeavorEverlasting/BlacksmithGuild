using System;
using BlacksmithGuild.Food;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class FoodActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            if (request == null)
            {
                return false;
            }

            return string.Equals(request.TargetEngine, CampaignActivityEngine.Food.ToString(), StringComparison.OrdinalIgnoreCase)
                || string.Equals(request.Operation, "AcquireFoodBeforeRunwayBreach", StringComparison.OrdinalIgnoreCase);
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var food = FoodInventoryAnalyzer.Analyze(MobileParty.MainParty);
            var targetFoodItems = EstimateTargetFoodItems(food.TroopCount);
            var shortfall = Math.Max(0, targetFoodItems - food.TotalFoodItems);
            var detail =
                "food plan: current=" + food.TotalFoodItems
                + " target=" + targetFoodItems
                + " shortfall=" + shortfall
                + " uniqueTypes=" + food.UniqueFoodTypes
                + " troops=" + food.TroopCount
                + " dailyDemand=" + food.EstimatedDailyFoodDemand.ToString("0.##")
                + " daysRemaining=" + food.EstimatedDaysRemaining.ToString("0.##")
                + " daysUntilFloor=" + food.EstimatedDaysUntilFloor.ToString("0.##")
                + " forecast=" + food.ForecastStatus
                + " expectedProof=" + request.ExpectedProof;

            if (!request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Deferred(
                    request,
                    detail + "; execution disabled, proposal recorded only");
            }

            return CampaignActivityDispatcher.Blocked(
                request,
                detail + "; food purchase execution adapter is not implemented yet",
                "food_execution_not_implemented");
        }

        private static int EstimateTargetFoodItems(int troopCount)
        {
            var demand = FoodDemandPolicy.EstimateDailyDemand(troopCount);
            return Math.Max(
                FoodProtectionPolicy.MinimumFoodItemFloor,
                (int)Math.Ceiling(demand * FoodDemandPolicy.TargetFoodBufferDays));
        }
    }
}
