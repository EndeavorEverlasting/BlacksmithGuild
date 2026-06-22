using BlacksmithGuild.DevTools.QuickStart;

namespace BlacksmithGuild.DevTools.Reporting
{
    /// <summary>
    /// Central policy for deferring heavy campaign reads/writes during Continue load and MapTransition.
    /// </summary>
    public static class MapTransitionGuard
    {
        public static bool IsUnsafeContinueLoadWindow()
        {
            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow)
            {
                return true;
            }

            if (CampaignSetupStateTracker.Phase == SetupPhase.MapTransition)
            {
                return true;
            }

            if (string.Equals(
                    GameSessionState.GetActiveStateName(),
                    "GameLoadingState",
                    System.StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (LaunchPathInference.GetCurrentPath() == LaunchPathKind.Continue)
            {
                var phase = CampaignSetupStateTracker.Phase;
                var settled = GameSessionState.IsCampaignMapReady
                    && GameSessionState.IsMainHeroReady
                    && (phase == SetupPhase.MapReady || phase == SetupPhase.Complete);

                if (!settled)
                {
                    return true;
                }
            }

            return false;
        }

        public static bool ShouldDeferHeavyCampaignTouch()
        {
            return IsUnsafeContinueLoadWindow();
        }

        public static string GetDeferReason()
        {
            if (string.Equals(
                    GameSessionState.GetActiveStateName(),
                    "GameLoadingState",
                    System.StringComparison.OrdinalIgnoreCase))
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
    }
}
