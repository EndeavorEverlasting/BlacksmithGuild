namespace BlacksmithGuild.DevTools
{
    public static class DevCommandRunner
    {
        public static void Run(string commandName)
        {
            if (!DevCommandRegistry.IsRegistered(commandName))
            {
                DebugLogger.Test($"Unknown command: {commandName}");
                return;
            }

            switch (commandName)
            {
                case DevCommandRegistry.ListScenariosCommand:
                    ListRegisteredCommands();
                    break;
                case DevCommandRegistry.AdvanceOneDayCommand:
                    if (!TryRunRiskyCommand("AdvanceOneDay"))
                    {
                        return;
                    }

                    TimeDevTools.AdvanceOneDay();
                    break;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    if (!TryRunRiskyCommand("ToggleFastForward"))
                    {
                        return;
                    }

                    TimeDevTools.ToggleFastForward();
                    break;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    EconomyTestScenarios.RunRichPlayerEconomyTest();
                    break;
            }
        }

        private static bool TryRunRiskyCommand(string commandName)
        {
            GameDataPreflight.RunOnce();

            if (GameDataPreflight.BlocksRiskyDevTools)
            {
                DebugLogger.Test(
                    $"{commandName} blocked because preflight failed: {GameDataPreflight.BlockReason}"
                );
                return false;
            }

            if (GameDataPreflight.Verdict == PreflightVerdict.Unknown ||
                GameDataPreflight.Verdict == PreflightVerdict.Warn)
            {
                DebugLogger.Test(
                    $"Warning: preflight was {GameDataPreflight.Verdict}; proceeding with {commandName}.",
                    showInGame: false
                );
            }

            return true;
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
