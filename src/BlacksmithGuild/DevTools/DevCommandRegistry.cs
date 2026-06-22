using System.Collections.Generic;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.Forge;
using BlacksmithGuild.HorseMarket;
using BlacksmithGuild.Market;
using BlacksmithGuild.TavernHeroes;
using BlacksmithGuild.Treasury;

namespace BlacksmithGuild.DevTools
{
    public static class DevCommandRegistry
    {
        public const string ListScenariosCommand = "ListScenarios";
        public const string AdvanceOneDayCommand = "AdvanceOneDay";
        public const string ToggleFastForwardCommand = "ToggleFastForward";
        public const string ShowForgeStatusCommand = "ShowForgeStatus";

        private static readonly HashSet<string> RegisteredCommands =
            new HashSet<string>
            {
                EconomyTestScenarios.RichPlayerEconomyTestName,
                ListScenariosCommand,
                AdvanceOneDayCommand,
                ToggleFastForwardCommand,
                ShowForgeStatusCommand,
                CharacterProgressionTestScenarios.RichSmithingProgressionTestName,
                CharacterProgressionTestScenarios.AddSmithingXpCommand,
                CharacterProgressionTestScenarios.AddSmithingFocusCommand,
                CharacterProgressionTestScenarios.AddEnduranceAttributeCommand,
                TreasuryDeltaWatchService.TreasurySnapshotNowCommand,
                ForgeRecommendationService.RankForgeCandidatesCommand,
                ForgeRecommendationService.SetForgeCandidateSourceStubCommand,
                ForgeRecommendationService.SetForgeCandidateSourceRealCommand,
                ForgeRecommendationService.ShowForgeCandidateSourceCommand,
                ForgeRecommendationService.SetForgeDoctrineProfitForgeCommand,
                ForgeRecommendationService.SetForgeDoctrineRareMetalConservationCommand,
                ForgeRecommendationService.SetForgeDoctrineCashCrisisCommand,
                ForgeRecommendationService.ShowForgeDoctrineCommand,
                ForgeRecommendationService.ProbeForgeRecipesCommand,
                SmithingAuditService.ProbeSmithingAuditCommand,
                SmithingAuditService.ProbeSmithingRefineApiCommand,
                SmithingAdvisoryService.RunSmithingAdvisoryNowCommand,
                SmithingSafeActionService.RunSmithingSafeActionNowCommand,
                SmithingRestPlanService.RunSmithingRestPlanNowCommand,
                BlacksmithAutomationService.RunBlacksmithAutomationNowCommand,
                GuildLoopService.RunGuildLoopNowCommand,
                CharacterDoctrineService.ShowCharacterDoctrineCommand,
                AutoCharacterBuildService.ApplyAutoCharacterBuildCommand,
                AutoCharacterBuildService.ShowAutoCharacterBuildProfilesCommand,
                AutoCharacterBuildService.ShowAutoCharacterBuildProfileCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildForgeQuartermasterWarlordCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildSmithEconomistCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildKingdomFounderCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildStewardSurgeonEngineerCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildWarCaptainCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildLightTouchVanillaPlusCommand,
                AutoCharacterBuildService.SetAutoCharacterBuildShadowTraderCommand,
                CharacterBuildVariantService.BuildCharacterChoiceCatalogNowCommand,
                CharacterBuildVariantService.GenerateCharacterBuildCandidatesNowCommand,
                CharacterBuildVariantService.SelectCharacterBuildBestNowCommand,
                CharacterBuildVariantService.RunCharacterVisibleReplayNowCommand,
                CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand,
                MarketIntelligenceService.MarketSnapshotNowCommand,
                HorseMarketRecommendationService.AnalyzeHorseMarketCommand,
                HorseMarketRecommendationService.ShowHorseMarketIntelCommand,
                HorseMarketRecommendationService.RankHorseMarketActionsCommand,
                AutoTravelService.ShowAutoTravelChoicesCommand,
                AutoTravelService.AutoTravelToRecommendedCommand,
                AutoTravelService.AutoTravelChoice1Command,
                AutoTravelService.AutoTravelChoice2Command,
                AutoTravelService.AutoTravelChoice3Command,
                AutoTravelService.AutoTravelChoice4Command,
                AutoTravelService.AutoTravelChoice5Command,
                TavernHeroIntelService.AnalyzeTavernHeroesCommand,
                TavernHeroIntelService.ShowTavernHeroIntelCommand,
                TavernHeroRecruitmentProbeService.ProbeTavernRecruitmentApiCommand,
                SettlementNavigationService.NavigateToSettlementTavernNowCommand,
                TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand,
                TavernHeroDoctrine.SetSmithingCrewCommand,
                TavernHeroDoctrine.SetScoutQuartermasterCommand,
                TavernHeroDoctrine.SetCombatEscortCommand
            };

        public static bool IsRegistered(string commandName)
        {
            return RegisteredCommands.Contains(commandName);
        }

        public static IReadOnlyCollection<string> RegisteredCommandNames => RegisteredCommands;
    }
}
