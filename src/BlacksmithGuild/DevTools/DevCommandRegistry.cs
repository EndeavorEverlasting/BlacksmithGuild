using System.Collections.Generic;
using BlacksmithGuild.CampaignRuntime;
using BlacksmithGuild.ClanIntel;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.Forge;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.HorseMarket;
using BlacksmithGuild.MapTrade;
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
        public const string ResumeCampaignClockCommand = "ResumeCampaignClock";
        public const string ShowForgeStatusCommand = "ShowForgeStatus";

        private static readonly HashSet<string> RegisteredCommands =
            new HashSet<string>
            {
                EconomyTestScenarios.RichPlayerEconomyTestName,
                ListScenariosCommand,
                AdvanceOneDayCommand,
                ToggleFastForwardCommand,
                ResumeCampaignClockCommand,
                ShowForgeStatusCommand,
                EngineToggleAuthority.ShowEngineToggleStateCommand,
                EngineToggleAuthority.CycleEngineToggleModeCommand,
                EngineToggleAuthority.SetEngineToggleManualCommand,
                EngineToggleAuthority.SetEngineToggleHybridCommand,
                EngineToggleAuthority.SetEngineToggleAutomationCommand,
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
                DevSaveService.SaveDevStartSaveNowCommand,
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
                CampaignRuntimeGovernor.RunCampaignGovernorCycleNowCommand,
                CampaignRuntimeGovernor.ShowCampaignGovernorDecisionCommand,
                CampaignRuntimeGovernor.PauseCampaignGovernorAutomationCommand,
                CampaignRuntimeGovernor.ResumeCampaignGovernorAutomationCommand,
                CampaignRuntimeRegent.ShowRuntimeRegentStateCommand,
                CampaignRouteCouncil.ConveneRouteCouncilCommand,
                CampaignRouteCouncil.ShowRouteCouncilCommand,
                HorseMarketAtlasService.ScanHorseAtlasCommand,
                HorseMarketAtlasService.ShowHorseAtlasCommand,
                HorseMarketAtlasService.RankHorseDestinationsCommand,
                HerdLedgerService.AnalyzeHerdLedgerCommand,
                HerdLedgerService.ShowHerdLedgerCommand,
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
                TavernHeroDoctrine.SetCombatEscortCommand,
                CohesionEngine.AnalyzeCohesionOpportunitiesCommand,
                CohesionEngine.ShowCohesionPlanCommand,
                CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand,
                CohesionExecutionDriver.AbortCohesionMoveNowCommand,
                CohesionDoctrine.SetCohesionDoctrineTradeForgeCommand,
                CohesionDoctrine.SetCohesionDoctrineReliefCommand,
                CohesionDoctrine.SetCohesionDoctrineEscortCommand,
                CohesionDoctrine.SetCohesionDoctrineBanditSuppressionCommand,
                MapTradeRouteSafetyAnalyzer.AnalyzeMapTradeRouteSafetyCommand,
                MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand,
                MapTradeAutonomousService.AbortMapTradeRouteNowCommand,
                MapTradeAutonomousService.ShowMapTradeRouteStatusCommand,
                MapTradeAutonomousService.AnalyzeTacticalConvergenceCommand,
                MapTradeAutonomousService.ShowTacticalConvergenceCommand,
                MapTradeForgeHandoffService.RunForgeHandoffAfterTradeNowCommand,
                MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand,
                MapTradeVanillaTradeDriver.ProbePackAnimalBuyNowCommand,
                SmithingSmeltService.ProbeWeaponSmeltNowCommand,
                SmithingSmeltService.RunWeaponSmeltNowCommand,
                AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand,
                AutonomousGuildLoopService.AbortAutonomousGuildLoopNowCommand,
                ClanContextService.AnalyzeClanContextCommand,
                ClanContextService.ShowClanContextCommand,
                NobleNetworkService.AnalyzeNobleNetworkCommand,
                NobleNetworkService.ShowNobleNetworkCommand,
                MarriageCandidateService.AnalyzeMarriageCandidatesCommand,
                CourtshipPlanService.ShowCourtshipPlanCommand,
                ClanRoleBoardService.AnalyzeClanRolesCommand,
                CourtshipProbeService.ProbeCourtshipApiCommand,
                AssistiveTownToTownProbeService.Command,
                AssistiveLeaveTownTravelService.Command
            };

        public static bool IsRegistered(string commandName)
        {
            return RegisteredCommands.Contains(commandName);
        }

        public static IReadOnlyCollection<string> RegisteredCommandNames => RegisteredCommands;
    }
}
