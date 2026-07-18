namespace BlacksmithGuild.Food
{
    public static class FoodDemandPolicy
    {
        // Conservative planning estimate for governor decisions. This is not a hidden mutation rule.
        // The value exists so the governor can plan before food reaches crisis state.
        public const float EstimatedFoodItemsPerTroopPerDay = 1.0f;

        public const float CriticalFoodBufferDays = 1.0f;
        public const float MinimumFoodBufferDays = 3.0f;
        public const float TargetFoodBufferDays = 7.0f;
        public const float WatchFoodBufferDays = 5.0f;

        public static string ClassifyForecast(float estimatedDaysRemaining, float daysUntilFloor)
        {
            if (estimatedDaysRemaining <= CriticalFoodBufferDays || daysUntilFloor <= 0f)
            {
                return "critical";
            }

            if (estimatedDaysRemaining <= MinimumFoodBufferDays || daysUntilFloor <= MinimumFoodBufferDays)
            {
                return "low";
            }

            if (estimatedDaysRemaining <= WatchFoodBufferDays || daysUntilFloor <= WatchFoodBufferDays)
            {
                return "watch";
            }

            return "ok";
        }

        public static float EstimateDailyDemand(int troopCount)
        {
            return troopCount <= 0 ? 0f : troopCount * EstimatedFoodItemsPerTroopPerDay;
        }
    }
}
