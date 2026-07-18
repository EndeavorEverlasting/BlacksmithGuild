using System;
using System.Collections.Generic;
using System.Reflection;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.Food
{
    public sealed class FoodMarketStockItem
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int Amount { get; set; }

        public string ToDetailString()
        {
            return (ItemId ?? "unknown_food") + " qty=" + Amount;
        }
    }

    public sealed class FoodMarketStockSnapshot
    {
        public string Status { get; set; }
        public string Reason { get; set; }
        public string SettlementName { get; set; }
        public List<FoodMarketStockItem> Items { get; } = new List<FoodMarketStockItem>();

        public string ToDetailString()
        {
            var parts = new List<string>();
            for (var i = 0; i < Items.Count; i++)
            {
                parts.Add(Items[i].ToDetailString());
            }

            return "market food stock: status=" + Status
                + " settlement=" + (SettlementName ?? "unknown")
                + " count=" + Items.Count
                + " reason=" + Reason
                + (parts.Count > 0 ? " stock=[" + string.Join("; ", parts.ToArray()) + "]" : string.Empty);
        }

        public static FoodMarketStockSnapshot Unknown(string reason)
        {
            return new FoodMarketStockSnapshot
            {
                Status = "unknown",
                Reason = reason
            };
        }
    }

    public sealed class FoodMarketCandidateMatch
    {
        public string CandidateKind { get; set; }
        public string TargetItemId { get; set; }
        public int DesiredQuantity { get; set; }
        public int MatchedQuantity { get; set; }
        public string Status { get; set; }
        public string Reason { get; set; }

        public string ToDetailString()
        {
            return CandidateKind
                + ":" + (TargetItemId ?? "any_food")
                + " desired=" + DesiredQuantity
                + " matched=" + MatchedQuantity
                + " status=" + Status
                + " reason=" + Reason;
        }
    }

    public sealed class FoodMarketCandidateMatchPlan
    {
        public string Status { get; set; }
        public string Reason { get; set; }
        public List<FoodMarketCandidateMatch> Matches { get; } = new List<FoodMarketCandidateMatch>();

        public string ToDetailString()
        {
            var parts = new List<string>();
            for (var i = 0; i < Matches.Count; i++)
            {
                parts.Add(Matches[i].ToDetailString());
            }

            return "food market matches: status=" + Status
                + " count=" + Matches.Count
                + " reason=" + Reason
                + (parts.Count > 0 ? " matches=[" + string.Join("; ", parts.ToArray()) + "]" : string.Empty);
        }
    }

    public static class FoodMarketStockScanner
    {
        public static FoodMarketStockSnapshot ScanCurrentSettlement(MobileParty party)
        {
            if (party == null)
            {
                return FoodMarketStockSnapshot.Unknown("party unavailable");
            }

            object settlement = GetMemberValue(party, "CurrentSettlement") ?? GetMemberValue(party, "Settlement");
            if (settlement == null)
            {
                return FoodMarketStockSnapshot.Unknown("current settlement unavailable");
            }

            var snapshot = new FoodMarketStockSnapshot
            {
                Status = "unknown",
                SettlementName = ResolveDisplayName(settlement),
                Reason = "market item roster unavailable"
            };

            var roster = FindItemRoster(settlement, 0, new HashSet<object>());
            if (roster == null)
            {
                return snapshot;
            }

            PopulateFoodItems(roster, snapshot);
            snapshot.Status = snapshot.Items.Count > 0 ? "scanned" : "empty";
            snapshot.Reason = snapshot.Items.Count > 0
                ? "read-only market stock scan completed"
                : "market roster found but no food stock was detected";
            return snapshot;
        }

        private static object FindItemRoster(object source, int depth, HashSet<object> visited)
        {
            if (source == null || depth > 4 || visited.Contains(source))
            {
                return null;
            }

            visited.Add(source);
            if (LooksLikeItemRoster(source))
            {
                return source;
            }

            var preferred = new[]
            {
                "ItemRoster",
                "MarketItemRoster",
                "MarketRoster",
                "Town",
                "MarketData",
                "SettlementComponent"
            };

            for (var i = 0; i < preferred.Length; i++)
            {
                var value = GetMemberValue(source, preferred[i]);
                var found = FindItemRoster(value, depth + 1, visited);
                if (found != null)
                {
                    return found;
                }
            }

            var type = source.GetType();
            var methods = type.GetMethods(BindingFlags.Public | BindingFlags.Instance);
            for (var i = 0; i < methods.Length; i++)
            {
                var method = methods[i];
                if (method.GetParameters().Length != 0 || method.ReturnType == typeof(void))
                {
                    continue;
                }

                if (method.ReturnType.Name.IndexOf("ItemRoster", StringComparison.OrdinalIgnoreCase) < 0
                    && method.Name.IndexOf("Roster", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                try
                {
                    var value = method.Invoke(source, null);
                    var found = FindItemRoster(value, depth + 1, visited);
                    if (found != null)
                    {
                        return found;
                    }
                }
                catch
                {
                    // Reflection scanner is read-only best-effort; unavailable members leave the scan unknown.
                }
            }

            return null;
        }

        private static bool LooksLikeItemRoster(object value)
        {
            if (value == null)
            {
                return false;
            }

            var type = value.GetType();
            return type.Name.IndexOf("ItemRoster", StringComparison.OrdinalIgnoreCase) >= 0
                || (GetMemberValue(value, "Count") != null && type.GetMethod("GetElementCopyAtIndex") != null);
        }

        private static void PopulateFoodItems(object roster, FoodMarketStockSnapshot snapshot)
        {
            var countObject = GetMemberValue(roster, "Count");
            int count;
            if (!TryConvertToInt(countObject, out count))
            {
                return;
            }

            var method = roster.GetType().GetMethod("GetElementCopyAtIndex");
            if (method == null)
            {
                return;
            }

            for (var i = 0; i < count; i++)
            {
                try
                {
                    var element = method.Invoke(roster, new object[] { i });
                    int amount;
                    if (!TryConvertToInt(GetMemberValue(element, "Amount"), out amount) || amount <= 0)
                    {
                        continue;
                    }

                    var equipment = GetMemberValue(element, "EquipmentElement");
                    var itemObject = GetMemberValue(equipment, "Item") ?? GetMemberValue(element, "Item");
                    var item = itemObject as ItemObject;
                    if (item == null || !FoodProtectionPolicy.IsFoodItem(item))
                    {
                        continue;
                    }

                    snapshot.Items.Add(new FoodMarketStockItem
                    {
                        ItemId = item.StringId ?? "unknown_food",
                        ItemName = item.Name?.ToString() ?? item.StringId ?? "Unknown food",
                        Amount = amount
                    });
                }
                catch
                {
                    // Keep scanning remaining roster entries if one element shape is not readable.
                }
            }
        }

        private static object GetMemberValue(object source, string name)
        {
            if (source == null || string.IsNullOrEmpty(name))
            {
                return null;
            }

            var type = source.GetType();
            var property = type.GetProperty(name, BindingFlags.Public | BindingFlags.Instance);
            if (property != null)
            {
                try
                {
                    return property.GetValue(source, null);
                }
                catch
                {
                    return null;
                }
            }

            var field = type.GetField(name, BindingFlags.Public | BindingFlags.Instance);
            if (field != null)
            {
                try
                {
                    return field.GetValue(source);
                }
                catch
                {
                    return null;
                }
            }

            return null;
        }

        private static string ResolveDisplayName(object value)
        {
            var name = GetMemberValue(value, "Name");
            if (name != null)
            {
                return name.ToString();
            }

            var stringId = GetMemberValue(value, "StringId");
            return stringId != null ? stringId.ToString() : "unknown";
        }

        private static bool TryConvertToInt(object value, out int result)
        {
            result = 0;
            if (value == null)
            {
                return false;
            }

            try
            {
                result = Convert.ToInt32(value);
                return true;
            }
            catch
            {
                return false;
            }
        }
    }

    public static class FoodMarketCandidateMatcher
    {
        public static FoodMarketCandidateMatchPlan Match(FoodProcurementCandidatePlan candidates, FoodMarketStockSnapshot stock)
        {
            var result = new FoodMarketCandidateMatchPlan();
            if (candidates == null)
            {
                result.Status = "blocked";
                result.Reason = "missing candidate plan";
                return result;
            }

            stock = stock ?? FoodMarketStockSnapshot.Unknown("market stock snapshot unavailable");
            if (!string.Equals(stock.Status, "scanned", StringComparison.OrdinalIgnoreCase)
                && !string.Equals(stock.Status, "empty", StringComparison.OrdinalIgnoreCase))
            {
                result.Status = "unknown";
                result.Reason = stock.Reason;
            }
            else
            {
                result.Status = "matched";
                result.Reason = "candidate matching completed against read-only market stock snapshot";
            }

            for (var i = 0; i < candidates.Candidates.Count; i++)
            {
                result.Matches.Add(MatchCandidate(candidates.Candidates[i], stock));
            }

            if (result.Matches.Count == 0)
            {
                result.Status = "not_needed";
                result.Reason = candidates.Reason;
            }

            return result;
        }

        private static FoodMarketCandidateMatch MatchCandidate(FoodProcurementCandidate candidate, FoodMarketStockSnapshot stock)
        {
            var matchedQuantity = SumMatchingStock(candidate, stock);
            var status = "unknown";
            var reason = stock.Reason;

            if (string.Equals(stock.Status, "scanned", StringComparison.OrdinalIgnoreCase)
                || string.Equals(stock.Status, "empty", StringComparison.OrdinalIgnoreCase))
            {
                if (matchedQuantity >= candidate.DesiredQuantity)
                {
                    status = "available";
                    reason = "candidate desired quantity available in read-only market stock";
                }
                else if (matchedQuantity > 0)
                {
                    status = "partial";
                    reason = "candidate partially available in read-only market stock";
                }
                else
                {
                    status = "unavailable";
                    reason = "candidate not found in read-only market stock";
                }
            }

            return new FoodMarketCandidateMatch
            {
                CandidateKind = candidate.CandidateKind,
                TargetItemId = candidate.TargetItemId,
                DesiredQuantity = candidate.DesiredQuantity,
                MatchedQuantity = matchedQuantity,
                Status = status,
                Reason = reason
            };
        }

        private static int SumMatchingStock(FoodProcurementCandidate candidate, FoodMarketStockSnapshot stock)
        {
            if (candidate == null || stock == null)
            {
                return 0;
            }

            var anyFood = string.Equals(candidate.TargetItemId, "any_food", StringComparison.OrdinalIgnoreCase)
                || string.Equals(candidate.TargetItemId, "diverse_food", StringComparison.OrdinalIgnoreCase)
                || string.IsNullOrEmpty(candidate.TargetItemId);
            var total = 0;
            for (var i = 0; i < stock.Items.Count; i++)
            {
                var item = stock.Items[i];
                if (anyFood || string.Equals(item.ItemId, candidate.TargetItemId, StringComparison.OrdinalIgnoreCase))
                {
                    total += Math.Max(0, item.Amount);
                }
            }

            return total;
        }
    }
}
