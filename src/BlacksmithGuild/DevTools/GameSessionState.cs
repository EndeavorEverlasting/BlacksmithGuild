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

        public static bool IsSettlementMenuReady { get; private set; }

        public static bool IsMapStateActive { get; private set; }

        public static bool IsCampaignMapSurfaceOpen { get; private set; }

        public static string ReadinessSurface { get; private set; } = ReadinessSurfaceKinds.Unknown;

        public static string SettlementMenuId { get; private set; }

        public static bool IsCampaignSessionReady =>
            IsMainHeroReady
            && (IsCampaignMapReady || IsSettlementInteriorReady || IsSettlementMenuReady);

        public static int RefreshGeneration { get; private set; }

        private const double RefreshTraceIntervalSec = 2.0;
        private const double ReadHeroTraceIntervalSec = 5.0;

        private static string _lastRefreshFingerprint;
        private static DateTime _lastRefreshTraceUtc = DateTime.MinValue;
        private static bool _lastHeroReadyProbe;
        private static DateTime _lastReadHeroTraceUtc = DateTime.MinValue;
        private static string _lastPromotionFingerprint;

        public static void Refresh()
        {
            var fingerprint = BuildRefreshFingerprint();
            var fingerprintChanged = !string.Equals(fingerprint, _lastRefreshFingerprint, StringComparison.Ordinal);
            var traceDue = fingerprintChanged
                || (DateTime.UtcNow - _lastRefreshTraceUtc).TotalSeconds >= RefreshTraceIntervalSec;

            if (!traceDue)
            {
                RefreshInternal(traceSubOps: false);
                RuntimeTrace.LogSuppressInterval(
                    $"refresh|{fingerprint}",
                    "GameSessionState",
                    "RefreshSuppressed",
                    fingerprint,
                    RefreshTraceIntervalSec);
                RefreshGeneration++;
                return;
            }

            _lastRefreshFingerprint = fingerprint;
            _lastRefreshTraceUtc = DateTime.UtcNow;

            RuntimeTrace.Run("GameSessionState", "Refresh", () => RefreshInternal(traceSubOps: true));
            MaybeTraceReadinessPromotion();
            RefreshGeneration++;
        }

        private static string BuildRefreshFingerprint()
        {
            var guardActive = MapTransitionGuard.IsUnsafeContinueLoadWindow();
            return string.Join(
                "|",
                IsCampaignLoaded ? "1" : "0",
                IsMainHeroReady ? "1" : "0",
                guardActive ? "g" : "-",
                GetActiveStateName(),
                IsCampaignMapReady ? "m" : "-",
                IsSettlementInteriorReady ? "s" : "-",
                IsSettlementMenuReady ? "u" : "-",
                Phase.ToString());
        }

        private static void RefreshInternal(bool traceSubOps)
        {
            if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch()
                && !MapTransitionGuard.TryDetectCampaignSessionLoaded(out _))
            {
                RefreshLightweight(traceSubOps);
                return;
            }

            RefreshFull(traceSubOps);
        }

        private static void RefreshLightweight(bool traceSubOps)
        {
            IsMapMenuOpen = false;
            MapMenuId = null;
            ActiveMenuId = null;
            CurrentLocationId = null;
            CurrentSettlementName = null;
            CurrentSettlementStringId = null;
            IsSettlementInteriorReady = false;
            IsTavernLocationReady = false;
            IsSettlementMenuReady = false;
            IsMapStateActive = false;
            IsCampaignMapSurfaceOpen = false;
            ReadinessSurface = ReadinessSurfaceKinds.Loading;

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

            ReadHeroInternal(traceSubOps);

            Phase = SessionPhase.CampaignLoading;
            IsTimePaused = false;
            IsCampaignMapReady = false;
            IsSettlementMenuReady = false;
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

        private static void RefreshFull(bool traceSubOps)
        {
            IsMapMenuOpen = false;
            MapMenuId = null;
            ActiveMenuId = null;
            CurrentLocationId = null;
            CurrentSettlementName = null;
            CurrentSettlementStringId = null;
            IsSettlementInteriorReady = false;
            IsTavernLocationReady = false;
            IsSettlementMenuReady = false;
            IsMapStateActive = false;
            IsCampaignMapSurfaceOpen = false;
            ReadinessSurface = ReadinessSurfaceKinds.Loading;

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

            ReadHeroInternal(traceSubOps);

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

            if (traceSubOps)
            {
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
            }
            else
            {
                ReadMenuState();
                IsCampaignMapReady = EvaluateCampaignMapReady(out _);
                EvaluateSettlementInteriorReady();
                IsTavernLocationReady = EvaluateTavernLocationReady();
            }

            EvaluateSettlementMenuReady();
            EvaluateReadinessSurface();

            if (IsSettlementInteriorReady)
            {
                Phase = SessionPhase.SettlementInterior;
            }
            else if (IsCampaignMapReady)
            {
                Phase = IsTimePaused ? SessionPhase.MapPaused : SessionPhase.MapActive;
            }
            else if (IsSettlementMenuReady)
            {
                Phase = SessionPhase.SettlementInterior;
            }
            else
            {
                Phase = SessionPhase.CampaignReady;
            }

            CanPollHelpHotkeys = IsCampaignMapReady || IsSettlementInteriorReady || IsSettlementMenuReady;
            CanPollRiskyHotkeys = IsCampaignMapReady && !IsMapMenuOpen;
            CanPollFileInbox = IsCampaignMapReady || IsSettlementInteriorReady || IsSettlementMenuReady;
            CanPollHotkeys = CanPollHelpHotkeys || CanPollRiskyHotkeys;
        }

        private static void ReadHeroInternal(bool traceSubOps)
        {
            bool heroReady;
            try
            {
                heroReady = Hero.MainHero != null;
            }
            catch
            {
                heroReady = false;
            }

            var heroChanged = heroReady != _lastHeroReadyProbe;
            var heroTraceDue = heroChanged
                || (DateTime.UtcNow - _lastReadHeroTraceUtc).TotalSeconds >= ReadHeroTraceIntervalSec;

            if (traceSubOps && heroTraceDue)
            {
                RuntimeTrace.Run("GameSessionState", "ReadHero", () => { IsMainHeroReady = heroReady; });
                _lastReadHeroTraceUtc = DateTime.UtcNow;
                _lastHeroReadyProbe = heroReady;
                return;
            }

            IsMainHeroReady = heroReady;
            if (heroChanged)
            {
                _lastHeroReadyProbe = heroReady;
            }
        }

        private static void EvaluateSettlementMenuReady()
        {
            IsSettlementMenuReady = false;

            if (!IsMainHeroReady || IsSettlementInteriorReady)
            {
                return;
            }

            if (!MapTransitionGuard.TryDetectSettlementMenuSignal(out _))
            {
                return;
            }

            IsSettlementMenuReady = true;
            var settlement = ResolveCurrentSettlement();
            if (settlement != null)
            {
                CaptureSettlementSnapshot(settlement);
            }
        }

        private static void MaybeTraceReadinessPromotion()
        {
            if (!IsCampaignSessionReady)
            {
                return;
            }

            var fingerprint =
                $"{IsCampaignMapReady}|{IsSettlementInteriorReady}|{IsSettlementMenuReady}|{Phase}";
            if (string.Equals(fingerprint, _lastPromotionFingerprint, StringComparison.Ordinal))
            {
                return;
            }

            _lastPromotionFingerprint = fingerprint;
            var detail = GetCommandReadyBlockDetail();
            RuntimeTrace.Run("GameSessionState", "ReadinessPromoted", () =>
            {
                DebugLogger.Test($"[TBG READINESS] promoted: {detail}", showInGame: false);
            });
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
            if (IsCampaignSessionReady)
            {
                if (IsCampaignMapReady)
                {
                    if (IsCampaignMapSurfaceOpen)
                    {
                        return "campaign map ready";
                    }

                    if (IsMapMenuOpen)
                    {
                        var settlement = CurrentSettlementName ?? CurrentSettlementStringId ?? "settlement";
                        return $"settlement town menu ({settlement})";
                    }

                    return "campaign map ready";
                }

                if (IsSettlementInteriorReady)
                {
                    return "settlement interior ready";
                }

                if (IsSettlementMenuReady)
                {
                    var settlement = CurrentSettlementName ?? CurrentSettlementStringId ?? "settlement";
                    return $"settlement menu ready ({settlement})";
                }

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
            IsSettlementMenuReady = false;
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
            IsMapStateActive = false;
            try
            {
                if (GameStateManager.Current?.ActiveState is MapState mapState)
                {
                    IsMapStateActive = true;
                    IsMapMenuOpen = mapState.AtMenu;
                    MapMenuId = mapState.GameMenuId;
                    ActiveMenuId = mapState.GameMenuId;
                    SettlementMenuId = mapState.GameMenuId;
                }
                else
                {
                    IsMapMenuOpen = false;
                    MapMenuId = null;
                    SettlementMenuId = null;
                }
            }
            catch
            {
                IsMapStateActive = false;
                IsMapMenuOpen = false;
                MapMenuId = null;
                SettlementMenuId = null;
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

        private static void EvaluateReadinessSurface()
        {
            SettlementMenuId = MapMenuId;
            IsCampaignMapSurfaceOpen = IsMapStateActive && !IsMapMenuOpen;

            if (!IsCampaignLoaded || !IsMainHeroReady)
            {
                ReadinessSurface = ReadinessSurfaceKinds.Loading;
                return;
            }

            if (MapTransitionGuard.IsUnsafeContinueLoadWindow()
                && !MapTransitionGuard.TryDetectCampaignSessionLoaded(out _))
            {
                ReadinessSurface = ReadinessSurfaceKinds.Loading;
                return;
            }

            var activeStateName = GetActiveStateName();
            if (string.Equals(activeStateName, "MainMenuState", StringComparison.Ordinal))
            {
                ReadinessSurface = ReadinessSurfaceKinds.MainMenu;
                return;
            }

            if (IsMapStateActive && IsMapMenuOpen)
            {
                ReadinessSurface = ReadinessSurfaceKinds.SettlementMenu;
                return;
            }

            if (IsSettlementInteriorReady)
            {
                ReadinessSurface = ReadinessSurfaceKinds.SettlementInterior;
                return;
            }

            if (IsCampaignMapSurfaceOpen)
            {
                ReadinessSurface = ReadinessSurfaceKinds.MapSurface;
                return;
            }

            ReadinessSurface = ReadinessSurfaceKinds.Unknown;
        }

        public static ReadinessSurfaceSnapshot CaptureReadinessSurfaceSnapshot()
        {
            return new ReadinessSurfaceSnapshot
            {
                MapStateActive = IsMapStateActive,
                SettlementMenuOpen = IsMapMenuOpen,
                SettlementMenuId = SettlementMenuId ?? MapMenuId ?? "",
                SettlementName = CurrentSettlementName ?? CurrentSettlementStringId ?? "",
                CampaignMapSurfaceOpen = IsCampaignMapSurfaceOpen,
                SettlementInteriorReady = IsSettlementInteriorReady,
                ReadinessSurface = ReadinessSurface ?? ReadinessSurfaceKinds.Unknown
            };
        }

        public static void LogReadinessSurfaceTrace(ReadinessSurfaceSnapshot snap)
        {
            var settlement = string.IsNullOrEmpty(snap.SettlementName) ? "unknown" : snap.SettlementName;
            DebugLogger.Test(
                $"[TBG READINESS] surface={snap.ReadinessSurface} settlement={settlement} atMenu={snap.SettlementMenuOpen.ToString().ToLowerInvariant()} mapReady={IsCampaignMapReady.ToString().ToLowerInvariant()} sessionReady={IsCampaignSessionReady.ToString().ToLowerInvariant()}",
                showInGame: false);
            DebugLogger.Test(
                $"[TBG TRACE] area=StatusFlush op=ReadinessSurface stage=ok surface={snap.ReadinessSurface} settlement={settlement} atMenu={snap.SettlementMenuOpen.ToString().ToLowerInvariant()} path={LaunchPathInference.GetPathLabel()}",
                showInGame: false);
        }

        public static string GetSessionReadyNoticeText()
        {
            var settlement = CurrentSettlementName ?? CurrentSettlementStringId ?? "settlement";
            switch (ReadinessSurface)
            {
                case ReadinessSurfaceKinds.SettlementMenu:
                    return $"session ready at {settlement} town menu. Press F8 for commands.";
                case ReadinessSurfaceKinds.MapSurface:
                    return "campaign map ready. Press F8 for commands.";
                case ReadinessSurfaceKinds.SettlementInterior:
                    return "settlement interior ready. Press F8 for commands.";
                default:
                    return "session ready. Press F8 for commands.";
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

        public static void SyncForgeStatus(bool skipRefresh = false)
        {
            RuntimeTrace.RunSafe("StatusFlush", "SyncForgeStatus", () =>
            {
                if (skipRefresh)
                {
                    RuntimeTrace.LogSkipped("StatusFlush", "SyncForgeStatusRefresh", "skipRefresh");
                }
                else
                {
                    RuntimeTrace.RunSafe("StatusFlush", "SyncForgeStatusRefresh", () => Refresh());
                }

                RuntimeTrace.RunSafe("StatusFlush", "ReadinessSurface", () =>
                {
                    LogReadinessSurfaceTrace(CaptureReadinessSurfaceSnapshot());
                });

                RuntimeTrace.RunSafe("StatusFlush", "session_snapshot_begin", () =>
                {
                    DebugLogger.Test(
                        $"[TBG STATUS] snapshot phase={Phase} timePaused={IsTimePaused.ToString().ToLowerInvariant()} sessionReady={IsCampaignSessionReady.ToString().ToLowerInvariant()} mapReady={IsCampaignMapReady.ToString().ToLowerInvariant()} surface={ReadinessSurface} campaignMapSurfaceOpen={IsCampaignMapSurfaceOpen.ToString().ToLowerInvariant()}",
                        showInGame: false);
                });
                RuntimeTrace.RunSafe("StatusFlush", "session_snapshot_ok", () => { });

                RuntimeTrace.RunSafe("StatusFlush", "update_session_begin", () => { });
                RuntimeTrace.RunSafe("StatusFlush", "update_session", () =>
                {
                    ForgeStatus.UpdateSession(Phase, IsTimePaused, flush: false);
                });
                RuntimeTrace.RunSafe("StatusFlush", "update_session_ok", () => { });

                RuntimeTrace.RunSafe("StatusFlush", "update_readiness_begin", () => { });
                RuntimeTrace.RunSafe("StatusFlush", "update_readiness", () =>
                {
                    var mapReady = IsCampaignMapReady;
                    var heroReady = IsMainHeroReady;
                    if (CampaignMapReadyOrchestrator.ShouldDeferHeavyStatusFlush(out var reason))
                    {
                        RuntimeTrace.LogSkipped(
                            "StatusFlush",
                            "update_readiness_heavy",
                            reason);
                    }

                    ForgeStatus.UpdateReadiness(mapReady, heroReady);
                });
                RuntimeTrace.RunSafe("StatusFlush", "update_readiness_ok", () => { });

                RuntimeTrace.RunSafe("StatusFlush", "file_write_begin", () => { });
                RuntimeTrace.RunSafe("StatusFlush", "file_write_ok", () => { });
            }, emitEnd: true);
        }
    }
}
