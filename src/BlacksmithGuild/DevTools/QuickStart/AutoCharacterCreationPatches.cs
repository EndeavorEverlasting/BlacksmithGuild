using System;
using BlacksmithGuild.DevTools;
using HarmonyLib;
using SandBox;
using TaleWorlds.MountAndBlade;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class AutoCharacterCreationPatches
    {
        private const string HarmonyId = "com.endeavoreverlasting.blacksmithguild.quickstart";

        private static Harmony _harmony;
        private static bool _applied;
        private static bool _loggedVanillaCreationLaunch;

        public static bool TryApply()
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation && !DevToolsConfig.AutoLoadDevSave)
            {
                return false;
            }

            if (_applied)
            {
                return true;
            }

            _harmony = new Harmony(HarmonyId);
            SkipIntroVideoIfConfigured();

            var introSkipOk = SandboxCampaignIntroSkip.TryApply(_harmony);
            var launchSandboxCreationOk = TryApplyLaunchSandboxCharacterCreationPatch();
            var managerNextStageOk = TryApplyManagerNextStagePatch();
            var startNewGameOk = DevToolsConfig.AutoLoadDevSaveOnStartNewGame
                && DevToolsConfig.AutoLoadDevSave
                && DevSaveAutoLoader.TryApplyStartNewGamePatch(_harmony);

            _applied = introSkipOk || launchSandboxCreationOk || managerNextStageOk || startNewGameOk;
            if (_applied)
            {
                CampaignSetupStateTracker.ResetForNewSession();
            }

            var activeState = GameSessionState.GetActiveStateName();
            GuildLog.Info(
                $"[TBG QUICKSTART] patches: IntroSkip={(introSkipOk ? "OK" : "SKIP")} " +
                $"LaunchSandboxObserve={(launchSandboxCreationOk ? "OK" : "SKIP")} " +
                $"NextStage={(managerNextStageOk ? "OK" : "SKIP")} " +
                $"StartNewGame={(startNewGameOk ? "OK" : "SKIP")} " +
                $"characterApi={(CharacterCreationReflection.IsAvailable ? "OK" : "SKIP")} " +
                $"activeState={activeState ?? "null"}",
                showInGame: false);

            if (_applied && DevToolsConfig.AutoSkipCharacterCreation)
            {
                GuildLog.Info(
                    "[TBG QUICKSTART] Character creation automation enabled (vanilla launch + Poll stage advance).",
                    showInGame: false);
            }

            return _applied;
        }

        private static bool TryApplyLaunchSandboxCharacterCreationPatch()
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return false;
            }

            try
            {
                var target = AccessTools.Method(typeof(SandBoxGameManager), "LaunchSandboxCharacterCreation");
                if (target == null)
                {
                    return false;
                }

                var prefix = AccessTools.Method(
                    typeof(AutoCharacterCreationPatches),
                    nameof(LaunchSandboxCharacterCreationPrefix));
                _harmony.Patch(target, prefix: new HarmonyMethod(prefix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] LaunchSandboxCharacterCreation patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool TryApplyManagerNextStagePatch()
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return false;
            }

            try
            {
                var managerType = AccessTools.TypeByName("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationManager");
                var target = managerType == null ? null : AccessTools.Method(managerType, "NextStage");
                if (target == null)
                {
                    return false;
                }

                var postfix = AccessTools.Method(typeof(AutoCharacterCreationPatches), nameof(ManagerNextStagePostfix));
                _harmony.Patch(target, postfix: new HarmonyMethod(postfix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] CharacterCreationManager.NextStage patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static void SkipIntroVideoIfConfigured()
        {
            if (!AutoCharacterCreationConfig.SkipIntroVideo)
            {
                return;
            }

            try
            {
                var splashField = AccessTools.Field(typeof(Module), "_splashScreenPlayed");
                splashField?.SetValue(Module.CurrentModule, true);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] launcher splash skip failed: {ex.Message}", showInGame: false);
            }
        }

        private static void LaunchSandboxCharacterCreationPrefix(SandBoxGameManager __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation || __instance == null)
            {
                return;
            }

            try
            {
                var loadingSavedGameField = AccessTools.Field(typeof(SandBoxGameManager), "_loadingSavedGame")
                    ?? AccessTools.Field(typeof(SandBoxGameManager), "<LoadingSavedGame>k__BackingField");
                var isSaveGame = loadingSavedGameField != null
                    && (bool)loadingSavedGameField.GetValue(__instance);

                if (isSaveGame)
                {
                    CampaignSetupStateTracker.MarkDevSaveLoadIfApplicable();
                    return;
                }

                if (IsStoryModeGameManager(__instance))
                {
                    CampaignSetupStateTracker.MarkStoryModeBlocked();
                    return;
                }

                if (!_loggedVanillaCreationLaunch)
                {
                    _loggedVanillaCreationLaunch = true;
                    GuildLog.Info(
                        "[TBG QUICKSTART] using vanilla character creation launch; Poll will auto-advance stages.",
                        showInGame: false);
                }
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] LaunchSandboxCharacterCreation observe failed: {ex.Message}", showInGame: false);
            }
        }

        private static void ManagerNextStagePostfix(object __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return;
            }

            var state = TaleWorlds.Core.GameStateManager.Current?.ActiveState;
            if (state == null)
            {
                return;
            }

            if (CharacterCreationReflection.IsStoryModeContent(state))
            {
                CampaignSetupStateTracker.MarkStoryModeBlocked();
                return;
            }

            CampaignSetupStateTracker.OnCharacterCreationStage(state);
        }

        private static bool IsStoryModeGameManager(SandBoxGameManager instance)
        {
            return instance != null
                && instance.GetType().FullName?.IndexOf("StoryMode", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
