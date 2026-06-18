namespace BlacksmithGuild.DevTools
{
    public static class HotkeyTraceService
    {
        private static bool _loggedPollingActive;
        private static bool _loggedMapReady;
        private static string _lastPollBlockReason;
        private static bool _warnedMenuKeys;

        public static void OnPollingActive()
        {
            if (!DevToolsConfig.HotkeyTraceEnabled || _loggedPollingActive)
            {
                return;
            }

            _loggedPollingActive = true;
            Log("[TBG HOTKEY TRACE] Campaign tick polling active.");
        }

        public static void OnMapReady()
        {
            if (!DevToolsConfig.HotkeyTraceEnabled || _loggedMapReady)
            {
                return;
            }

            _loggedMapReady = true;
            GameSessionState.Refresh();
            var activeState = GameSessionState.GetActiveStateName();
            var atMenu = GameSessionState.IsMapMenuOpen;
            var missionActive = GameSessionState.IsMissionActiveForTrace();
            Log(
                $"[TBG HOTKEY TRACE] CanPollHotkeys=true; activeState={activeState}; atMenu={atMenu.ToString().ToLowerInvariant()}; missionActive={missionActive.ToString().ToLowerInvariant()}"
            );

            if (atMenu && !_warnedMenuKeys)
            {
                _warnedMenuKeys = true;
                var menuId = GameSessionState.MapMenuId ?? "unknown";
                Log(
                    $"[TBG HOTKEY TRACE] READY at menu={menuId}; F-keys may be swallowed — use Ctrl+Alt+7-1 or close panel"
                );
                InGameNotice.Warn(
                    "TBG WARN: Map menu open — close panel for F-keys, or use Ctrl+Alt+7-1."
                );
            }
        }

        public static void OnPollBlocked(string reason)
        {
            if (!DevToolsConfig.HotkeyTraceEnabled)
            {
                return;
            }

            if (string.Equals(_lastPollBlockReason, reason, System.StringComparison.Ordinal))
            {
                return;
            }

            _lastPollBlockReason = reason;
            Log($"[TBG HOTKEY TRACE] CanPollHotkeys=false; reason={reason}");
        }

        public static void OnKeyDetected(string hotkeyLabel)
        {
            if (!DevToolsConfig.HotkeyTraceEnabled)
            {
                return;
            }

            Log($"[TBG HOTKEY TRACE] key={hotkeyLabel} detected");

            if (DevToolsConfig.HotkeyTraceVisibleKeys)
            {
                InGameNotice.Info($"TBG KEY: {hotkeyLabel} detected.");
            }
        }

        public static void OnCommandReceived(string hotkeyLabel, string commandName)
        {
            if (!DevToolsConfig.HotkeyTraceEnabled)
            {
                return;
            }

            Log($"[TBG COMMAND TRACE] hotkey={hotkeyLabel} command={commandName} received");
        }

        public static void OnCommandResult(string hotkeyLabel, string commandName, DevCommandResult result, string reason = null)
        {
            if (!DevToolsConfig.HotkeyTraceEnabled)
            {
                return;
            }

            if (string.IsNullOrEmpty(reason))
            {
                Log($"[TBG COMMAND TRACE] hotkey={hotkeyLabel} command={commandName} result={result}");
                return;
            }

            Log(
                $"[TBG COMMAND TRACE] hotkey={hotkeyLabel} command={commandName} result={result} reason={reason}"
            );
        }

        public static void LogVersionAtStartup()
        {
            if (!DevToolsConfig.HotkeyTraceEnabled)
            {
                return;
            }

            var reload = PendingReloadWatcher.IsReloadBlocked
                ? "blocked"
                : PendingReloadWatcher.IsReloadPending
                    ? "pending"
                    : "clear";

            Log(
                $"[TBG VERSION] Loaded assembly: version={PendingReloadWatcher.LoadedModuleVersion} dllUtc={PendingReloadWatcher.LoadedDllWriteUtcIso}"
            );
            Log($"[TBG VERSION] Pending reload state: {reload}");
        }

        private static void Log(string message)
        {
            GuildLog.Info(message, showInGame: false);
        }
    }
}
