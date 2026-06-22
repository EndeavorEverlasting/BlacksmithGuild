using System;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeVanillaTradeDriver
    {
        public const string ProbeVanillaTradeExecutionNowCommand = "ProbeVanillaTradeExecutionNow";

        public static string LastProbeMethod { get; private set; }
        public static bool LastProbeAvailable { get; private set; }
        public static string LastProbeDetail { get; private set; }
        public static MapTradeExecutionResult LastExecutionResult { get; private set; }

        public static bool ProbeTradeApi(out string detail)
        {
            detail = null;
            LastProbeMethod = null;
            LastProbeAvailable = false;
            LastProbeDetail = null;

            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady && !GameSessionState.IsSettlementInteriorReady)
            {
                detail = GameSessionState.GetCommandReadyBlockDetail();
                LastProbeDetail = detail;
                return false;
            }

            var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            if (settlement == null)
            {
                detail = "party not at settlement — travel required before trade probe";
                LastProbeDetail = detail;
                return false;
            }

            if (TryProbeSettlementEntry(out detail))
            {
                LastProbeMethod = "PlayerEncounter.EnterSettlement";
            }

            var signatures = MapTradeTradeActionReflection.ProbeApplySignatures();
            if (signatures.Any(s => !s.EndsWith(":missing", StringComparison.Ordinal)))
            {
                LastProbeMethod = signatures.First(s => !s.EndsWith(":missing", StringComparison.Ordinal));
                LastProbeAvailable = true;
                LastProbeDetail = string.Join("; ", signatures);
                detail = LastProbeDetail;
                return true;
            }

            detail = detail ?? "no vanilla trade action candidates found";
            LastProbeDetail = detail;
            return false;
        }

        public static bool TryExecuteBuy(MapTradeMission mission, out string detail)
        {
            detail = null;
            LastExecutionResult = null;

            if (mission == null)
            {
                detail = "no mission";
                return false;
            }

            if (DevToolsConfig.MapTradeAllowDirectInventoryMutation || DevToolsConfig.MapTradeAllowDirectGoldMutation)
            {
                detail = "direct mutation forbidden by config";
                return false;
            }

            if (!ProbeTradeApi(out detail))
            {
                return false;
            }

            var settlement = mission.TargetSettlement
                ?? MobileParty.MainParty?.CurrentSettlement
                ?? GameSessionState.ResolveCurrentSettlement();
            if (settlement == null)
            {
                detail = "settlement not resolved for buy";
                return false;
            }

            if (!SettlementNavigationHelper.TryEnsureSettlementInterior(out var navDetail))
            {
                detail = navDetail ?? "settlement interior not ready";
                return false;
            }

            SettlementNavigationHelper.TryOpenMarketMenu(out _);

            var item = MapTradeTradeActionReflection.ResolveItem(mission.ItemId);
            if (item == null)
            {
                detail = $"item not found: {mission.ItemId}";
                return false;
            }

            var hero = Hero.MainHero;
            if (hero == null)
            {
                detail = "MainHero unavailable";
                return false;
            }

            var reserve = DevToolsConfig.MapTradeSafeGoldReserve;
            var maxSpend = hero.Gold > reserve
                ? (int)(hero.Gold * DevToolsConfig.MapTradeMaxGoldSpendPercent / 100f)
                : 0;
            var spendable = Math.Max(0, hero.Gold - reserve);
            spendable = Math.Min(spendable, maxSpend > 0 ? maxSpend : spendable);

            if (mission.BuyPrice > 0 && spendable < mission.BuyPrice)
            {
                detail = $"insufficient spendable gold ({spendable} < {mission.BuyPrice}, reserve {reserve})";
                return false;
            }

            if (MapTradeTradeActionReflection.TryExecuteBuy(settlement, item, 1, out var result, out detail))
            {
                LastExecutionResult = result;
                LastProbeMethod = result.ExecutionMethod;
                LastProbeAvailable = true;
                LastProbeDetail = detail;
                return true;
            }

            detail = detail ?? $"trade driver probed ({LastProbeMethod}) but buy execution not proven";
            LastProbeDetail = detail;
            return false;
        }

        public static bool TryExecuteSell(MapTradeMission mission, out string detail)
        {
            detail = "sell execution not implemented in 006C-1";
            return false;
        }

        public static bool RunProbeExecutionNow(string source = ProbeVanillaTradeExecutionNowCommand)
        {
            GameSessionState.Refresh();
            var signatures = MapTradeTradeActionReflection.ProbeApplySignatures();
            var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            MapTradeExecutionResult execution = null;
            string attemptDetail = null;
            var success = false;

            if (settlement != null)
            {
                SettlementNavigationHelper.TryEnsureSettlementInterior(out _);
                var mission = MapTradeMissionSelector.SelectBestMission();
                if (mission?.ItemId != null)
                {
                    var item = MapTradeTradeActionReflection.ResolveItem(mission.ItemId);
                    if (item != null)
                    {
                        success = MapTradeTradeActionReflection.TryExecuteBuy(settlement, item, 1, out execution, out attemptDetail);
                    }
                }
            }

            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"readOnly\": false,");
            sb.AppendLine($"  \"settlement\": {NullableString(settlement?.Name?.ToString() ?? settlement?.StringId)},");
            sb.AppendLine("  \"signatures\": [");
            for (var i = 0; i < signatures.Count; i++)
            {
                sb.Append($"    \"{Escape(signatures[i])}\"");
                sb.AppendLine(i < signatures.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ],");
            sb.AppendLine($"  \"attemptSuccess\": {(success ? "true" : "false")},");
            sb.AppendLine($"  \"attemptDetail\": {NullableString(attemptDetail)},");
            sb.AppendLine("  \"tradeExecution\": ");
            AppendExecution(sb, execution, "  ");
            sb.AppendLine(",");
            sb.AppendLine($"  \"verdict\": \"{(success ? "ProbeBuySuccess" : "ProbeBuyBlocked")}\"");
            sb.AppendLine("}");

            var path = Path.Combine(BasePath.Name, "BlacksmithGuild_MapTradeProbe.json");
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
            InGameNotice.Info($"TBG MAP TRADE PROBE: {(success ? "buy delta proven" : attemptDetail ?? "blocked")}");
            return success;
        }

        public static bool ProbePackAnimalBuyApi(out string detail)
        {
            detail = "pack-animal buy API not proven";
            return false;
        }

        public static bool ProbeSmithingSmeltApi(out string detail)
        {
            detail = "weapon smelt API not proven";
            var hero = Hero.MainHero;
            if (hero == null)
            {
                detail = "MainHero unavailable for smelt probe";
                return false;
            }

            var smithingType = hero.GetType().Assembly.GetType("TaleWorlds.CampaignSystem.CampaignBehaviors.SmithingBehavior");
            if (smithingType != null)
            {
                detail = "SmithingBehavior type found but headless smelt path not proven";
            }

            return false;
        }

        private static bool TryProbeSettlementEntry(out string detail)
        {
            detail = null;
            try
            {
                if (PlayerEncounter.Current != null || PlayerEncounter.InsideSettlement)
                {
                    return true;
                }

                PlayerEncounter.EnterSettlement();
                return PlayerEncounter.Current != null || PlayerEncounter.InsideSettlement;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                return false;
            }
        }

        private static void AppendExecution(StringBuilder sb, MapTradeExecutionResult execution, string indent)
        {
            if (execution == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"goldBefore\": {execution.GoldBefore},");
            sb.AppendLine($"{indent}  \"goldAfter\": {execution.GoldAfter},");
            sb.AppendLine($"{indent}  \"goldDelta\": {execution.GoldDelta},");
            sb.AppendLine($"{indent}  \"itemId\": {NullableString(execution.ItemId)},");
            sb.AppendLine($"{indent}  \"itemName\": {NullableString(execution.ItemName)},");
            sb.AppendLine($"{indent}  \"quantityBought\": {execution.QuantityBought},");
            sb.AppendLine($"{indent}  \"inventoryBefore\": {execution.InventoryBefore},");
            sb.AppendLine($"{indent}  \"inventoryAfter\": {execution.InventoryAfter},");
            sb.AppendLine($"{indent}  \"executionMethod\": {NullableString(execution.ExecutionMethod)}");
            sb.Append($"{indent}}}");
        }

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
