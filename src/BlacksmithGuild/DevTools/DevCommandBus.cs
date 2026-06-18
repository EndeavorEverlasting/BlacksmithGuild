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
            bool showHotkeyAck = false,
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
                return DevCommandResult.Unknown;
            }

            if (showHotkeyAck)
            {
                GuildLog.Display($"TBG HOTKEY: {commandName} fired");
            }

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
            return result;
        }

        private static bool RequiresRiskyGate(string commandName)
        {
            return commandName == DevCommandRegistry.AdvanceOneDayCommand
                || commandName == DevCommandRegistry.ToggleFastForwardCommand
                || commandName == EconomyTestScenarios.RichPlayerEconomyTestName;
        }

        private static bool IsMutationCommand(string commandName)
        {
            return commandName == EconomyTestScenarios.RichPlayerEconomyTestName;
        }

        private static DevCommandResult Execute(string commandName)
        {
            switch (commandName)
            {
                case DevCommandRegistry.ListScenariosCommand:
                    ListRegisteredCommands();
                    return DevCommandResult.Success;
                case DevCommandRegistry.AdvanceOneDayCommand:
                    return TimeDevTools.AdvanceOneDay() ? DevCommandResult.Success : DevCommandResult.Failed;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    return TimeDevTools.ToggleFastForward() ? DevCommandResult.Success : DevCommandResult.Failed;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    return EconomyTestScenarios.RunRichPlayerEconomyTest();
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
        }
    }
}
