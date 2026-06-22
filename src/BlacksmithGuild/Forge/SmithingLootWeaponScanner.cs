using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingLootWeaponScanner
    {
        public static int CountSmeltableWeapons()
        {
            return EnumerateCandidates().Sum(candidate => candidate.Amount);
        }

        public static SmithingLootWeaponCandidate SelectBestCandidate()
        {
            return EnumerateCandidates().FirstOrDefault();
        }

        public static IReadOnlyList<SmithingLootWeaponCandidate> EnumerateCandidates()
        {
            var results = new List<SmithingLootWeaponCandidate>();
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return results;
            }

            var equippedIds = CollectEquippedItemIds();
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0)
                {
                    continue;
                }

                if (!IsWeaponItem(item))
                {
                    continue;
                }

                if (IsExcluded(item, equippedIds))
                {
                    continue;
                }

                var tier = ReadTier(item);
                if (tier > DevToolsConfig.SmithingSmeltMaxWeaponTier)
                {
                    continue;
                }

                results.Add(new SmithingLootWeaponCandidate
                {
                    ItemId = item.StringId,
                    ItemName = item.Name?.ToString() ?? item.StringId,
                    Amount = element.Amount,
                    Tier = tier,
                    Value = ReadValue(item),
                    RosterIndex = i
                });
            }

            return results
                .OrderBy(candidate => candidate.Tier)
                .ThenBy(candidate => candidate.Value)
                .ThenBy(candidate => candidate.ItemName)
                .ToList();
        }

        public static bool IsWeaponItem(ItemObject item)
        {
            if (item == null)
            {
                return false;
            }

            try
            {
                var type = item.ItemType;
                return type == ItemObject.ItemTypeEnum.OneHandedWeapon
                    || type == ItemObject.ItemTypeEnum.TwoHandedWeapon
                    || type == ItemObject.ItemTypeEnum.Polearm
                    || type == ItemObject.ItemTypeEnum.Thrown
                    || type == ItemObject.ItemTypeEnum.Bow
                    || type == ItemObject.ItemTypeEnum.Crossbow
                    || type == ItemObject.ItemTypeEnum.Shield
                    || type == ItemObject.ItemTypeEnum.Arrows
                    || type == ItemObject.ItemTypeEnum.Bolts;
            }
            catch
            {
                return false;
            }
        }

        private static bool IsExcluded(ItemObject item, HashSet<string> equippedIds)
        {
            if (item == null)
            {
                return true;
            }

            if (!string.IsNullOrEmpty(item.StringId) && equippedIds.Contains(item.StringId))
            {
                return true;
            }

            if (DevToolsConfig.SmithingSmeltRequireLootOnly && IsPlayerCrafted(item))
            {
                return true;
            }

            if (IsQuestItem(item))
            {
                return true;
            }

            return false;
        }

        private static bool IsPlayerCrafted(ItemObject item)
        {
            try
            {
                var property = item.GetType().GetProperty("IsCraftedByPlayer");
                if (property != null && property.GetValue(item) is bool crafted && crafted)
                {
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static bool IsQuestItem(ItemObject item)
        {
            try
            {
                if (!item.IsTradeGood && item.Value <= 0)
                {
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static HashSet<string> CollectEquippedItemIds()
        {
            var ids = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            var hero = Hero.MainHero;
            if (hero == null)
            {
                return ids;
            }

            AddEquipment(ids, hero.BattleEquipment);
            AddEquipment(ids, hero.CivilianEquipment);
            return ids;
        }

        private static void AddEquipment(HashSet<string> ids, Equipment equipment)
        {
            if (equipment == null)
            {
                return;
            }

            for (var slot = 0; slot < 12; slot++)
            {
                try
                {
                    var element = equipment[slot];
                    var item = element.Item;
                    if (item != null && !string.IsNullOrEmpty(item.StringId))
                    {
                        ids.Add(item.StringId);
                    }
                }
                catch
                {
                }
            }
        }

        private static int ReadTier(ItemObject item)
        {
            try
            {
                return (int)item.Tier;
            }
            catch
            {
                return 99;
            }
        }

        private static int ReadValue(ItemObject item)
        {
            try
            {
                return item.Value;
            }
            catch
            {
                return int.MaxValue;
            }
        }
    }
}
