using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Food;
using BlacksmithGuild.Forge;
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
        public const string ProbePackAnimalBuyNowCommand = "ProbePackAnimalBuyNow";
        public const string ProbeFoodBuyNowCommand = "ProbeFoodBuyNow";

        public static string LastProbeMethod { get; private set; }
        public static bool LastProbeAvailable { get; private set; }
        public static string LastProbeDetail { get; private set; }
        public static bool LastPackAnimalProbeAvailable { get; private set; }
        public static bool LastSmeltProbeAvailable { get; private set; }
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

            var classification = mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                ? "PackAnimal"
                : "Ordinary";
            if (MapTradeTradeActionReflection.TryExecuteBuy(
                    settlement,
                    item,
                    1,
                    out var result,
                    out detail,
                    itemClassification: classification))
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
            // Must always return + write probe JSON so inbox ACK can complete on the game tick.
            GameSessionState.Refresh();
            List<string> signatures = new List<string>();
            Settlement settlement = null;
            MapTradeExecutionResult execution = null;
            string attemptDetail = null;
            var success = false;

            try
            {
                try
                {
                    signatures = MapTradeTradeActionReflection.ProbeApplySignatures();
                }
                catch (Exception ex)
                {
                    attemptDetail = $"ProbeApplySignatures failed: {ex.Message}";
                }

                settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
                if (settlement == null)
                {
                    attemptDetail = attemptDetail ?? "party not at settlement — travel required before trade probe";
                }
                else
                {
                    if (!GameSessionState.IsSettlementInteriorReady)
                    {
                        SettlementNavigationHelper.TryEnsureSettlementInterior(out var navDetail);
                        if (!string.IsNullOrWhiteSpace(navDetail) && attemptDetail == null)
                        {
                            attemptDetail = navDetail;
                        }
                    }

                    // Prefer a local town roster item so we do not block on market-wide RunScanNow
                    // / SelectBestMission while already on settlement_menu.
                    var item = TryPickLocalOrdinaryBuyItem(settlement);
                    var itemSource = item != null ? "local_settlement_roster" : null;
                    if (item == null)
                    {
                        try
                        {
                            var mission = MapTradeMissionSelector.SelectBestMission();
                            if (mission?.ItemId != null
                                && mission.MissionType != MapTradeMissionType.BuyPackAnimalForCapacityThenTrade)
                            {
                                item = MapTradeTradeActionReflection.ResolveItem(mission.ItemId);
                                itemSource = "SelectBestMission";
                                if (item != null && FoodProtectionPolicy.IsFoodItem(item))
                                {
                                    attemptDetail = "best mission item is food/pack; ordinary trade probe skipped that item";
                                    item = null;
                                }
                            }
                            else
                            {
                                attemptDetail = attemptDetail ?? "no ordinary mission item available";
                            }
                        }
                        catch (Exception ex)
                        {
                            attemptDetail = $"SelectBestMission failed: {ex.Message}";
                        }
                    }

                    if (item != null)
                    {
                        success = MapTradeTradeActionReflection.TryExecuteBuy(
                            settlement,
                            item,
                            1,
                            out execution,
                            out attemptDetail,
                            itemClassification: "Ordinary");
                        if (!string.IsNullOrWhiteSpace(itemSource) && !string.IsNullOrWhiteSpace(attemptDetail))
                        {
                            attemptDetail = $"{attemptDetail} (source={itemSource})";
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                success = false;
                attemptDetail = $"RunProbeExecutionNow exception: {ex.Message}";
                DebugLogger.Test($"[TBG MAP TRADE] probe exception: {ex}", showInGame: false);
            }

            try
            {
                WriteOrdinaryProbeArtifact(source, settlement, signatures, success, attemptDetail, execution);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MAP TRADE] probe artifact write failed: {ex.Message}", showInGame: false);
            }

            InGameNotice.Info($"TBG MAP TRADE PROBE: {(success ? "buy delta proven" : attemptDetail ?? "blocked")}");
            return success;
        }

        private static ItemObject TryPickLocalOrdinaryBuyItem(Settlement settlement)
        {
            try
            {
                var roster = settlement?.ItemRoster;
                if (roster == null)
                {
                    return null;
                }

                foreach (var element in roster)
                {
                    var item = element.EquipmentElement.Item;
                    if (item == null || element.Amount <= 0)
                    {
                        continue;
                    }

                    if (FoodProtectionPolicy.IsFoodItem(item))
                    {
                        continue;
                    }

                    if (item.IsAnimal || item.HorseComponent != null)
                    {
                        continue;
                    }

                    // Prefer cheap trade goods / materials over gear.
                    if (item.IsTradeGood || item.Type == ItemObject.ItemTypeEnum.Goods)
                    {
                        return item;
                    }
                }

                foreach (var element in roster)
                {
                    var item = element.EquipmentElement.Item;
                    if (item == null || element.Amount <= 0 || FoodProtectionPolicy.IsFoodItem(item))
                    {
                        continue;
                    }

                    if (item.IsAnimal || item.HorseComponent != null)
                    {
                        continue;
                    }

                    return item;
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MAP TRADE] local item pick failed: {ex.Message}", showInGame: false);
            }

            return null;
        }

        private static void WriteOrdinaryProbeArtifact(
            string source,
            Settlement settlement,
            List<string> signatures,
            bool success,
            string attemptDetail,
            MapTradeExecutionResult execution)
        {
            signatures = signatures ?? new List<string>();
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
        }

        public static bool ProbePackAnimalBuyApi(out string detail)
        {
            detail = "pack-animal buy API not proven";
            LastPackAnimalProbeAvailable = false;

            if (!ProbeTradeApi(out detail))
            {
                return false;
            }

            var party = MobileParty.MainParty;
            var settlement = party?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            if (settlement != null && MapTradePackAnimalMissionHelper.HasPackAnimalStockAt(settlement, party))
            {
                detail = "pack-animal stock at settlement + BuyItemsAction probe OK";
                LastPackAnimalProbeAvailable = true;
                return true;
            }

            var mission = MapTradePackAnimalMissionHelper.TryBuildPackAnimalMission(party);
            if (mission != null)
            {
                detail = $"pack-animal mission available -> {mission.TargetSettlementName} ({mission.ItemName})";
                LastPackAnimalProbeAvailable = true;
                return true;
            }

            detail = MapTradePackAnimalMissionHelper.IsUnderCapacityBuffer(party)
                ? "under capacity buffer but no affordable pack animals in range"
                : "capacity buffer OK — pack-animal buy not required";
            return false;
        }

        public static bool RunProbePackAnimalBuyNow(string source = ProbePackAnimalBuyNowCommand)
        {
            GameSessionState.Refresh();
            var signatures = MapTradeTradeActionReflection.ProbeApplySignatures();
            var party = MobileParty.MainParty;
            var settlement = party?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            MapTradeExecutionResult execution = null;
            string attemptDetail = null;
            var success = false;
            MapTradeMission mission = null;
            var underBuffer = MapTradePackAnimalMissionHelper.IsUnderCapacityBuffer(party);

            mission = MapTradePackAnimalMissionHelper.TryBuildPackAnimalMission(party);
            if (settlement != null
                && MapTradePackAnimalMissionHelper.TryGetCheapestPackOfferAtSettlement(
                    settlement,
                    party,
                    out var itemId,
                    out var itemName,
                    out var buyPrice,
                    out var stock))
            {
                mission = new MapTradeMission
                {
                    MissionType = MapTradeMissionType.BuyPackAnimalForCapacityThenTrade,
                    ItemId = itemId,
                    ItemName = itemName,
                    TargetSettlement = settlement,
                    TargetSettlementName = settlement.Name?.ToString() ?? settlement.StringId,
                    BuyPrice = buyPrice,
                    Stock = stock
                };

                SettlementNavigationHelper.TryEnsureSettlementInterior(out _);
                success = TryExecuteBuy(mission, out attemptDetail);
                execution = LastExecutionResult;
            }
            else if (mission != null)
            {
                attemptDetail =
                    $"pack mission for travel -> {mission.TargetSettlementName} ({mission.ItemName}); arrive then retry buy";
            }
            else
            {
                attemptDetail = underBuffer
                    ? "no pack-animal mission — no affordable pack stock in range"
                    : "capacity buffer OK — pack buy not needed";
            }

            WritePackAnimalProbeJson(source, signatures, settlement, mission, underBuffer, success, attemptDetail, execution);
            InGameNotice.Info($"TBG PACK BUY PROBE: {(success ? "pack delta proven" : attemptDetail ?? "blocked")}");
            return success;
        }

        public static bool RunProbeFoodBuyNow(string source = ProbeFoodBuyNowCommand)
        {
            GameSessionState.Refresh();
            var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            MapTradeExecutionResult execution = null;
            string attemptDetail = null;
            var success = false;

            if (settlement == null)
            {
                attemptDetail = "party not at settlement — travel required before food buy";
            }
            else
            {
                SettlementNavigationHelper.TryEnsureSettlementInterior(out _);
                SettlementNavigationHelper.TryOpenMarketMenu(out _);
                var market = FoodMarketStockScanner.ScanCurrentSettlement(MobileParty.MainParty);
                var offer = market?.Items?
                    .Where(i => i != null && !string.IsNullOrWhiteSpace(i.ItemId) && i.Amount > 0)
                    .OrderBy(i => i.ItemName ?? i.ItemId)
                    .FirstOrDefault();
                if (offer == null)
                {
                    attemptDetail = "no food stock at current settlement market";
                }
                else
                {
                    var item = MapTradeTradeActionReflection.ResolveItem(offer.ItemId);
                    if (item == null || !FoodProtectionPolicy.IsFoodItem(item))
                    {
                        attemptDetail = $"food offer unresolved or not food: {offer.ItemId}";
                    }
                    else
                    {
                        success = MapTradeTradeActionReflection.TryExecuteBuy(
                            settlement,
                            item,
                            1,
                            out execution,
                            out attemptDetail,
                            itemClassification: "Food");
                        LastExecutionResult = execution;
                        if (success && execution != null)
                        {
                            LastProbeMethod = execution.ExecutionMethod;
                            LastProbeAvailable = true;
                            LastProbeDetail = attemptDetail;
                        }
                    }
                }
            }

            WriteFoodBuyProbeJson(source, settlement, success, attemptDetail, execution);
            InGameNotice.Info($"TBG FOOD BUY PROBE: {(success ? "food delta proven" : attemptDetail ?? "blocked")}");
            return success;
        }

        private static void WriteFoodBuyProbeJson(
            string source,
            Settlement settlement,
            bool success,
            string attemptDetail,
            MapTradeExecutionResult execution)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"readOnly\": false,");
            sb.AppendLine($"  \"settlement\": {NullableString(settlement?.Name?.ToString() ?? settlement?.StringId)},");
            sb.AppendLine($"  \"attemptSuccess\": {(success ? "true" : "false")},");
            sb.AppendLine($"  \"attemptDetail\": {NullableString(attemptDetail)},");
            sb.AppendLine("  \"tradeExecution\": ");
            AppendExecution(sb, execution, "  ");
            sb.AppendLine(",");
            sb.AppendLine($"  \"verdict\": \"{(success ? "ProbeFoodBuySuccess" : "ProbeFoodBuyBlocked")}\"");
            sb.AppendLine("}");
            var path = Path.Combine(BasePath.Name, "BlacksmithGuild_FoodBuyProbe.json");
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
        }

        private static void WritePackAnimalProbeJson(
            string source,
            System.Collections.Generic.List<string> signatures,
            Settlement settlement,
            MapTradeMission mission,
            bool underBuffer,
            bool success,
            string attemptDetail,
            MapTradeExecutionResult execution)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"readOnly\": false,");
            sb.AppendLine($"  \"underCapacityBuffer\": {(underBuffer ? "true" : "false")},");
            sb.AppendLine($"  \"settlement\": {NullableString(settlement?.Name?.ToString() ?? settlement?.StringId)},");
            sb.AppendLine($"  \"missionType\": {NullableString(mission?.MissionType.ToString())},");
            sb.AppendLine($"  \"itemId\": {NullableString(mission?.ItemId)},");
            sb.AppendLine($"  \"itemName\": {NullableString(mission?.ItemName)},");
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
            sb.AppendLine($"  \"verdict\": \"{(success ? "ProbePackBuySuccess" : "ProbePackBuyBlocked")}\"");
            sb.AppendLine("}");

            var path = Path.Combine(BasePath.Name, "BlacksmithGuild_MapTradePackAnimalProbe.json");
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
        }

        public static bool ProbeSmithingSmeltApi(out string detail)
        {
            detail = "weapon smelt API not proven";
            LastSmeltProbeAvailable = false;

            if (!SmithingSmeltApi.RunSmeltApiProbe(out detail))
            {
                return false;
            }

            var hero = Hero.MainHero;
            var candidate = SmithingLootWeaponScanner.SelectBestCandidate();
            if (candidate == null)
            {
                detail = "DoSmelting mapped but no smeltable loot weapons in party";
                return false;
            }

            var item = Game.Current?.ObjectManager?.GetObject<ItemObject>(candidate.ItemId);
            string smeltDetail = null;
            if (item == null || !SmithingSmeltApi.CanInvokeSmeltWeapon(hero, item, out smeltDetail))
            {
                detail = smeltDetail ?? "weapon smelt preflight blocked";
                return false;
            }

            detail = $"DoSmelting mapped; candidate={candidate.ItemName}";
            LastSmeltProbeAvailable = true;
            return true;
        }

        public static bool RunProbeWeaponSmeltNow(string source = SmithingSmeltService.ProbeWeaponSmeltNowCommand)
        {
            var success = SmithingSmeltService.RunSmeltApiProbeNow(source);
            LastSmeltProbeAvailable = SmithingSmeltService.LastProbeAvailable;
            InGameNotice.Info($"TBG SMELT PROBE: {(success ? "API mapped" : "blocked")}");
            return success;
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
            sb.AppendLine($"{indent}  \"executionMethod\": {NullableString(execution.ExecutionMethod)},");
            sb.AppendLine($"{indent}  \"itemClassification\": {NullableString(execution.ItemClassification)}");
            sb.Append($"{indent}}}");
        }

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
