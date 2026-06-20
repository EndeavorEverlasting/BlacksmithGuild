namespace BlacksmithGuild.Forge
{
    public static class SmithingReservePolicy
    {
        public const int CharcoalFloor = 2;
        public const int HardwoodFloor = 4;
        public const int HardwoodPerCharcoal = 1;

        public static bool IsCharcoalItem(string itemId, string itemName)
        {
            return MatchesToken(itemId, itemName, "charcoal");
        }

        public static bool IsHardwoodItem(string itemId, string itemName)
        {
            return MatchesToken(itemId, itemName, "hardwood");
        }

        public static bool IsIronOreItem(string itemId, string itemName)
        {
            return MatchesToken(itemId, itemName, "iron_ore")
                || MatchesToken(itemId, itemName, "iron ore");
        }

        public static string DescribeReserveStatus(int have, int floor)
        {
            if (have < floor)
            {
                return "low";
            }

            return have == floor ? "at-floor" : "ok";
        }

        private static bool MatchesToken(string itemId, string itemName, string token)
        {
            if (!string.IsNullOrEmpty(itemId)
                && itemId.IndexOf(token, System.StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }

            return !string.IsNullOrEmpty(itemName)
                && itemName.IndexOf(token, System.StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
