using TaleWorlds.InputSystem;

namespace BlacksmithGuild.DevTools
{
    public static class DevHotkeyHandler
    {
        private static bool _f7WasDown;
        private static bool _f8WasDown;
        private static bool _f9WasDown;
        private static bool _f10WasDown;
        private static bool _f11WasDown;
        private static bool _legacyDWasDown;
        private static bool _legacyFWasDown;
        private static bool _legacyLWasDown;
        private static bool _legacySWasDown;
        private static bool _legacyXWasDown;
        private static bool _legacyCWasDown;

        public static void Poll()
        {
            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            if (TryFireEdge(InputKey.F7, ref _f7WasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.ShowForgeStatusCommand, "F7", hotkeyLabel: "F7");
                return;
            }

            if (TryFireEdge(InputKey.F8, ref _f8WasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.ListScenariosCommand, "F8", hotkeyLabel: "F8");
                return;
            }

            if (TryFireEdge(InputKey.F9, ref _f9WasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.AdvanceOneDayCommand, "F9", hotkeyLabel: "F9");
                return;
            }

            if (TryFireEdge(InputKey.F10, ref _f10WasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.ToggleFastForwardCommand, "F10", hotkeyLabel: "F10");
                return;
            }

            if (TryFireEdge(InputKey.F11, ref _f11WasDown))
            {
                DevCommandBus.TryRun(
                    EconomyTestScenarios.RichPlayerEconomyTestName,
                    "F11",
                    hotkeyLabel: "F11"
                );
                return;
            }

            if (!IsCtrlAltDown())
            {
                _legacyDWasDown = Input.IsKeyDown(InputKey.D);
                _legacyFWasDown = Input.IsKeyDown(InputKey.F);
                _legacyLWasDown = Input.IsKeyDown(InputKey.L);
                _legacySWasDown = Input.IsKeyDown(InputKey.S);
                _legacyXWasDown = Input.IsKeyDown(InputKey.X);
                _legacyCWasDown = Input.IsKeyDown(InputKey.C);
                return;
            }

            if (TryFireEdge(InputKey.D, ref _legacyDWasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.AdvanceOneDayCommand, "Ctrl+Alt+D", hotkeyLabel: "Ctrl+Alt+D");
            }
            else if (TryFireEdge(InputKey.F, ref _legacyFWasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.ToggleFastForwardCommand, "Ctrl+Alt+F", hotkeyLabel: "Ctrl+Alt+F");
            }
            else if (TryFireEdge(InputKey.L, ref _legacyLWasDown))
            {
                DevCommandBus.TryRun(DevCommandRegistry.ListScenariosCommand, "Ctrl+Alt+L", hotkeyLabel: "Ctrl+Alt+L");
            }
            else if (TryFireEdge(InputKey.S, ref _legacySWasDown))
            {
                DevCommandBus.TryRun(
                    CharacterProgressionTestScenarios.RichSmithingProgressionTestName,
                    "Ctrl+Alt+S",
                    hotkeyLabel: "Ctrl+Alt+S"
                );
            }
            else if (TryFireEdge(InputKey.X, ref _legacyXWasDown))
            {
                DevCommandBus.TryRun(
                    CharacterProgressionTestScenarios.AddSmithingXpCommand,
                    "Ctrl+Alt+X",
                    hotkeyLabel: "Ctrl+Alt+X"
                );
            }
            else if (TryFireEdge(InputKey.C, ref _legacyCWasDown))
            {
                DevCommandBus.TryRun(
                    CharacterProgressionTestScenarios.AddSmithingFocusCommand,
                    "Ctrl+Alt+C",
                    hotkeyLabel: "Ctrl+Alt+C"
                );
            }
        }

        private static bool TryFireEdge(InputKey key, ref bool wasDown)
        {
            bool isDown = Input.IsKeyDown(key);
            bool fired = isDown && !wasDown;
            wasDown = isDown;
            return fired;
        }

        private static bool IsCtrlAltDown()
        {
            bool ctrl =
                Input.IsKeyDown(InputKey.LeftControl) || Input.IsKeyDown(InputKey.RightControl);
            bool alt = Input.IsKeyDown(InputKey.LeftAlt) || Input.IsKeyDown(InputKey.RightAlt);
            return ctrl && alt;
        }
    }
}
