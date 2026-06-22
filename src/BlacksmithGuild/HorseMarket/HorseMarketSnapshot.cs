using System.Collections.Generic;

namespace BlacksmithGuild.HorseMarket
{
    public sealed class HorseMarketSettlementSnapshot
    {
        public string Name { get; set; }
        public string StringId { get; set; }
        public string Type { get; set; }
        public bool MarketAvailable { get; set; }
        public string BlockedReason { get; set; }
    }

    public sealed class HorseMarketPlayerSnapshot
    {
        public int Gold { get; set; }
        public int SafeGoldReserve { get; set; }
        public int SpendableGold { get; set; }
    }

    public sealed class HorseMarketCapacitySnapshot
    {
        public double TargetBufferPercent { get; set; }
        public float CurrentCapacity { get; set; }
        public float CurrentCarriedWeight { get; set; }
        public float CurrentFreeCapacity { get; set; }
        public double CurrentBufferPercent { get; set; }
        public float CapacityDeficit { get; set; }
        public double ProjectedBufferAfterRecommendedBuys { get; set; }
    }

    public sealed class HorseMarketHerdSnapshot
    {
        public bool HerdModelAvailable { get; set; }
        public bool? HerdPenaltyObserved { get; set; }
        public string HerdPenaltyText { get; set; }
        public string FootmenOnHorsesBonus { get; set; }
        public string SpeedSummary { get; set; }
    }

    public sealed class HorseAnimalSnapshot
    {
        public string StringId { get; set; }
        public string Name { get; set; }
        public int Count { get; set; }
        public int Value { get; set; }
        public float Weight { get; set; }
        public string ItemCategory { get; set; }
        public string ItemType { get; set; }
        public int Tier { get; set; }
        public bool HasHorseComponent { get; set; }
        public float? Speed { get; set; }
        public float? Maneuver { get; set; }
        public float? ChargeDamage { get; set; }
        public int? HitPoints { get; set; }
        public bool? IsMountable { get; set; }
        public HorseAnimalClassification Classification { get; set; }
        public ClassificationConfidence ClassificationConfidence { get; set; }
        public string ClassificationReason { get; set; }
        public int? AskPrice { get; set; }
        public int? BaseValue { get; set; }
        public double QualityScore { get; set; }
        public double CapacityUtilityScore { get; set; }
        public double UpgradeUtilityScore { get; set; }
        public double ProfitScore { get; set; }
        public List<string> RiskFlags { get; set; } = new List<string>();
    }

    public sealed class HorseMarketAnalysisContext
    {
        public string SessionPhase { get; set; }
        public string SettlementResolveMethod { get; set; }
        public bool UpgradeDemandAvailable { get; set; }
        public HorseMarketSettlementSnapshot Settlement { get; set; } = new HorseMarketSettlementSnapshot();
        public HorseMarketPlayerSnapshot Player { get; set; } = new HorseMarketPlayerSnapshot();
        public HorseMarketCapacitySnapshot Capacity { get; set; } = new HorseMarketCapacitySnapshot();
        public HorseMarketHerdSnapshot Herd { get; set; } = new HorseMarketHerdSnapshot();
        public List<HorseAnimalSnapshot> PlayerAnimals { get; set; } = new List<HorseAnimalSnapshot>();
        public List<HorseAnimalSnapshot> MarketAnimals { get; set; } = new List<HorseAnimalSnapshot>();
    }
}
