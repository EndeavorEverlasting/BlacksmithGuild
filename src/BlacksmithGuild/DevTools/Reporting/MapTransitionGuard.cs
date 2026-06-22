using BlacksmithGuild.DevTools.QuickStart;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.GameState;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.Reporting
{
    /// <summary>
    /// Central policy for deferring heavy campaign reads/writes during Continue load and MapTransition.
    /// </summary>
    public static class MapTransitionGuard
    {
        private static bool _wasUnsafe;

        public static bool IsUnsafeContinueLoadWindow()
        {
            if (IsPlaySetupUnsafe())
            {
                return true;
            }

            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow
                && !TryDetectCampaignSessionLoaded(out _))
            {
                return true;
            }

            if (CampaignSetupStateTracker.Phase == SetupPhase.MapTransition
                && !TryDetectCampaignSessionLoaded(out _))
            {
                return true;
            }

            if (IsTransientGameLoadingState())
            {
                return true;
            }

            if (LaunchPathInference.GetCurrentPath() == LaunchPathKind.Continue)
            {
                var phase = CampaignSetupStateTracker.Phase;
                if (phase == SetupPhase.MapReady || phase == SetupPhase.Complete)
                {
                    return false;
                }

                if (TryDetectCampaignSessionLoaded(out _))
                {
                    return false;
                }

                if (GameSessionState.IsCampaignSessionReady)
                {
                    return false;
                }

                return true;
            }

            return false;
        }

        public static bool ShouldDeferHeavyCampaignTouch()
        {
            var unsafeNow = IsUnsafeContinueLoadWindow();
            if (_wasUnsafe && !unsafeNow)
            {
                RuntimeTrace.LogDeferOnce(
                    "guard_cleared",
                    "MapTransitionGuard",
                    "GuardCleared",
                    GameSessionState.GetCommandReadyBlockDetail());
            }

            _wasUnsafe = unsafeNow;
            return unsafeNow;
        }

        public static string GetDeferReason()
        {
            if (IsPlaySetupUnsafe())
            {
                return "play_setup_active";
            }

            if (IsTransientGameLoadingState())
            {
                return "game_loading_state";
            }

            if (CampaignSetupStateTracker.Phase == SetupPhase.MapTransition)
            {
                return "map_load_transition";
            }

            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow)
            {
                return "map_load_transition";
            }

            if (LaunchPathInference.GetCurrentPath() == LaunchPathKind.Continue)
            {
                return "continue_load_unsettled";
            }

            return "map_load_transition";
        }

        public static bool TraceGuardCheck(string operation)
        {
            if (ShouldDeferHeavyCampaignTouch())
            {
                RuntimeTrace.LogDeferOnce(
                    $"map_transition_guard|{operation}",
                    "MapTransitionGuard",
                    operation,
                    GetDeferReason());
                return true;
            }

            RuntimeTrace.Run("MapTransitionGuard", operation, () => { });
            return false;
        }

        public static bool TryDetectCampaignSessionLoaded(out string detail)
        {
            detail = null;

            if (IsPlaySetupUnsafe())
            {
                detail = "play_setup_active";
                return false;
            }

            try
            {
                if (Campaign.Current == null)
                {
                    detail = "Campaign.Current is null";
                    return false;
                }
            }
            catch
            {
                detail = "Campaign.Current unavailable";
                return false;
            }

            try
            {
                if (Hero.MainHero == null)
                {
                    detail = "MainHero is null";
                    return false;
                }
            }
            catch
            {
                detail = "MainHero unavailable";
                return false;
            }

            if (!HasLoadedUiSignal(out detail))
            {
                return false;
            }

            RuntimeTrace.LogDeferOnce(
                "campaign_session_detected",
                "MapTransitionGuard",
                "CampaignSessionDetected",
                detail);
            return true;
        }

        public static bool TryDetectSettlementMenuSignal(out string detail)
        {
            detail = null;

            try
            {
                if (GameStateManager.Current?.ActiveState is MapState mapState && mapState.AtMenu)
                {
                    var settlement = GameSessionState.ResolveCurrentSettlement();
                    if (settlement != null)
                    {
                        detail = $"settlement_menu:{settlement.StringId}";
                        RuntimeTrace.LogDeferOnce(
                            $"settlement_menu|{settlement.StringId}",
                            "GameSessionState",
                            "SettlementMenuDetected",
                            detail);
                        return true;
                    }

                    var menuId = Campaign.Current?.CurrentMenuContext?.StringId;
                    if (!string.IsNullOrEmpty(menuId))
                    {
                        detail = $"map_menu:{menuId}";
                        RuntimeTrace.LogDeferOnce(
                            $"settlement_menu|{menuId}",
                            "GameSessionState",
                            "SettlementMenuDetected",
                            detail);
                        return true;
                    }
                }
            }
            catch
            {
            }

            return false;
        }

        private static bool IsPlaySetupUnsafe()
        {
            return LaunchPathInference.GetCurrentPath() == LaunchPathKind.Play
                && LaunchPathInference.IsContinueOnlyMapReadyBlocked();
        }

        private static bool IsTransientGameLoadingState()
        {
            if (!string.Equals(
                    GameSessionState.GetActiveStateName(),
                    "GameLoadingState",
                    System.StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            return !TryDetectCampaignSessionLoaded(out _);
        }

        private static bool HasLoadedUiSignal(out string detail)
        {
            detail = null;

            try
            {
                if (GameStateManager.Current?.ActiveState is MapState)
                {
                    detail = "MapState";
                    return true;
                }
            }
            catch
            {
            }

            try
            {
                if (PlayerEncounter.InsideSettlement)
                {
                    detail = "InsideSettlement";
                    return true;
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
                    detail = $"party_settlement:{settlement.StringId}";
                    return true;
                }
            }
            catch
            {
            }

            try
            {
                var menuContext = Campaign.Current?.CurrentMenuContext;
                if (menuContext != null)
                {
                    detail = $"menu_context:{menuContext.StringId}";
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }
    }
}
