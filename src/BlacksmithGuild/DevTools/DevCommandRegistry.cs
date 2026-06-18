using System.Collections.Generic;

namespace BlacksmithGuild.DevTools
{
    public static class DevCommandRegistry
    {
        public const string ListScenariosCommand = "ListScenarios";
        public const string AdvanceOneDayCommand = "AdvanceOneDay";
        public const string ToggleFastForwardCommand = "ToggleFastForward";
        public const string AddSmithingXpCommand = "AddSmithingXp";
        public const string AddSmithingFocusCommand = "AddSmithingFocus";
        public const string AddEnduranceAttributeCommand = "AddEnduranceAttribute";

        private static readonly HashSet<string> RegisteredCommands =
            new HashSet<string>
            {
                EconomyTestScenarios.RichPlayerEconomyTestName,
                CharacterProgressionTestScenarios.RichSmithingProgressionTestName,
                ListScenariosCommand,
                AdvanceOneDayCommand,
                ToggleFastForwardCommand,
                AddSmithingXpCommand,
                AddSmithingFocusCommand,
                AddEnduranceAttributeCommand
            };

        public static bool IsRegistered(string commandName)
        {
            return RegisteredCommands.Contains(commandName);
        }

        public static IReadOnlyCollection<string> RegisteredCommandNames => RegisteredCommands;
    }
}
