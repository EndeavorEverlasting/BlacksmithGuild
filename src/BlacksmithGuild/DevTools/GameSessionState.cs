using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public enum SessionPhase
    {
        ModuleOnly,
        CampaignLoading,
        CampaignReady,
        MapPaused,
        MapActive,
        Unknown
    }

    public static class GameSessionState
    {
        public static SessionPhase Phase { get; private set; } = SessionPhase.ModuleOnly;

        public static bool IsCampaignLoaded { get; private set; }

        public static bool IsMainHeroReady { get; private set; }

        public static bool IsTimePaused { get; private set; }

        public static bool CanPollFileInbox { get; private set; }

        public static bool CanPollHotkeys { get; private set; }

        public static void Refresh()
        {
            try
            {
                IsCampaignLoaded = Campaign.Current != null;
            }
            catch
            {
                IsCampaignLoaded = false;
            }

            if (!IsCampaignLoaded)
            {
                Phase = SessionPhase.ModuleOnly;
                IsMainHeroReady = false;
                IsTimePaused = false;
                CanPollFileInbox = false;
                CanPollHotkeys = false;
                return;
            }

            try
            {
                IsMainHeroReady = Hero.MainHero != null;
            }
            catch
            {
                IsMainHeroReady = false;
            }

            if (!IsMainHeroReady)
            {
                Phase = SessionPhase.CampaignLoading;
                IsTimePaused = false;
                CanPollFileInbox = false;
                CanPollHotkeys = false;
                return;
            }

            try
            {
                IsTimePaused = Campaign.Current.TimeControlMode == CampaignTimeControlMode.Stop;
            }
            catch
            {
                IsTimePaused = false;
            }

            Phase = IsTimePaused ? SessionPhase.MapPaused : SessionPhase.MapActive;
            CanPollFileInbox = true;
            CanPollHotkeys = Phase == SessionPhase.MapActive || Phase == SessionPhase.MapPaused;
        }
    }
}
