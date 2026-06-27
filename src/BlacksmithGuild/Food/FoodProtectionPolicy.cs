using System;
using TaleWorlds.Core;

namespace BlacksmithGuild.Food
{
    public static class FoodProtectionPolicy
    {
        public const int MinimumFoodItemFloor = 8;
        public const int MinimumFoodDiversityFloor = 3;

        public static bool IsFoodItem(ItemObject item)
        {
            if (item == null)
            {
                return false;
            }

            try
            {
                if (item.IsFood)
                {
                    return true;
                }
            }
            catch
            {
            }

            var text = $"{item.StringId} {item.Name?.ToString()} {item.ItemCategory?.StringId}";
            return ContainsFoodToken(text);
        }

        public static bool IsProtectedFood(ItemObject item, int totalFoodItems)
        {
            if (!IsFoodItem(item))
            {
                return false;
            }

            return totalFoodItems <= MinimumFoodItemFloor;
        }

        private static bool ContainsFoodToken(string text)
        {
            if (string.IsNullOrWhiteSpace(text))
            {
                return false;
            }

            return text.IndexOf("grain", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("fish", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("meat", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("butter", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("cheese", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("date", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("grape", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("olive", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("beer", StringComparison.OrdinalIgnoreCase) >= 0
                || text.IndexOf("wine", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
