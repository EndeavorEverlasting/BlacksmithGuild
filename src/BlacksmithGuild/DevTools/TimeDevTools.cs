using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class TimeDevTools
    {
        private static bool _fastForwardActive;

        public static bool IsFastForwardActive => _fastForwardActive;

        public static string LastFailReason { get; private set; }

        public static bool AdvanceOneDay()
        {
            LastFailReason = null;

            if (Campaign.Current == null)
            {
                LastFailReason = "no active campaign";
                DebugLogger.Test("AdvanceOneDay: FAIL — no active campaign.");
                return false;
            }

            CampaignEventDispatcher.Instance.DailyTick();
            DebugLogger.Test("AdvanceOneDay: DailyTick fired.");
            return true;
        }

        public static bool ToggleFastForward()
        {
            LastFailReason = null;

            if (Campaign.Current == null)
            {
                LastFailReason = "no active campaign";
                DebugLogger.Test("ToggleFastForward: FAIL — no active campaign.");
                return false;
            }

            _fastForwardActive = !_fastForwardActive;

            if (_fastForwardActive)
            {
                Campaign.Current.TimeControlMode = CampaignTimeControlMode.UnstoppableFastForward;
                DebugLogger.Test("ToggleFastForward: ON (unstoppable fast-forward).");
            }
            else
            {
                Campaign.Current.TimeControlMode = CampaignTimeControlMode.Stop;
                DebugLogger.Test("ToggleFastForward: OFF (time stopped).");
            }

            return true;
        }

        public static bool ResumeCampaignClock()
        {
            LastFailReason = null;
            if (Campaign.Current == null)
            {
                LastFailReason = "no active campaign";
                DebugLogger.Test("ResumeCampaignClock: FAIL — no active campaign.");
                return false;
            }

            return CampaignClockResumeHelper.EnsureClockRunning("ResumeCampaignClock");
        }
    }
}
