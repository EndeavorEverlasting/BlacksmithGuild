using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.Reporting
{
    public sealed class ActionPlanStep
    {
        public int Step { get; set; }
        public string Text { get; set; }
    }

    public sealed class SourceHonestyInfo
    {
        public string Requested { get; set; }
        public string Resolved { get; set; }
        public bool FallbackUsed { get; set; }
        public string Detail { get; set; }
        public ReportVerdict Verdict { get; set; }
        public string VerdictMessage { get; set; }
    }

    public sealed class MaterialGapRow
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int Need { get; set; }
        public int Have { get; set; }
        public string BuyTown { get; set; }
        public int? BuyPrice { get; set; }
        public int? Stock { get; set; }
        public string BuyHint { get; set; }
    }

    public sealed class CraftCandidateRow
    {
        public string Name { get; set; }
        public float FinalScore { get; set; }
        public int NetProfit { get; set; }
        public bool IsStub { get; set; }
    }

    public sealed class MarketBuyAtNearestRow
    {
        public string ItemName { get; set; }
        public int BuyPrice { get; set; }
        public string SellTown { get; set; }
        public int SellPrice { get; set; }
        public int Spread { get; set; }
        public bool IsSmithingInput { get; set; }
    }

    public sealed class MarketSpreadRow
    {
        public string ItemName { get; set; }
        public string BuyTown { get; set; }
        public int BuyPrice { get; set; }
        public string SellTown { get; set; }
        public int SellPrice { get; set; }
        public int Spread { get; set; }
    }

    public sealed class MarketInventorySellRow
    {
        public string ItemName { get; set; }
        public int Quantity { get; set; }
        public string BestSellTown { get; set; }
        public int BestSellPrice { get; set; }
        public int SpreadVsWorst { get; set; }
    }

    public sealed class MarketAdvisorySnapshot
    {
        public bool HasScan { get; set; }
        public string NearestTown { get; set; }
        public float NearestDistance { get; set; }
        public int TownsScanned { get; set; }
        public bool ExpandedScanUsed { get; set; }
        public IReadOnlyList<ActionPlanStep> ActionPlan { get; set; } = new List<ActionPlanStep>();
        public IReadOnlyList<MarketBuyAtNearestRow> RouteRows { get; set; } = new List<MarketBuyAtNearestRow>();
        public IReadOnlyList<MarketInventorySellRow> InventoryRows { get; set; } = new List<MarketInventorySellRow>();
        public IReadOnlyList<MarketSpreadRow> SpreadRows { get; set; } = new List<MarketSpreadRow>();
    }
}
