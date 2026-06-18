using System.Collections.Generic;

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
                CharacterProgressionTestScenarios.AddEnduranceAttributeCommand
            };

        public static bool IsRegistered(string commandName)
        {
            return RegisteredCommands.Contains(commandName);
        }

        public static IReadOnlyCollection<string> RegisteredCommandNames => RegisteredCommands;
    }
}
