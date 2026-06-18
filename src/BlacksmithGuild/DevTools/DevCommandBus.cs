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
            GameSessionState.Refresh();
            ForgeStatus.UpdateSession(GameSessionState.Phase, GameSessionState.IsTimePaused);
            ForgeStatus.UpdateReadiness(
                GameSessionState.IsCampaignLoaded,
                GameSessionState.IsMainHeroReady
            );

            DebugLogger.Test(
                $"Command received: {commandName} (source: {source})",
                showInGame: false
            );

            if (!DevCommandRegistry.IsRegistered(commandName))
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
                if (!GameReadinessService.CanRunRiskyCommands(out var blockReason))
                {
                    DebugLogger.Test($"{commandName} blocked: {blockReason}");
                    ForgeStatus.RecordCommand(commandName, source, "BLOCKED", blockReason, sequence);
                    ForgeStatus.SetTest(commandName, "BLOCKED", blockReason);
                    CertificationTracker.OnCommandResult(commandName, DevCommandResult.Blocked, blockReason);
                    Sprint002CertificationTracker.OnCommandResult(commandName, DevCommandResult.Blocked, blockReason);
                    NotifyBlocked(commandName, hotkeyLabel, blockReason);
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
            return result;
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
                    InGameNotice.Info("TBG F9: Daily tick test requested.");
                    break;
                case "F11":
                    InGameNotice.Info("TBG F11: Gold test requested.");
                    break;
            }
        }

        private static void NotifyBlocked(string commandName, string hotkeyLabel, string blockReason)
        {
            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                InGameNotice.Blocked($"TBG {hotkeyLabel} BLOCKED: {blockReason}");
                return;
            }

            InGameNotice.Blocked($"TBG BLOCKED: {commandName} blocked because {blockReason}");
        }

        private static void NotifyUnknown(string commandName, string hotkeyLabel)
        {
            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                InGameNotice.Fail($"TBG {hotkeyLabel} FAILED: unknown command {commandName}");
            }
        }

        private static void NotifyResult(string commandName, string hotkeyLabel, DevCommandResult result)
        {
            if (result == DevCommandResult.Blocked || result == DevCommandResult.Unknown)
            {
                return;
            }

            if (commandName == DevCommandRegistry.ShowForgeStatusCommand ||
                commandName == DevCommandRegistry.ListScenariosCommand)
            {
                return;
            }

            if (!string.IsNullOrEmpty(hotkeyLabel))
            {
                NotifyHotkeyResult(commandName, hotkeyLabel, result);
                return;
            }

            if (result == DevCommandResult.Success)
            {
                InGameNotice.Success($"TBG: {commandName} Success");
            }
            else if (result == DevCommandResult.Failed)
            {
                InGameNotice.Fail($"TBG FAILED: {commandName} — {GetFailReason(commandName)}");
            }
        }

        private static void NotifyHotkeyResult(string commandName, string hotkeyLabel, DevCommandResult result)
        {
            switch (hotkeyLabel)
            {
                case "F9":
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success("TBG F9: DailyTick fired.");
                    }
                    else
                    {
                        InGameNotice.Fail($"TBG F9 FAILED: {GetFailReason(commandName)}");
                    }
                    break;

                case "F10":
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success(
                            TimeDevTools.IsFastForwardActive
                                ? "TBG F10: Fast-forward ON."
                                : "TBG F10: Fast-forward OFF."
                        );
                    }
                    else
                    {
                        InGameNotice.Fail($"TBG F10 FAILED: {GetFailReason(commandName)}");
                    }
                    break;

                case "F11":
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success(
                            $"TBG F11: Gold test PASS, +{EconomyTestScenarios.RichPlayerGoldDelta}."
                        );
                    }
                    else
                    {
                        InGameNotice.Fail($"TBG F11 FAILED: {GetFailReason(commandName)}");
                    }
                    break;

                default:
                    if (result == DevCommandResult.Success)
                    {
                        InGameNotice.Success($"TBG {hotkeyLabel}: {commandName} Success");
                    }
                    else if (result == DevCommandResult.Failed)
                    {
                        InGameNotice.Fail($"TBG {hotkeyLabel} FAILED: {GetFailReason(commandName)}");
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
                || commandName == CharacterProgressionTestScenarios.AddEnduranceAttributeCommand;
        }

        private static bool IsMutationCommand(string commandName)
        {
            return commandName == EconomyTestScenarios.RichPlayerEconomyTestName
                || commandName == CharacterProgressionTestScenarios.RichSmithingProgressionTestName
                || commandName == CharacterProgressionTestScenarios.AddSmithingXpCommand
                || commandName == CharacterProgressionTestScenarios.AddSmithingFocusCommand
                || commandName == CharacterProgressionTestScenarios.AddEnduranceAttributeCommand;
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
                default:
                    return DevCommandResult.Unknown;
            }
        }

        private static void ListRegisteredCommands()
        {
            DebugLogger.Test("Registered dev commands:");
            foreach (var name in DevCommandRegistry.RegisteredCommandNames)
            {
                DebugLogger.Test($"  - {name}", showInGame: false);
            }

            DebugLogger.Test("Press F7 for status summary (read-only).", showInGame: false);

            InGameNotice.Info("TBG COMMANDS");
            InGameNotice.Info("F7 Status | F8 Commands | F9 Daily tick test");
            InGameNotice.Info("F10 Fast-forward ON/OFF | F11 Gold test");
            InGameNotice.Info("Ctrl+Alt+D/F/L/S/X/C legacy commands");
        }
    }
}
