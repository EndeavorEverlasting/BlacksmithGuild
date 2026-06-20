using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Roster;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.Market
{
    public static class MarketIntelligenceService
    {
        public const string MarketSnapshotNowCommand = "MarketSnapshotNow";

        private const int MaxNearbyTowns = 5;
        private const float MaxMapDistance = 30f;
        private const int ExpandedMaxNearbyTowns = 8;
        private const float ExpandedMaxMapDistance = 60f;
        private const int MaxSpreadRows = 15;
        private const int MaxInventoryRows = 10;
        private const int MaxTownGoodsRows = 12;
        private const int MaxRouteRows = 5;
        private const int MaxActionPlanSteps = 4;

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_MarketIntel.json");

        private static MarketIntelSummary _summary = new MarketIntelSummary();
        private static MarketIntelReport _cachedReport = new MarketIntelReport();
        private static bool _summaryRecorded;

        public static MarketIntelSummary Summary => _summary;

        public static bool HasCachedScan => _summaryRecorded && _summary.HasScan;

        public static MarketAdvisorySnapshot GetAdvisorySnapshot()
        {
            if (!HasCachedScan)
            {
                return new MarketAdvisorySnapshot();
            }

            return new MarketAdvisorySnapshot
            {
                HasScan = true,
                NearestTown = _cachedReport.NearestTown,
                NearestDistance = _cachedReport.NearestDistance,
                TownsScanned = _cachedReport.TownsScanned,
                ExpandedScanUsed = _cachedReport.ExpandedScanUsed,
                ActionPlan = _cachedReport.ActionPlan,
                RouteRows = MapRouteRows(_cachedReport.RouteRows),
                InventoryRows = MapInventoryRows(_cachedReport.InventoryRows),
                SpreadRows = MapSpreadRows(_cachedReport.SpreadRows)
            };
        }

        public static bool TryFindBuyAtNearest(string itemId, string itemName, out string townName, out int buyPrice, out int stock)
        {
            townName = null;
            buyPrice = 0;
            stock = 0;

            if (!HasCachedScan)
            {
                return false;
            }

            var route = _cachedReport.RouteRows.FirstOrDefault(row =>
                MatchesItem(row.ItemId, row.ItemName, itemId, itemName));
            if (route != null)
            {
                townName = route.BuyTown;
                buyPrice = route.BuyPrice;
                stock = route.Stock;
                return true;
            }

            var nearest = _cachedReport.Towns.FirstOrDefault();
            if (nearest?.Goods == null)
            {
                return false;
            }

            var good = nearest.Goods.FirstOrDefault(entry =>
                MatchesItem(entry.ItemId, entry.ItemName, itemId, itemName));
            if (good == null)
            {
                return false;
            }

            townName = nearest.Name;
            buyPrice = good.BuyPrice;
            stock = good.Stock;
            return true;
        }

        public static bool RunScanNow(string source = MarketSnapshotNowCommand)
        {
            if (Campaign.Current == null || Hero.MainHero == null || MobileParty.MainParty == null)
            {
                DebugLogger.Test("[TBG MARKET] scan blocked: campaign not ready.", showInGame: false);
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                var detail = GameSessionState.GetCampaignMapBlockDetail();
                DebugLogger.Test($"[TBG MARKET] scan blocked: {detail}", showInGame: false);
                InGameNotice.Blocked($"{ModDisplay.Name} — Market: map not ready ({detail}).");
                return false;
            }

            try
            {
                var report = BuildReport(source);
                _cachedReport = report;
                UpdateSummary(report);
                WriteJsonReport(report);
                WriteMarketReport(source);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MARKET] scan failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Market Intel");
            if (!_summaryRecorded || !_summary.HasScan)
            {
                report.Line("scan", "none yet (press Ctrl+Alt+M on map)");
                return;
            }

            report.Line("nearest", _summary.NearestTown ?? "unknown");
            report.Line("distance", $"{_summary.NearestDistance:0.1}u");
            report.Line("towns", _summary.TownsScanned.ToString());
            report.Line("spreads", _summary.SpreadCount.ToString());
            report.Line("routes", _summary.RouteCount.ToString());
            report.Line("inventory", _summary.InventoryCount.ToString());
            if (!string.IsNullOrEmpty(_summary.TopRouteLabel))
            {
                report.Line("topRoute", _summary.TopRouteLabel);
            }
            if (!string.IsNullOrEmpty(_summary.TopSpreadLabel))
            {
                report.Line("topSpread", _summary.TopSpreadLabel);
            }

            report.Line("json", _summary.ReportPath);
        }

        public static string BuildCompactSummaryLine()
        {
            if (!_summaryRecorded || !_summary.HasScan)
            {
                return null;
            }

            return ModDisplay.CompactLine(
                "Market",
                $"nearest={_summary.NearestTown} ({_summary.NearestDistance:0.1}u) spreads={_summary.SpreadCount}");
        }

        private static MarketIntelReport BuildReport(string source)
        {
            var report = BuildReportWithScan(source, MaxNearbyTowns, MaxMapDistance, expandedScanUsed: false);
            if (report.RouteRows.Count > 0)
            {
                return report;
            }

            return BuildReportWithScan(source, ExpandedMaxNearbyTowns, ExpandedMaxMapDistance, expandedScanUsed: true);
        }

        private static MarketIntelReport BuildReportWithScan(
            string source,
            int maxTowns,
            float maxDistance,
            bool expandedScanUsed)
        {
            var party = MobileParty.MainParty;
            var partyPosition = party.GetPosition2D;
            var nearbyTowns = ResolveNearbyTowns(partyPosition, maxTowns, maxDistance);
            if (nearbyTowns.Count == 0)
            {
                throw new InvalidOperationException("no towns found");
            }

            var townDistances = nearbyTowns.ToDictionary(
                s => s.Name?.ToString() ?? s.StringId,
                s => s.GetPosition2D.Distance(partyPosition),
                StringComparer.OrdinalIgnoreCase);

            var candidateItems = CollectCandidateItems(nearbyTowns, party.ItemRoster);
            var priceMatrix = BuildPriceMatrix(nearbyTowns, candidateItems, party);
            var inventoryRows = BuildInventoryRows(party.ItemRoster, priceMatrix);
            var spreadRows = BuildSpreadRows(priceMatrix);
            var townSnapshots = BuildTownSnapshots(nearbyTowns, priceMatrix);

            var nearest = nearbyTowns[0];
            var nearestName = nearest.Name?.ToString() ?? nearest.StringId;
            var routeRows = BuildNearestTownRoutes(priceMatrix, nearestName, townDistances);
            var actionPlan = BuildActionPlan(nearestName, routeRows, inventoryRows);

            return new MarketIntelReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                NearestTown = nearestName,
                NearestDistance = nearest.GetPosition2D.Distance(partyPosition),
                TownsScanned = nearbyTowns.Count,
                ExpandedScanUsed = expandedScanUsed,
                Towns = townSnapshots,
                InventoryRows = inventoryRows,
                SpreadRows = spreadRows,
                RouteRows = routeRows,
                ActionPlan = actionPlan
            };
        }

        private static List<Settlement> ResolveNearbyTowns(Vec2 partyPosition, int maxTowns, float maxDistance)
        {
            var towns = Town.AllTowns
                .Select(t => t.Settlement)
                .Where(s => s != null && s.IsTown)
                .Select(s => new
                {
                    Settlement = s,
                    Distance = s.GetPosition2D.Distance(partyPosition)
                })
                .OrderBy(x => x.Distance)
                .ToList();

            var withinRange = towns
                .Where(x => x.Distance <= maxDistance)
                .Take(maxTowns)
                .Select(x => x.Settlement)
                .ToList();

            if (withinRange.Count > 0)
            {
                return withinRange;
            }

            return towns.Take(maxTowns).Select(x => x.Settlement).ToList();
        }

        private static HashSet<ItemObject> CollectCandidateItems(
            IReadOnlyList<Settlement> towns,
            ItemRoster partyRoster)
        {
            var items = new HashSet<ItemObject>();

            AddTradeGoodsFromRoster(partyRoster, items);
            foreach (var town in towns)
            {
                AddTradeGoodsFromRoster(town.ItemRoster, items);
            }

            return items;
        }

        private static void AddTradeGoodsFromRoster(ItemRoster roster, HashSet<ItemObject> items)
        {
            if (roster == null)
            {
                return;
            }

            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || !IsTradeGood(item) || element.Amount <= 0)
                {
                    continue;
                }

                items.Add(item);
            }
        }

        private static bool IsTradeGood(ItemObject item)
        {
            try
            {
                return item.IsTradeGood;
            }
            catch
            {
                return item.ItemCategory != null;
            }
        }

        private static Dictionary<string, ItemPriceMatrix> BuildPriceMatrix(
            IReadOnlyList<Settlement> towns,
            HashSet<ItemObject> items,
            MobileParty party)
        {
            var matrix = new Dictionary<string, ItemPriceMatrix>(StringComparer.OrdinalIgnoreCase);

            foreach (var item in items)
            {
                var itemId = item.StringId ?? item.Name?.ToString() ?? "unknown";
                if (!matrix.TryGetValue(itemId, out var row))
                {
                    row = new ItemPriceMatrix
                    {
                        ItemId = itemId,
                        ItemName = item.Name?.ToString() ?? itemId
                    };
                    matrix[itemId] = row;
                }

                foreach (var settlement in towns)
                {
                    var town = settlement.Town;
                    if (town == null)
                    {
                        continue;
                    }

                    var townName = settlement.Name?.ToString() ?? settlement.StringId;
                    if (!TryGetPrices(town, item, party, out var buy, out var sell))
                    {
                        continue;
                    }

                    row.ByTown[townName] = new TownPriceEntry
                    {
                        TownName = townName,
                        BuyPrice = buy,
                        SellPrice = sell,
                        Stock = GetStockCount(settlement.ItemRoster, item)
                    };
                }
            }

            return matrix;
        }

        private static bool TryGetPrices(
            Town town,
            ItemObject item,
            MobileParty party,
            out int buyPrice,
            out int sellPrice)
        {
            buyPrice = 0;
            sellPrice = 0;

            try
            {
                buyPrice = town.GetItemPrice(item, party, isSelling: false);
                sellPrice = town.GetItemPrice(item, party, isSelling: true);
                return buyPrice > 0 || sellPrice > 0;
            }
            catch
            {
                try
                {
                    var market = town.MarketData;
                    if (market == null)
                    {
                        return false;
                    }

                    buyPrice = market.GetPrice(item, party, isSelling: false, town.Settlement?.Party);
                    sellPrice = market.GetPrice(item, party, isSelling: true, town.Settlement?.Party);
                    return buyPrice > 0 || sellPrice > 0;
                }
                catch
                {
                    return false;
                }
            }
        }

        private static int GetStockCount(ItemRoster roster, ItemObject item)
        {
            if (roster == null || item == null)
            {
                return 0;
            }

            try
            {
                return roster.GetItemNumber(item);
            }
            catch
            {
                return 0;
            }
        }

        private static List<InventorySellRow> BuildInventoryRows(
            ItemRoster partyRoster,
            Dictionary<string, ItemPriceMatrix> matrix)
        {
            var rows = new List<InventorySellRow>();
            if (partyRoster == null)
            {
                return rows;
            }

            for (var i = 0; i < partyRoster.Count; i++)
            {
                var element = partyRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || !IsTradeGood(item) || element.Amount <= 0)
                {
                    continue;
                }

                var itemId = item.StringId ?? item.Name?.ToString();
                if (string.IsNullOrEmpty(itemId) || !matrix.TryGetValue(itemId, out var priceRow))
                {
                    continue;
                }

                if (priceRow.ByTown.Count == 0)
                {
                    continue;
                }

                var best = priceRow.ByTown.Values.OrderByDescending(x => x.SellPrice).First();
                var worst = priceRow.ByTown.Values.OrderBy(x => x.SellPrice).First();
                rows.Add(new InventorySellRow
                {
                    ItemId = itemId,
                    ItemName = priceRow.ItemName,
                    Quantity = element.Amount,
                    BestSellTown = best.TownName,
                    BestSellPrice = best.SellPrice,
                    WorstSellPrice = worst.SellPrice,
                    SpreadVsWorst = best.SellPrice - worst.SellPrice
                });
            }

            return rows
                .OrderByDescending(r => r.SpreadVsWorst)
                .ThenByDescending(r => r.Quantity)
                .Take(MaxInventoryRows)
                .ToList();
        }

        private static List<TradeSpreadRow> BuildSpreadRows(Dictionary<string, ItemPriceMatrix> matrix)
        {
            var rows = new List<TradeSpreadRow>();

            foreach (var priceRow in matrix.Values)
            {
                if (priceRow.ByTown.Count < 2)
                {
                    continue;
                }

                TownPriceEntry bestBuy = null;
                TownPriceEntry bestSell = null;

                foreach (var townEntry in priceRow.ByTown.Values)
                {
                    if (bestBuy == null || townEntry.BuyPrice < bestBuy.BuyPrice)
                    {
                        bestBuy = townEntry;
                    }

                    if (bestSell == null || townEntry.SellPrice > bestSell.SellPrice)
                    {
                        bestSell = townEntry;
                    }
                }

                if (bestBuy == null || bestSell == null)
                {
                    continue;
                }

                if (string.Equals(bestBuy.TownName, bestSell.TownName, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                var spread = bestSell.SellPrice - bestBuy.BuyPrice;
                if (spread <= 0)
                {
                    continue;
                }

                rows.Add(new TradeSpreadRow
                {
                    ItemId = priceRow.ItemId,
                    ItemName = priceRow.ItemName,
                    BuyTown = bestBuy.TownName,
                    BuyPrice = bestBuy.BuyPrice,
                    SellTown = bestSell.TownName,
                    SellPrice = bestSell.SellPrice,
                    Spread = spread
                });
            }

            return rows
                .OrderByDescending(r => r.Spread)
                .Take(MaxSpreadRows)
                .ToList();
        }

        private static List<TradeRouteRow> BuildNearestTownRoutes(
            Dictionary<string, ItemPriceMatrix> matrix,
            string nearestTownName,
            Dictionary<string, float> townDistances)
        {
            var rows = new List<TradeRouteRow>();

            foreach (var priceRow in matrix.Values)
            {
                if (!priceRow.ByTown.TryGetValue(nearestTownName, out var nearestEntry))
                {
                    continue;
                }

                if (nearestEntry.Stock <= 0)
                {
                    continue;
                }

                TownPriceEntry bestSell = null;
                foreach (var townEntry in priceRow.ByTown.Values)
                {
                    if (string.Equals(townEntry.TownName, nearestTownName, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    if (bestSell == null || townEntry.SellPrice > bestSell.SellPrice)
                    {
                        bestSell = townEntry;
                    }
                }

                if (bestSell == null)
                {
                    continue;
                }

                var spread = bestSell.SellPrice - nearestEntry.BuyPrice;
                if (spread <= 0)
                {
                    continue;
                }

                townDistances.TryGetValue(bestSell.TownName, out var sellDistance);
                rows.Add(new TradeRouteRow
                {
                    ItemId = priceRow.ItemId,
                    ItemName = priceRow.ItemName,
                    BuyTown = nearestTownName,
                    BuyPrice = nearestEntry.BuyPrice,
                    Stock = nearestEntry.Stock,
                    SellTown = bestSell.TownName,
                    SellPrice = bestSell.SellPrice,
                    Spread = spread,
                    SellDistance = sellDistance,
                    IsSmithingInput = IsSmithingInput(priceRow.ItemId, priceRow.ItemName)
                });
            }

            return rows
                .OrderByDescending(r => r.Spread)
                .Take(MaxRouteRows)
                .ToList();
        }

        private static List<ActionPlanStep> BuildActionPlan(
            string nearestTownName,
            List<TradeRouteRow> routeRows,
            List<InventorySellRow> inventoryRows)
        {
            var steps = new List<ActionPlanStep>();
            var stepNum = 1;

            var topRoute = routeRows.FirstOrDefault();
            if (topRoute != null)
            {
                var smithTag = topRoute.IsSmithingInput ? " [smith]" : string.Empty;
                steps.Add(new ActionPlanStep
                {
                    Step = stepNum++,
                    Text =
                        $"Enter {nearestTownName}: buy {topRoute.ItemName} @ {topRoute.BuyPrice} (stock {topRoute.Stock}){smithTag}"
                });
                steps.Add(new ActionPlanStep
                {
                    Step = stepNum++,
                    Text =
                        $"Ride to {topRoute.SellTown} ({topRoute.SellDistance:0.0}u): sell @ {topRoute.SellPrice} (+{topRoute.Spread})"
                });
            }

            var inventorySell = inventoryRows
                .Where(r => r.SpreadVsWorst > 0)
                .OrderByDescending(r => r.SpreadVsWorst)
                .FirstOrDefault();

            if (inventorySell != null && stepNum <= MaxActionPlanSteps)
            {
                steps.Add(new ActionPlanStep
                {
                    Step = stepNum++,
                    Text =
                        $"Sell {inventorySell.ItemName} x{inventorySell.Quantity} @ {inventorySell.BestSellTown} {inventorySell.BestSellPrice} (+{inventorySell.SpreadVsWorst})"
                });
            }

            if (steps.Count == 0)
            {
                steps.Add(new ActionPlanStep
                {
                    Step = 1,
                    Text = $"No profitable routes from {nearestTownName} in scan range — ride toward another town and press Ctrl+Alt+M again."
                });
            }

            return steps.Take(MaxActionPlanSteps).ToList();
        }

        private static bool IsSmithingInput(string itemId, string itemName)
        {
            var combined = $"{itemId} {itemName}".ToLowerInvariant();
            return combined.Contains("iron")
                || combined.Contains("hardwood")
                || combined.Contains("charcoal")
                || combined.Contains("ore")
                || combined.Contains("steel");
        }

        private static string FormatSmithTag(bool isSmithingInput)
        {
            return isSmithingInput ? " [smith]" : string.Empty;
        }

        private static List<MarketTownSnapshot> BuildTownSnapshots(
            IReadOnlyList<Settlement> towns,
            Dictionary<string, ItemPriceMatrix> matrix)
        {
            var snapshots = new List<MarketTownSnapshot>();
            var partyPosition = MobileParty.MainParty.GetPosition2D;

            foreach (var settlement in towns)
            {
                var townName = settlement.Name?.ToString() ?? settlement.StringId;
                var goods = matrix.Values
                    .Select(row =>
                    {
                        if (!row.ByTown.TryGetValue(townName, out var entry) || entry.Stock <= 0)
                        {
                            return null;
                        }

                        return new MarketTownGoodRow
                        {
                            ItemId = row.ItemId,
                            ItemName = row.ItemName,
                            Stock = entry.Stock,
                            BuyPrice = entry.BuyPrice,
                            SellPrice = entry.SellPrice
                        };
                    })
                    .Where(g => g != null)
                    .OrderByDescending(g => g.Stock)
                    .Take(MaxTownGoodsRows)
                    .ToList();

                snapshots.Add(new MarketTownSnapshot
                {
                    SettlementId = settlement.StringId,
                    Name = townName,
                    Distance = settlement.GetPosition2D.Distance(partyPosition),
                    Goods = goods
                });
            }

            return snapshots;
        }

        private static void UpdateSummary(MarketIntelReport report)
        {
            var topSpread = report.SpreadRows.FirstOrDefault();
            var topRoute = report.RouteRows.FirstOrDefault();
            _summary = new MarketIntelSummary
            {
                HasScan = true,
                NearestTown = report.NearestTown,
                NearestDistance = report.NearestDistance,
                TownsScanned = report.TownsScanned,
                SpreadCount = report.SpreadRows.Count,
                RouteCount = report.RouteRows.Count,
                InventoryCount = report.InventoryRows.Count,
                ExpandedScanUsed = report.ExpandedScanUsed,
                TopSpreadLabel = topSpread == null
                    ? null
                    : $"{topSpread.ItemName} +{topSpread.Spread} ({topSpread.BuyTown}->{topSpread.SellTown})",
                TopRouteLabel = topRoute == null
                    ? null
                    : $"{topRoute.ItemName} +{topRoute.Spread} ({topRoute.BuyTown}->{topRoute.SellTown})",
                ReportPath = "BlacksmithGuild_MarketIntel.json"
            };
            _summaryRecorded = true;
        }

        private static void WriteMarketReport(string source)
        {
            var report = ReportFormatter.BeginReport("MARKET INTEL", source, "market-intel");

            report.Section("Context");
            report.Line("nearest", _cachedReport.NearestTown ?? "unknown");
            report.Line("distance", $"{_cachedReport.NearestDistance:0.1} map units");
            report.Line("townsScanned", _cachedReport.TownsScanned.ToString());
            if (_cachedReport.ExpandedScanUsed)
            {
                report.Line("scan", "expanded (no routes in 30u)");
            }

            if (_cachedReport.ActionPlan.Count > 0)
            {
                report.Section("Action Plan");
                foreach (var step in _cachedReport.ActionPlan)
                {
                    report.Line(step.Step.ToString(), step.Text);
                }
            }

            if (_cachedReport.RouteRows.Count > 0)
            {
                report.Section($"Buy @ Nearest ({_cachedReport.NearestTown})");
                foreach (var row in _cachedReport.RouteRows)
                {
                    var smithTag = FormatSmithTag(row.IsSmithingInput);
                    report.Line(
                        row.ItemName,
                        $"buy={row.BuyPrice} stock={row.Stock} -> {row.SellTown} sell={row.SellPrice} (+{row.Spread}){smithTag}");
                }
            }
            else
            {
                report.Section($"Buy @ Nearest ({_cachedReport.NearestTown})");
                report.Line("rows", "none (no profitable buy routes from nearest town)");
            }

            if (_cachedReport.InventoryRows.Count > 0)
            {
                report.Section("Sell From Inventory");
                foreach (var line in MarketTableFormatter.FormatInventoryTable(_cachedReport.InventoryRows))
                {
                    report.TableLine(line);
                }
            }
            else
            {
                report.Section("Sell From Inventory");
                report.Line("rows", "none (no trade goods in party inventory)");
            }

            if (_cachedReport.SpreadRows.Count > 0)
            {
                report.Section("Top Cross-Town Spreads");
                foreach (var line in MarketTableFormatter.FormatSpreadTable(_cachedReport.SpreadRows))
                {
                    report.TableLine(line);
                }
            }
            else
            {
                report.Section("Top Cross-Town Spreads");
                report.Line("rows", "none (no positive spreads among nearby towns)");
            }

            var nearestSnapshot = _cachedReport.Towns.FirstOrDefault();
            if (nearestSnapshot?.Goods.Count > 0)
            {
                report.Section($"Nearest Town Goods ({nearestSnapshot.Name})");
                foreach (var good in nearestSnapshot.Goods.Take(MaxTownGoodsRows))
                {
                    report.Line(
                        good.ItemName,
                        $"stock={good.Stock} buy={good.BuyPrice} sell={good.SellPrice}");
                }
            }

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_MarketIntel.json");

            var snapshot = GetAdvisorySnapshot();
            AdvisoryReportSections.EmitContextSummary(report, snapshot);
            AdvisoryReportSections.EmitActionPlan(report, snapshot.ActionPlan);
            AdvisoryReportSections.EmitBuyAtNearest(report, snapshot.RouteRows);
            AdvisoryReportSections.EmitInventorySells(report, snapshot.InventoryRows);
            AdvisoryReportSections.EmitTopSpreads(report, snapshot.SpreadRows);

            report.EndReport(
                emitInGame: string.Equals(source, MarketSnapshotNowCommand, StringComparison.Ordinal),
                emitToFile: true);
        }

        private static void WriteJsonReport(MarketIntelReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, SerializeReport(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MARKET] Failed to write JSON: {ex.Message}", showInGame: false);
            }
        }

        private static string SerializeReport(MarketIntelReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"nearestTown\": \"{Escape(report.NearestTown)}\",");
            builder.AppendLine($"  \"nearestDistance\": {report.NearestDistance:0.##},");
            builder.AppendLine($"  \"townsScanned\": {report.TownsScanned},");
            builder.AppendLine($"  \"expandedScanUsed\": {(report.ExpandedScanUsed ? "true" : "false")},");
            builder.AppendLine("  \"routeRows\": [");
            AppendRouteRows(builder, report.RouteRows);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"actionPlan\": [");
            AppendActionPlan(builder, report.ActionPlan);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"towns\": [");
            AppendTownSnapshots(builder, report.Towns);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"inventoryRows\": [");
            AppendInventoryRows(builder, report.InventoryRows);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"spreadRows\": [");
            AppendSpreadRows(builder, report.SpreadRows);
            builder.AppendLine("  ]");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendRouteRows(StringBuilder builder, List<TradeRouteRow> rows)
        {
            for (var i = 0; i < rows.Count; i++)
            {
                var row = rows[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"itemId\": \"{Escape(row.ItemId)}\",");
                builder.AppendLine($"      \"itemName\": \"{Escape(row.ItemName)}\",");
                builder.AppendLine($"      \"buyTown\": \"{Escape(row.BuyTown)}\",");
                builder.AppendLine($"      \"buyPrice\": {row.BuyPrice},");
                builder.AppendLine($"      \"stock\": {row.Stock},");
                builder.AppendLine($"      \"sellTown\": \"{Escape(row.SellTown)}\",");
                builder.AppendLine($"      \"sellPrice\": {row.SellPrice},");
                builder.AppendLine($"      \"spread\": {row.Spread},");
                builder.AppendLine($"      \"sellDistance\": {row.SellDistance:0.##},");
                builder.AppendLine($"      \"isSmithingInput\": {(row.IsSmithingInput ? "true" : "false")}");
                builder.Append(i < rows.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendActionPlan(StringBuilder builder, List<ActionPlanStep> steps)
        {
            for (var i = 0; i < steps.Count; i++)
            {
                var step = steps[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"step\": {step.Step},");
                builder.AppendLine($"      \"text\": \"{Escape(step.Text)}\"");
                builder.Append(i < steps.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendTownSnapshots(StringBuilder builder, List<MarketTownSnapshot> towns)
        {
            for (var t = 0; t < towns.Count; t++)
            {
                var town = towns[t];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"settlementId\": \"{Escape(town.SettlementId)}\",");
                builder.AppendLine($"      \"name\": \"{Escape(town.Name)}\",");
                builder.AppendLine($"      \"distance\": {town.Distance:0.##},");
                builder.AppendLine("      \"goods\": [");
                for (var g = 0; g < town.Goods.Count; g++)
                {
                    var good = town.Goods[g];
                    builder.AppendLine("        {");
                    builder.AppendLine($"          \"itemId\": \"{Escape(good.ItemId)}\",");
                    builder.AppendLine($"          \"itemName\": \"{Escape(good.ItemName)}\",");
                    builder.AppendLine($"          \"stock\": {good.Stock},");
                    builder.AppendLine($"          \"buyPrice\": {good.BuyPrice},");
                    builder.AppendLine($"          \"sellPrice\": {good.SellPrice}");
                    builder.Append(g < town.Goods.Count - 1 ? "        }," : "        }");
                    builder.AppendLine();
                }

                builder.AppendLine("      ]");
                builder.Append(t < towns.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendInventoryRows(StringBuilder builder, List<InventorySellRow> rows)
        {
            for (var i = 0; i < rows.Count; i++)
            {
                var row = rows[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"itemId\": \"{Escape(row.ItemId)}\",");
                builder.AppendLine($"      \"itemName\": \"{Escape(row.ItemName)}\",");
                builder.AppendLine($"      \"quantity\": {row.Quantity},");
                builder.AppendLine($"      \"bestSellTown\": \"{Escape(row.BestSellTown)}\",");
                builder.AppendLine($"      \"bestSellPrice\": {row.BestSellPrice},");
                builder.AppendLine($"      \"worstSellPrice\": {row.WorstSellPrice},");
                builder.AppendLine($"      \"spreadVsWorst\": {row.SpreadVsWorst}");
                builder.Append(i < rows.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendSpreadRows(StringBuilder builder, List<TradeSpreadRow> rows)
        {
            for (var i = 0; i < rows.Count; i++)
            {
                var row = rows[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"itemId\": \"{Escape(row.ItemId)}\",");
                builder.AppendLine($"      \"itemName\": \"{Escape(row.ItemName)}\",");
                builder.AppendLine($"      \"buyTown\": \"{Escape(row.BuyTown)}\",");
                builder.AppendLine($"      \"buyPrice\": {row.BuyPrice},");
                builder.AppendLine($"      \"sellTown\": \"{Escape(row.SellTown)}\",");
                builder.AppendLine($"      \"sellPrice\": {row.SellPrice},");
                builder.AppendLine($"      \"spread\": {row.Spread}");
                builder.Append(i < rows.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private static List<MarketBuyAtNearestRow> MapRouteRows(List<TradeRouteRow> rows)
        {
            return rows
                .Select(row => new MarketBuyAtNearestRow
                {
                    ItemName = row.ItemName,
                    BuyPrice = row.BuyPrice,
                    SellTown = row.SellTown,
                    SellPrice = row.SellPrice,
                    Spread = row.Spread,
                    IsSmithingInput = row.IsSmithingInput
                })
                .ToList();
        }

        private static List<MarketInventorySellRow> MapInventoryRows(List<InventorySellRow> rows)
        {
            return rows
                .Select(row => new MarketInventorySellRow
                {
                    ItemName = row.ItemName,
                    Quantity = row.Quantity,
                    BestSellTown = row.BestSellTown,
                    BestSellPrice = row.BestSellPrice,
                    SpreadVsWorst = row.SpreadVsWorst
                })
                .ToList();
        }

        private static List<MarketSpreadRow> MapSpreadRows(List<TradeSpreadRow> rows)
        {
            return rows
                .Select(row => new MarketSpreadRow
                {
                    ItemName = row.ItemName,
                    BuyTown = row.BuyTown,
                    BuyPrice = row.BuyPrice,
                    SellTown = row.SellTown,
                    SellPrice = row.SellPrice,
                    Spread = row.Spread
                })
                .ToList();
        }

        private static bool MatchesItem(string leftId, string leftName, string rightId, string rightName)
        {
            if (!string.IsNullOrEmpty(leftId)
                && !string.IsNullOrEmpty(rightId)
                && string.Equals(leftId, rightId, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName)
                && !string.IsNullOrEmpty(rightName)
                && string.Equals(leftName, rightName, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName) && !string.IsNullOrEmpty(rightName))
            {
                return leftName.IndexOf(rightName, StringComparison.OrdinalIgnoreCase) >= 0
                    || rightName.IndexOf(leftName, StringComparison.OrdinalIgnoreCase) >= 0;
            }

            return false;
        }
    }
}
