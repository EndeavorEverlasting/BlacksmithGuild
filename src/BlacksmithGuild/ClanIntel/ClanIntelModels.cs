using System.Collections.Generic;

namespace BlacksmithGuild.ClanIntel
{
    public class ClanIntelEnvelope
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ReadOnly { get; set; } = true;
        public bool MutationApplied { get; set; }
        public string Doctrine { get; set; }
        public string Verdict { get; set; }
        public string BlockedReason { get; set; }
    }

    public sealed class PlayerClanSnapshot
    {
        public string Name { get; set; }
        public int? Tier { get; set; }
        public float? Renown { get; set; }
        public float? NextTierRenownNeeded { get; set; }
        public int? CompanionCount { get; set; }
        public int? CompanionLimit { get; set; }
        public int? PartySizeLimit { get; set; }
        public int? WorkshopLimit { get; set; }
        public string Kingdom { get; set; }
        public string Posture { get; set; }
        public bool? HasSpouse { get; set; }
    }

    public sealed class SocialPriority
    {
        public string Type { get; set; }
        public string Priority { get; set; }
        public string Reason { get; set; }
    }

    public sealed class RecommendedAction
    {
        public string Command { get; set; }
        public string Reason { get; set; }
    }

    public sealed class KingdomPostureBlock
    {
        public string RecommendedPosture { get; set; }
        public List<string> Reasons { get; set; } = new List<string>();
    }

    public sealed class FactionPowerPostureBlock
    {
        public string AllegianceMode { get; set; }
        public string KingdomName { get; set; }
        public string MapFactionName { get; set; }
        public bool IsAtWar { get; set; }
        public int? PlayerPartyStrength { get; set; }
        public int? PlayerTroopCount { get; set; }
        public int? NearestHostileStrength { get; set; }
        public float? NearestHostileDistance { get; set; }
        public float? StrengthRatioVsNearestHostile { get; set; }
        public int HostileCountInRadius { get; set; }
        public int FriendlyProtectorStrengthInRadius { get; set; }
        public string PowerVerdict { get; set; }
        public List<string> Warnings { get; set; } = new List<string>();
    }

    public sealed class ClanContextReport : ClanIntelEnvelope
    {
        public PlayerClanSnapshot PlayerClan { get; set; } = new PlayerClanSnapshot();
        public List<SocialPriority> SocialPriorities { get; set; } = new List<SocialPriority>();
        public List<RecommendedAction> RecommendedActions { get; set; } = new List<RecommendedAction>();
        public List<string> BlockedActions { get; set; } = new List<string>();
        public KingdomPostureBlock KingdomPosture { get; set; } = new KingdomPostureBlock();
        public FactionPowerPostureBlock FactionPowerPosture { get; set; } = new FactionPowerPostureBlock();
    }

    public sealed class NobleTarget
    {
        public string TargetNoble { get; set; }
        public string HeroId { get; set; }
        public string Clan { get; set; }
        public string Faction { get; set; }
        public int? Relation { get; set; }
        public string StrategicValue { get; set; }
        public List<string> Reasons { get; set; } = new List<string>();
        public string RecommendedAction { get; set; }
        public float? Distance { get; set; }
        public string RouteSafety { get; set; }
        public float Score { get; set; }
    }

    public sealed class NobleNetworkReport : ClanIntelEnvelope
    {
        public List<NobleTarget> Targets { get; set; } = new List<NobleTarget>();
        public NobleTarget TopTarget { get; set; }
    }

    public sealed class MarriageCandidateEntry
    {
        public string Candidate { get; set; }
        public string HeroId { get; set; }
        public string Category { get; set; }
        public string Culture { get; set; }
        public string Clan { get; set; }
        public float? Distance { get; set; }
        public string RouteSafety { get; set; }
        public string PoliticalValue { get; set; }
        public string SkillsValue { get; set; }
        public bool? CourtshipAvailable { get; set; }
        public string RecommendedAction { get; set; }
        public List<string> Warnings { get; set; } = new List<string>();
        public float Score { get; set; }
    }

    public sealed class MarriageCandidatesReport : ClanIntelEnvelope
    {
        public List<MarriageCandidateEntry> Candidates { get; set; } = new List<MarriageCandidateEntry>();
        public MarriageCandidateEntry TopCandidate { get; set; }
    }

    public sealed class TravelPlanBlock
    {
        public string TargetSettlement { get; set; }
        public string TargetHero { get; set; }
        public float? Distance { get; set; }
        public string RouteSafety { get; set; }
        public string RecommendedAction { get; set; }
    }

    public sealed class CourtshipPlanReport : ClanIntelEnvelope
    {
        public MarriageCandidateEntry TopCandidate { get; set; }
        public TravelPlanBlock TravelPlan { get; set; } = new TravelPlanBlock();
        public NobleTarget NobleContext { get; set; }
        public List<string> NextSteps { get; set; } = new List<string>();
        public List<string> CertificationGaps { get; set; } = new List<string>();
    }

    public sealed class ClanRoleSlot
    {
        public string Role { get; set; }
        public string Assigned { get; set; }
        public int? FitScore { get; set; }
        public bool MissingBetterCandidate { get; set; }
        public List<string> AssignedHeroes { get; set; } = new List<string>();
        public string RecommendedRecruitment { get; set; }
        public int? StaminaAvailable { get; set; }
    }

    public sealed class ClanRolesReport : ClanIntelEnvelope
    {
        public Dictionary<string, ClanRoleSlot> Roles { get; set; } = new Dictionary<string, ClanRoleSlot>();
        public List<string> RecruitmentGaps { get; set; } = new List<string>();
    }

    public sealed class CourtshipProbeHint
    {
        public string Name { get; set; }
        public bool Available { get; set; }
    }

    public sealed class CourtshipProbeReport : ClanIntelEnvelope
    {
        public List<CourtshipProbeHint> Hints { get; set; } = new List<CourtshipProbeHint>();
    }
}
