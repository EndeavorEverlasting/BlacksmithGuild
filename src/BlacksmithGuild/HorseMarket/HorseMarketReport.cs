using System.Collections.Generic;

namespace BlacksmithGuild.HorseMarket
{
    public sealed class HorseMarketReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ReadOnly { get; set; } = true;
        public bool MutationApplied { get; set; }
        public HorseMarketSettlementSnapshot Settlement { get; set; } = new HorseMarketSettlementSnapshot();
        public HorseMarketPlayerSnapshot Player { get; set; } = new HorseMarketPlayerSnapshot();
        public HorseMarketCapacitySnapshot Capacity { get; set; } = new HorseMarketCapacitySnapshot();
        public HorseMarketHerdSnapshot Herd { get; set; } = new HorseMarketHerdSnapshot();
        public bool UpgradeDemandAvailable { get; set; }
        public List<HorseAnimalSnapshot> PlayerAnimals { get; set; } = new List<HorseAnimalSnapshot>();
        public List<HorseAnimalSnapshot> MarketAnimals { get; set; } = new List<HorseAnimalSnapshot>();
        public List<HorseMarketActionCandidate> Recommendations { get; set; } = new List<HorseMarketActionCandidate>();
        public HorseMarketActionCandidate TopRecommendation { get; set; }
        public string BlockedReason { get; set; }
        public string Verdict { get; set; }
    }
}
