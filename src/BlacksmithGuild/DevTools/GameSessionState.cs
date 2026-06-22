using System;
using System.Reflection;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.GameState;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.CampaignSystem.Settlements.Locations;
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
        SettlementInterior,
        Unknown
    }

    public static class GameSessionState
    {
        public static SessionPhase Phase { get; private set; } = SessionPhase.ModuleOnly;

        public static bool IsCampaignLoaded { get; private set; }

        public static bool IsMainHeroReady { get; private set; }

        public static bool IsTimePaused { get; private set; }

        public static bool IsCampaignMapReady { get; private set; }

        public static bool IsSettlementInteriorReady { get; private set; }

        public static bool IsTavernLocationReady { get; private set; }

        public static bool IsMapMenuOpen { get; private set; }

        public static string MapMenuId { get; private set; }

        public static string ActiveMenuId { get; private set; }

        public static string CurrentLocationId { get; private set; }

        public static string CurrentSettlementName { get; private set; }

        public static string CurrentSettlementStringId { get; private set; }

        public static bool CanPollHelpHotkeys { get; private set; }

        public static bool CanPollRiskyHotkeys { get; private set; }

        public static bool CanPollFileInbox { get; private set; }

        public static bool CanPollHotkeys { get; private set; }

        public static void Refresh()
        {
            RuntimeTrace.Run("GameSessionState", "Refresh", () =>
            {
                if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch())
                {
                    RefreshLightweight();
                    return;
                }

                RefreshFull();
            });
        }

        private static void RefreshLightweight()
        {
            IsMapMenuOpen = false;
            MapMenuId = null;
            ActiveMenuId = null;
            CurrentLocationId = null;
            CurrentSettlementName = null;
            CurrentSettlementStringId = null;
            IsSettlementInteriorReady = false;
            IsTavernLocationReady = false;

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
                ResetToModuleOnly();
                return;
            }

            RuntimeTrace.Run("GameSessionState", "ReadHero", () =>
            {
                try
                {
                    IsMainHeroReady = Hero.MainHero != null;
                }
                catch
                {
                    IsMainHeroReady = false;
                }
            });

            Phase = SessionPhase.CampaignLoading;
            IsTimePaused = false;
            IsCampaignMapReady = false;
            CanPollHelpHotkeys = false;
            CanPollRiskyHotkeys = false;
            CanPollFileInbox = false;
            CanPollHotkeys = false;

            var reason = MapTransitionGuard.GetDeferReason();
            RuntimeTrace.LogDeferOnce("refresh_read_menu", "GameSessionState", "ReadMenuState", reason);
            RuntimeTrace.LogDeferOnce("refresh_eval_settlement", "GameSessionState", "EvaluateSettlementInterior", reason);
            RuntimeTrace.LogDeferOnce("refresh_eval_map_ready", "GameSessionState", "EvaluateMapReady", reason);
            RuntimeTrace.LogDeferOnce("refresh_eval_tavern", "GameSessionState", "EvaluateTavernLocation", reason);
        }

        private static void RefreshFull()
        {
            IsMapMenuOpen = false;
            MapMenuId = null;
            ActiveMenuId = null;
            CurrentLocationId = null;
            CurrentSettlementName = null;
            CurrentSettlementStringId = null;
            IsSettlementInteriorReady = false;
            IsTavernLocationReady = false;

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
                ResetToModuleOnly();
                return;
            }

            RuntimeTrace.Run("GameSessionState", "ReadHero", () =>
            {
                try
                {
                    IsMainHeroReady = Hero.MainHero != null;
                }
                catch
                {
                    IsMainHeroReady = false;
                }
            });

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

            RuntimeTrace.Run("GameSessionState", "ReadMenuState", ReadMenuState);
            IsCampaignMapReady = RuntimeTrace.Run(
                "GameSessionState",
                "EvaluateMapReady",
                () => EvaluateCampaignMapReady(out _));
            RuntimeTrace.Run("GameSessionState", "EvaluateSettlementInterior", EvaluateSettlementInteriorReady);
            IsTavernLocationReady = RuntimeTrace.Run(
                "GameSessionState",
                "EvaluateTavernLocation",
                EvaluateTavernLocationReady);

            if (IsSettlementInteriorReady)
            {
                Phase = SessionPhase.SettlementInterior;
            }
            else if (IsCampaignMapReady)
            {
                Phase = IsTimePaused ? SessionPhase.MapPaused : SessionPhase.MapActive;
            }
            else
            {
                Phase = SessionPhase.CampaignReady;
            }

            CanPollHelpHotkeys = IsCampaignMapReady || IsSettlementInteriorReady;
            CanPollRiskyHotkeys = IsCampaignMapReady && !IsMapMenuOpen;
            CanPollFileInbox = IsCampaignMapReady || IsSettlementInteriorReady;
            CanPollHotkeys = CanPollHelpHotkeys || CanPollRiskyHotkeys;
        }

        public static bool EvaluateCampaignMapReady(out string blockDetail)
        {
            blockDetail = null;

            if (!TryEnsureHeroReady(out blockDetail))
            {
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

        public static bool EvaluateSettlementInteriorReady(out string blockDetail)
        {
            blockDetail = null;
            EvaluateSettlementInteriorReady();
            if (IsSettlementInteriorReady)
            {
                return true;
            }

            blockDetail = BuildSettlementBlockDetail();
            return false;
        }

        public static string GetCampaignMapBlockDetail()
        {
            EvaluateCampaignMapReady(out var blockDetail);
            return blockDetail ?? "campaign map ready";
        }

        public static string GetCommandReadyBlockDetail()
        {
            if (IsCampaignMapReady || IsSettlementInteriorReady)
            {
                return "command ready";
            }

            if (IsMainHeroReady && IsSettlementInteriorReady == false)
            {
                var settlementDetail = BuildSettlementBlockDetail();
                if (!string.IsNullOrEmpty(settlementDetail))
                {
                    return settlementDetail;
                }
            }

            return GetCampaignMapBlockDetail();
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

        public static Settlement ResolveCurrentSettlement()
        {
            try
            {
                var partySettlement = MobileParty.MainParty?.CurrentSettlement;
                if (partySettlement != null)
                {
                    return partySettlement;
                }
            }
            catch
            {
            }

            try
            {
                return PlayerEncounter.LocationEncounter?.Settlement
                       ?? PlayerEncounter.EncounterSettlement;
            }
            catch
            {
                return null;
            }
        }

        private static void ResetToModuleOnly()
        {
            Phase = SessionPhase.ModuleOnly;
            IsMainHeroReady = false;
            IsTimePaused = false;
            IsCampaignMapReady = false;
            CanPollHelpHotkeys = false;
            CanPollRiskyHotkeys = false;
            CanPollFileInbox = false;
            CanPollHotkeys = false;
        }

        private static bool TryEnsureHeroReady(out string blockDetail)
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

            return true;
        }

        private static void EvaluateSettlementInteriorReady()
        {
            if (!TryEnsureHeroReady(out _) || IsMissionActive())
            {
                return;
            }

            try
            {
                if (PlayerEncounter.InsideSettlement)
                {
                    IsSettlementInteriorReady = true;
                    CaptureSettlementSnapshot(ResolveCurrentSettlement());
                    return;
                }
            }
            catch
            {
            }

            try
            {
                var settlement = MobileParty.MainParty?.CurrentSettlement;
                if (settlement != null)
                {
                    IsSettlementInteriorReady = true;
                    CaptureSettlementSnapshot(settlement);
                }
            }
            catch
            {
            }
        }

        private static bool EvaluateTavernLocationReady()
        {
            if (!IsSettlementInteriorReady)
            {
                return false;
            }

            if (!string.IsNullOrEmpty(CurrentLocationId)
                && CurrentLocationId.IndexOf("tavern", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }

            if (!string.IsNullOrEmpty(ActiveMenuId)
                && ActiveMenuId.IndexOf("tavern", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return true;
            }

            try
            {
                var settlement = ResolveCurrentSettlement();
                var complex = settlement?.LocationComplex;
                var tavern = complex?.GetLocationWithId("tavern");
                if (tavern == null)
                {
                    return false;
                }

                var encounter = PlayerEncounter.LocationEncounter;
                if (encounter != null && encounter.IsTavern(tavern))
                {
                    CurrentLocationId = tavern.StringId;
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static void CaptureSettlementSnapshot(Settlement settlement)
        {
            if (settlement == null)
            {
                return;
            }

            CurrentSettlementName = settlement.Name?.ToString() ?? settlement.StringId;
            CurrentSettlementStringId = settlement.StringId;
            CurrentLocationId = TryResolveCurrentLocationId(settlement);
        }

        private static string TryResolveCurrentLocationId(Settlement settlement)
        {
            try
            {
                var menuId = Campaign.Current?.CurrentMenuContext?.StringId;
                if (!string.IsNullOrEmpty(menuId))
                {
                    ActiveMenuId = menuId;
                    if (menuId.IndexOf("tavern", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return "tavern";
                    }
                }
            }
            catch
            {
            }

            try
            {
                var hero = Hero.MainHero;
                var complex = settlement?.LocationComplex;
                if (hero != null && complex != null)
                {
                    var location = complex.GetLocationOfCharacter(hero);
                    return location?.StringId;
                }
            }
            catch
            {
            }

            return null;
        }

        private static string BuildSettlementBlockDetail()
        {
            if (IsMissionActive())
            {
                return "mission active";
            }

            var settlement = ResolveCurrentSettlement();
            if (settlement == null)
            {
                return "party not at a settlement";
            }

            if (!IsSettlementInteriorReady)
            {
                return $"outside settlement {settlement.Name} — enter town first";
            }

            if (!IsTavernLocationReady)
            {
                return $"inside {settlement.Name} but not in tavern location";
            }

            return "settlement interior ready";
        }

        private static void ReadMenuState()
        {
            try
            {
                if (GameStateManager.Current?.ActiveState is MapState mapState)
                {
                    IsMapMenuOpen = mapState.AtMenu;
                    MapMenuId = mapState.GameMenuId;
                    ActiveMenuId = mapState.GameMenuId;
                }
            }
            catch
            {
                IsMapMenuOpen = false;
                MapMenuId = null;
            }

            try
            {
                var menuId = Campaign.Current?.CurrentMenuContext?.StringId;
                if (!string.IsNullOrEmpty(menuId))
                {
                    ActiveMenuId = menuId;
                }
            }
            catch
            {
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

        public static void SyncForgeStatus()
        {
            Refresh();
            ForgeStatus.UpdateSession(Phase, IsTimePaused);
            ForgeStatus.UpdateReadiness(IsCampaignMapReady, IsMainHeroReady);
        }
    }
}
