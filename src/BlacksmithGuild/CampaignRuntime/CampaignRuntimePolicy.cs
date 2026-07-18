namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignRuntimePolicy
    {
        public const string BranchGameHealth = "game_health";
        public const string BranchSurfaceSafety = "surface_safety";
        public const string BranchThreatPoliticsSafety = "threat_politics_safety";
        public const string BranchFoodQuantity = "food_quantity";
        public const string BranchFoodDiversity = "food_diversity";
        public const string BranchRefreshHorseAtlas = "refresh_horse_atlas";
        public const string BranchAnalyzeHerdLedger = "analyze_herd_ledger";
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

        public const string BranchHorseToManRatioGate = "horse_to_man_ratio";
        public const float MinHorseSurplusForRecruitment = 2.0f;

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
                case BranchRefreshHorseAtlas:
                    return 6;
                case BranchAnalyzeHerdLedger:
                    return 7;
                case BranchCapacityPressure:
                    return 8;
                case BranchHorseSpeedUtility:
                    return 9;
                case BranchSmithingReadiness:
                    return 10;
                case BranchProfitableTrade:
                    return 11;
                case BranchTravelOpportunity:
                    return 12;
                case BranchCompanionOpportunity:
                    return 13;
                case BranchDiplomacyAdjustment:
                    return 14;
                case BranchReportInsufficient:
                    return 15;
                case BranchObserveOnly:
                    return 16;
                default:
                    return 99;
            }
        }
    }
}
