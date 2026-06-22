namespace BlacksmithGuild.HorseMarket
{
    public static class HorseMarketDoctrine
    {
        public const double TargetBufferPercent = 25.0;
        public const double MaxCarriedWeightFraction = 0.75;
        public const int DefaultSafeGoldReserve = 500;
        public const double ProfitVsBaseValueThreshold = 0.85;
        public const int HardPenaltyBreaksBuffer = -1000;
        public const int HardPenaltyInsufficientGold = -1000;
        public const int PenaltyUnknownClassification = -250;
        public const int PenaltyWarNobleSellWithoutProof = -500;
    }
}
