using System;
using System.Reflection;
using System.Text;
using HarmonyLib;
using SandBox;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class SandboxCampaignIntroSkip
    {
        private static bool _probeLogged;
        private static int _campaignIntroSkipCount;
        private static FieldInfo _playedIntroVideoField;
        private static MethodInfo _launchCampaignIntroVideoMethod;
        private static MethodInfo _simulateCharacterCreationMethod;

        public static bool TryApply(Harmony harmony)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation || !AutoCharacterCreationConfig.SkipSandboxCampaignIntro)
            {
                return false;
            }

            ProbeSandBoxApi();

            var applied = false;
            applied |= TryApplyVideoPlaybackActivatePatch(harmony);
            applied |= TryApplyCleanAndPushStatePatch(harmony);
            applied |= TryApplyOnLoadFinishedIntroFlagPatch(harmony);
            applied |= TryApplyGameEndDisarmPatch(harmony);
            return applied;
        }

        private static void ProbeSandBoxApi()
        {
            if (_probeLogged)
            {
                return;
            }

            _probeLogged = true;

            var managerType = typeof(SandBoxGameManager);
            _playedIntroVideoField = AccessTools.Field(managerType, "_playedIntroVideo")
                ?? AccessTools.Field(managerType, "_introVideoPlayed");
            _launchCampaignIntroVideoMethod = AccessTools.Method(managerType, "LaunchCampaignIntroVideo");
            _simulateCharacterCreationMethod = AccessTools.Method(managerType, "SimulateCharacterCreation");

            var launchSandbox = AccessTools.Method(managerType, "LaunchSandboxCharacterCreation");
            var activeState = GameSessionState.GetActiveStateName();

            var detail = new StringBuilder();
            detail.Append("introField=").Append(_playedIntroVideoField != null ? "found" : "missing");
            detail.Append(" launchIntro=").Append(_launchCampaignIntroVideoMethod != null ? "found" : "missing");
            detail.Append(" launchSandbox=").Append(launchSandbox != null ? "found" : "missing");
            detail.Append(" simulateCreation=").Append(_simulateCharacterCreationMethod != null ? "found" : "missing");
            detail.Append(" activeState=").Append(activeState ?? "null");

            GuildLog.Info($"[TBG QUICKSTART] SandBox intro probe: {detail}", showInGame: false);
        }

        private static bool TryApplyOnLoadFinishedIntroFlagPatch(Harmony harmony)
        {
            if (_playedIntroVideoField == null)
            {
                return false;
            }

            try
            {
                var target = AccessTools.DeclaredMethod(typeof(SandBoxGameManager), "OnLoadFinished");
                var prefix = AccessTools.Method(typeof(SandboxCampaignIntroSkip), nameof(OnLoadFinishedIntroFlagPrefix));
                harmony.Patch(target, prefix: new HarmonyMethod(prefix) { priority = Priority.First });
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] intro flag patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool TryApplyVideoPlaybackActivatePatch(Harmony harmony)
        {
            try
            {
                var target = AccessTools.DeclaredMethod(typeof(GameState), "OnActivate");
                if (target == null)
                {
                    return false;
                }

                var prefix = AccessTools.Method(typeof(SandboxCampaignIntroSkip), nameof(GameStateOnActivatePrefix));
                harmony.Patch(target, prefix: new HarmonyMethod(prefix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] GameState.OnActivate video skip patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool TryApplyCleanAndPushStatePatch(Harmony harmony)
        {
            try
            {
                var target = AccessTools.Method(typeof(GameStateManager), "CleanAndPushState");
                if (target == null)
                {
                    return false;
                }

                var postfix = AccessTools.Method(typeof(SandboxCampaignIntroSkip), nameof(CleanAndPushStatePostfix));
                harmony.Patch(target, postfix: new HarmonyMethod(postfix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] CleanAndPushState patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool TryApplyGameEndDisarmPatch(Harmony harmony)
        {
            try
            {
                var target = AccessTools.Method(typeof(Game), "End");
                if (target == null)
                {
                    return false;
                }

                var prefix = AccessTools.Method(typeof(SandboxCampaignIntroSkip), nameof(GameEndPrefix));
                harmony.Patch(target, prefix: new HarmonyMethod(prefix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] Game.End disarm patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static void GameEndPrefix()
        {
            CampaignSetupStateTracker.DisarmBootstrap("game end");
        }

        private static void OnLoadFinishedIntroFlagPrefix(SandBoxGameManager __instance)
        {
            if (!ShouldSkipIntroVideo(__instance))
            {
                return;
            }

            try
            {
                _playedIntroVideoField?.SetValue(__instance, true);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] intro flag set failed: {ex.Message}", showInGame: false);
            }
        }

        private static bool GameStateOnActivatePrefix(GameState __instance)
        {
            if (__instance == null)
            {
                return true;
            }

            if (__instance.GetType().Name.IndexOf("Video", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return true;
            }

            return VideoPlaybackOnActivatePrefix(__instance);
        }

        private static bool IsCharacterCreationBootstrapActive()
        {
            if (CampaignSetupStateTracker.Phase != SetupPhase.CharacterCreation)
            {
                return false;
            }

            var stateType = CharacterCreationReflection.StateType;
            var active = GameStateManager.Current?.ActiveState;
            return stateType != null && active?.GetType() == stateType;
        }

        private static bool VideoPlaybackOnActivatePrefix(object __instance)
        {
            if (!ShouldSkipIntroVideo(null))
            {
                return true;
            }

            if (IsCharacterCreationBootstrapActive())
            {
                return true;
            }

            if (!IsSkippableVideoState(__instance))
            {
                return true;
            }

            try
            {
                CampaignSetupStateTracker.AnnounceCutsceneSkip();
                SkipCampaignIntroVideo(__instance, "OnActivate");
                return false;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] video skip failed: {ex.Message}", showInGame: false);
                return true;
            }
        }

        private static void CleanAndPushStatePostfix(GameState gameState)
        {
            if (!ShouldSkipIntroVideo(null) || gameState == null)
            {
                return;
            }

            if (CampaignSetupStateTracker.Phase == SetupPhase.CharacterCreation)
            {
                return;
            }

            if (!IsSkippableVideoState(gameState))
            {
                return;
            }

            try
            {
                CampaignSetupStateTracker.AnnounceCutsceneSkip();
                SkipCampaignIntroVideo(gameState, "CleanAndPushState");
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] CleanAndPushState video skip failed: {ex.Message}", showInGame: false);
            }
        }

        private static bool ShouldSkipIntroVideo(SandBoxGameManager instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation || !AutoCharacterCreationConfig.SkipSandboxCampaignIntro)
            {
                return false;
            }

            if (!CampaignSetupStateTracker.IsBootstrapArmed || CampaignSetupStateTracker.DevSaveLoadUsed)
            {
                return false;
            }

            if (instance != null && IsStoryModeGameManager(instance))
            {
                return false;
            }

            try
            {
                if (instance != null)
                {
                    var loadingSavedGameField = AccessTools.Field(typeof(SandBoxGameManager), "_loadingSavedGame")
                        ?? AccessTools.Field(typeof(SandBoxGameManager), "<LoadingSavedGame>k__BackingField");
                    if (loadingSavedGameField != null && (bool)loadingSavedGameField.GetValue(instance))
                    {
                        return false;
                    }
                }
            }
            catch
            {
            }

            return true;
        }

        private static bool IsSkippableVideoState(object state)
        {
            if (state == null)
            {
                return false;
            }

            var typeName = state.GetType().Name;
            if (typeName.IndexOf("Video", StringComparison.OrdinalIgnoreCase) < 0)
            {
                return false;
            }

            try
            {
                var path = AccessTools.Property(state.GetType(), "VideoPath")?.GetValue(state) as string;
                if (!string.IsNullOrEmpty(path))
                {
                    if (path.IndexOf("campaign", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return true;
                    }

                    return false;
                }
            }
            catch
            {
            }

            return CampaignSetupStateTracker.IsBootstrapArmed && !CampaignSetupStateTracker.BootstrapUsed;
        }

        private static void SkipCampaignIntroVideo(object videoState, string source)
        {
            TryMarkIntroVideoPlayed();
            _campaignIntroSkipCount++;
            GuildLog.Info(
                $"[TBG QUICKSTART] intro skip: campaign video via {source} (count={_campaignIntroSkipCount})",
                showInGame: false);
            FinishVideoState(videoState);
        }

        private static void TryMarkIntroVideoPlayed()
        {
            if (_playedIntroVideoField == null)
            {
                return;
            }

            try
            {
                if (Game.Current?.GameManager is SandBoxGameManager sandbox)
                {
                    _playedIntroVideoField.SetValue(sandbox, true);
                }
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] intro flag set failed: {ex.Message}", showInGame: false);
            }
        }

        private static void FinishVideoState(object videoState)
        {
            var onFinished = AccessTools.Method(videoState.GetType(), "OnVideoFinished");
            onFinished?.Invoke(videoState, null);
        }

        private static bool IsStoryModeGameManager(SandBoxGameManager instance)
        {
            return instance != null
                && instance.GetType().FullName?.IndexOf("StoryMode", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
