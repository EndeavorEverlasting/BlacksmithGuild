using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class TimeDevTools
    {
        private static bool _fastForwardActive;

        public static bool IsFastForwardActive => _fastForwardActive;

        public static void AdvanceOneDay()
        {
            if (Campaign.Current == null)
            {
                DebugLogger.Test("AdvanceOneDay: FAIL — no active campaign.");
                return;
            }

            CampaignEventDispatcher.Instance.DailyTick();
            DebugLogger.Test("AdvanceOneDay: DailyTick fired.");
        }

        public static void ToggleFastForward()
        {
            if (Campaign.Current == null)
            {
                DebugLogger.Test("ToggleFastForward: FAIL — no active campaign.");
                return;
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
        }
    }
}
