using System.Collections.Generic;

namespace BlacksmithGuild.HorseMarket
{
    public enum HorseMarketActionType
    {
        BuyCapacity,
        BuyProfit,
        HoldUpgradeReserve,
        HoldCapacityReserve,
        SellExcess,
        WatchPrice,
        BlockedNoMarket,
        BlockedInsufficientGold,
        BlockedWouldBreakCapacityBuffer,
        BlockedUnknownClassification
    }

    public enum HorseAnimalClassification
    {
        PackAnimal,
        RidingMount,
        WarMount,
        NobleMount,
        Livestock,
        UnknownHorse
    }

    public enum ClassificationConfidence
    {
        High,
        Medium,
        Low
    }

    public enum RecommendationConfidence
    {
        High,
        Medium,
        Low
    }

    public sealed class HorseMarketActionCandidate
    {
        public HorseMarketActionType ActionType { get; set; }
        public string ItemStringId { get; set; }
        public string ItemName { get; set; }
        public HorseAnimalClassification Classification { get; set; }
        public int Quantity { get; set; }
        public int UnitPrice { get; set; }
        public int TotalCost { get; set; }
        public int ExpectedProfit { get; set; }
        public float CapacityDeltaEstimate { get; set; }
        public double ProjectedBufferPercent { get; set; }
        public double Score { get; set; }
        public List<string> Reasons { get; set; } = new List<string>();
        public List<string> RiskFlags { get; set; } = new List<string>();
        public RecommendationConfidence Confidence { get; set; }
    }
}
