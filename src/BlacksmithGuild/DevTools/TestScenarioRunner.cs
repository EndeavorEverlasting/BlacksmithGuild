namespace BlacksmithGuild.DevTools
{
    public static class TestScenarioRunner
    {
        public static void Run(string scenarioName)
        {
            if (!DevCommandRegistry.IsRegistered(scenarioName))
            {
                DebugLogger.Test($"Unknown scenario: {scenarioName}");
                return;
            }

            switch (scenarioName)
            {
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    EconomyTestScenarios.RunRichPlayerEconomyTest();
                    break;
            }
        }
    }
}
