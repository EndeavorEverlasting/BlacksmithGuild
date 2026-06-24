using BlacksmithGuild.ClanIntel;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.Forge;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.HorseMarket;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;
using BlacksmithGuild.TavernHeroes;
using BlacksmithGuild.Treasury;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.DevTools
{
    public enum DevCommandResult
    {
        Success,
        Blocked,
        Failed,
        Unknown
    }

    public static class DevCommandBus
    {
        public static DevCommandResult TryRun(
            string commandName,
            string source,
            string hotkeyLabel = null,
            int sequence = -1)
        {
            GameSessionState.SyncForgeStatus();

            DebugLogger.Test(
                $"Command received: {commandName} (source: {source})",
                showInGame: false
            );

            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                HotkeyTraceService.OnCommandReceived(hotkeyLabel, commandName);
            }

            var travelName = ExtractAutoTravelName(commandName);
            if (travelName != null)
            {
                commandName = AutoTravelService.AutoTravelPrefix + travelName;
            }

            if (travelName == null && !DevCommandRegistry.IsRegistered(commandName))
            {
                DebugLogger.Test($"Unknown command: {commandName}");
                ForgeStatus.RecordCommand(commandName, source, "FAIL", "unknown command", sequence);
                NotifyUnknown(commandName, hotkeyLabel);
                return DevCommandResult.Unknown;
            }

            NotifyRequest(commandName, hotkeyLabel);

            if (IsMutationCommand(commandName))
            {
                DebugLogger.Test($"MUTATION COMMAND: {commandName}", showInGame: false);
                DebugLogger.Test("Use disposable campaign only.", showInGame: false);
            }

            if (RequiresRiskyGate(commandName))
            {
                var canRun = commandName == TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand
                    ? GameReadinessService.CanRunTavernRecruitment(out var tavernBlockReason)
                    : GameReadinessService.CanRunRiskyCommands(out tavernBlockReason);
                if (!canRun)
                {
                    var blockReason = tavernBlockReason;
                    DebugLogger.Test($"{commandName} blocked: {blockReason}");
                    ForgeStatus.RecordCommand(commandName, source, "BLOCKED", blockReason, sequence);
                    ForgeStatus.SetTest(commandName, "BLOCKED", blockReason);
                    CertificationTracker.OnCommandResult(commandName, DevCommandResult.Blocked, blockReason);
                    Sprint002CertificationTracker.OnCommandResult(commandName, DevCommandResult.Blocked, blockReason);
                    NotifyBlocked(commandName, hotkeyLabel, blockReason);
                    TraceCommandResult(hotkeyLabel, commandName, DevCommandResult.Blocked, blockReason);
                    return DevCommandResult.Blocked;
                }

                if (GameReadinessService.Verdict == PreflightVerdict.Unknown ||
                    GameReadinessService.Verdict == PreflightVerdict.Warn)
                {
                    DebugLogger.Test(
                        $"Warning: preflight was {GameReadinessService.Verdict}; proceeding with {commandName}.",
                        showInGame: false
                    );
                }
            }

            DebugLogger.Test($"Command started: {commandName}", showInGame: false);

            var result = Execute(commandName);
            ForgeStatus.RecordCommand(commandName, source, result.ToString(), null, sequence);
            CertificationTracker.OnCommandResult(commandName, result);
            Sprint002CertificationTracker.OnCommandResult(commandName, result);
            NotifyResult(commandName, hotkeyLabel, result);
            TraceCommandResult(hotkeyLabel, commandName, result);
            return result;
        }

        private static void TraceCommandResult(
            string hotkeyLabel,
            string commandName,
            DevCommandResult result,
            string reason = null)
        {
            if (string.IsNullOrEmpty(hotkeyLabel))
            {
                return;
            }

            var detail = reason ?? (result == DevCommandResult.Blocked
                ? GameReadinessService.LastBlockReason
                : null);
            HotkeyTraceService.OnCommandResult(hotkeyLabel, commandName, result, detail);
        }

        private static void NotifyRequest(string commandName, string hotkeyLabel)
        {
            if (string.IsNullOrEmpty(hotkeyLabel))
            {
                return;
            }

            switch (hotkeyLabel)
            {
                case "F9":
                    InGameNotice.Info(ModDisplay.CompactLine("F9", "Daily tick test requested."));
                    break;
                case "F11":
                    InGameNotice.Info(ModDisplay.CompactLine("F11", "Gold test requested."));
                    break;
                case "Ctrl+Alt+D":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+D", "Daily tick test requested."));
                    break;
                case "Ctrl+Alt+F":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+F", "Fast-forward toggle requested."));
                    break;
                case "Ctrl+Alt+S":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+S", "Progression test requested."));
                    break;
                case "Ctrl+Alt+X":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+X", "Smithing XP test requested."));
                    break;
                case "Ctrl+Alt+C":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+C", "Smithing focus test requested."));
                    break;
                case "Ctrl+Alt+B":
                    InGameNotice.Info(ModDisplay.CompactLine("Ctrl+Alt+B", "Abort movement automation requested."));
                    break;
            }
        }

        private static void NotifyBlocked(string commandName, string hotkeyLabel, string blockReason)
        {
            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                InGameNotice.Blocked(ModDisplay.CompactLine(hotkeyLabel, $"BLOCKED: {blockReason}"));
                return;
            }

            InGameNotice.Blocked(ModDisplay.CompactLine("Command", $"{commandName} blocked because {blockReason}"));
        }

        private static void NotifyUnknown(string commandName, string hotkeyLabel)
        {
            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                InGameNotice.Fail(ModDisplay.CompactLine(hotkeyLabel, $"FAILED: unknown command {commandName}"));
            }
        }

        private static void NotifyResult(string commandName, string hotkeyLabel, DevCommandResult result)
        {
            if (result == DevCommandResult.Blocked || result == DevCommandResult.Unknown)
            {
                return;
            }

            if (commandName == DevCommandRegistry.ShowForgeStatusCommand ||
                commandName == DevCommandRegistry.ListScenariosCommand ||
                commandName == ForgeRecommendationService.RankForgeCandidatesCommand ||
                commandName == ForgeRecommendationService.ShowForgeCandidateSourceCommand ||
                commandName == ForgeRecommendationService.ShowForgeDoctrineCommand ||
                commandName == ForgeRecommendationService.ProbeForgeRecipesCommand ||
                commandName == SmithingAuditService.ProbeSmithingAuditCommand ||
                commandName == SmithingAuditService.ProbeSmithingRefineApiCommand ||
                commandName == MarketIntelligenceService.MarketSnapshotNowCommand ||
                commandName == HorseMarketRecommendationService.AnalyzeHorseMarketCommand ||
                commandName == HorseMarketRecommendationService.ShowHorseMarketIntelCommand ||
                commandName == HorseMarketRecommendationService.RankHorseMarketActionsCommand ||
                commandName == AutoTravelService.ShowAutoTravelChoicesCommand ||
                commandName == TavernHeroIntelService.AnalyzeTavernHeroesCommand ||
                commandName == TavernHeroIntelService.ShowTavernHeroIntelCommand ||
                commandName == TavernHeroRecruitmentProbeService.ProbeTavernRecruitmentApiCommand ||
                commandName == SettlementNavigationService.NavigateToSettlementTavernNowCommand ||
                commandName == CohesionEngine.AnalyzeCohesionOpportunitiesCommand ||
                commandName == CohesionEngine.ShowCohesionPlanCommand ||
                commandName == MapTradeRouteSafetyAnalyzer.AnalyzeMapTradeRouteSafetyCommand ||
                commandName == MapTradeAutonomousService.ShowMapTradeRouteStatusCommand ||
                commandName == MapTradeAutonomousService.AnalyzeTacticalConvergenceCommand ||
                commandName == MapTradeAutonomousService.ShowTacticalConvergenceCommand ||
                commandName == MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand ||
                commandName == ClanContextService.AnalyzeClanContextCommand ||
                commandName == ClanContextService.ShowClanContextCommand ||
                commandName == NobleNetworkService.AnalyzeNobleNetworkCommand ||
                commandName == NobleNetworkService.ShowNobleNetworkCommand ||
                commandName == MarriageCandidateService.AnalyzeMarriageCandidatesCommand ||
                commandName == CourtshipPlanService.ShowCourtshipPlanCommand ||
                commandName == ClanRoleBoardService.AnalyzeClanRolesCommand ||
                commandName == CourtshipProbeService.ProbeCourtshipApiCommand ||
                commandName == AssistiveTownToTownProbeService.Command ||
                commandName == AssistiveLeaveTownTravelService.Command ||
                commandName == MapTradeForgeHandoffService.RunForgeHandoffAfterTradeNowCommand ||
                IsTavernDoctrineCommand(commandName) ||
                IsAutoCharacterBuildNonMutationCommand(commandName))
            {
                return;
            }

            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                NotifyHotkeyResult(commandName, hotkeyLabel, result);
                return;
            }

            NotifyNonHotkeyResult(commandName, result);
        }

        private static void NotifyNonHotkeyResult(string commandName, DevCommandResult result)
        {
            if (result == DevCommandResult.Failed)
            {
                InGameNotice.Fail(ModDisplay.CompactLine("Command", $"{commandName} — {GetFailReason(commandName)}"));
                return;
            }

            if (result != DevCommandResult.Success)
            {
                return;
            }

            switch (commandName)
            {
                case DevCommandRegistry.AdvanceOneDayCommand:
                    InGameNotice.Success("DailyTick fired.");
                    break;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    InGameNotice.Success(
                        TimeDevTools.IsFastForwardActive
                            ? "Fast-forward ON."
                            : "Fast-forward OFF."
                    );
                    break;
                case TreasuryDeltaWatchService.TreasurySnapshotNowCommand:
                    InGameNotice.Success(
                        $"Treasury snapshot gen={TreasuryDeltaWatchService.Summary.SnapshotGeneration}, actors={TreasuryDeltaWatchService.Summary.ActorsTracked}."
                    );
                    break;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    InGameNotice.Success(
                        $"Gold test PASS, +{EconomyTestScenarios.RichPlayerGoldDelta}."
                    );
                    break;
                default:
                    DebugLogger.Test($"{commandName} succeeded (file/inbox source).", showInGame: false);
                    break;
            }
        }

        private static void NotifyHotkeyResult(string commandName, string hotkeyLabel, DevCommandResult result)
        {
            switch (hotkeyLabel)
            {
                case "F9":
                case "Ctrl+Alt+D":
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success(
                            hotkeyLabel == "F9"
                                ? ModDisplay.CompactLine("F9", "DailyTick fired.")
                                : ModDisplay.CompactLine("Ctrl+Alt+D", "DailyTick fired.")
                        );
                    }
                    else
                    {
                        InGameNotice.Fail(ModDisplay.CompactLine(hotkeyLabel, $"FAILED: {GetFailReason(commandName)}"));
                    }
                    break;

                case "F10":
                case "Ctrl+Alt+F":
                    if (result == DevCommandResult.Success)
                    {
                        var onOff = TimeDevTools.IsFastForwardActive ? "ON." : "OFF.";
                        InGameNotice.Success(ModDisplay.CompactLine(hotkeyLabel, $"Fast-forward {onOff}"));
                    }
                    else
                    {
                        InGameNotice.Fail(ModDisplay.CompactLine(hotkeyLabel, $"FAILED: {GetFailReason(commandName)}"));
                    }
                    break;

                case "F11":
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success(
                            ModDisplay.CompactLine(
                                "F11",
                                $"Gold test PASS, +{EconomyTestScenarios.RichPlayerGoldDelta}.")
                        );
                    }
                    else
                    {
                        InGameNotice.Fail(ModDisplay.CompactLine("F11", $"FAILED: {GetFailReason(commandName)}"));
                    }
                    break;

                case "Ctrl+Alt+B":
                    if (result == DevCommandResult.Blocked || result == DevCommandResult.Failed)
                    {
                        InGameNotice.Fail(ModDisplay.CompactLine(hotkeyLabel, $"FAILED: {GetFailReason(commandName)}"));
                    }

                    break;

                default:
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success(ModDisplay.CompactLine(hotkeyLabel, $"{commandName} completed."));
                    }
                    else if (result == DevCommandResult.Failed)
                    {
                        InGameNotice.Fail(ModDisplay.CompactLine(hotkeyLabel, $"FAILED: {GetFailReason(commandName)}"));
                    }
                    break;
            }
        }

        private static string GetFailReason(string commandName)
        {
            if (commandName == DevCommandRegistry.AdvanceOneDayCommand ||
                commandName == DevCommandRegistry.ToggleFastForwardCommand)
            {
                return TimeDevTools.LastFailReason ?? "command failed";
            }

            if (commandName == EconomyTestScenarios.RichPlayerEconomyTestName)
            {
                return EconomyTestScenarios.LastFailReason ?? "command failed";
            }

            if (commandName != null && commandName.StartsWith(AutoTravelService.AutoTravelPrefix))
            {
                return AutoTravelService.LastFailReason ?? "auto-travel failed";
            }

            if (commandName == AutoTravelService.ShowAutoTravelChoicesCommand ||
                commandName == AutoTravelService.AutoTravelToRecommendedCommand ||
                commandName == AutoTravelService.AutoTravelChoice1Command ||
                commandName == AutoTravelService.AutoTravelChoice2Command ||
                commandName == AutoTravelService.AutoTravelChoice3Command ||
                commandName == AutoTravelService.AutoTravelChoice4Command ||
                commandName == AutoTravelService.AutoTravelChoice5Command)
            {
                return AutoTravelService.LastFailReason ?? "auto-travel failed";
            }

            if (commandName == TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand)
            {
                return TavernHeroRecruitmentService.LastFailReason
                       ?? TavernHeroRecruitmentService.LastBlockedReason
                       ?? "tavern recruitment failed";
            }

            if (commandName == TavernHeroIntelService.AnalyzeTavernHeroesCommand
                || commandName == TavernHeroIntelService.ShowTavernHeroIntelCommand
                || commandName == SettlementNavigationService.NavigateToSettlementTavernNowCommand)
            {
                return "tavern command failed";
            }

            if (commandName == CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand)
            {
                return CohesionExecutionDriver.LastFailReason ?? "cohesion move failed";
            }

            if (commandName == MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand)
            {
                return MapTradeAutonomousService.LastFailReason ?? "map trade route failed";
            }

            if (commandName == AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand)
            {
                return AutonomousGuildLoopService.LastFailReason ?? "autonomous guild loop failed";
            }

            if (commandName == AssistiveTownToTownProbeService.Command)
            {
                return AssistiveTownToTownProbeService.LastFailReason ?? "assistive town-trade probe failed";
            }

            if (commandName == AssistiveLeaveTownTravelService.Command)
            {
                return AssistiveLeaveTownTravelService.LastFailReason ?? "assistive leave-town travel failed";
            }

            return "command failed";
        }

        private static bool RequiresRiskyGate(string commandName)
        {
            return commandName == DevCommandRegistry.AdvanceOneDayCommand
                || commandName == DevCommandRegistry.ToggleFastForwardCommand
                || commandName == EconomyTestScenarios.RichPlayerEconomyTestName
                || commandName == CharacterProgressionTestScenarios.RichSmithingProgressionTestName
                || commandName == CharacterProgressionTestScenarios.AddSmithingXpCommand
                || commandName == CharacterProgressionTestScenarios.AddSmithingFocusCommand
                || commandName == CharacterProgressionTestScenarios.AddEnduranceAttributeCommand
                || commandName == AutoCharacterBuildService.ApplyAutoCharacterBuildCommand
                || commandName == AutoTravelService.AutoTravelToRecommendedCommand
                || commandName == AutoTravelService.AutoTravelChoice1Command
                || commandName == AutoTravelService.AutoTravelChoice2Command
                || commandName == AutoTravelService.AutoTravelChoice3Command
                || commandName == AutoTravelService.AutoTravelChoice4Command
                || commandName == AutoTravelService.AutoTravelChoice5Command
                || (commandName != null && commandName.StartsWith(AutoTravelService.AutoTravelPrefix))
                || commandName == TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand
                || commandName == CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand
                || commandName == MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand
                || commandName == MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand
                || commandName == SmithingSmeltService.RunWeaponSmeltNowCommand
                || commandName == AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand;
        }

        private static bool IsMutationCommand(string commandName)
        {
            return commandName == EconomyTestScenarios.RichPlayerEconomyTestName
                || commandName == CharacterProgressionTestScenarios.RichSmithingProgressionTestName
                || commandName == CharacterProgressionTestScenarios.AddSmithingXpCommand
                || commandName == CharacterProgressionTestScenarios.AddSmithingFocusCommand
                || commandName == CharacterProgressionTestScenarios.AddEnduranceAttributeCommand
                || commandName == AutoCharacterBuildService.ApplyAutoCharacterBuildCommand
                || commandName == SmithingSafeActionService.RunSmithingSafeActionNowCommand
                || commandName == AutoTravelService.AutoTravelToRecommendedCommand
                || commandName == AutoTravelService.AutoTravelChoice1Command
                || commandName == AutoTravelService.AutoTravelChoice2Command
                || commandName == AutoTravelService.AutoTravelChoice3Command
                || commandName == AutoTravelService.AutoTravelChoice4Command
                || commandName == AutoTravelService.AutoTravelChoice5Command
                || (commandName != null && commandName.StartsWith(AutoTravelService.AutoTravelPrefix))
                || commandName == TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand
                || commandName == CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand
                || commandName == MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand
                || commandName == MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand
                || commandName == SmithingSmeltService.RunWeaponSmeltNowCommand
                || commandName == AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand;
        }

        private static DevCommandResult Execute(string commandName)
        {
            switch (commandName)
            {
                case DevCommandRegistry.ListScenariosCommand:
                    ListRegisteredCommands();
                    return DevCommandResult.Success;
                case DevCommandRegistry.ShowForgeStatusCommand:
                    ForgeStatus.DisplaySummaryInGame();
                    return DevCommandResult.Success;
                case DevCommandRegistry.AdvanceOneDayCommand:
                    return TimeDevTools.AdvanceOneDay() ? DevCommandResult.Success : DevCommandResult.Failed;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    return TimeDevTools.ToggleFastForward() ? DevCommandResult.Success : DevCommandResult.Failed;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    return EconomyTestScenarios.RunRichPlayerEconomyTest();
                case CharacterProgressionTestScenarios.RichSmithingProgressionTestName:
                    return CharacterProgressionTestScenarios.RunRichSmithingProgressionTest();
                case CharacterProgressionTestScenarios.AddSmithingXpCommand:
                    return CharacterProgressionTestScenarios.RunAddSmithingXpOnly();
                case CharacterProgressionTestScenarios.AddSmithingFocusCommand:
                    return CharacterProgressionTestScenarios.RunAddSmithingFocusOnly();
                case CharacterProgressionTestScenarios.AddEnduranceAttributeCommand:
                    return CharacterProgressionTestScenarios.RunAddEnduranceAttributeOnly();
                case TreasuryDeltaWatchService.TreasurySnapshotNowCommand:
                    return TreasuryDeltaWatchService.RunSnapshotNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.RankForgeCandidatesCommand:
                    return ForgeRecommendationService.RunRankNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.SetForgeCandidateSourceStubCommand:
                    return ForgeRecommendationService.SetRequestedSourceKind(ForgeCandidateSourceKind.Stub)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.SetForgeCandidateSourceRealCommand:
                    return ForgeRecommendationService.SetRequestedSourceKind(ForgeCandidateSourceKind.Real)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.ShowForgeCandidateSourceCommand:
                    return ForgeRecommendationService.ShowCandidateSource()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.SetForgeDoctrineProfitForgeCommand:
                    return ForgeRecommendationService.SetActiveDoctrine(ForgeDoctrine.ProfitForge)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.SetForgeDoctrineRareMetalConservationCommand:
                    return ForgeRecommendationService.SetActiveDoctrine(ForgeDoctrine.RareMetalConservation)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.SetForgeDoctrineCashCrisisCommand:
                    return ForgeRecommendationService.SetActiveDoctrine(ForgeDoctrine.CashCrisis)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.ShowForgeDoctrineCommand:
                    return ForgeRecommendationService.ShowDoctrine()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ForgeRecommendationService.ProbeForgeRecipesCommand:
                    return ForgeRecipeProbeService.RunProbeNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingAuditService.ProbeSmithingAuditCommand:
                    return SmithingAuditService.RunAuditNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingAuditService.ProbeSmithingRefineApiCommand:
                    return SmithingAuditService.RunRefineApiProbeNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case AutoCharacterBuildService.ApplyAutoCharacterBuildCommand:
                    return AutoCharacterBuildService.TryApplyFromCommand();
                case AutoCharacterBuildService.ShowAutoCharacterBuildProfilesCommand:
                    return AutoCharacterBuildService.ShowProfiles();
                case AutoCharacterBuildService.ShowAutoCharacterBuildProfileCommand:
                    return AutoCharacterBuildService.ShowSelectedProfile();
                case AutoCharacterBuildService.SetAutoCharacterBuildForgeQuartermasterWarlordCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById(AutoCharacterBuildProfileRegistry.DefaultProfileId);
                case AutoCharacterBuildService.SetAutoCharacterBuildSmithEconomistCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("SmithEconomist");
                case AutoCharacterBuildService.SetAutoCharacterBuildKingdomFounderCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("KingdomFounder");
                case AutoCharacterBuildService.SetAutoCharacterBuildStewardSurgeonEngineerCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("StewardSurgeonEngineer");
                case AutoCharacterBuildService.SetAutoCharacterBuildWarCaptainCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("WarCaptain");
                case AutoCharacterBuildService.SetAutoCharacterBuildLightTouchVanillaPlusCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("LightTouchVanillaPlus");
                case AutoCharacterBuildService.SetAutoCharacterBuildShadowTraderCommand:
                    return AutoCharacterBuildService.SetSelectedProfileById("ShadowTrader");
                case MarketIntelligenceService.MarketSnapshotNowCommand:
                    return MarketIntelligenceService.RunScanNow(MarketIntelligenceService.MarketSnapshotNowCommand)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case HorseMarketRecommendationService.AnalyzeHorseMarketCommand:
                case HorseMarketRecommendationService.RankHorseMarketActionsCommand:
                    return HorseMarketRecommendationService.RunAnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case HorseMarketRecommendationService.ShowHorseMarketIntelCommand:
                    return HorseMarketRecommendationService.ShowLastIntel()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingAdvisoryService.RunSmithingAdvisoryNowCommand:
                    return SmithingAdvisoryService.RunAdvisoryNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingSafeActionService.RunSmithingSafeActionNowCommand:
                    if (SmithingSafeActionService.RunSafeActionNow(source: commandName))
                    {
                        return DevCommandResult.Success;
                    }

                    return SmithingSafeActionService.LastWasGuardrailBlock
                        ? DevCommandResult.Blocked
                        : DevCommandResult.Failed;
                case GuildLoopService.RunGuildLoopNowCommand:
                    return GuildLoopService.RunGuildLoopNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingRestPlanService.RunSmithingRestPlanNowCommand:
                    return SmithingRestPlanService.RunRestPlanNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case BlacksmithAutomationService.RunBlacksmithAutomationNowCommand:
                    if (BlacksmithAutomationService.RunAutomationNow(source: commandName))
                    {
                        return DevCommandResult.Success;
                    }

                    return BlacksmithAutomationService.LastWasGuardrailBlock
                        ? DevCommandResult.Blocked
                        : DevCommandResult.Failed;
                case CharacterDoctrineService.ShowCharacterDoctrineCommand:
                    return CharacterDoctrineService.ShowDoctrineNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CharacterBuildVariantService.BuildCharacterChoiceCatalogNowCommand:
                    return CharacterBuildVariantService.BuildCatalogNow();
                case CharacterBuildVariantService.GenerateCharacterBuildCandidatesNowCommand:
                    return CharacterBuildVariantService.GenerateCandidatesNow();
                case CharacterBuildVariantService.SelectCharacterBuildBestNowCommand:
                    return CharacterBuildVariantService.SelectBestNow();
                case CharacterBuildVariantService.RunCharacterVisibleReplayNowCommand:
                    return CharacterBuildVariantService.RunVisibleReplayNow();
                case CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand:
                    return CharacterBuildVariantService.DumpSnapshotNow();
                case AutoTravelService.ShowAutoTravelChoicesCommand:
                    return AutoTravelService.ShowChoices();
                case AutoTravelService.AutoTravelToRecommendedCommand:
                    return AutoTravelService.TravelToRecommended();
                case AutoTravelService.AutoTravelChoice1Command:
                    return AutoTravelService.TravelByChoiceNumber(1);
                case AutoTravelService.AutoTravelChoice2Command:
                    return AutoTravelService.TravelByChoiceNumber(2);
                case AutoTravelService.AutoTravelChoice3Command:
                    return AutoTravelService.TravelByChoiceNumber(3);
                case AutoTravelService.AutoTravelChoice4Command:
                    return AutoTravelService.TravelByChoiceNumber(4);
                case AutoTravelService.AutoTravelChoice5Command:
                    return AutoTravelService.TravelByChoiceNumber(5);
                case TavernHeroIntelService.AnalyzeTavernHeroesCommand:
                    return TavernHeroIntelService.RunAnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case TavernHeroIntelService.ShowTavernHeroIntelCommand:
                    return TavernHeroIntelService.ShowLastIntel()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case TavernHeroRecruitmentProbeService.ProbeTavernRecruitmentApiCommand:
                    return TavernHeroRecruitmentProbeService.RunProbeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SettlementNavigationService.NavigateToSettlementTavernNowCommand:
                {
                    var navActions = new System.Collections.Generic.List<TavernHeroRecruitmentActionStep>();
                    return SettlementNavigationService.TryNavigateToTavernNow(out _, navActions)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                }
                case TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand:
                    if (TavernHeroRecruitmentService.RunRecruitVisibleNow(source: commandName))
                    {
                        return DevCommandResult.Success;
                    }

                    return TavernHeroRecruitmentService.LastWasGuardrailBlock
                        ? DevCommandResult.Blocked
                        : DevCommandResult.Failed;
                case TavernHeroDoctrine.SetSmithingCrewCommand:
                    return TavernHeroDoctrine.SetDoctrine(TavernHeroDoctrineKind.SmithingCrew)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case TavernHeroDoctrine.SetScoutQuartermasterCommand:
                    return TavernHeroDoctrine.SetDoctrine(TavernHeroDoctrineKind.ScoutQuartermaster)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case TavernHeroDoctrine.SetCombatEscortCommand:
                    return TavernHeroDoctrine.SetDoctrine(TavernHeroDoctrineKind.CombatEscort)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionEngine.AnalyzeCohesionOpportunitiesCommand:
                    return CohesionEngine.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionEngine.ShowCohesionPlanCommand:
                    return CohesionStatusReport.ShowStatusNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand:
                    return CohesionExecutionDriver.StartMoveNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionExecutionDriver.AbortCohesionMoveNowCommand:
                    return CohesionExecutionDriver.AbortNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionDoctrine.SetCohesionDoctrineTradeForgeCommand:
                    return CohesionDoctrine.SetDoctrine(CohesionDoctrineKind.TradeForge)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionDoctrine.SetCohesionDoctrineReliefCommand:
                    return CohesionDoctrine.SetDoctrine(CohesionDoctrineKind.Relief)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionDoctrine.SetCohesionDoctrineEscortCommand:
                    return CohesionDoctrine.SetDoctrine(CohesionDoctrineKind.Escort)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CohesionDoctrine.SetCohesionDoctrineBanditSuppressionCommand:
                    return CohesionDoctrine.SetDoctrine(CohesionDoctrineKind.BanditSuppression)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeRouteSafetyAnalyzer.AnalyzeMapTradeRouteSafetyCommand:
                    return MapTradeRouteSafetyAnalyzer.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand:
                    return MapTradeAutonomousService.StartRouteNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeAutonomousService.AbortMapTradeRouteNowCommand:
                    return MapTradeAutonomousService.AbortNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeAutonomousService.ShowMapTradeRouteStatusCommand:
                    return MapTradeAutonomousService.ShowStatusNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeAutonomousService.AnalyzeTacticalConvergenceCommand:
                    CohesionDoctrine.SetDoctrine(CohesionDoctrineKind.TradeForge);
                    return CohesionEngine.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeAutonomousService.ShowTacticalConvergenceCommand:
                    return CohesionStatusReport.ShowStatusNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeForgeHandoffService.RunForgeHandoffAfterTradeNowCommand:
                    return MapTradeForgeHandoffService.RunHandoffNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand:
                    return AutonomousGuildLoopService.StartNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case AutonomousGuildLoopService.AbortAutonomousGuildLoopNowCommand:
                    return AutomationAbortService.AbortAllMovementAutomationNow()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeVanillaTradeDriver.ProbeVanillaTradeExecutionNowCommand:
                    return MapTradeVanillaTradeDriver.RunProbeExecutionNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MapTradeVanillaTradeDriver.ProbePackAnimalBuyNowCommand:
                    return MapTradeVanillaTradeDriver.RunProbePackAnimalBuyNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingSmeltService.ProbeWeaponSmeltNowCommand:
                    return SmithingSmeltService.RunSmeltApiProbeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case SmithingSmeltService.RunWeaponSmeltNowCommand:
                    return SmithingSmeltService.TrySmeltOneLootWeaponNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ClanContextService.AnalyzeClanContextCommand:
                    return ClanContextService.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ClanContextService.ShowClanContextCommand:
                    return ClanContextService.ShowLast()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case NobleNetworkService.AnalyzeNobleNetworkCommand:
                    return NobleNetworkService.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case NobleNetworkService.ShowNobleNetworkCommand:
                    return NobleNetworkService.ShowLast()
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case MarriageCandidateService.AnalyzeMarriageCandidatesCommand:
                    return MarriageCandidateService.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CourtshipPlanService.ShowCourtshipPlanCommand:
                    return CourtshipPlanService.ShowPlanNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case ClanRoleBoardService.AnalyzeClanRolesCommand:
                    return ClanRoleBoardService.AnalyzeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case CourtshipProbeService.ProbeCourtshipApiCommand:
                    return CourtshipProbeService.RunProbeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case AssistiveTownToTownProbeService.Command:
                    return AssistiveTownToTownProbeService.RunProbeNow(source: commandName)
                        ? DevCommandResult.Success
                        : DevCommandResult.Failed;
                case AssistiveLeaveTownTravelService.Command:
                    return AssistiveLeaveTownTravelService.RunNow(executeTravel: false, source: commandName);
                default:
                    if (commandName != null && commandName.StartsWith(AutoTravelService.AutoTravelPrefix))
                    {
                        return AutoTravelService.TravelByName(commandName.Substring(AutoTravelService.AutoTravelPrefix.Length));
                    }

                    return DevCommandResult.Unknown;
            }
        }

        private static string ExtractAutoTravelName(string commandName)
        {
            if (string.IsNullOrWhiteSpace(commandName) || !commandName.StartsWith(AutoTravelService.AutoTravelPrefix))
            {
                return null;
            }

            return commandName.Substring(AutoTravelService.AutoTravelPrefix.Length).Trim();
        }

        private static void ListRegisteredCommands()
        {
            DebugLogger.Test("Registered dev commands:");
            foreach (var name in DevCommandRegistry.RegisteredCommandNames)
            {
                DebugLogger.Test($"  - {name}", showInGame: false);
            }

            DebugLogger.Test("Press F7 for status summary (read-only).", showInGame: false);

            InGameNotice.Info($"{ModDisplay.Name} — Commands");
            InGameNotice.Info("F7 Status | F8 Commands");
            InGameNotice.Info("F9 Daily tick | F10 Fast-forward | F11 Gold test");
            InGameNotice.Info("Ctrl+Alt+M Market intel | Ctrl+Alt+R Rank forge | Ctrl+Alt+G Guild loop");
            InGameNotice.Info("Inbox: RunSmithingRestPlanNow | RunBlacksmithAutomationNow | ShowCharacterDoctrine");
            InGameNotice.Info("Travel: ShowAutoTravelChoices, AutoTravelChoice1-5, AutoTravel:<town>");
            InGameNotice.Info("Tavern: AnalyzeTavernHeroes, NavigateToSettlementTavernNow, RecruitTavernHeroVisibleNow");
            InGameNotice.Info("Messages appear in lower-left feed. Logs contain full detail.");

            CommandSurfaceService.WriteCommandSurface(DevCommandRegistry.ListScenariosCommand);
        }

        private static bool IsAutoCharacterBuildNonMutationCommand(string commandName)
        {
            return commandName == CharacterDoctrineService.ShowCharacterDoctrineCommand
                || commandName == AutoCharacterBuildService.ShowAutoCharacterBuildProfilesCommand
                || commandName == AutoCharacterBuildService.ShowAutoCharacterBuildProfileCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildForgeQuartermasterWarlordCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildSmithEconomistCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildKingdomFounderCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildStewardSurgeonEngineerCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildWarCaptainCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildLightTouchVanillaPlusCommand
                || commandName == AutoCharacterBuildService.SetAutoCharacterBuildShadowTraderCommand
                || commandName == CharacterBuildVariantService.BuildCharacterChoiceCatalogNowCommand
                || commandName == CharacterBuildVariantService.GenerateCharacterBuildCandidatesNowCommand
                || commandName == CharacterBuildVariantService.SelectCharacterBuildBestNowCommand
                || commandName == CharacterBuildVariantService.RunCharacterVisibleReplayNowCommand
                || commandName == CharacterBuildVariantService.DumpCharacterBuildSnapshotNowCommand;
        }

        private static bool IsTavernDoctrineCommand(string commandName)
        {
            return commandName == TavernHeroDoctrine.SetSmithingCrewCommand
                || commandName == TavernHeroDoctrine.SetScoutQuartermasterCommand
                || commandName == TavernHeroDoctrine.SetCombatEscortCommand;
        }
    }
}
