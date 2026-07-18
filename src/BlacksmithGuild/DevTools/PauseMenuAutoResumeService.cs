using System;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Auto-dismisses the pause (escape) menu and resumes the campaign clock.
    /// Enables multitasking: user can alt-tab away and the game keeps running.
    /// Hooks into the campaign tick to detect and dismiss the menu automatically.
    /// </summary>
    public static class PauseMenuAutoResumeService
    {
        private static float _accumulator;
        private const float PollIntervalSec = 1.5f;
        private static bool _lastDismissResult;
        private static DateTime _lastDismissUtc = DateTime.MinValue;
        private static int _dismissCount;
        private static int _failCount;
        private static DateTime _serviceStartedUtc = DateTime.MinValue;

        public static bool AutoResumeEnabled
        {
            get => DevToolsConfig.PauseMenuAutoResumeEnabled;
            set => DevToolsConfig.PauseMenuAutoResumeEnabled = value;
        }

        public static int DismissCount => _dismissCount;
        public static int FailCount => _failCount;
        public static DateTime LastDismissUtc => _lastDismissUtc;

        /// <summary>
        /// Called from SubModule.OnApplicationTick (campaign tick only).
        /// Detects pause menu and auto-dismisses it.
        /// </summary>
        public static void OnCampaignTick()
        {
            if (!AutoResumeEnabled)
            {
                return;
            }

            if (_serviceStartedUtc == DateTime.MinValue)
            {
                _serviceStartedUtc = DateTime.UtcNow;
                DebugLogger.Test("[TBG PAUSE] auto-resume service started", showInGame: false);
            }

            _accumulator += 0.016f;
            if (_accumulator < PollIntervalSec)
            {
                return;
            }

            _accumulator = 0f;

            if (!EscapeMenuHelper.IsEscapeMenuOpen())
            {
                return;
            }

            if (GameSessionState.IsMapMenuOpen)
            {
                _lastDismissResult = EscapeMenuHelper.DismissIfOpen();
                _lastDismissUtc = DateTime.UtcNow;

                if (_lastDismissResult)
                {
                    _dismissCount++;
                }
                else
                {
                    _failCount++;
                    return;
                }

                System.Threading.Thread.Sleep(300);
            }

            var clockOk = Campaign.Current != null
                && Campaign.Current.TimeControlMode == CampaignTimeControlMode.Stop;

            if (clockOk && Campaign.Current != null)
            {
                Campaign.Current.TimeControlMode = CampaignTimeControlMode.StoppablePlay;
                DebugLogger.Test(
                    $"[TBG PAUSE] auto-dismissed pause menu count={_dismissCount} fail={_failCount}",
                    showInGame: false);
            }
        }
    }
}
