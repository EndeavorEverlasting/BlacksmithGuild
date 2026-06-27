using System.Collections.Generic;

namespace BlacksmithGuild.CampaignRuntime
{
    public sealed class CampaignRuntimeDecision
    {
        public string CycleId { get; set; }
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string Surface { get; set; }
        public string GameHealth { get; set; }
        public string SelectedBranch { get; set; }
        public string SelectedReason { get; set; }
        public int PriorityRank { get; set; }
        public List<CampaignRuntimeBlockedBranch> BlockedBranches { get; set; } = new List<CampaignRuntimeBlockedBranch>();
        public string CurrentTown { get; set; }
        public string DestinationCandidate { get; set; }
        public string FoodStatus { get; set; }
        public string FoodDiversityStatus { get; set; }
        public string FoodForecastStatus { get; set; }
        public string CapacityStatus { get; set; }
        public string HorseStatus { get; set; }
        public string StaminaStatus { get; set; }
        public string MaterialStatus { get; set; }
        public string TradeStatus { get; set; }
        public string SmithingStatus { get; set; }
        public string CompanionStatus { get; set; }
        public string DiplomacyStatus { get; set; }
        public string ThreatStatus { get; set; }
        public bool ReportInsufficient { get; set; }
        public bool MapScanRequired { get; set; }
        public string Confidence { get; set; }
        public bool Allowed { get; set; }
        public string FailureClass { get; set; }
        public string RouteCouncilWinningEngine { get; set; }
        public string RouteCouncilRecommendedActivity { get; set; }
        public string RouteCouncilRecommendedDestination { get; set; }
        public string RouteCouncilBlockedReason { get; set; }
        public string RouteCouncilVerdict { get; set; }
        public string HorseAtlasVerdict { get; set; }
        public string HorseAtlasTopDestination { get; set; }
        public bool HorseAtlasLocalVerificationRequired { get; set; }
        public string HerdLedgerPosture { get; set; }
        public string NextAction { get; set; }
        public CampaignActivityRequest ProposedActivity { get; set; }
        public CampaignActivityResult LatestActivityResult { get; set; }
    }

    public sealed class CampaignRuntimeBlockedBranch
    {
        public string Branch { get; set; }
        public string Reason { get; set; }
        public int PriorityRank { get; set; }
    }
}
