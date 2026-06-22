using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.MapTrade;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Stops all TBG movement automation FSMs from one inbox command / hotkey.
    /// </summary>
    public static class AutomationAbortService
    {
        public static bool AbortAllMovementAutomationNow()
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked(
                    $"{ModDisplay.Name} — Abort blocked: {GameSessionState.GetCampaignMapBlockDetail()}.");
                return false;
            }

            var aborted = false;

            if (AutonomousGuildLoopService.IsRunning && AutonomousGuildLoopService.AbortNow())
            {
                aborted = true;
            }

            if (CohesionExecutionDriver.IsRunning)
            {
                CohesionExecutionDriver.AbortNow();
                aborted = true;
            }

            if (MapTradeAutonomousService.IsRunning)
            {
                MapTradeAutonomousService.AbortNow();
                aborted = true;
            }

            if (AutoTravelService.HasActiveRoute && AutoTravelService.AbortNow())
            {
                aborted = true;
            }

            if (aborted)
            {
                InGameNotice.Blocked("TBG AUTOMATION: all movement automation aborted.");
            }
            else
            {
                InGameNotice.Info("TBG AUTOMATION: no active movement automation.");
            }

            return true;
        }
    }
}
