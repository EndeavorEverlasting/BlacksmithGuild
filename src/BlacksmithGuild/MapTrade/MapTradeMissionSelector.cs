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
            try
            {
                return SelectBestMissionInner();
            }
            catch (Exception ex)
            {
                var reason = $"SelectBestMission crashed: {ex.GetType().Name}: {ex.Message}. "
                    + "BuyItemsAction was removed in Bannerlord v1.4.7 (Default Public Version). "
                    + "Switch to beta v1.4.6 in Steam > Properties > Game Versions & Betas.";
                DebugLogger.Test($"[TBG ENGINE ERROR] engine=MapTrade step=SelectBestMission ex={ex.GetType().Name}:{ex.Message}", showInGame: true);
                GuildLog.Info($"[ERROR] [MapTrade] {reason}", showInGame: true);
                return Blocked(reason);
            }
        }

        private static MapTradeMission SelectBestMissionInner()
        {
            DebugLogger.Test("[TBG ENGINE START] engine=MapTrade step=SelectBestMission:cachedScan", showInGame: false);
            if (!MarketIntelligenceService.HasCachedScan
                && !MarketIntelligenceService.RunScanNow("MapTradeMissionSelector"))
            {
                return Blocked("market scan unavailable");
            }
            DebugLogger.Test("[TBG ENGINE DONE] engine=MapTrade step=SelectBestMission:cachedScan", showInGame: false);

            var main = MobileParty.MainParty;
            var candidates = new List<MapTradeMission>();

            DebugLogger.Test("[TBG ENGINE START] engine=MapTrade step=SelectBestMission:packAnimal", showInGame: false);
            var packMission = MapTradePackAnimalMissionHelper.TryBuildPackAnimalMission(main);
            DebugLogger.Test($"[TBG ENGINE DONE] engine=MapTrade step=SelectBestMission:packAnimal found={packMission != null}", showInGame: false);
            if (packMission != null)
            {
                candidates.Add(packMission);
            }

            DebugLogger.Test("[TBG ENGINE START] engine=MapTrade step=SelectBestMission:smithingLoop", showInGame: false);
            foreach (var input in SmithingInputs)
            {
                if (!MarketIntelligenceService.TryFindBuyAtNearest(input.Id, input.Name, out var townName, out var buyPrice, out var stock))
                {
                    continue;
                }

                DebugLogger.Test($"[TBG ENGINE START] engine=MapTrade step=SelectBestMission:resolveSettlement town={townName}", showInGame: false);
                var settlement = ResolveSettlement(townName);
                DebugLogger.Test($"[TBG ENGINE DONE] engine=MapTrade step=SelectBestMission:resolveSettlement found={settlement != null}", showInGame: false);
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

                candidates.Add(new MapTradeMission
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
                });
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

        private static float ScoreForgeInput(float distance, int buyPrice, int stock)
        {
            var distanceScore = Math.Max(0f, DevToolsConfig.MapTradeMaxRouteDistance - distance);
            var stockScore = Math.Min(stock, 50);
            var pricePenalty = buyPrice > 0 ? 10000f / buyPrice : 0f;
            return distanceScore + stockScore + pricePenalty;
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
