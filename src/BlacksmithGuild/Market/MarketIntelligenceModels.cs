using System;
using System.Collections.Generic;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.Market
{
    public sealed class MarketTownSnapshot
    {
        public string SettlementId { get; set; }
        public string Name { get; set; }
        public float Distance { get; set; }
        public List<MarketTownGoodRow> Goods { get; set; } = new List<MarketTownGoodRow>();
    }

    public sealed class MarketTownGoodRow
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int Stock { get; set; }
        public int BuyPrice { get; set; }
        public int SellPrice { get; set; }
    }

    public sealed class InventorySellRow
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int Quantity { get; set; }
        public string BestSellTown { get; set; }
        public int BestSellPrice { get; set; }
        public int WorstSellPrice { get; set; }
        public int SpreadVsWorst { get; set; }
    }

    public sealed class TradeSpreadRow
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public string BuyTown { get; set; }
        public int BuyPrice { get; set; }
        public string SellTown { get; set; }
        public int SellPrice { get; set; }
        public int Spread { get; set; }
    }

    public sealed class TradeRouteRow
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public string BuyTown { get; set; }
        public int BuyPrice { get; set; }
        public int Stock { get; set; }
        public string SellTown { get; set; }
        public int SellPrice { get; set; }
        public int Spread { get; set; }
        public float SellDistance { get; set; }
        public bool IsSmithingInput { get; set; }
    }

    public sealed class MarketIntelSummary
    {
        public bool HasScan { get; set; }
        public string NearestTown { get; set; }
        public float NearestDistance { get; set; }
        public int TownsScanned { get; set; }
        public int SpreadCount { get; set; }
        public int RouteCount { get; set; }
        public int InventoryCount { get; set; }
        public string TopSpreadLabel { get; set; }
        public string TopRouteLabel { get; set; }
        public bool ExpandedScanUsed { get; set; }
        public string ReportPath { get; set; } = "BlacksmithGuild_MarketIntel.json";
    }

    public sealed class MarketIntelReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string NearestTown { get; set; }
        public float NearestDistance { get; set; }
        public int TownsScanned { get; set; }
        public bool ExpandedScanUsed { get; set; }
        public List<MarketTownSnapshot> Towns { get; set; } = new List<MarketTownSnapshot>();
        public List<InventorySellRow> InventoryRows { get; set; } = new List<InventorySellRow>();
        public List<TradeSpreadRow> SpreadRows { get; set; } = new List<TradeSpreadRow>();
        public List<TradeRouteRow> RouteRows { get; set; } = new List<TradeRouteRow>();
        public List<ActionPlanStep> ActionPlan { get; set; } = new List<ActionPlanStep>();
    }

    internal sealed class TownPriceEntry
    {
        public string TownName { get; set; }
        public int BuyPrice { get; set; }
        public int SellPrice { get; set; }
        public int Stock { get; set; }
    }

    internal sealed class ItemPriceMatrix
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public Dictionary<string, TownPriceEntry> ByTown { get; } =
            new Dictionary<string, TownPriceEntry>(StringComparer.OrdinalIgnoreCase);
    }
}
