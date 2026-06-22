using System.Collections.Generic;
using BlacksmithGuild.Cohesion;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.MapTrade
{
    public enum MapTradeMissionType
    {
        BuySmithingMaterialAndKeep,
        BuySmithingMaterialThenSellSurplus,
        BuyProfitGoodAndSell,
        BuyPackAnimalForCapacityThenTrade,
        TravelOnlySafetyCert,
        BlockedNoSafeMission
    }

    public enum MapTradeRouteState
    {
        Idle,
        Preflight,
        SelectMission,
        CohesionCheck,
        TravelToTarget,
        WaitForArrival,
        EnterSettlement,
        ExecuteTrade,
        ForgeHandoff,
        Complete,
        Blocked,
        Aborted,
        Failed
    }

    public sealed class MapTradeMission
    {
        public MapTradeMissionType MissionType { get; set; }
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public Settlement TargetSettlement { get; set; }
        public string TargetSettlementName { get; set; }
        public float Distance { get; set; }
        public int BuyPrice { get; set; }
        public int Stock { get; set; }
        public float Score { get; set; }
        public string BlockReason { get; set; }
    }

    public sealed class MapTradeCohesionDecision
    {
        public string Phase { get; set; }
        public string RecommendedAction { get; set; }
        public float Score { get; set; }
        public string BlockedReason { get; set; }
    }

    public sealed class MapTradeRouteSafetyReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ReadOnly { get; set; } = true;
        public string Verdict { get; set; }
        public string BlockedReason { get; set; }
        public int HostileCount { get; set; }
        public float NearestHostileDistance { get; set; }
        public string ArmyPressureWindow { get; set; }
        public CohesionOpportunity SelectedCohesionOpportunity { get; set; }
        public List<MapTradeCohesionDecision> CohesionDecisions { get; set; } = new List<MapTradeCohesionDecision>();
    }

    public sealed class MapTradeExecutionResult
    {
        public int GoldBefore { get; set; }
        public int GoldAfter { get; set; }
        public int GoldDelta { get; set; }
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int QuantityBought { get; set; }
        public int InventoryBefore { get; set; }
        public int InventoryAfter { get; set; }
        public string ExecutionMethod { get; set; }
        public string ItemClassification { get; set; }
    }

    public sealed class MapTradeCertReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool VisibleModeEnabled { get; set; }
        public int DecisionPauseMs { get; set; }
        public bool MutationApplied { get; set; }
        public MapTradeRouteState State { get; set; }
        public MapTradeMission Mission { get; set; }
        public List<MapTradeCohesionDecision> CohesionDecisions { get; set; } = new List<MapTradeCohesionDecision>();
        public List<string> Steps { get; set; } = new List<string>();
        public string TradeDriverMethod { get; set; }
        public bool TradeDriverAvailable { get; set; }
        public MapTradeExecutionResult TradeExecution { get; set; }
        public string BlockedReason { get; set; }
        public string Verdict { get; set; }
    }

    public sealed class MapTradeForgeHandoffReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ForgeHandoffRan { get; set; }
        public string ForgeHandoffResult { get; set; }
        public string BlockedReason { get; set; }
    }

    public sealed class MapTradeArmyPressureReport
    {
        public string GeneratedUtc { get; set; }
        public string Window { get; set; }
        public int HostilePartiesInRadius { get; set; }
        public int FriendlyProtectorsInRadius { get; set; }
    }

    public sealed class MapTradeStatusSnapshot
    {
        public MapTradeRouteState State { get; set; }
        public string Verdict { get; set; }
        public string BlockedReason { get; set; }
        public bool IsRunning { get; set; }
        public bool IsTerminal { get; set; }
        public MapTradeMission Mission { get; set; }
    }
}
