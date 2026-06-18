namespace BlacksmithGuild
{
    public sealed class ForgeCandidate
    {
        public string WeaponClass { get; set; }
        public string DesignName { get; set; }

        public int EstimatedValue { get; set; }
        public int EstimatedMaterialCost { get; set; }
        public int RareMaterialPenalty { get; set; }
        public int EstimatedNetProfit { get; set; }

        public float Score { get; set; }

        public string Reason { get; set; }

        public override string ToString()
        {
            return $"{DesignName} [{WeaponClass}] | Value {EstimatedValue} | Net {EstimatedNetProfit} | Score {Score}";
        }
    }
}
