using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using BlacksmithGuild.DevTools.Automation;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;
using TaleWorlds.ObjectSystem;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeTradeActionReflection
    {
        private static int _tradeIterationSeq;

        // Records a real, mod-observed trade iteration to BlacksmithGuild_TradeIterations.jsonl and emits a
        // trade.completed runtime event. Deltas come straight from live gold/inventory reads in TryExecuteBuy;
        // nothing is synthesized. The offline economic-loop certifier counts only rows with a real gold AND
        // inventory delta (FakeGameplayDelta=false). This is the single chokepoint for every proven buy
        // (vanilla driver, autonomous trade route, guild loop, probes, pack-animal buys).
        private static void RecordProvenTradeIteration(MapTradeExecutionResult execution, string direction)
        {
            if (execution == null)
            {
                return;
            }

            var iteration = Interlocked.Increment(ref _tradeIterationSeq);
            MapTradeTradeIterationWriter.Append(new MapTradeIterationRecord
            {
                Iteration = iteration,
                ItemName = execution.ItemName,
                Direction = direction,
                GoldBefore = execution.GoldBefore,
                GoldAfter = execution.GoldAfter,
                InventoryBefore = execution.InventoryBefore,
                InventoryAfter = execution.InventoryAfter,
                FakeGameplayDelta = false
            });

            var payload = "{\"iteration\":" + iteration
                + ",\"goldDelta\":" + (execution.GoldAfter - execution.GoldBefore)
                + ",\"inventoryDelta\":" + (execution.InventoryAfter - execution.InventoryBefore)
                + ",\"itemName\":\"" + EscapeJson(execution.ItemName) + "\"}";
            AutomationRuntimeEventEmitter.Emit(
                AutomationRuntimeEventEmitter.TradeCompleted,
                reason: direction,
                payloadJson: payload);
        }

        private static string EscapeJson(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        public static List<string> ProbeApplySignatures()
        {
            var signatures = new List<string>();
            foreach (var typeName in new[]
            {
                "TaleWorlds.CampaignSystem.Actions.BuyItemsAction",
                "TaleWorlds.CampaignSystem.Actions.SellItemsAction"
            })
            {
                var type = ResolveType(typeName);
                if (type == null)
                {
                    signatures.Add($"{typeName}:missing");
                    continue;
                }

                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Static))
                {
                    if (!string.Equals(method.Name, "Apply", StringComparison.Ordinal))
                    {
                        continue;
                    }

                    var parameters = method.GetParameters();
                    var signature = $"{type.Name}.Apply({string.Join(", ", parameters.Select(p => p.ParameterType.Name))})";
                    signatures.Add(signature);
                }
            }

            return signatures;
        }

        public static bool TryExecuteBuy(
            Settlement settlement,
            ItemObject item,
            int quantity,
            out MapTradeExecutionResult result,
            out string detail)
        {
            result = null;
            detail = null;

            if (settlement == null || item == null || quantity <= 0)
            {
                detail = "settlement, item, or quantity invalid";
                return false;
            }

            var mainParty = MobileParty.MainParty;
            var hero = Hero.MainHero;
            if (mainParty?.Party == null || hero == null)
            {
                detail = "MainParty or MainHero unavailable";
                return false;
            }

            var goldBefore = hero.Gold;
            var inventoryBefore = GetItemCount(mainParty, item);

            AutomationRuntimeEventEmitter.Emit(
                AutomationRuntimeEventEmitter.TradeStarted,
                reason: "buy",
                payloadJson: "{\"itemId\":\"" + EscapeJson(item.StringId) + "\",\"quantity\":" + quantity + "}");

            if (TryInvokeBuyItemsAction(mainParty.Party, settlement, item, quantity, out var methodUsed)
                || TryInvokeSellItemsActionBuy(mainParty.Party, settlement, item, quantity, out methodUsed))
            {
                var goldAfter = hero.Gold;
                var inventoryAfter = GetItemCount(mainParty, item);
                var goldDelta = goldAfter - goldBefore;
                var inventoryDelta = inventoryAfter - inventoryBefore;

                result = new MapTradeExecutionResult
                {
                    GoldBefore = goldBefore,
                    GoldAfter = goldAfter,
                    GoldDelta = goldDelta,
                    ItemId = item.StringId,
                    ItemName = item.Name?.ToString() ?? item.StringId,
                    QuantityBought = inventoryDelta,
                    InventoryBefore = inventoryBefore,
                    InventoryAfter = inventoryAfter,
                    ExecutionMethod = methodUsed
                };

                if (inventoryDelta > 0 && goldDelta < 0)
                {
                    detail = $"buy verified via {methodUsed}: gold {goldDelta}, items +{inventoryDelta}";
                    RecordProvenTradeIteration(result, "buy");
                    return true;
                }

                detail = $"{methodUsed} invoked but delta not proven (gold {goldDelta}, items {inventoryDelta})";
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.TradeBlocked, reason: detail);
                return false;
            }

            detail = detail ?? "no applicable BuyItemsAction/SellItemsAction Apply overload succeeded";
            AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.TradeBlocked, reason: detail);
            return false;
        }

        public static ItemObject ResolveItem(string itemId)
        {
            if (string.IsNullOrWhiteSpace(itemId))
            {
                return null;
            }

            try
            {
                return MBObjectManager.Instance?.GetObject<ItemObject>(itemId);
            }
            catch
            {
                return null;
            }
        }

        private static int GetItemCount(MobileParty party, ItemObject item)
        {
            try
            {
                return party?.ItemRoster?.GetItemNumber(item) ?? 0;
            }
            catch
            {
                return 0;
            }
        }

        private static bool TryInvokeBuyItemsAction(
            PartyBase buyerParty,
            Settlement settlement,
            ItemObject item,
            int quantity,
            out string methodUsed)
        {
            methodUsed = null;
            var type = ResolveType("TaleWorlds.CampaignSystem.Actions.BuyItemsAction");
            if (type == null)
            {
                return false;
            }

            var element = new ItemRosterElement(item, quantity);

            foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Static))
            {
                if (!string.Equals(method.Name, "Apply", StringComparison.Ordinal))
                {
                    continue;
                }

                var parameters = method.GetParameters();
                if (parameters.Length < 4)
                {
                    continue;
                }

                try
                {
                    var args = BuildApplyArguments(parameters, buyerParty, settlement.Party, settlement, element, quantity);
                    if (args == null)
                    {
                        continue;
                    }

                    method.Invoke(null, args);
                    methodUsed = $"BuyItemsAction.Apply({DescribeParameters(parameters)})";
                    return true;
                }
                catch
                {
                }
            }

            return false;
        }

        private static bool TryInvokeSellItemsActionBuy(
            PartyBase buyerParty,
            Settlement settlement,
            ItemObject item,
            int quantity,
            out string methodUsed)
        {
            methodUsed = null;
            var type = ResolveType("TaleWorlds.CampaignSystem.Actions.SellItemsAction");
            if (type == null || settlement?.Party == null)
            {
                return false;
            }

            var element = new ItemRosterElement(item, quantity);
            var sellerParty = settlement.Party;

            foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Static))
            {
                if (!string.Equals(method.Name, "Apply", StringComparison.Ordinal))
                {
                    continue;
                }

                var parameters = method.GetParameters();
                if (parameters.Length < 4)
                {
                    continue;
                }

                try
                {
                    var args = BuildApplyArguments(parameters, buyerParty, sellerParty, settlement, element, quantity);
                    if (args == null)
                    {
                        continue;
                    }

                    method.Invoke(null, args);
                    methodUsed = $"SellItemsAction.Apply({DescribeParameters(parameters)}) settlement-buy";
                    return true;
                }
                catch
                {
                }
            }

            return false;
        }

        private static object[] BuildApplyArguments(
            ParameterInfo[] parameters,
            PartyBase primaryParty,
            PartyBase secondaryParty,
            Settlement settlement,
            ItemRosterElement element,
            int quantity)
        {
            var args = new object[parameters.Length];
            for (var i = 0; i < parameters.Length; i++)
            {
                var paramType = parameters[i].ParameterType;
                if (paramType == typeof(PartyBase))
                {
                    args[i] = i == 0 ? primaryParty : secondaryParty;
                }
                else if (paramType == typeof(ItemRosterElement))
                {
                    args[i] = element;
                }
                else if (paramType == typeof(int))
                {
                    args[i] = quantity;
                }
                else if (paramType == typeof(Settlement))
                {
                    args[i] = settlement;
                }
                else if (paramType.IsEnum)
                {
                    args[i] = Enum.GetValues(paramType).GetValue(0);
                }
                else if (parameters[i].HasDefaultValue)
                {
                    args[i] = parameters[i].DefaultValue;
                }
                else
                {
                    return null;
                }
            }

            return args;
        }

        private static string DescribeParameters(ParameterInfo[] parameters)
        {
            var sb = new StringBuilder();
            for (var i = 0; i < parameters.Length; i++)
            {
                if (i > 0)
                {
                    sb.Append(", ");
                }

                sb.Append(parameters[i].ParameterType.Name);
            }

            return sb.ToString();
        }

        private static Type ResolveType(string typeName)
        {
            return typeof(Campaign).Assembly.GetType(typeName)
                ?? AppDomain.CurrentDomain.GetAssemblies()
                    .SelectMany(a =>
                    {
                        try { return a.GetTypes(); }
                        catch { return Array.Empty<Type>(); }
                    })
                    .FirstOrDefault(t => t.FullName == typeName);
        }
    }
}
