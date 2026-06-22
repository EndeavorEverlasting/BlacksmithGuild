using System.Collections.Generic;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public enum CohesionDoctrineKind
    {
        TradeForge,
        Relief,
        Escort,
        BanditSuppression,
        SafeTraversal,
        Rally
    }

    public enum CohesionObjectiveType
    {
        TradeForge,
        Relief,
        Escort,
        BanditSuppression,
        SafeTraversal,
        Rally,
        ForgeHubMove
    }

    public enum CohesionRelationToPlayer
    {
        Player,
        Clan,
        Allied,
        Friendly,
        NeutralProtector,
        Hostile,
        Unknown
    }

    public enum CohesionPartyType
    {
        PlayerParty,
        ClanParty,
        LordParty,
        Army,
        Caravan,
        VillagerParty,
        BanditParty,
        HostileArmy,
        Unknown
    }

    public enum CohesionIntent
    {
        MovingToObjective,
        MovingTowardPlayer,
        MovingAwayFromPlayer,
        ChasingHostile,
        FleeingProtector,
        Patrolling,
        ShadowableProtector,
        PotentialHelper,
        PotentialThreat,
        Unknown
    }

    public enum CohesionConfidence
    {
        High,
        Medium,
        Low,
        Unknown
    }

    public enum CohesionRecommendedAction
    {
        MoveTowardHelper,
        ShadowProtector,
        WaitForCohesionWindow,
        AdvanceDuringProtectorPressure,
        RallyAtSafeSettlement,
        RallyAtConvergencePoint,
        EscortAlongRoute,
        ContinueTradeRoute,
        ContinueForgeProcurement,
        DuckIntoSettlement,
        RerouteAroundThreat,
        AbortCohesion,
        BlockedNoHelper,
        BlockedInsufficientStrength,
        BlockedNoMovementApi,
        BlockedUnknownRisk,
        BlockedWouldTriggerCombat,
        None
    }

    public enum CohesionExecutionState
    {
        Idle,
        Preflight,
        ScanParties,
        InferIntent,
        BuildObjectives,
        ScoreOpportunities,
        SelectCohesionPlan,
        MoveTowardCohesion,
        WaitForCohesionWindow,
        ShadowProtector,
        EvaluateWindow,
        AdvanceThroughWindow,
        DuckIntoSettlement,
        ResumeOriginalObjective,
        Complete,
        Blocked,
        Aborted,
        Failed
    }

    public sealed class CohesionObjective
    {
        public string ObjectiveId { get; set; }
        public CohesionObjectiveType ObjectiveType { get; set; }
        public string TargetSettlementId { get; set; }
        public string TargetSettlementName { get; set; }
        public Vec2 TargetPosition { get; set; }
        public List<string> RequiredItemIds { get; set; } = new List<string>();
        public string DesiredOutcome { get; set; }
        public float MaxDurationHours { get; set; } = 72f;
        public float MaxDistance { get; set; } = 160f;
        public float RiskTolerance { get; set; } = 0.5f;
        public bool AllowCombatContact { get; set; }
        public bool PreferAvoidingCombat { get; set; } = true;
    }

    public sealed class CohesionPartySnapshot
    {
        public string PartyId { get; set; }
        public string Name { get; set; }
        public string Faction { get; set; }
        public CohesionRelationToPlayer RelationToPlayer { get; set; }
        public CohesionPartyType PartyType { get; set; }
        public float PositionX { get; set; }
        public float PositionY { get; set; }
        public float Speed { get; set; }
        public int Strength { get; set; }
        public int TroopCount { get; set; }
        public int WoundedCount { get; set; }
        public string TargetPartyId { get; set; }
        public string TargetSettlementId { get; set; }
        public string CurrentBehavior { get; set; }
        public CohesionIntent InferredIntent { get; set; }
        public bool ControllableByPlayer { get; set; }
        public bool MovementApiAvailable { get; set; }
        public CohesionConfidence Confidence { get; set; }
        public List<string> ExtractionWarnings { get; set; } = new List<string>();
        public float DistanceToPlayer { get; set; }
    }

    public sealed class CohesionEtaBlock
    {
        public float? PlayerEtaHours { get; set; }
        public float? HelperEtaHours { get; set; }
        public float? HostileEtaHours { get; set; }
        public float? ConvergenceEtaHours { get; set; }
        public float? EscapeMarginHours { get; set; }
    }

    public sealed class CohesionPowerBlock
    {
        public int? PlayerStrength { get; set; }
        public int? HelperStrength { get; set; }
        public int? CombinedFriendlyStrength { get; set; }
        public int? HostileClusterStrength { get; set; }
        public float? StrengthRatio { get; set; }
        public string Confidence { get; set; }
    }

    public sealed class CohesionRiskBlock
    {
        public string InterceptRisk { get; set; }
        public bool? CombatContactLikely { get; set; }
        public string NearestSafeSettlement { get; set; }
        public float? FallbackEtaHours { get; set; }
    }

    public sealed class CohesionConvergencePoint
    {
        public float X { get; set; }
        public float Y { get; set; }
        public string Label { get; set; }
        public string SettlementId { get; set; }
    }

    public sealed class CohesionOpportunity
    {
        public string OpportunityId { get; set; }
        public CohesionObjectiveType ObjectiveType { get; set; }
        public CohesionPartySnapshot PrimaryParty { get; set; }
        public List<CohesionPartySnapshot> HelperParties { get; set; } = new List<CohesionPartySnapshot>();
        public List<CohesionPartySnapshot> HostileParties { get; set; } = new List<CohesionPartySnapshot>();
        public List<CohesionPartySnapshot> ProtectorParties { get; set; } = new List<CohesionPartySnapshot>();
        public CohesionConvergencePoint ConvergencePoint { get; set; }
        public CohesionEtaBlock Eta { get; set; } = new CohesionEtaBlock();
        public CohesionPowerBlock Power { get; set; } = new CohesionPowerBlock();
        public CohesionRiskBlock Risk { get; set; } = new CohesionRiskBlock();
        public CohesionRecommendedAction RecommendedAction { get; set; }
        public float Score { get; set; }
        public CohesionConfidence Confidence { get; set; }
        public List<string> Reasons { get; set; } = new List<string>();
        public List<string> Risks { get; set; } = new List<string>();
        public string BlockedReason { get; set; }
    }

    public sealed class CohesionOpportunitiesReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public bool ReadOnly { get; set; } = true;
        public bool MutationApplied { get; set; }
        public string Doctrine { get; set; }
        public CohesionObjective CurrentObjective { get; set; }
        public List<CohesionPartySnapshot> PartySnapshots { get; set; } = new List<CohesionPartySnapshot>();
        public List<CohesionOpportunity> Opportunities { get; set; } = new List<CohesionOpportunity>();
        public CohesionOpportunity SelectedOpportunity { get; set; }
        public string Verdict { get; set; }
    }

    public sealed class CohesionMoveStep
    {
        public string State { get; set; }
        public string Action { get; set; }
        public string Mode { get; set; }
        public string Result { get; set; }
        public List<string> Notes { get; set; } = new List<string>();
    }

    public sealed class CohesionMoveReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string LegitimacyMode { get; set; } = "VanillaVisibleCohesion";
        public bool VisibleModeEnabled { get; set; }
        public int DecisionPauseMs { get; set; }
        public bool MutationApplied { get; set; }
        public List<string> MutationTypes { get; set; } = new List<string>();
        public string SelectedOpportunityId { get; set; }
        public CohesionObjective Objective { get; set; }
        public CohesionExecutionState State { get; set; }
        public string Verdict { get; set; }
        public string BlockedReason { get; set; }
        public List<CohesionMoveStep> Steps { get; set; } = new List<CohesionMoveStep>();
        public List<string> CohesionWindowsUsed { get; set; } = new List<string>();
        public bool HelperMovementCommanded { get; set; }
        public string HelperMovementMethod { get; set; }
        public string HelperMovementReason { get; set; }
        public bool TeleportUsed { get; set; }
        public bool RawPositionSet { get; set; }
        public bool ObjectiveResumed { get; set; }
    }
}
