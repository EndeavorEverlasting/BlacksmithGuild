namespace BlacksmithGuild.ClanIntel
{
    public static class ClanIntelDoctrine
    {
        public const string DefaultDoctrine = "AseraiTradeSmith";
        public const string PreferredCultureId = "aserai";

        public static float CultureFitWeight => 1.4f;
        public static float FactionSafetyWeight => 1.2f;
        public static float RelationDeficitWeight => 0.8f;
        public static float DistancePenaltyPerUnit => 0.15f;
        public static float MaxScanDistance => 160f;
    }
}
