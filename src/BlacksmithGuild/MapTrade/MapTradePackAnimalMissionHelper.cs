using System;
using System.Linq;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.HorseMarket;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradePackAnimalMissionHelper
    {
        public static bool IsUnderCapacityBuffer(MobileParty party)
        {
            if (party == null || Hero.MainHero == null)
            {
                return false;
            }

            try
            {
                var context = HorseMarketAnalyzer.BuildContext(party, Hero.MainHero);
                return context.Capacity.CurrentBufferPercent < DevToolsConfig.MapTradeTargetCapacityBufferPercent;
            }
            catch
            {
                return false;
            }
        }

        public static MapTradeMission TryBuildPackAnimalMission(MobileParty party)
        {
            if (party == null || !IsUnderCapacityBuffer(party))
            {
                return null;
            }

            MapTradeMission best = null;
            var bestScore = float.MinValue;

            foreach (var settlement in Settlement.All)
            {
                if (settlement == null || !settlement.IsTown)
                {
                    continue;
                }

                var distance = CampaignMapMovementHelper.Distance(party, settlement);
                if (distance > DevToolsConfig.MapTradeMaxRouteDistance)
                {
                    continue;
                }

                if (!TryFindCheapestPackAnimal(settlement, party, out var itemId, out var itemName, out var buyPrice, out var stock))
                {
                    continue;
                }

                var score = ScorePackMission(party, distance, buyPrice, stock);
                if (score <= bestScore)
                {
                    continue;
                }

                bestScore = score;
                best = new MapTradeMission
                {
                    MissionType = MapTradeMissionType.BuyPackAnimalForCapacityThenTrade,
                    ItemId = itemId,
                    ItemName = itemName,
                    TargetSettlement = settlement,
                    TargetSettlementName = settlement.Name?.ToString() ?? settlement.StringId,
                    Distance = distance,
                    BuyPrice = buyPrice,
                    Stock = stock,
                    Score = score
                };
            }

            return best;
        }

        public static bool HasPackAnimalStockAt(Settlement settlement, MobileParty party)
        {
            return TryFindCheapestPackAnimal(settlement, party, out _, out _, out _, out _);
        }

        public static bool TryGetCheapestPackOfferAtSettlement(
            Settlement settlement,
            MobileParty party,
            out string itemId,
            out string itemName,
            out int buyPrice,
            out int stock)
        {
            return TryFindCheapestPackAnimal(settlement, party, out itemId, out itemName, out buyPrice, out stock);
        }

        private static float ScorePackMission(MobileParty party, float distance, int buyPrice, int stock)
        {
            var context = HorseMarketAnalyzer.BuildContext(party, Hero.MainHero);
            var deficit = Math.Max(
                0f,
                (float)(DevToolsConfig.MapTradeTargetCapacityBufferPercent - context.Capacity.CurrentBufferPercent));
            var distanceScore = Math.Max(0f, DevToolsConfig.MapTradeMaxRouteDistance - distance);
            var pricePenalty = buyPrice > 0 ? 5000f / buyPrice : 0f;
            return deficit * 50f + distanceScore + pricePenalty + Math.Min(stock, 5);
        }

        private static bool TryFindCheapestPackAnimal(
            Settlement settlement,
            MobileParty party,
            out string itemId,
            out string itemName,
            out int buyPrice,
            out int stock)
        {
            itemId = null;
            itemName = null;
            buyPrice = 0;
            stock = 0;

            var roster = settlement?.ItemRoster;
            if (roster == null)
            {
                return false;
            }

            ItemObject bestItem = null;
            var bestPrice = int.MaxValue;
            var bestStock = 0;

            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0 || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item))
                {
                    continue;
                }

                var classification = HorseMarketClassifier.Classify(item);
                if (classification.Classification != HorseAnimalClassification.PackAnimal)
                {
                    continue;
                }

                var price = TryGetBuyPrice(settlement.Town, item, party);
                if (!price.HasValue || price.Value <= 0)
                {
                    continue;
                }

                if (price.Value >= bestPrice)
                {
                    continue;
                }

                bestPrice = price.Value;
                bestItem = item;
                bestStock = element.Amount;
            }

            if (bestItem == null)
            {
                return false;
            }

            itemId = bestItem.StringId ?? bestItem.Name?.ToString();
            itemName = bestItem.Name?.ToString() ?? itemId;
            buyPrice = bestPrice;
            stock = bestStock;
            return !string.IsNullOrEmpty(itemId);
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
    }
}
