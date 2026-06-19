using System;
using BlacksmithGuild.DevTools;
using HarmonyLib;
using SandBox;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class AutoCharacterCreationPatches
    {
        private const string HarmonyId = "com.endeavoreverlasting.blacksmithguild.quickstart";

        private static Harmony _harmony;
        private static bool _applied;

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
            var onLoadFinishedOk = TryApplySandBoxOnLoadFinishedPatch();
            var launchSandboxCreationOk = TryApplyLaunchSandboxCharacterCreationPatch();
            var managerNextStageOk = TryApplyManagerNextStagePatch();
            var startNewGameOk = DevToolsConfig.AutoLoadDevSaveOnStartNewGame
                && DevToolsConfig.AutoLoadDevSave
                && DevSaveAutoLoader.TryApplyStartNewGamePatch(_harmony);

            _applied = introSkipOk || onLoadFinishedOk || launchSandboxCreationOk || managerNextStageOk || startNewGameOk;
            if (_applied)
            {
                CampaignSetupStateTracker.ResetForNewSession();
            }

            var activeState = GameSessionState.GetActiveStateName();
            GuildLog.Info(
                $"[TBG QUICKSTART] patches: IntroSkip={(introSkipOk ? "OK" : "SKIP")} " +
                $"OnLoadFinished={(onLoadFinishedOk ? "OK" : "SKIP")} " +
                $"LaunchSandboxCreation={(launchSandboxCreationOk ? "OK" : "SKIP")} " +
                $"NextStage={(managerNextStageOk ? "OK" : "SKIP")} " +
                $"StartNewGame={(startNewGameOk ? "OK" : "SKIP")} " +
                $"characterApi={(CharacterCreationReflection.IsAvailable ? "OK" : "SKIP")} " +
                $"activeState={activeState ?? "null"}",
                showInGame: false);

            if (_applied && (CharacterCreationReflection.IsAvailable || DevToolsConfig.AutoLoadDevSave))
            {
                GuildLog.Info("[TBG QUICKSTART] Character creation automation enabled.", showInGame: false);
            }

            return _applied;
        }

        private static bool TryApplySandBoxOnLoadFinishedPatch()
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return false;
            }

            try
            {
                var target = AccessTools.DeclaredMethod(typeof(SandBoxGameManager), "OnLoadFinished");
                var prefix = AccessTools.Method(typeof(AutoCharacterCreationPatches), nameof(OnLoadFinishedPrefix));
                _harmony.Patch(target, prefix: new HarmonyMethod(prefix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] OnLoadFinished patch failed: {ex.Message}", showInGame: false);
                return false;
            }
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

        private static bool OnLoadFinishedPrefix(SandBoxGameManager __instance)
        {
            return !TryAutoAdvanceSandboxSetup(__instance, "OnLoadFinished");
        }

        private static bool LaunchSandboxCharacterCreationPrefix(SandBoxGameManager __instance)
        {
            return !TryAutoAdvanceSandboxSetup(__instance, "LaunchSandboxCharacterCreation");
        }

        private static bool TryAutoAdvanceSandboxSetup(SandBoxGameManager instance, string phaseName)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return false;
            }

            try
            {
                var loadingSavedGameField = AccessTools.Field(typeof(SandBoxGameManager), "_loadingSavedGame")
                    ?? AccessTools.Field(typeof(SandBoxGameManager), "<LoadingSavedGame>k__BackingField");
                var isSaveGame = loadingSavedGameField != null
                    && (bool)loadingSavedGameField.GetValue(instance);

                if (isSaveGame)
                {
                    CampaignSetupStateTracker.MarkDevSaveLoadIfApplicable();
                    return false;
                }

                if (IsStoryModeGameManager(instance))
                {
                    CampaignSetupStateTracker.MarkStoryModeBlocked();
                    return false;
                }

                if (!CharacterCreationReflection.IsAvailable)
                {
                    GuildLog.Info(
                        $"[TBG QUICKSTART] {phaseName}: character API unavailable — vanilla path.",
                        showInGame: false);
                    GuildLog.Display($"TBG QUICKSTART: setup stalled at {phaseName} — see Phase1.log");
                    return false;
                }

                AccessTools.DeclaredProperty(typeof(MBGameManager), "IsLoaded")?.SetValue(instance, true);

                var content = CreateSandboxCharacterCreationContent();
                if (content == null)
                {
                    GuildLog.Info(
                        $"[TBG QUICKSTART] {phaseName}: could not create character creation content — vanilla path.",
                        showInGame: false);
                    GuildLog.Display($"TBG QUICKSTART: setup stalled at {phaseName} — see Phase1.log");
                    return false;
                }

                var stateType = CharacterCreationReflection.StateType;
                var createState = AccessTools.Method(typeof(GameStateManager), "CreateState", new[] { typeof(object[]) });
                if (createState == null)
                {
                    createState = AccessTools.Method(typeof(GameStateManager), "CreateState");
                }

                object gameState;
                if (createState != null && createState.IsGenericMethodDefinition)
                {
                    gameState = createState.MakeGenericMethod(stateType).Invoke(
                        Game.Current.GameStateManager,
                        new object[] { new object[] { content } }
                    );
                }
                else
                {
                    gameState = createState?.Invoke(
                        Game.Current.GameStateManager,
                        new object[] { stateType, new object[] { content } }
                    );
                }

                if (gameState == null)
                {
                    GuildLog.Info(
                        $"[TBG QUICKSTART] {phaseName}: could not create character creation state — vanilla path.",
                        showInGame: false);
                    GuildLog.Display($"TBG QUICKSTART: setup stalled at {phaseName} — see Phase1.log");
                    return false;
                }

                Game.Current.GameStateManager.CleanAndPushState((GameState)gameState, 0);

                CampaignSetupStateTracker.MarkSandboxBootstrapStarted();
                CampaignSetupStateTracker.OnCharacterCreationStage(gameState);

                GuildLog.Info($"[TBG QUICKSTART] {phaseName}: character creation skipped — auto-advancing.", showInGame: false);
                GuildLog.Display("TBG QUICKSTART: auto-advancing character creation.");
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] {phaseName} prefix failed: {ex.Message}", showInGame: false);
                GuildLog.Display($"TBG QUICKSTART: setup stalled at {phaseName} — see Phase1.log");
                return false;
            }
        }

        private static void ManagerNextStagePostfix(object __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return;
            }

            var state = GameStateManager.Current?.ActiveState;
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

        private static object CreateSandboxCharacterCreationContent()
        {
            var contentType = AccessTools.TypeByName("SandBox.SandboxCharacterCreationContent")
                ?? AccessTools.TypeByName("SandboxCharacterCreationContent");

            if (contentType == null)
            {
                return null;
            }

            return Activator.CreateInstance(contentType);
        }

        private static bool IsStoryModeGameManager(SandBoxGameManager instance)
        {
            return instance != null
                && instance.GetType().FullName?.IndexOf("StoryMode", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
