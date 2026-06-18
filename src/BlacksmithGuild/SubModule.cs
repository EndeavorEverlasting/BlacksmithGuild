using System.Collections.Generic;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;

namespace BlacksmithGuild
{
    public sealed class SubModule : MBSubModuleBase
    {
        protected override void OnSubModuleLoad()
        {
            base.OnSubModuleLoad();
            GuildLog.Info("module loaded.");
        }

        protected override void OnGameStart(Game game, IGameStarter gameStarterObject)
        {
            base.OnGameStart(game, gameStarterObject);

            if (game.GameType is Campaign)
            {
                GuildLog.Info("campaign detected. Running Phase 1 fake forge advisor.");
                RunFakeForgeAdvisor();
            }
        }

        private static void RunFakeForgeAdvisor()
        {
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
