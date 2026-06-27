using System;
using System.Collections.Generic;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.Food
{
    public static class FoodInventoryAnalyzer
    {
        public static FoodInventoryStatus Analyze(MobileParty party)
        {
            var status = new FoodInventoryStatus();
            if (party?.ItemRoster == null)
            {
                status.QuantityStatus = "unknown";
                status.DiversityStatus = "unknown";
                status.ForecastStatus = "unknown";
                status.Detail = "party inventory unavailable";
                return status;
            }

            var unique = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0 || !FoodProtectionPolicy.IsFoodItem(item))
                {
                    continue;
                }

                status.TotalFoodItems += element.Amount;
                unique.Add(item.StringId ?? item.Name?.ToString() ?? "unknown_food");
            }

            status.UniqueFoodTypes = unique.Count;
            status.TroopCount = ResolveTroopCount(party);
            status.EstimatedDailyFoodDemand = FoodDemandPolicy.EstimateDailyDemand(status.TroopCount);
            status.EstimatedDaysRemaining = status.EstimatedDailyFoodDemand <= 0f
                ? 999f
                : status.TotalFoodItems / status.EstimatedDailyFoodDemand;
            status.EstimatedDaysUntilFloor = status.EstimatedDailyFoodDemand <= 0f
                ? 999f
                : Math.Max(0f, status.TotalFoodItems - FoodProtectionPolicy.MinimumFoodItemFloor) / status.EstimatedDailyFoodDemand;

            status.QuantityStatus = status.TotalFoodItems <= 0
                ? "critical"
                : status.TotalFoodItems < FoodProtectionPolicy.MinimumFoodItemFloor
                    ? "low"
                    : "ok";
            status.DiversityStatus = status.UniqueFoodTypes < FoodProtectionPolicy.MinimumFoodDiversityFloor
                ? "low"
                : "ok";
            status.ForecastStatus = FoodDemandPolicy.ClassifyForecast(
                status.EstimatedDaysRemaining,
                status.EstimatedDaysUntilFloor);
            status.NeedsFoodProcurement = status.QuantityStatus != "ok"
                || status.DiversityStatus != "ok"
                || status.ForecastStatus == "critical"
                || status.ForecastStatus == "low";
            status.Detail =
                $"foodItems={status.TotalFoodItems} uniqueTypes={status.UniqueFoodTypes} troops={status.TroopCount} dailyDemand={status.EstimatedDailyFoodDemand:0.##} daysRemaining={status.EstimatedDaysRemaining:0.##} daysUntilFloor={status.EstimatedDaysUntilFloor:0.##}";
            return status;
        }

        private static int ResolveTroopCount(MobileParty party)
        {
            try
            {
                return Math.Max(1, party.MemberRoster.TotalManCount);
            }
            catch
            {
                return 1;
            }
        }
    }

    public sealed class FoodInventoryStatus
    {
        public int TotalFoodItems { get; set; }
        public int UniqueFoodTypes { get; set; }
        public int TroopCount { get; set; }
        public float EstimatedDailyFoodDemand { get; set; }
        public float EstimatedDaysRemaining { get; set; }
        public float EstimatedDaysUntilFloor { get; set; }
        public string QuantityStatus { get; set; }
        public string DiversityStatus { get; set; }
        public string ForecastStatus { get; set; }
        public bool NeedsFoodProcurement { get; set; }
        public string Detail { get; set; }
    }
}
