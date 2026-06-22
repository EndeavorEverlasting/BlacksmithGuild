using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Roster;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;

namespace BlacksmithGuild.HorseMarket
{
    public static class HorseMarketAnalyzer
    {
        public static HorseMarketAnalysisContext BuildContext(MobileParty party, Hero hero)
        {
            var (settlement, resolveMethod) = ResolveSettlement(party);
            var context = new HorseMarketAnalysisContext
            {
                SessionPhase = GameSessionState.Phase.ToString(),
                SettlementResolveMethod = resolveMethod,
                UpgradeDemandAvailable = false,
                Settlement = BuildSettlementSnapshot(settlement),
                Player = BuildPlayerSnapshot(hero),
                Capacity = BuildCapacitySnapshot(party),
                Herd = BuildHerdSnapshot(party),
                PlayerAnimals = BuildPlayerAnimals(party?.ItemRoster),
                MarketAnimals = BuildMarketAnimals(settlement, party)
            };

            ScoreMarketAnimals(context.MarketAnimals, context.Capacity);
            return context;
        }

        private static (Settlement settlement, string resolveMethod) ResolveSettlement(MobileParty party)
        {
            try
            {
                var partySettlement = party?.CurrentSettlement;
                if (partySettlement != null)
                {
                    return (partySettlement, "partyCurrentSettlement");
                }
            }
            catch
            {
            }

            try
            {
                var encounterSettlement = GameSessionState.ResolveCurrentSettlement();
                if (encounterSettlement != null)
                {
                    return (encounterSettlement, "playerEncounter");
                }
            }
            catch
            {
            }

            return (null, "none");
        }

        private static HorseMarketSettlementSnapshot BuildSettlementSnapshot(Settlement settlement)
        {
            var snapshot = new HorseMarketSettlementSnapshot();
            if (settlement == null)
            {
                snapshot.MarketAvailable = false;
                snapshot.BlockedReason = "party not at a settlement";
                return snapshot;
            }

            snapshot.Name = settlement.Name?.ToString() ?? settlement.StringId;
            snapshot.StringId = settlement.StringId;
            snapshot.Type = ResolveSettlementType(settlement);
            snapshot.MarketAvailable = settlement.ItemRoster != null
                                       && (settlement.IsTown || settlement.IsVillage || settlement.IsCastle);
            if (!snapshot.MarketAvailable)
            {
                snapshot.BlockedReason = "settlement has no market roster";
            }

            return snapshot;
        }

        private static HorseMarketPlayerSnapshot BuildPlayerSnapshot(Hero hero)
        {
            var gold = 0;
            try
            {
                gold = hero?.Gold ?? 0;
            }
            catch
            {
                gold = 0;
            }

            var reserve = HorseMarketDoctrine.DefaultSafeGoldReserve;
            return new HorseMarketPlayerSnapshot
            {
                Gold = gold,
                SafeGoldReserve = reserve,
                SpendableGold = Math.Max(0, gold - reserve)
            };
        }

        private static HorseMarketCapacitySnapshot BuildCapacitySnapshot(MobileParty party)
        {
            var capacity = new HorseMarketCapacitySnapshot
            {
                TargetBufferPercent = HorseMarketDoctrine.TargetBufferPercent
            };

            if (party == null)
            {
                return capacity;
            }

            try
            {
                capacity.CurrentCapacity = party.InventoryCapacity;
            }
            catch
            {
                capacity.CurrentCapacity = 0f;
            }

            try
            {
                capacity.CurrentCarriedWeight = party.TotalWeightCarried;
            }
            catch
            {
                capacity.CurrentCarriedWeight = ComputeRosterWeight(party.ItemRoster);
            }

            capacity.CurrentFreeCapacity = Math.Max(0f, capacity.CurrentCapacity - capacity.CurrentCarriedWeight);
            capacity.CurrentBufferPercent = capacity.CurrentCapacity > 0f
                ? capacity.CurrentFreeCapacity / capacity.CurrentCapacity * 100.0
                : 0.0;

            var targetFree = (float)(capacity.CurrentCapacity * (HorseMarketDoctrine.TargetBufferPercent / 100.0));
            capacity.CapacityDeficit = Math.Max(0f, targetFree - capacity.CurrentFreeCapacity);
            capacity.ProjectedBufferAfterRecommendedBuys = capacity.CurrentBufferPercent;
            return capacity;
        }

