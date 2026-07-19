using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.DevTools.Diagnostics;
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
            var span = AutomationRuntimeEventEmitter.BeginSpan(
                "MapTradeMissionSelector.SelectBestMission",
                expectedSignal: "mission_selected_or_blocked",
                preState: RuntimeStateSnapshot.Capture("mission-selector.pre"));
            try
            {
                if (!MarketIntelligenceService.HasCachedScan)
                {
                    var marketScan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.MarketScan",
                        span,
                        expectedSignal: "market_scan_cached",
                        preState: RuntimeStateSnapshot.Capture("market-scan.pre"));
                    if (!MarketIntelligenceService.RunScanNow("MapTradeMissionSelector"))
                    {
                        AutomationRuntimeEventEmitter.BlockSpan(marketScan, "market scan unavailable", RuntimeStateSnapshot.Capture("market-scan.blocked"));
                        var blocked = Blocked("market scan unavailable");
                        AutomationRuntimeEventEmitter.BlockSpan(span, blocked.BlockReason, RuntimeStateSnapshot.Capture("mission-selector.blocked"));
                        return blocked;
                    }

                    AutomationRuntimeEventEmitter.CompleteSpan(marketScan, "market_scan_cached", RuntimeStateSnapshot.Capture("market-scan.post"));
                }

                var main = MobileParty.MainParty;
                var candidates = new List<MapTradeMission>();

                var packEvaluation = AutomationRuntimeEventEmitter.BeginSpan(
                    "MapTradeMissionSelector.PackMissionEvaluation",
                    span,
                    expectedSignal: "pack_mission_evaluated",
                    preState: RuntimeStateSnapshot.Capture("pack-mission.pre", candidateCount: candidates.Count));
                var packMission = MapTradePackAnimalMissionHelper.TryBuildPackAnimalMission(main);
                if (packMission != null)
                {
                    candidates.Add(packMission);
                }
                AutomationRuntimeEventEmitter.CompleteSpan(packEvaluation, "pack_mission_evaluated", RuntimeStateSnapshot.Capture("pack-mission.post", candidateCount: candidates.Count));

                foreach (var input in SmithingInputs)
                {
                    var inputSpan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.SmithingInputLookup",
                        span,
                        expectedSignal: input.Id + "_evaluated",
                        preState: RuntimeStateSnapshot.Capture("smithing-input.pre", candidateCount: candidates.Count));
                    if (!MarketIntelligenceService.TryFindBuyAtNearest(input.Id, input.Name, out var townName, out var buyPrice, out var stock))
                    {
                        AutomationRuntimeEventEmitter.CompleteSpan(inputSpan, "input_not_available", RuntimeStateSnapshot.Capture("smithing-input.unavailable", candidateCount: candidates.Count));
                        continue;
                    }

                    var settlementSpan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.SettlementResolution",
                        inputSpan,
                        expectedSignal: "settlement_resolved",
                        preState: RuntimeStateSnapshot.Capture("settlement.pre", destination: townName, candidateCount: candidates.Count));
                    var settlement = ResolveSettlement(townName);
                    if (settlement == null)
                    {
                        AutomationRuntimeEventEmitter.BlockSpan(settlementSpan, "settlement unavailable", RuntimeStateSnapshot.Capture("settlement.blocked", destination: townName, candidateCount: candidates.Count));
                        AutomationRuntimeEventEmitter.CompleteSpan(inputSpan, "settlement_not_resolved", RuntimeStateSnapshot.Capture("smithing-input.unresolved", destination: townName, candidateCount: candidates.Count));
                        continue;
                    }
                    AutomationRuntimeEventEmitter.CompleteSpan(settlementSpan, "settlement_resolved", RuntimeStateSnapshot.Capture("settlement.post", destination: townName, candidateCount: candidates.Count));

                    var distanceSpan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.DistanceEvaluation",
                        inputSpan,
                        expectedSignal: "distance_evaluated",
                        preState: RuntimeStateSnapshot.Capture("distance.pre", destination: townName, candidateCount: candidates.Count));
                    var distance = main != null ? CampaignMapMovementHelper.Distance(main, settlement) : float.MaxValue;
                    if (distance > DevToolsConfig.MapTradeMaxRouteDistance)
                    {
                        AutomationRuntimeEventEmitter.BlockSpan(distanceSpan, "distance exceeds route maximum", RuntimeStateSnapshot.Capture("distance.blocked", destination: townName, candidateCount: candidates.Count));
                        AutomationRuntimeEventEmitter.CompleteSpan(inputSpan, "input_out_of_range", RuntimeStateSnapshot.Capture("smithing-input.out-of-range", destination: townName, candidateCount: candidates.Count));
                        continue;
                    }
                    AutomationRuntimeEventEmitter.CompleteSpan(distanceSpan, "distance_evaluated", RuntimeStateSnapshot.Capture("distance.post", destination: townName, candidateCount: candidates.Count));

                    var candidateSpan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.CandidateCreation",
                        inputSpan,
                        expectedSignal: "candidate_created",
                        preState: RuntimeStateSnapshot.Capture("candidate.pre", destination: townName, candidateCount: candidates.Count));
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
                    AutomationRuntimeEventEmitter.CompleteSpan(candidateSpan, "candidate_created", RuntimeStateSnapshot.Capture("candidate.post", destination: townName, candidateCount: candidates.Count));
                    AutomationRuntimeEventEmitter.CompleteSpan(inputSpan, input.Id + "_evaluated", RuntimeStateSnapshot.Capture("smithing-input.post", destination: townName, candidateCount: candidates.Count));
                }

                if (candidates.Count == 0)
                {
                    var fallbackSpan = AutomationRuntimeEventEmitter.BeginSpan(
                        "MapTradeMissionSelector.Fallback",
                        span,
                        expectedSignal: "fallback_selected_or_blocked",
                        preState: RuntimeStateSnapshot.Capture("fallback.pre", candidateCount: candidates.Count));
                    var nearestTown = FindNearestTown(main);
                    if (nearestTown != null && MapTradeBanditAvoidanceService.EvaluateRiskLevel() != "High")
                    {
                        var fallback = new MapTradeMission
                        {
                            MissionType = MapTradeMissionType.TravelOnlySafetyCert,
                            TargetSettlement = nearestTown,
                            TargetSettlementName = nearestTown.Name?.ToString(),
                            Distance = CampaignMapMovementHelper.Distance(main, nearestTown),
                            Score = 1f
                        };
                        AutomationRuntimeEventEmitter.CompleteSpan(fallbackSpan, "fallback_selected", RuntimeStateSnapshot.Capture("fallback.post", destination: fallback.TargetSettlementName, candidateCount: candidates.Count));
                        AutomationRuntimeEventEmitter.CompleteSpan(span, "mission_selected", RuntimeStateSnapshot.Capture("mission-selector.post", destination: fallback.TargetSettlementName, candidateCount: candidates.Count));
                        return fallback;
                    }

                    var noFallback = Blocked("no forge procurement mission and travel-only fallback unavailable");
                    AutomationRuntimeEventEmitter.BlockSpan(fallbackSpan, noFallback.BlockReason, RuntimeStateSnapshot.Capture("fallback.blocked", candidateCount: candidates.Count));
                    AutomationRuntimeEventEmitter.BlockSpan(span, noFallback.BlockReason, RuntimeStateSnapshot.Capture("mission-selector.blocked", candidateCount: candidates.Count));
                    return noFallback;
                }

                var orderingSpan = AutomationRuntimeEventEmitter.BeginSpan(
                    "MapTradeMissionSelector.FinalOrdering",
                    span,
                    expectedSignal: "best_candidate_selected",
                    preState: RuntimeStateSnapshot.Capture("ordering.pre", candidateCount: candidates.Count));
                var selected = candidates.OrderByDescending(m => m.Score).ThenBy(m => m.Distance).First();
                AutomationRuntimeEventEmitter.CompleteSpan(orderingSpan, "best_candidate_selected", RuntimeStateSnapshot.Capture("ordering.post", destination: selected.TargetSettlementName, candidateCount: candidates.Count));
                AutomationRuntimeEventEmitter.CompleteSpan(span, "mission_selected", RuntimeStateSnapshot.Capture("mission-selector.post", destination: selected.TargetSettlementName, candidateCount: candidates.Count));
                return selected;
            }
            catch (Exception ex)
            {
                AutomationRuntimeEventEmitter.FailSpan(span, ex, RuntimeStateSnapshot.Capture("mission-selector.error"));
                throw;
            }
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
