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
                    TimeDevTools.AdvanceOneDay();
                    break;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    TimeDevTools.ToggleFastForward();
                    break;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    EconomyTestScenarios.RunRichPlayerEconomyTest();
                    break;
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