        private static HorseMarketHerdSnapshot BuildHerdSnapshot(MobileParty party)
        {
            var herd = new HorseMarketHerdSnapshot
            {
                HerdModelAvailable = false,
                HerdPenaltyObserved = null
            };

            if (party == null)
            {
                return herd;
            }

            try
            {
                herd.SpeedSummary = $"speed={party.Speed:0.##}";
                herd.HerdModelAvailable = true;
            }
            catch
            {
                herd.SpeedSummary = null;
            }

            try
            {
                var spareMounts = CountSpareMounts(party);
                var troopCount = party.MemberRoster?.TotalManCount ?? 0;
                if (spareMounts > Math.Max(2, troopCount / 4))
                {
                    herd.HerdPenaltyObserved = true;
                    herd.HerdPenaltyText = $"spare mounts={spareMounts} vs troops={troopCount}";
                }
                else if (spareMounts > 0)
                {
                    herd.HerdPenaltyObserved = false;
                    herd.HerdPenaltyText = $"spare mounts={spareMounts}";
                }
            }
            catch
            {
                herd.HerdPenaltyText = null;
            }

            return herd;
        }

        private static List<HorseAnimalSnapshot> BuildPlayerAnimals(ItemRoster roster)
        {
            var animals = new List<HorseAnimalSnapshot>();
            if (roster == null)
            {
                return animals;
            }

            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0 || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item))
                {
                    continue;
                }

