using System;
using System.Collections;
using System.Reflection;
using System.Text;
using HarmonyLib;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class QuickStartDiagnostics
    {
        public static void LogIntroDecision(
            string hook,
            string stateType,
            string decision,
            string reason)
        {
            var subStage = CampaignSetupStateTracker.SubStage ?? "null";
            var launchIntent = MainMenuAutoLauncher.CurrentLaunchIntentLabel;
            GuildLog.Info(
                $"[TBG QUICKSTART] intro decision: hook={hook} state={stateType ?? "null"} " +
                $"phase={CampaignSetupStateTracker.Phase} subStage={subStage} " +
                $"forwardDone={SandboxCampaignIntroSkip.ForwardIntroSkipDone} " +
                $"launchIntent={launchIntent} isForwardLaunch={MainMenuAutoLauncher.IsForwardLaunchInProgress} " +
                $"bootstrapComplete={CampaignSetupStateTracker.BootstrapCompletedThisProcess} " +
                $"decision={decision} reason={reason}",
                showInGame: false);
        }

        public static void LogStateStack(string trigger)
        {
            try
            {
                var manager = GameStateManager.Current;
                if (manager == null)
                {
                    GuildLog.Info($"[TBG QUICKSTART] state stack ({trigger}): unavailable (GameStateManager null)", showInGame: false);
                    return;
                }

                var current = manager.ActiveState?.GetType().Name ?? "null";
                var stackField = AccessTools.Field(typeof(GameStateManager), "_stateStack")
                    ?? AccessTools.Field(typeof(GameStateManager), "StateStack");
                if (stackField?.GetValue(manager) is IEnumerable stack)
                {
                    var names = new StringBuilder();
                    foreach (var item in stack)
                    {
                        if (names.Length > 0)
                        {
                            names.Append(" > ");
                        }

                        names.Append(item?.GetType().Name ?? "null");
                    }

                    GuildLog.Info(
                        $"[TBG QUICKSTART] state stack ({trigger}): current={current} stack={names}",
                        showInGame: false);
                    return;
                }

                GuildLog.Info($"[TBG QUICKSTART] state stack ({trigger}): current={current} stack=unavailable", showInGame: false);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] state stack ({trigger}): unavailable ({ex.Message})", showInGame: false);
            }
        }
    }
}
