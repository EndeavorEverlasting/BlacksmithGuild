using System;

namespace BlacksmithGuild.Food
{
    public sealed class FoodProcurementPlan
    {
        public int CurrentFoodItems { get; set; }
        public int TargetFoodItems { get; set; }
        public int FoodShortfall { get; set; }
        public int CurrentUniqueFoodTypes { get; set; }
        public int TargetUniqueFoodTypes { get; set; }
        public int UniqueFoodTypeShortfall { get; set; }
        public int TroopCount { get; set; }
        public float EstimatedDailyDemand { get; set; }
        public float EstimatedDaysRemaining { get; set; }
        public float EstimatedDaysUntilFloor { get; set; }
        public string ForecastStatus { get; set; }
        public bool ProcurementNeeded { get; set; }
        public string Reason { get; set; }

        public string ToDetailString()
        {
            return "food plan: current=" + CurrentFoodItems
                + " target=" + TargetFoodItems
                + " shortfall=" + FoodShortfall
                + " uniqueTypes=" + CurrentUniqueFoodTypes
                + " targetUniqueTypes=" + TargetUniqueFoodTypes
                + " uniqueTypeShortfall=" + UniqueFoodTypeShortfall
                + " troops=" + TroopCount
                + " dailyDemand=" + EstimatedDailyDemand.ToString("0.##")
                + " daysRemaining=" + EstimatedDaysRemaining.ToString("0.##")
                + " daysUntilFloor=" + EstimatedDaysUntilFloor.ToString("0.##")
                + " forecast=" + ForecastStatus
                + " procurementNeeded=" + ProcurementNeeded
                + " reason=" + Reason;
        }
    }

    public static class FoodProcurementPlanner
    {
        public static FoodProcurementPlan Plan(FoodInventoryStatus food)
        {
            food = food ?? new FoodInventoryStatus
            {
                QuantityStatus = "unknown",
                DiversityStatus = "unknown",
                ForecastStatus = "unknown"
            };

            var targetFoodItems = EstimateTargetFoodItems(food.TroopCount);
            var foodShortfall = Math.Max(0, targetFoodItems - food.TotalFoodItems);
            var uniqueShortfall = Math.Max(0, FoodProtectionPolicy.MinimumFoodDiversityFloor - food.UniqueFoodTypes);
            var needed = food.NeedsFoodProcurement || foodShortfall > 0 || uniqueShortfall > 0;

            return new FoodProcurementPlan
            {
                CurrentFoodItems = food.TotalFoodItems,
                TargetFoodItems = targetFoodItems,
                FoodShortfall = foodShortfall,
                CurrentUniqueFoodTypes = food.UniqueFoodTypes,
                TargetUniqueFoodTypes = FoodProtectionPolicy.MinimumFoodDiversityFloor,
                UniqueFoodTypeShortfall = uniqueShortfall,
                TroopCount = food.TroopCount,
                EstimatedDailyDemand = food.EstimatedDailyFoodDemand,
                EstimatedDaysRemaining = food.EstimatedDaysRemaining,
                EstimatedDaysUntilFloor = food.EstimatedDaysUntilFloor,
                ForecastStatus = food.ForecastStatus,
                ProcurementNeeded = needed,
                Reason = BuildReason(food, foodShortfall, uniqueShortfall)
            };
        }

        public static int EstimateTargetFoodItems(int troopCount)
        {
            var demand = FoodDemandPolicy.EstimateDailyDemand(troopCount);
            return Math.Max(
                FoodProtectionPolicy.MinimumFoodItemFloor,
                (int)Math.Ceiling(demand * FoodDemandPolicy.TargetFoodBufferDays));
        }

        private static string BuildReason(FoodInventoryStatus food, int foodShortfall, int uniqueShortfall)
        {
            if (string.Equals(food.QuantityStatus, "critical", StringComparison.OrdinalIgnoreCase))
            {
                return "food quantity critical";
            }

            if (string.Equals(food.QuantityStatus, "low", StringComparison.OrdinalIgnoreCase))
            {
                return "food quantity below protected floor";
            }

            if (string.Equals(food.ForecastStatus, "critical", StringComparison.OrdinalIgnoreCase)
                || string.Equals(food.ForecastStatus, "low", StringComparison.OrdinalIgnoreCase))
            {
                return "food runway below planning horizon";
            }

            if (uniqueShortfall > 0)
            {
                return "food diversity below protected floor";
            }

            if (foodShortfall > 0)
            {
                return "food below target buffer";
            }

            return "food procurement not required";
        }
    }
}
