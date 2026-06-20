using System.Collections.Generic;
using BlacksmithGuild.Forge;

namespace BlacksmithGuild
{
    public sealed class ForgeCandidate
    {
        public string Id { get; set; }
        public string WeaponClass { get; set; }
        public string DesignName { get; set; }
        public string Source { get; set; }

        public int EstimatedValue { get; set; }
        public int EstimatedMaterialCost { get; set; }
        public int RareMaterialPenalty { get; set; }
        public int EstimatedNetProfit { get; set; }
        public int DoctrineScore { get; set; }
        public float FinalScore { get; set; }

        public float Score { get; set; }

        public string Reason { get; set; }

        public List<RecipeMaterialNeed> MaterialNeeds { get; set; } = new List<RecipeMaterialNeed>();

        public override string ToString()
        {
            return $"{DesignName} [{WeaponClass}] | Net {EstimatedNetProfit} | Final {FinalScore:0} | {Reason}";
        }
    }
}
