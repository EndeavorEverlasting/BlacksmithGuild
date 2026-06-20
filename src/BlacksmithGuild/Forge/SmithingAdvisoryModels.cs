using System.Collections.Generic;

namespace BlacksmithGuild.Forge
{
    public enum SmithingActionKind
    {
        Rest,
        RefineCharcoal,
        Smelt,
        RefineMaterial,
        CraftRanked,
        TakeOrder,
        BuyMaterials
    }

    public enum SmithingWorkerRole
    {
        MainSmith,
        OrderSmith,
        CharcoalRefiner,
        Smelter,
        MaterialRefiner,
        Apprentice,
        ReserveWorker
    }

    public sealed class SmithingWorkerProfile
    {
        public string Name { get; set; }
        public bool IsMainHero { get; set; }
        public int CraftingSkill { get; set; }
        public int Stamina { get; set; }
        public int MaxStamina { get; set; }
        public bool StaminaKnown { get; set; }
    }

    public sealed class SmithingCrewRow
    {
        public int Rank { get; set; }
        public string HeroName { get; set; }
        public string Action { get; set; }
        public string Target { get; set; }
        public string Reason { get; set; }
        public string StaminaLabel { get; set; }
    }

    public sealed class SmithingRecommendation
    {
        public int Priority { get; set; }
        public string HeroName { get; set; }
        public string Action { get; set; }
        public string Target { get; set; }
        public string Reason { get; set; }
        public string ReserveImpact { get; set; }
    }

    public sealed class SmithingReserveHealth
    {
        public int CharcoalHave { get; set; }
        public int CharcoalFloor { get; set; }
        public int HardwoodHave { get; set; }
        public int HardwoodFloor { get; set; }
        public string CharcoalStatus { get; set; }
        public string HardwoodStatus { get; set; }
    }

    public sealed class SmithingAdvisoryReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string Status { get; set; }
        public string Detail { get; set; }
        public SmithingReserveHealth ReserveHealth { get; set; } = new SmithingReserveHealth();
        public List<SmithingWorkerProfile> Workers { get; set; } = new List<SmithingWorkerProfile>();
        public List<SmithingCrewRow> Crew { get; set; } = new List<SmithingCrewRow>();
        public List<SmithingRecommendation> Recommendations { get; set; } = new List<SmithingRecommendation>();
    }
}