                animals.Add(BuildAnimalSnapshot(item, element.Amount, askPrice: null));
            }

            return animals;
        }

        private static List<HorseAnimalSnapshot> BuildMarketAnimals(Settlement settlement, MobileParty party)
        {
            var animals = new List<HorseAnimalSnapshot>();
            if (settlement == null)
            {
                return animals;
            }

            var roster = settlement.ItemRoster;
            if (roster == null)
            {
                return animals;
            }

            var town = settlement.Town;
            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0 || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item))
                {
                    continue;
                }

                var askPrice = TryGetBuyPrice(town, item, party);
                animals.Add(BuildAnimalSnapshot(item, element.Amount, askPrice));
            }

            return animals.OrderBy(a => a.AskPrice ?? int.MaxValue).ToList();
        }

        private static HorseAnimalSnapshot BuildAnimalSnapshot(ItemObject item, int count, int? askPrice)
        {
            var classification = HorseMarketClassifier.Classify(item);
            var snapshot = new HorseAnimalSnapshot
            {
                StringId = item.StringId ?? item.Name?.ToString() ?? "unknown",
                Name = item.Name?.ToString() ?? item.StringId ?? "unknown",
                Count = count,
                Value = SafeValue(item),
                Weight = SafeWeight(item),
                ItemCategory = SafeCategory(item),
                ItemType = SafeItemType(item),
                Tier = SafeTier(item),
                HasHorseComponent = HasHorseComponent(item),
                Speed = SafeSpeed(item),
                Maneuver = SafeManeuver(item),
                ChargeDamage = SafeChargeDamage(item),
                HitPoints = SafeHitPoints(item),
                IsMountable = SafeIsMountable(item),
                Classification = classification.Classification,
                ClassificationConfidence = classification.Confidence,
                ClassificationReason = classification.Reason,
                AskPrice = askPrice,
                BaseValue = SafeValue(item)
            };

            snapshot.CapacityUtilityScore = HorseMarketClassifier.EstimateCapacityContribution(
                item,
                snapshot.Classification);
            snapshot.QualityScore = snapshot.Tier + (snapshot.Maneuver ?? 0f) * 0.01f + (snapshot.ChargeDamage ?? 0f) * 0.02f;
            snapshot.UpgradeUtilityScore = snapshot.Classification == HorseAnimalClassification.WarMount
                                           || snapshot.Classification == HorseAnimalClassification.NobleMount
                ? snapshot.QualityScore
                : 0.0;
            return snapshot;
        }

        private static void ScoreMarketAnimals(List<HorseAnimalSnapshot> animals, HorseMarketCapacitySnapshot capacity)
        {
            foreach (var animal in animals)
            {
                if (!animal.AskPrice.HasValue || !animal.BaseValue.HasValue || animal.BaseValue.Value <= 0)
                {
                    animal.ProfitScore = 0;
                    animal.RiskFlags.Add("price_unknown");
                    continue;
                }

                var ratio = (double)animal.AskPrice.Value / animal.BaseValue.Value;
                animal.ProfitScore = ratio <= HorseMarketDoctrine.ProfitVsBaseValueThreshold
                    ? (1.0 - ratio) * 100.0
                    : 0.0;

                if (capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent
                    && animal.Classification != HorseAnimalClassification.PackAnimal)
                {
                    animal.RiskFlags.Add("not_pack_while_under_buffer");
                }
            }
        }

        private static int? TryGetBuyPrice(Town town, ItemObject item, MobileParty party)
        {
            if (town == null || item == null)
            {
                return null;
            }

            try
            {
                var price = town.GetItemPrice(item, party, isSelling: false);
                return price > 0 ? price : (int?)null;
            }
            catch
            {
                try
                {
                    var market = town.MarketData;
                    if (market == null)
                    {
                        return null;
                    }

                    var price = market.GetPrice(item, party, isSelling: false, town.Settlement?.Party);
                    return price > 0 ? price : (int?)null;
                }
                catch
                {
                    return null;
                }
            }
        }

        private static int CountSpareMounts(MobileParty party)
        {
            var mounts = 0;
            var roster = party.ItemRoster;
            if (roster == null)
            {
                return 0;
            }

            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item))
                {
                    continue;
                }

                mounts += element.Amount;
            }

            return mounts;
        }

        private static float ComputeRosterWeight(ItemRoster roster)
        {
            if (roster == null)
            {
                return 0f;
            }

            var total = 0f;
            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null)
                {
                    continue;
                }

                total += item.Weight * element.Amount;
            }

            return total;
        }

        private static string ResolveSettlementType(Settlement settlement)
        {
            if (settlement.IsTown)
            {
                return "Town";
            }

            if (settlement.IsVillage)
            {
                return "Village";
            }

            if (settlement.IsCastle)
            {
                return "Castle";
            }

            return "Settlement";
        }

        private static int SafeValue(ItemObject item)
        {
            try
            {
                return item.Value;
            }
            catch
            {
                return 0;
            }
        }

        private static float SafeWeight(ItemObject item)
        {
            try
            {
                return item.Weight;
            }
            catch
            {
                return 0f;
            }
        }

        private static string SafeCategory(ItemObject item)
        {
            try
            {
                return item?.ItemCategory?.StringId ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        private static string SafeItemType(ItemObject item)
        {
            try
            {
                return item.ItemType.ToString();
            }
            catch
            {
                return string.Empty;
            }
        }

        private static int SafeTier(ItemObject item)
        {
            try
            {
                return (int)item.Tier;
            }
            catch
            {
                return 0;
            }
        }

        private static bool HasHorseComponent(ItemObject item)
        {
            try
            {
                return item.HorseComponent != null;
            }
            catch
            {
                return false;
            }
        }

        private static float? SafeSpeed(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.Speed;
            }
            catch
            {
                return null;
            }
        }

        private static float? SafeManeuver(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.Maneuver;
            }
            catch
            {
                return null;
            }
        }

        private static float? SafeChargeDamage(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.ChargeDamage;
            }
            catch
            {
                return null;
            }
        }

        private static int? SafeHitPoints(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.HitPoints;
            }
            catch
            {
                return null;
            }
        }

        private static bool? SafeIsMountable(ItemObject item)
        {
            try
            {
                return item.HorseComponent != null;
            }
            catch
            {
                return null;
            }
        }
    }
}
