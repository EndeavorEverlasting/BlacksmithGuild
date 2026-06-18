using System;
using System.Reflection;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.GameState;
using TaleWorlds.Core;

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

        public static bool IsCampaignMapReady { get; private set; }

        public static bool IsMapMenuOpen { get; private set; }

        public static string MapMenuId { get; private set; }

        public static bool CanPollHelpHotkeys { get; private set; }

        public static bool CanPollRiskyHotkeys { get; private set; }

        public static bool CanPollFileInbox { get; private set; }

        public static bool CanPollHotkeys { get; private set; }

        public static void Refresh()
        {
            IsMapMenuOpen = false;
            MapMenuId = null;

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
                IsCampaignMapReady = false;
                CanPollHelpHotkeys = false;
                CanPollRiskyHotkeys = false;
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
                IsCampaignMapReady = false;
                CanPollHelpHotkeys = false;
                CanPollRiskyHotkeys = false;
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

            ReadMapMenuState();
            IsCampaignMapReady = EvaluateCampaignMapReady(out _);

            Phase = IsCampaignMapReady
                ? (IsTimePaused ? SessionPhase.MapPaused : SessionPhase.MapActive)
                : SessionPhase.CampaignReady;

            CanPollHelpHotkeys = true;
            CanPollRiskyHotkeys = IsCampaignMapReady && !IsMapMenuOpen;
            CanPollFileInbox = IsCampaignMapReady;
            CanPollHotkeys = CanPollHelpHotkeys || CanPollRiskyHotkeys;
        }

        public static bool EvaluateCampaignMapReady(out string blockDetail)
        {
            blockDetail = null;

            try
            {
                if (Campaign.Current == null)
                {
                    blockDetail = "Campaign.Current is null";
                    return false;
                }
            }
            catch
            {
                blockDetail = "Campaign.Current unavailable";
                return false;
            }

            try
            {
                if (Hero.MainHero == null)
                {
                    blockDetail = "MainHero is null";
                    return false;
                }
            }
            catch
            {
                blockDetail = "MainHero unavailable";
                return false;
            }

            if (IsMissionActive())
            {
                blockDetail = "mission active";
                return false;
            }

            try
            {
                var activeState = GameStateManager.Current?.ActiveState;
                if (activeState is MapState)
                {
                    return true;
                }

                blockDetail = activeState == null
                    ? "active game state is null"
                    : $"active state: {activeState.GetType().Name}";
                return false;
            }
            catch
            {
                blockDetail = "game state unavailable";
                return false;
            }
        }

        public static string GetCampaignMapBlockDetail()
        {
            EvaluateCampaignMapReady(out var blockDetail);
            return blockDetail ?? "campaign map ready";
        }

        public static string GetActiveStateName()
        {
            try
            {
                return GameStateManager.Current?.ActiveState?.GetType().Name ?? "null";
            }
            catch
            {
                return "unknown";
            }
        }

        public static bool IsMissionActiveForTrace()
        {
            return IsMissionActive();
        }

        private static void ReadMapMenuState()
        {
            try
            {
                if (GameStateManager.Current?.ActiveState is MapState mapState)
                {
                    IsMapMenuOpen = mapState.AtMenu;
                    MapMenuId = mapState.GameMenuId;
                }
            }
            catch
            {
                IsMapMenuOpen = false;
                MapMenuId = null;
            }
        }

        private static bool IsMissionActive()
        {
            try
            {
                var missionType = Type.GetType(
                    "TaleWorlds.MountAndBlade.Mission, TaleWorlds.MountAndBlade"
                );
                if (missionType == null)
                {
                    return false;
                }

                var current = missionType.GetProperty(
                    "Current",
                    BindingFlags.Public | BindingFlags.Static
                )?.GetValue(null);

                return current != null;
            }
            catch
            {
                return true;
            }
        }
    }
}
