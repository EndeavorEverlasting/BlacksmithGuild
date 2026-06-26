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
            status.QuantityStatus = status.TotalFoodItems <= 0
                ? "critical"
                : status.TotalFoodItems < FoodProtectionPolicy.MinimumFoodItemFloor
                    ? "low"
                    : "ok";
            status.DiversityStatus = status.UniqueFoodTypes < FoodProtectionPolicy.MinimumFoodDiversityFloor
                ? "low"
                : "ok";
            status.Detail = $"foodItems={status.TotalFoodItems} uniqueTypes={status.UniqueFoodTypes}";
            return status;
        }
    }

    public sealed class FoodInventoryStatus
    {
        public int TotalFoodItems { get; set; }
        public int UniqueFoodTypes { get; set; }
        public string QuantityStatus { get; set; }
        public string DiversityStatus { get; set; }
        public string Detail { get; set; }
    }
}
