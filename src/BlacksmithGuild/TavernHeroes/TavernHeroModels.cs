using System.Collections.Generic;

namespace BlacksmithGuild.TavernHeroes
{
    public sealed class TavernHeroCandidate
    {
        public string HeroId { get; set; }
        public string Name { get; set; }
        public string Occupation { get; set; }
        public string Culture { get; set; }
        public string Clan { get; set; }
        public bool? IsWanderer { get; set; }
        public bool? IsCompanion { get; set; }
        public bool? IsAlive { get; set; }
        public bool? IsPrisoner { get; set; }
        public string CurrentSettlement { get; set; }
        public bool? RecruitmentAvailable { get; set; }
        public int? RecruitmentCost { get; set; }
        public Dictionary<string, int?> Skills { get; set; } = new Dictionary<string, int?>();
        public List<string> Traits { get; set; } = new List<string>();
        public int? EquipmentTier { get; set; }
        public int? EquipmentValue { get; set; }
        public List<string> RiskFlags { get; set; } = new List<string>();
        public List<string> Warnings { get; set; } = new List<string>();
        public float Score { get; set; }
    }

    public sealed class TavernHeroRecommendation
    {
        public string HeroId { get; set; }
        public string Name { get; set; }
        public float Score { get; set; }
        public List<string> Reasons { get; set; } = new List<string>();
        public int? RecruitmentCost { get; set; }
        public string Label { get; set; }
    }

    public sealed class TavernHeroSettlementSnapshot
    {
        public string Name { get; set; }
        public string StringId { get; set; }
        public string Type { get; set; }
        public bool? HasTavern { get; set; }
        public bool PlayerInSettlement { get; set; }
        public bool PlayerInTavern { get; set; }
        public string ActiveMenuId { get; set; }
        public string CurrentLocationId { get; set; }
        public string BlockedReason { get; set; }
    }

    public sealed class TavernHeroPlayerSnapshot
    {
        public int Gold { get; set; }
        public int SafeGoldReserve { get; set; }
        public int SpendableGold { get; set; }
    }

    public sealed class TavernHeroCompanionStateSnapshot
    {
        public int? CurrentCompanionCount { get; set; }
        public int? CompanionLimit { get; set; }
        public int? RemainingSlots { get; set; }
        public bool LimitAvailable { get; set; }
        public List<string> PartyHeroes { get; set; } = new List<string>();
        public List<string> SmithingCrewCandidates { get; set; } = new List<string>();
    }

    public sealed class TavernHeroIntelReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ReadOnly { get; set; } = true;
        public bool MutationApplied { get; set; }
        public string Doctrine { get; set; }
        public TavernHeroSettlementSnapshot Settlement { get; set; } = new TavernHeroSettlementSnapshot();
        public TavernHeroPlayerSnapshot Player { get; set; } = new TavernHeroPlayerSnapshot();
        public TavernHeroCompanionStateSnapshot CompanionState { get; set; } = new TavernHeroCompanionStateSnapshot();
        public List<TavernHeroCandidate> Candidates { get; set; } = new List<TavernHeroCandidate>();
        public List<TavernHeroRecommendation> Recommendations { get; set; } = new List<TavernHeroRecommendation>();
        public TavernHeroRecommendation TopRecommendation { get; set; }
        public string BlockedReason { get; set; }
        public string Verdict { get; set; }
    }

    public sealed class TavernHeroRecruitmentActionStep
    {
        public string Step { get; set; }
        public string Mode { get; set; }
        public string Result { get; set; }
        public string Detail { get; set; }
    }

    public sealed class TavernHeroRecruitmentReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string LegitimacyMode { get; set; } = "VanillaVisibleRecruitment";
        public bool VisibleModeEnabled { get; set; }
        public int DecisionPauseMs { get; set; }
        public TavernHeroRecommendation SelectedCandidate { get; set; }
        public TavernHeroRecruitmentStateSnapshot Before { get; set; } = new TavernHeroRecruitmentStateSnapshot();
        public TavernHeroRecruitmentStateSnapshot After { get; set; } = new TavernHeroRecruitmentStateSnapshot();
        public List<TavernHeroRecruitmentActionStep> Actions { get; set; } = new List<TavernHeroRecruitmentActionStep>();
        public TavernHeroRecruitmentAudit MutationAudit { get; set; } = new TavernHeroRecruitmentAudit();
        public string BlockedReason { get; set; }
        public string Verdict { get; set; }
    }

    public sealed class TavernHeroRecruitmentStateSnapshot
    {
        public int Gold { get; set; }
        public int? GoldDelta { get; set; }
        public int? CompanionCount { get; set; }
        public List<string> PartyHeroes { get; set; } = new List<string>();
        public bool? CandidateInParty { get; set; }
    }

    public sealed class TavernHeroRecruitmentAudit
    {
        public bool GoldMutatedByVanillaRecruitment { get; set; }
        public bool PartyChangedByVanillaRecruitment { get; set; }
        public bool DirectHeroInjectionUsed { get; set; }
        public bool FreeRecruitmentUsed { get; set; }
    }
}
