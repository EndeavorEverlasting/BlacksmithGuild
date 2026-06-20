using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingPartyInventory
    {
        public static int CountCharcoal() =>
            CountMatching(SmithingReservePolicy.IsCharcoalItem);

        public static int CountHardwood() =>
            CountMatching(SmithingReservePolicy.IsHardwoodItem);

        public static int CountItem(string itemId, string itemName)
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return 0;
            }

            var total = 0;
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null)
                {
                    continue;
                }

                if (MatchesItem(item.StringId, item.Name?.ToString(), itemId, itemName))
                {
                    total += element.Amount;
                }
            }

            return total;
        }

        private static int CountMatching(System.Func<string, string, bool> matcher)
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return 0;
            }

            var total = 0;
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null)
                {
                    continue;
                }

                if (matcher(item.StringId, item.Name?.ToString()))
                {
                    total += element.Amount;
                }
            }

            return total;
        }

        private static bool MatchesItem(string leftId, string leftName, string rightId, string rightName)
        {
            if (!string.IsNullOrEmpty(leftId)
                && !string.IsNullOrEmpty(rightId)
                && string.Equals(leftId, rightId, System.StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName)
                && !string.IsNullOrEmpty(rightName)
                && string.Equals(leftName, rightName, System.StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName) && !string.IsNullOrEmpty(rightName))
            {
                return leftName.IndexOf(rightName, System.StringComparison.OrdinalIgnoreCase) >= 0
                    || rightName.IndexOf(leftName, System.StringComparison.OrdinalIgnoreCase) >= 0;
            }

            return false;
        }
    }
}
