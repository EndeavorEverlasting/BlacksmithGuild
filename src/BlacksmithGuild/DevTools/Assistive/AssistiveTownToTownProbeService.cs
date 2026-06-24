using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Forge;
using BlacksmithGuild.HorseMarket;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTownToTownProbeService
    {
        public const string Command = "AssistiveTownToTownProbe";

        private static readonly string ProbePath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TownToTownTradeProbe.json");

        public static string LastFailReason { get; private set; }

        public static bool RunProbeNow(string source = Command)
        {
            GameSessionState.Refresh();
            AssistReadinessEvaluator.ApplyInboxAndAssistFlags();

            if (!AssistReadinessEvaluator.CanAcceptAssistiveCommand)
            {
                LastFailReason = AssistReadinessEvaluator.IsInGameAssistReady
                    ? "assist command blocked by loading or mission"
                    : GameSessionState.GetCommandReadyBlockDetail();
                DebugLogger.Test($"[TBG ASSIST] {Command} blocked: {LastFailReason}", showInGame: false);
                return false;
            }

            var travel = AssistiveLeaveTownTravelService.AssessTravelReadiness();
            var marketOk = MarketIntelligenceService.RunScanNow(source);
            MapTradeVanillaTradeDriver.ProbeTradeApi(out var tradeProbeDetail);
            MapTradeVanillaTradeDriver.ProbePackAnimalBuyApi(out _);

            var settlement = GameSessionState.CurrentSettlementName
                ?? GameSessionState.CurrentSettlementStringId
                ?? "";
            var gold = SafeGold();
            var packAnimalCount = CountPackAnimals();
            var nearbyTowns = BuildNearbyTownCandidates();
            var recommendedNextTown = travel.TargetSettlement ?? nearbyTowns.FirstOrDefault();
            var canExecuteTradeSafely = MapTradeVanillaTradeDriver.LastProbeAvailable
                && !DevToolsConfig.MapTradeAllowDirectInventoryMutation
                && !DevToolsConfig.MapTradeAllowDirectGoldMutation
                && AssistReadinessEvaluator.IsOpenMapReady;
            var tradeExecution = canExecuteTradeSafely ? "probe_available" : "advisory_only";
            var recommendedAction = BuildRecommendedAction(marketOk, travel, recommendedNextTown);

            WriteProbeJson(
                settlement,
                gold,
                packAnimalCount,
                nearbyTowns,
                recommendedNextTown,
                recommendedAction,
                canExecuteTradeSafely,
                tradeExecution,
                tradeProbeDetail,
                travel);

            AssistiveSessionWriter.WriteSnapshot(
                nextTownRecommendation: recommendedNextTown,
                tradeExecution: tradeExecution,
                travelCommandMode: travel.TravelCommandMode,
                currentSettlement: settlement,
                reason: travel.Reason);

            DebugLogger.Test(
                $"[TBG ASSIST] {Command} ok surface={GameSessionState.ReadinessSurface} trade={tradeExecution} travel={travel.TravelCommandMode}",
                showInGame: false);
            return true;
        }

        public static void WriteTravelEvidence(AssistiveTravelReadiness travel)
        {
            if (travel == null)
            {
                return;
            }

            try
            {
                if (!File.Exists(ProbePath))
                {
                    return;
                }

                var text = File.ReadAllText(ProbePath);
                if (text.Contains("\"travelReadiness\""))
                {
                    return;
                }

                var insert = new StringBuilder();
                insert.AppendLine("  ,\"travelReadiness\": {");
                insert.AppendLine($"    \"canLeaveSettlement\": {travel.CanLeaveSettlement.ToString().ToLowerInvariant()},");
                insert.AppendLine($"    \"canSetTravelTarget\": {travel.CanSetTravelTarget.ToString().ToLowerInvariant()},");
                insert.AppendLine($"    \"currentSettlement\": \"{Escape(travel.CurrentSettlement)}\",");
                insert.AppendLine($"    \"targetSettlement\": {(travel.TargetSettlement == null ? "null" : $"\"{Escape(travel.TargetSettlement)}\"")},");
                insert.AppendLine($"    \"travelCommandMode\": \"{Escape(travel.TravelCommandMode)}\",");
                insert.AppendLine($"    \"reason\": \"{Escape(travel.Reason)}\"");
                insert.AppendLine("  }");

                var trimmed = text.TrimEnd();
                if (trimmed.EndsWith("}", StringComparison.Ordinal))
                {
                    trimmed = trimmed.Substring(0, trimmed.Length - 1);
                }

                File.WriteAllText(ProbePath, trimmed + insert.ToString() + "\n}\n");
            }
            catch
            {
            }
        }

        private static void WriteProbeJson(
            string currentSettlement,
            int gold,
            int packAnimalCount,
            IReadOnlyList<string> nearbyTowns,
            string recommendedNextTown,
            string recommendedAction,
            bool canExecuteTradeSafely,
            string tradeExecution,
            string tradeProbeDetail,
            AssistiveTravelReadiness travel)
        {
            var advisory = MarketIntelligenceService.GetAdvisorySnapshot();
            var inventorySummary = BuildInventorySummary();
            var tradeGoodsSummary = BuildTradeGoodsSummary();
            var smithingGoods = BuildSmithingGoodsSummary();

            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
            builder.AppendLine($"  \"command\": \"{Command}\",");
            builder.AppendLine($"  \"currentSettlement\": \"{Escape(currentSettlement)}\",");
            builder.AppendLine($"  \"readinessSurface\": \"{Escape(GameSessionState.ReadinessSurface ?? ReadinessSurfaceKinds.Unknown)}\",");
            builder.AppendLine($"  \"gold\": {gold},");
            builder.AppendLine($"  \"partyInventorySummary\": \"{Escape(inventorySummary)}\",");
            builder.AppendLine($"  \"packAnimalCount\": {packAnimalCount},");
            builder.AppendLine($"  \"tradeGoodsSummary\": \"{Escape(tradeGoodsSummary)}\",");
            builder.AppendLine("  \"nearbyTownCandidates\": [");
            for (var i = 0; i < nearbyTowns.Count; i++)
            {
                var comma = i < nearbyTowns.Count - 1 ? "," : "";
                builder.AppendLine($"    \"{Escape(nearbyTowns[i])}\"{comma}");
            }

            builder.AppendLine("  ],");
            builder.AppendLine($"  \"marketIntelSummary\": \"{Escape(BuildMarketIntelSummary(advisory))}\",");
            builder.AppendLine($"  \"smithingRelevantGoods\": \"{Escape(smithingGoods)}\",");
            builder.AppendLine($"  \"recommendedNextTown\": {(recommendedNextTown == null ? "null" : $"\"{Escape(recommendedNextTown)}\"")},");
            builder.AppendLine($"  \"recommendedAction\": \"{Escape(recommendedAction)}\",");
            builder.AppendLine($"  \"canExecuteTradeSafely\": {canExecuteTradeSafely.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"tradeExecution\": \"{Escape(tradeExecution)}\",");
            builder.AppendLine($"  \"tradeProbeDetail\": {(tradeProbeDetail == null ? "null" : $"\"{Escape(tradeProbeDetail)}\"")},");
            builder.AppendLine("  \"travelReadiness\": {");
            builder.AppendLine($"    \"canLeaveSettlement\": {travel.CanLeaveSettlement.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"canSetTravelTarget\": {travel.CanSetTravelTarget.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"currentSettlement\": \"{Escape(travel.CurrentSettlement)}\",");
            builder.AppendLine($"    \"targetSettlement\": {(travel.TargetSettlement == null ? "null" : $"\"{Escape(travel.TargetSettlement)}\"")},");
            builder.AppendLine($"    \"travelCommandMode\": \"{Escape(travel.TravelCommandMode)}\",");
            builder.AppendLine($"    \"reason\": \"{Escape(travel.Reason)}\"");
            builder.AppendLine("  }");
            builder.AppendLine("}");
            File.WriteAllText(ProbePath, builder.ToString());
        }

        private static int SafeGold()
        {
            try
            {
                return Hero.MainHero?.Gold ?? 0;
            }
            catch
            {
                return 0;
            }
        }

        private static int CountPackAnimals()
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return 0;
            }

            var count = 0;
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null)
                {
                    continue;
                }

                var classification = HorseMarketClassifier.Classify(item);
                if (classification.Classification == HorseAnimalClassification.PackAnimal)
                {
                    count += element.Amount;
                }
            }

            return count;
        }

        private static List<string> BuildNearbyTownCandidates()
        {
            var main = MobileParty.MainParty;
            if (main == null)
            {
                return new List<string>();
            }

            return Settlement.All
                .Where(s => s != null && s.IsTown)
                .Select(s => new { Name = s.Name?.ToString() ?? s.StringId, Distance = main.GetPosition2D.Distance(s.GetPosition2D) })
                .OrderBy(x => x.Distance)
                .Take(5)
                .Select(x => x.Name)
                .ToList();
        }

        private static string BuildInventorySummary()
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return "empty";
            }

            var slots = party.ItemRoster.Count;
            var totalItems = 0;
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                totalItems += party.ItemRoster.GetElementCopyAtIndex(i).Amount;
            }

            return $"slots={slots} items={totalItems}";
        }

        private static string BuildTradeGoodsSummary()
        {
            var advisory = MarketIntelligenceService.GetAdvisorySnapshot();
            if (!advisory.HasScan)
            {
                return "no market scan";
            }

            return $"routes={advisory.RouteRows?.Count ?? 0} inventoryRows={advisory.InventoryRows?.Count ?? 0}";
        }

        private static string BuildSmithingGoodsSummary()
        {
            return $"charcoal={SmithingPartyInventory.CountCharcoal()} hardwood={SmithingPartyInventory.CountHardwood()} ironOre={SmithingPartyInventory.CountItem("iron_ore", "iron ore")}";
        }

        private static string BuildMarketIntelSummary(MarketAdvisorySnapshot advisory)
        {
            if (!advisory.HasScan)
            {
                return "scan_unavailable";
            }

            return $"nearest={advisory.NearestTown} distance={advisory.NearestDistance:0.1} towns={advisory.TownsScanned}";
        }

        private static string BuildRecommendedAction(
            bool marketOk,
            AssistiveTravelReadiness travel,
            string recommendedNextTown)
        {
            if (!marketOk)
            {
                return "refresh market scan when map ready";
            }

            if (travel.TravelCommandMode == "advisory_only")
            {
                return string.IsNullOrEmpty(recommendedNextTown)
                    ? "leave town then travel to nearest trade town"
                    : $"leave town then travel toward {recommendedNextTown}";
            }

            if (travel.TravelCommandMode == "execute")
            {
                return string.IsNullOrEmpty(recommendedNextTown)
                    ? "travel to recommended town"
                    : $"travel to {recommendedNextTown}";
            }

            return "wait for assist-ready session";
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
