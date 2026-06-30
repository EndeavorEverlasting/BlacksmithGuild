using BlacksmithGuild.Forge;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.Market;
using BlacksmithGuild.DevTools.Reporting;
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
        private static bool _f12WasDown;
        private static bool _fallback7WasDown;
        private static bool _fallback8WasDown;
        private static bool _fallback9WasDown;
        private static bool _fallback0WasDown;
        private static bool _fallback1WasDown;
        private static bool _legacyDWasDown;
        private static bool _legacyFWasDown;
        private static bool _legacyLWasDown;
        private static bool _legacySWasDown;
        private static bool _legacyXWasDown;
        private static bool _legacyCWasDown;
        private static bool _legacyMWasDown;
        private static bool _legacyRWasDown;
        private static bool _legacyGWasDown;
        private static bool _legacyBWasDown;
        private static bool _legacyTWasDown;

        public static void Poll()
        {
            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch())
            {
                RuntimeTrace.LogDeferOnce(
                    "hotkey_poll",
                    "DevHotkeyHandler",
                    "Poll",
                    MapTransitionGuard.GetDeferReason());
                return;
            }

            RuntimeTrace.Run("DevHotkeyHandler", "NextOperation", () =>
            {
                GameSessionState.Refresh();

                if (GameSessionState.CanPollHelpHotkeys)
                {
                    HotkeyTraceService.OnPollingActive();
                }
                else
                {
                    HotkeyTraceService.OnPollBlocked(GameSessionState.GetCampaignMapBlockDetail());
                }

                PollHotkeys();
            });
        }

        private static void PollHotkeys()
        {
            if (TryHelpHotkey(InputKey.F7, "F7", DevCommandRegistry.ShowForgeStatusCommand, ref _f7WasDown))
            {
                return;
            }

            if (TryHelpHotkey(InputKey.F8, "F8", DevCommandRegistry.ListScenariosCommand, ref _f8WasDown))
            {
                return;
            }

            if (TryRiskyHotkey(InputKey.F9, "F9", DevCommandRegistry.AdvanceOneDayCommand, ref _f9WasDown))
            {
                return;
            }

            if (TryRiskyHotkey(InputKey.F10, "F10", DevCommandRegistry.ToggleFastForwardCommand, ref _f10WasDown))
            {
                return;
            }

            if (TryRiskyHotkey(
                    InputKey.F11,
                    "F11",
                    EconomyTestScenarios.RichPlayerEconomyTestName,
                    ref _f11WasDown))
            {
                return;
            }

            if (DevToolsConfig.LegacyF12MarketHotkey &&
                TryHelpHotkey(
                    InputKey.F12,
                    "F12",
                    MarketIntelligenceService.MarketSnapshotNowCommand,
                    ref _f12WasDown))
            {
                return;
            }

            if (IsCtrlAltDown())
            {
                if (TryHelpHotkey(
                        InputKey.M,
                        "Ctrl+Alt+M",
                        MarketIntelligenceService.MarketSnapshotNowCommand,
                        ref _legacyMWasDown))
                {
                    return;
                }

                if (TryHelpHotkey(
                        InputKey.G,
                        "Ctrl+Alt+G",
                        GuildLoopService.RunGuildLoopNowCommand,
                        ref _legacyGWasDown))
                {
                    return;
                }

                if (TryEngineToggleHotkey(InputKey.T, "Ctrl+Alt+T", ref _legacyTWasDown))
                {
                    return;
                }

                if (TryHelpHotkey(InputKey.D7, "Ctrl+Alt+7", DevCommandRegistry.ShowForgeStatusCommand, ref _fallback7WasDown))
                {
                    return;
                }

                if (TryHelpHotkey(InputKey.D8, "Ctrl+Alt+8", DevCommandRegistry.ListScenariosCommand, ref _fallback8WasDown))
                {
                    return;
                }

                if (TryRiskyHotkey(InputKey.D9, "Ctrl+Alt+9", DevCommandRegistry.AdvanceOneDayCommand, ref _fallback9WasDown))
                {
                    return;
                }

                if (TryRiskyHotkey(InputKey.D0, "Ctrl+Alt+0", DevCommandRegistry.ToggleFastForwardCommand, ref _fallback0WasDown))
                {
                    return;
                }

                if (TryRiskyHotkey(
                        InputKey.D1,
                        "Ctrl+Alt+1",
                        EconomyTestScenarios.RichPlayerEconomyTestName,
                        ref _fallback1WasDown))
                {
                    return;
                }

                if (TryMovementAbortHotkey(InputKey.B, "Ctrl+Alt+B", ref _legacyBWasDown))
                {
                    return;
                }

                if (TryFireEdge(InputKey.D, ref _legacyDWasDown))
                {
                    RunCommand("Ctrl+Alt+D", DevCommandRegistry.AdvanceOneDayCommand, "Ctrl+Alt+D");
                }
                else if (TryFireEdge(InputKey.F, ref _legacyFWasDown))
                {
                    RunCommand("Ctrl+Alt+F", DevCommandRegistry.ToggleFastForwardCommand, "Ctrl+Alt+F");
                }
                else if (TryFireEdge(InputKey.L, ref _legacyLWasDown))
                {
                    RunCommand("Ctrl+Alt+L", DevCommandRegistry.ListScenariosCommand, "Ctrl+Alt+L");
                }
                else if (TryFireEdge(InputKey.S, ref _legacySWasDown))
                {
                    RunCommand(
                        "Ctrl+Alt+S",
                        CharacterProgressionTestScenarios.RichSmithingProgressionTestName,
                        "Ctrl+Alt+S"
                    );
                }
                else if (TryFireEdge(InputKey.X, ref _legacyXWasDown))
                {
                    RunCommand(
                        "Ctrl+Alt+X",
                        CharacterProgressionTestScenarios.AddSmithingXpCommand,
                        "Ctrl+Alt+X"
                    );
                }
                else if (TryFireEdge(InputKey.C, ref _legacyCWasDown))
                {
                    RunCommand(
                        "Ctrl+Alt+C",
                        CharacterProgressionTestScenarios.AddSmithingFocusCommand,
                        "Ctrl+Alt+C"
                    );
                }
                else if (TryFireEdge(InputKey.R, ref _legacyRWasDown))
                {
                    RunCommand(
                        "Ctrl+Alt+R",
                        ForgeRecommendationService.RankForgeCandidatesCommand,
                        "Ctrl+Alt+R"
                    );
                }

                return;
            }

            _legacyDWasDown = Input.IsKeyDown(InputKey.D);
            _legacyFWasDown = Input.IsKeyDown(InputKey.F);
            _legacyLWasDown = Input.IsKeyDown(InputKey.L);
            _legacySWasDown = Input.IsKeyDown(InputKey.S);
            _legacyXWasDown = Input.IsKeyDown(InputKey.X);
            _legacyCWasDown = Input.IsKeyDown(InputKey.C);
            _legacyMWasDown = Input.IsKeyDown(InputKey.M);
            _legacyRWasDown = Input.IsKeyDown(InputKey.R);
            _legacyGWasDown = Input.IsKeyDown(InputKey.G);
            _legacyBWasDown = Input.IsKeyDown(InputKey.B);
            _legacyTWasDown = Input.IsKeyDown(InputKey.T);
        }

        private static bool TryHelpHotkey(InputKey key, string label, string commandName, ref bool wasDown)
        {
            if (!GameSessionState.CanPollHelpHotkeys)
            {
                return false;
            }

            if (!TryFireEdge(key, ref wasDown))
            {
                return false;
            }

            RunCommand(label, commandName, label);
            return true;
        }

        private static bool TryMovementAbortHotkey(InputKey key, string label, ref bool wasDown)
        {
            if (!GameSessionState.CanPollRiskyHotkeys)
            {
                return false;
            }

            if (!TryFireEdge(key, ref wasDown))
            {
                return false;
            }

            RunCommand(label, AutonomousGuildLoopService.AbortAutonomousGuildLoopNowCommand, label);
            return true;
        }

        private static bool TryEngineToggleHotkey(InputKey key, string label, ref bool wasDown)
        {
            if (!GameSessionState.CanPollHelpHotkeys)
            {
                return false;
            }

            if (!TryFireEdge(key, ref wasDown))
            {
                return false;
            }

            HotkeyTraceService.OnKeyDetected(label);
            var ok = EngineToggleAuthority.RunCommand(EngineToggleAuthority.CycleEngineToggleModeCommand, label);
            HotkeyTraceService.OnCommandResult(
                label,
                EngineToggleAuthority.CycleEngineToggleModeCommand,
                ok ? DevCommandResult.Success : DevCommandResult.Failed);
            return true;
        }

        private static bool TryRiskyHotkey(InputKey key, string label, string commandName, ref bool wasDown)
        {
            if (!GameSessionState.CanPollHelpHotkeys)
            {
                return false;
            }

            if (!TryFireEdge(key, ref wasDown))
            {
                return false;
            }

            RunCommand(label, commandName, label);
            return true;
        }

        private static void RunCommand(string source, string commandName, string hotkeyLabel)
        {
            HotkeyTraceService.OnKeyDetected(hotkeyLabel);
            DevCommandBus.TryRun(commandName, source, hotkeyLabel: hotkeyLabel);
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
