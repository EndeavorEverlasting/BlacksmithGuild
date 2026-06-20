using System.Collections.Generic;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.Forge;
using BlacksmithGuild.Market;
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
                GuildLoopService.RunGuildLoopNowCommand,
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
                MarketIntelligenceService.MarketSnapshotNowCommand
            };

        public static bool IsRegistered(string commandName)
        {
            return RegisteredCommands.Contains(commandName);
        }

        public static IReadOnlyCollection<string> RegisteredCommandNames => RegisteredCommands;
    }
}
