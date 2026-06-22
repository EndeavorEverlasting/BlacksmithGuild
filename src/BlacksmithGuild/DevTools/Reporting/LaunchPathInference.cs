using BlacksmithGuild.DevTools.QuickStart;

namespace BlacksmithGuild.DevTools.Reporting
{
    public enum LaunchPathKind
    {
        Unknown = 0,
        Play,
        Continue
    }

    /// <summary>
    /// Infers whether the current session is on Play vs Continue path without faking readiness.
    /// </summary>
    public static class LaunchPathInference
    {
        private static string _rememberedIntent;

        public static void RecordIntent(string intent)
        {
            if (string.IsNullOrWhiteSpace(intent))
            {
                return;
            }

            _rememberedIntent = intent.Trim().ToLowerInvariant();
        }

        public static LaunchPathKind GetCurrentPath()
        {
            var active = MainMenuAutoLauncher.CurrentLaunchIntentLabel;
            if (string.Equals(active, "continue", System.StringComparison.OrdinalIgnoreCase))
            {
                return LaunchPathKind.Continue;
            }

            if (!string.Equals(active, "none", System.StringComparison.OrdinalIgnoreCase)
                && !string.IsNullOrEmpty(active))
            {
                return LaunchPathKind.Play;
            }

            if (string.Equals(_rememberedIntent, "continue", System.StringComparison.OrdinalIgnoreCase)
                || CampaignSetupStateTracker.DevSaveLoadUsed)
            {
                return LaunchPathKind.Continue;
            }

            if (string.Equals(_rememberedIntent, "play", System.StringComparison.OrdinalIgnoreCase)
                || CampaignSetupStateTracker.BootstrapUsed)
            {
                return LaunchPathKind.Play;
            }

            var phase = CampaignSetupStateTracker.Phase;
            if (phase == SetupPhase.CharacterCreation
                || phase == SetupPhase.IntroVideo
                || phase == SetupPhase.SandboxVideo)
            {
                return LaunchPathKind.Play;
            }

            if (phase == SetupPhase.MapReady || phase == SetupPhase.Complete)
            {
                if (CampaignSetupStateTracker.DevSaveLoadUsed
                    || string.Equals(_rememberedIntent, "continue", System.StringComparison.OrdinalIgnoreCase))
                {
                    return LaunchPathKind.Continue;
                }

                if (CampaignSetupStateTracker.BootstrapUsed
                    || string.Equals(_rememberedIntent, "play", System.StringComparison.OrdinalIgnoreCase))
                {
                    return LaunchPathKind.Play;
                }
            }

            return LaunchPathKind.Unknown;
        }

        public static string GetPathLabel()
        {
            switch (GetCurrentPath())
            {
                case LaunchPathKind.Play:
                    return "play";
                case LaunchPathKind.Continue:
                    return "continue";
                default:
                    return "unknown";
            }
        }

        /// <summary>
        /// True when Continue-only map-ready hooks must not run (Play setup / pre-campaign).
        /// </summary>
        public static bool IsContinueOnlyMapReadyBlocked()
        {
            var path = GetCurrentPath();
            var phase = CampaignSetupStateTracker.Phase;

            if (path == LaunchPathKind.Play)
            {
                return phase != SetupPhase.MapReady && phase != SetupPhase.Complete;
            }

            if (path == LaunchPathKind.Unknown)
            {
                return phase == SetupPhase.CharacterCreation
                    || phase == SetupPhase.IntroVideo
                    || phase == SetupPhase.SandboxVideo
                    || phase == SetupPhase.MainMenu;
            }

            return false;
        }

        public static bool AreAutonomousDriversBlocked(
            bool immediateHooksCompleted,
            bool stabilizationActive)
        {
            if (!GameSessionState.IsCampaignMapReady || !GameSessionState.IsMainHeroReady)
            {
                return true;
            }

            if (!immediateHooksCompleted || stabilizationActive)
            {
                return true;
            }

            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow)
            {
                return true;
            }

            if (IsContinueOnlyMapReadyBlocked())
            {
                return true;
            }

            return false;
        }
    }
}
