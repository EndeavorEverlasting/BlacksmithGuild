using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeMissionSelector
    {
        private const int MinSurplusSellSpread = 5;

        private static readonly (string Id, string Name)[] SmithingInputs =
        {
            ("hardwood", "Hardwood"),
            ("charcoal", "Charcoal"),
            ("iron", "Iron Ore"),
            ("iron_ore", "Iron Ore"),
            ("crude_iron", "Crude Iron"),
            ("wrought_iron", "Wrought Iron"),
            ("steel", "Steel")
        };

        public static MapTradeMission SelectBestMission()
        {
            if (!MarketIntelligenceService.HasCachedScan
                && !MarketIntelligenceService.RunScanNow("MapTradeMissionSelector"))
            {
                return Blocked("market scan unavailable");
            }

            var main = MobileParty.MainParty;
            var candidates = new List<MapTradeMission>();

            var packMission = MapTradePackAnimalMissionHelper.TryBuildPackAnimalMission(main);
            if (packMission != null)
            {
                candidates.Add(packMission);
            }

            if (MarketIntelligenceService.TryGetBestSpreadRow(out var spreadRow))
            {
                var buySettlement = ResolveSettlement(spreadRow.BuyTown);
                var sellSettlement = ResolveSettlement(spreadRow.SellTown);
                if (buySettlement != null && sellSettlement != null)
                {
                    var distance = main != null
                        ? CampaignMapMovementHelper.Distance(main, buySettlement)
                        : float.MaxValue;

                    if (distance <= DevToolsConfig.MapTradeMaxRouteDistance)
                    {
                        candidates.Add(new MapTradeMission
                        {
                            MissionType = MapTradeMissionType.BuyProfitGoodAndSell,
                            ItemId = spreadRow.ItemId,
                            ItemName = spreadRow.ItemName,
                            TargetSettlement = buySettlement,
                            TargetSettlementName = buySettlement.Name?.ToString() ?? spreadRow.BuyTown,
                            SellSettlement = sellSettlement,
                            SellSettlementName = sellSettlement.Name?.ToString() ?? spreadRow.SellTown,
                            Distance = distance,
                            BuyPrice = spreadRow.BuyPrice,
                            SellPrice = spreadRow.SellPrice,
                            Score = ScoreSpreadMission(distance, spreadRow.Spread)
                        });
                    }
                }
            }

            foreach (var input in SmithingInputs)
            {
                if (!MarketIntelligenceService.TryFindBuyAtNearest(input.Id, input.Name, out var townName, out var buyPrice, out var stock))
                {
                    continue;
                }

                var settlement = ResolveSettlement(townName);
                if (settlement == null)
                {
                    continue;
                }

                var distance = main != null
                    ? CampaignMapMovementHelper.Distance(main, settlement)
                    : float.MaxValue;

                if (distance > DevToolsConfig.MapTradeMaxRouteDistance)
                {
                    continue;
                }

                var mission = new MapTradeMission
                {
                    MissionType = MapTradeMissionType.BuySmithingMaterialAndKeep,
                    ItemId = input.Id,
                    ItemName = input.Name,
                    TargetSettlement = settlement,
                    TargetSettlementName = settlement.Name?.ToString() ?? townName,
                    Distance = distance,
                    BuyPrice = buyPrice,
                    Stock = stock,
                    Score = ScoreForgeInput(distance, buyPrice, stock)
                };

                if (MarketIntelligenceService.TryGetTopInventorySellRow(out var surplus)
                    && surplus.SpreadVsWorst >= MinSurplusSellSpread)
                {
                    var sellSettlement = ResolveSettlement(surplus.BestSellTown);
                    if (sellSettlement != null)
                    {
                        mission = new MapTradeMission
                        {
                            MissionType = MapTradeMissionType.BuySmithingMaterialThenSellSurplus,
                            ItemId = input.Id,
                            ItemName = input.Name,
                            TargetSettlement = settlement,
                            TargetSettlementName = settlement.Name?.ToString() ?? townName,
                            SellSettlement = sellSettlement,
                            SellSettlementName = sellSettlement.Name?.ToString() ?? surplus.BestSellTown,
                            SellItemId = surplus.ItemId,
                            SellItemName = surplus.ItemName,
                            Distance = distance,
                            BuyPrice = buyPrice,
                            SellPrice = surplus.BestSellPrice,
                            Stock = stock,
                            Score = ScoreForgeInput(distance, buyPrice, stock) + surplus.SpreadVsWorst
                        };
                    }
                }

                candidates.Add(mission);
            }

            if (candidates.Count == 0)
            {
                var nearestTown = FindNearestTown(main);
                if (nearestTown != null && MapTradeBanditAvoidanceService.EvaluateRiskLevel() != "High")
                {
                    return new MapTradeMission
                    {
                        MissionType = MapTradeMissionType.TravelOnlySafetyCert,
                        TargetSettlement = nearestTown,
                        TargetSettlementName = nearestTown.Name?.ToString(),
                        Distance = CampaignMapMovementHelper.Distance(main, nearestTown),
                        Score = 1f
                    };
                }

                return Blocked("no forge procurement mission and travel-only fallback unavailable");
            }

            return candidates.OrderByDescending(m => m.Score).ThenBy(m => m.Distance).First();
        }

        public static bool NeedsCohesionCheck(MapTradeMission mission)
        {
            if (mission?.MissionType == MapTradeMissionType.BlockedNoSafeMission)
            {
                return true;
            }

            var risk = MapTradeBanditAvoidanceService.EvaluateRiskLevel();
            return risk == "Medium" || risk == "High";
        }

        public static bool NeedsSellExecution(MapTradeMission mission)
        {
            if (mission == null)
            {
                return false;
            }

            return mission.MissionType == MapTradeMissionType.BuySmithingMaterialThenSellSurplus
                || mission.MissionType == MapTradeMissionType.BuyProfitGoodAndSell
                || !string.IsNullOrWhiteSpace(mission.SellItemId);
        }

        public static bool ShouldAttemptSell(MapTradeMission mission, out MapTradeMission sellMission)
        {
            sellMission = null;
            if (mission == null)
            {
                return false;
            }

            var party = MobileParty.MainParty;
            var current = party?.CurrentSettlement;
            if (current == null)
            {
                return false;
            }

            var settlementName = current.Name?.ToString() ?? current.StringId;

            if (NeedsSellExecution(mission))
            {
                var sellItemId = !string.IsNullOrWhiteSpace(mission.SellItemId)
                    ? mission.SellItemId
                    : mission.ItemId;
                var sellSettlement = mission.SellSettlement ?? current;

                if (!string.Equals(
                        sellSettlement.Name?.ToString() ?? sellSettlement.StringId,
                        settlementName,
                        StringComparison.OrdinalIgnoreCase)
                    && mission.MissionType == MapTradeMissionType.BuyProfitGoodAndSell)
                {
                    return false;
                }

                sellMission = new MapTradeMission
                {
                    MissionType = mission.MissionType,
                    ItemId = sellItemId,
                    ItemName = !string.IsNullOrWhiteSpace(mission.SellItemName)
                        ? mission.SellItemName
                        : mission.ItemName,
                    TargetSettlement = sellSettlement,
                    TargetSettlementName = sellSettlement.Name?.ToString() ?? settlementName,
                    SellPrice = mission.SellPrice
                };
                return true;
            }

            if (!MarketIntelligenceService.HasCachedScan)
            {
                MarketIntelligenceService.RunScanNow("MapTradeMissionSelector.Sell");
            }

            if (!MarketIntelligenceService.TryFindSellCandidateAtSettlement(
                    settlementName,
                    out var itemId,
                    out var itemName,
                    out var sellPrice,
                    out _))
            {
                return false;
            }

            sellMission = new MapTradeMission
            {
                MissionType = MapTradeMissionType.BuyProfitGoodAndSell,
                ItemId = itemId,
                ItemName = itemName,
                TargetSettlement = current,
                TargetSettlementName = settlementName,
                SellPrice = sellPrice
            };
            return true;
        }

        public static MapTradeMission TryBuildSellProbeMission(Settlement settlement)
        {
            if (settlement == null)
            {
                return null;
            }

            if (!MarketIntelligenceService.HasCachedScan)
            {
                MarketIntelligenceService.RunScanNow("MapTradeMissionSelector.SellProbe");
            }

            var settlementName = settlement.Name?.ToString() ?? settlement.StringId;
            if (!MarketIntelligenceService.TryFindSellCandidateAtSettlement(
                    settlementName,
                    out var itemId,
                    out var itemName,
                    out var sellPrice,
                    out _))
            {
                return null;
            }

            return new MapTradeMission
            {
                MissionType = MapTradeMissionType.BuyProfitGoodAndSell,
                ItemId = itemId,
                ItemName = itemName,
                TargetSettlement = settlement,
                TargetSettlementName = settlementName,
                SellPrice = sellPrice
            };
        }

        private static float ScoreForgeInput(float distance, int buyPrice, int stock)
        {
            var distanceScore = Math.Max(0f, DevToolsConfig.MapTradeMaxRouteDistance - distance);
            var stockScore = Math.Min(stock, 50);
            var pricePenalty = buyPrice > 0 ? 10000f / buyPrice : 0f;
            return distanceScore + stockScore + pricePenalty;
        }

        private static float ScoreSpreadMission(float distance, int spread)
        {
            var distanceScore = Math.Max(0f, DevToolsConfig.MapTradeMaxRouteDistance - distance);
            return distanceScore + spread * 2f;
        }

        private static Settlement FindNearestTown(MobileParty party)
        {
            if (party == null)
            {
                return null;
            }

            Settlement best = null;
            var bestDistance = float.MaxValue;
            foreach (var settlement in Settlement.All)
            {
                if (settlement == null || !settlement.IsTown)
                {
                    continue;
                }

                var distance = CampaignMapMovementHelper.Distance(party, settlement);
                if (distance < bestDistance)
                {
                    bestDistance = distance;
                    best = settlement;
                }
            }

            return best;
        }

        private static Settlement ResolveSettlement(string townName)
        {
            if (string.IsNullOrWhiteSpace(townName))
            {
                return null;
            }

            return Settlement.All.FirstOrDefault(s =>
                s != null
                && s.IsTown
                && s.Name != null
                && string.Equals(s.Name.ToString(), townName, StringComparison.OrdinalIgnoreCase));
        }

        private static MapTradeMission Blocked(string reason)
        {
            return new MapTradeMission
            {
                MissionType = MapTradeMissionType.BlockedNoSafeMission,
                BlockReason = reason,
                Score = 0f
            };
        }
    }
}
