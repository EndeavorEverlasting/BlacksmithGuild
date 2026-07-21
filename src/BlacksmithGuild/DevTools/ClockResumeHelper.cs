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
        // When the escape (pause) menu is open, automatically dismisses it before resuming.
        public static bool EnsureClockRunning(string caller)
        {
            var who = string.IsNullOrWhiteSpace(caller) ? "unknown" : caller;
            try
            {
                if (Campaign.Current == null
                    || GameSessionState.IsMissionActiveForTrace())
                {
                    DebugLogger.Test(
                        $"[TBG CLOCK] resume skipped caller={who} reason=unsafe_surface running={IsClockRunning().ToString().ToLowerInvariant()}",
                        showInGame: false);
                    return IsClockRunning();
                }

                // When a map menu is open, check if it's the escape (pause) menu.
                // If so, dismiss it automatically. Other menus (settlement, trade, etc.) block resume.
                if (GameSessionState.IsMapMenuOpen)
                {
                    if (EscapeMenuHelper.IsEscapeMenuOpen())
                    {
                        DebugLogger.Test(
                            $"[TBG CLOCK] resume caller={who} escape_menu detected, dismissing",
                            showInGame: false);
                        EscapeMenuHelper.DismissIfOpen();
                        // Give the game ~300ms to process the Escape key
                        System.Threading.Thread.Sleep(300);
                        // Re-check: if escape menu is still open, skip
                        if (GameSessionState.IsMapMenuOpen && EscapeMenuHelper.IsEscapeMenuOpen())
                        {
                            DebugLogger.Test(
                                $"[TBG CLOCK] resume skipped caller={who} reason=escape_menu_still_open running={IsClockRunning().ToString().ToLowerInvariant()}",
                                showInGame: false);
                            return IsClockRunning();
                        }
                    }
                    else
                    {
                        DebugLogger.Test(
                            $"[TBG CLOCK] resume skipped caller={who} reason=map_menu_open running={IsClockRunning().ToString().ToLowerInvariant()}",
                            showInGame: false);
                        return IsClockRunning();
                    }
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
}
