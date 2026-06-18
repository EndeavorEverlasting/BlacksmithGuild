using System.Collections.Generic;

namespace BlacksmithGuild.DevTools
{
    public static class DevCommandRegistry
    {
        private static readonly HashSet<string> RegisteredScenarios =
            new HashSet<string> { EconomyTestScenarios.RichPlayerEconomyTestName };

        public static bool IsRegistered(string scenarioName)
        {
            return RegisteredScenarios.Contains(scenarioName);
        }

        public static IReadOnlyCollection<string> RegisteredScenarioNames =>
            RegisteredScenarios;
    }
}
