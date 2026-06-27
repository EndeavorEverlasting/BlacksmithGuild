namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignRuntimePolicy
    {
        public const string BranchGameHealth = "game_health";
        public const string BranchSurfaceSafety = "surface_safety";
        public const string BranchThreatPoliticsSafety = "threat_politics_safety";
        public const string BranchFoodQuantity = "food_quantity";
        public const string BranchFoodDiversity = "food_diversity";
        public const string BranchCapacityPressure = "capacity_pressure";
        public const string BranchHorseSpeedUtility = "horse_speed_utility";
        public const string BranchSmithingReadiness = "smithing_or_prep";
        public const string BranchProfitableTrade = "profitable_trade";
        public const string BranchTravelOpportunity = "travel_to_best_known_opportunity";
        public const string BranchCompanionOpportunity = "companion_tavern_opportunity";
        public const string BranchDiplomacyAdjustment = "diplomacy_political_adjustment";
        public const string BranchReportInsufficient = "report_insufficient";
        public const string BranchObserveOnly = "observe_only";
        public const string BranchFailSafePause = "failsafe_pause";

        public static int RankForBranch(string branch)
        {
            switch (branch)
            {
                case BranchGameHealth:
                    return 1;
                case BranchSurfaceSafety:
                    return 2;
                case BranchThreatPoliticsSafety:
                    return 3;
                case BranchFoodQuantity:
                    return 4;
                case BranchFoodDiversity:
                    return 5;
                case BranchCapacityPressure:
                    return 6;
                case BranchHorseSpeedUtility:
                    return 7;
                case BranchSmithingReadiness:
                    return 8;
                case BranchProfitableTrade:
                    return 9;
                case BranchTravelOpportunity:
                    return 10;
                case BranchCompanionOpportunity:
                    return 11;
                case BranchDiplomacyAdjustment:
                    return 12;
                case BranchReportInsufficient:
                    return 13;
                case BranchObserveOnly:
                    return 14;
                default:
                    return 99;
            }
        }
    }
}
