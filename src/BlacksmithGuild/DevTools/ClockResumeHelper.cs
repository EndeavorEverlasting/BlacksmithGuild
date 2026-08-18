using System;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    // Shared clock-resume policy for every movement driver. A travel command only becomes visible
    // mechanics when the campaign clock is running, so all drivers route through this single helper
    // instead of duplicating (and drifting on) TimeControlMode logic.
    public static class CampaignClockResumeHelper
    {
        // Resumes a stopped campaign clock when it is safe to do so, logging before/after.
        // Returns true when the clock is running after the call.
        public static bool EnsureClockRunning(string caller)
        {
            var who = string.IsNullOrWhiteSpace(caller) ? "unknown" : caller;
            try
            {
                if (Campaign.Current == null || GameSessionState.IsMissionActiveForTrace())
                {
                    DebugLogger.Test(
                        $"[TBG CLOCK] resume skipped caller={who} reason=unsafe_surface running={IsClockRunning().ToString().ToLowerInvariant()}",
                        showInGame: false);
                    return IsClockRunning();
                }

                if (IsEscapeMenuOpen())
                {
                    DebugLogger.Test(
                        $"[TBG CLOCK] resume skipped caller={who} reason=escape_menu_open running={IsClockRunning().ToString().ToLowerInvariant()}",
                        showInGame: false);
                    return IsClockRunning();
                }

                if (GameSessionState.IsMapMenuOpen)
                {
                    DebugLogger.Test(
                        $"[TBG CLOCK] resume skipped caller={who} reason=map_menu_open running={IsClockRunning().ToString().ToLowerInvariant()}",
                        showInGame: false);
                    return IsClockRunning();
                }

                if (Campaign.Current.TimeControlMode == CampaignTimeControlMode.Stop)
                {
                    DebugLogger.Test(
                        $"[TBG CLOCK] resume caller={who} before=Stop after=StoppablePlay",
                        showInGame: false);
                    Campaign.Current.TimeControlMode = CampaignTimeControlMode.StoppablePlay;
                    return true;
                }

                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG CLOCK] resume failed caller={who}: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool IsEscapeMenuOpen()
        {
            try
            {
                var surface = GameSessionState.LatestGameplaySurface?.GameplaySurface;
                return string.Equals(surface, GameplaySurfaceKinds.EscapeMenu, StringComparison.Ordinal);
            }
            catch
            {
                return false;
            }
        }

        public static bool IsClockRunning()
        {
            try
            {
                return Campaign.Current != null
                    && Campaign.Current.TimeControlMode != CampaignTimeControlMode.Stop;
            }
            catch
            {
                return false;
            }
        }
    }

    /// <summary>
    /// Remembers a route-blocking escape-menu pause and restores the campaign clock after the
    /// operator returns to the campaign map. This service never sends global input or dismisses UI;
    /// it only performs the existing in-process clock transition once the surface is safe again.
    /// </summary>
    internal static class PauseAwareCampaignClockRecoveryService
    {
        private const float PollIntervalSeconds = 0.25f;
        private static readonly TimeSpan RecoveryWindow = TimeSpan.FromSeconds(5);

        private static float _pollAccumulator;
        private static bool _escapeMenuObserved;
        private static DateTime _lastEscapeMenuObservedUtc = DateTime.MinValue;

        public static void Poll(float dt)
        {
            if (dt <= 0f)
            {
                return;
            }

            _pollAccumulator += dt;
            if (_pollAccumulator < PollIntervalSeconds)
            {
                return;
            }

            _pollAccumulator = 0f;
            var snapshot = GameSessionState.LatestGameplaySurface;
            if (snapshot == null)
            {
                return;
            }

            if (string.Equals(snapshot.GameplaySurface, GameplaySurfaceKinds.EscapeMenu, StringComparison.Ordinal))
            {
                if (!_escapeMenuObserved)
                {
                    DebugLogger.Test(
                        "[TBG PAUSE] escape menu observed; clock recovery armed",
                        showInGame: false);
                }

                _escapeMenuObserved = true;
                _lastEscapeMenuObservedUtc = DateTime.UtcNow;
                return;
            }

            if (!_escapeMenuObserved)
            {
                return;
            }

            if (DateTime.UtcNow - _lastEscapeMenuObservedUtc > RecoveryWindow)
            {
                Reset("recovery_window_expired");
                return;
            }

            if (GameSessionState.IsMapMenuOpen || GameSessionState.IsMissionActiveForTrace())
            {
                return;
            }

            if (!string.Equals(snapshot.GameplaySurface, GameplaySurfaceKinds.CampaignMap, StringComparison.Ordinal))
            {
                return;
            }

            if (!GameSessionState.IsTimePaused || CampaignClockResumeHelper.IsClockRunning())
            {
                Reset("clock_already_running");
                return;
            }

            var resumed = CampaignClockResumeHelper.EnsureClockRunning(nameof(PauseAwareCampaignClockRecoveryService));
            DebugLogger.Test(
                $"[TBG PAUSE] post-escape clock recovery resumed={resumed.ToString().ToLowerInvariant()}",
                showInGame: false);

            if (resumed)
            {
                Reset("clock_resumed");
            }
        }

        private static void Reset(string reason)
        {
            if (_escapeMenuObserved)
            {
                DebugLogger.Test($"[TBG PAUSE] clock recovery disarmed reason={reason}", showInGame: false);
            }

            _escapeMenuObserved = false;
            _lastEscapeMenuObservedUtc = DateTime.MinValue;
        }
    }
}
