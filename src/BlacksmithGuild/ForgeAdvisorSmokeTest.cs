using System.Collections.Generic;

namespace BlacksmithGuild
{
    public static class ForgeAdvisorSmokeTest
    {
        public static void Run()
        {
            GuildLog.Info("campaign detected. Running Phase 1 fake forge advisor.");

            var advisor = new ForgeAdvisor(new MaterialReservePolicy());

            var fakeCandidates = new List<ForgeCandidate>
            {
                new ForgeCandidate
                {
                    WeaponClass = "Two-Handed Sword",
                    DesignName = "Long Warblade",
                    EstimatedValue = 14800,
                    EstimatedMaterialCost = 2200,
                    RareMaterialPenalty = 1350
                },
                new ForgeCandidate
                {
                    WeaponClass = "Polearm",
                    DesignName = "Heavy Glaive Pattern",
                    EstimatedValue = 11200,
                    EstimatedMaterialCost = 1200,
                    RareMaterialPenalty = 250
                },
                new ForgeCandidate
                {
                    WeaponClass = "One-Handed Sword",
                    DesignName = "Officer Sidearm",
                    EstimatedValue = 6200,
                    EstimatedMaterialCost = 900,
                    RareMaterialPenalty = 100
                }
            };

            var ranked = advisor.RankCandidates(fakeCandidates, ForgeDoctrine.ProfitForge);

            if (ranked.Count > 0)
            {
                var top = ranked[0];

                GuildLog.Info(
                    $"Top fake candidate: {top.DesignName} | Score {top.Score} | {top.Reason}"
                );
            }
            else
            {
                GuildLog.Info("No fake candidates found.");
            }
        }
    }
}
