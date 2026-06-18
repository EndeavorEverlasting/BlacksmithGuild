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

            var onLoadFinishedOk = TryApplySandBoxOnLoadFinishedPatch();
            var managerNextStageOk = TryApplyManagerNextStagePatch();
            var startNewGameOk = DevToolsConfig.AutoLoadDevSave && DevSaveAutoLoader.TryApplyStartNewGamePatch(_harmony);

            _applied = onLoadFinishedOk || managerNextStageOk || startNewGameOk;
            if (_applied)
            {
                CampaignSetupStateTracker.ResetForNewSession();
            }

            GuildLog.Info(
                $"[TBG QUICKSTART] patches: OnLoadFinished={(onLoadFinishedOk ? "OK" : "SKIP")} " +
                $"NextStage={(managerNextStageOk ? "OK" : "SKIP")} " +
                $"StartNewGame={(startNewGameOk ? "OK" : "SKIP")} " +
                $"characterApi={(CharacterCreationReflection.IsAvailable ? "OK" : "SKIP")}",
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
                GuildLog.Info($"[TBG QUICKSTART] intro skip failed: {ex.Message}", showInGame: false);
            }
        }

        private static bool OnLoadFinishedPrefix(SandBoxGameManager __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return true;
            }

            try
            {
                var loadingSavedGameField = AccessTools.Field(typeof(SandBoxGameManager), "_loadingSavedGame");
                var isSaveGame = loadingSavedGameField != null
                    && (bool)loadingSavedGameField.GetValue(__instance);

                if (isSaveGame)
                {
                    CampaignSetupStateTracker.MarkDevSaveLoadIfApplicable();
                    return true;
                }

                if (IsStoryModeGameManager(__instance))
                {
                    CampaignSetupStateTracker.MarkStoryModeBlocked();
                    return true;
                }

                if (!CharacterCreationReflection.IsAvailable)
                {
                    return true;
                }

                AccessTools.DeclaredProperty(typeof(MBGameManager), "IsLoaded")?.SetValue(__instance, true);

                var content = CreateSandboxCharacterCreationContent();
                if (content == null)
                {
                    GuildLog.Info("[TBG QUICKSTART] could not create character creation content — vanilla path.", showInGame: false);
                    return true;
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
                    GuildLog.Info("[TBG QUICKSTART] could not create character creation state — vanilla path.", showInGame: false);
                    return true;
                }

                Game.Current.GameStateManager.CleanAndPushState((GameState)gameState, 0);

                CampaignSetupStateTracker.MarkSandboxBootstrapStarted();
                CampaignSetupStateTracker.OnCharacterCreationStage(gameState);

                GuildLog.Info("[TBG QUICKSTART] Character creation skipped — auto-advancing.", showInGame: false);
                return false;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] OnLoadFinished prefix failed: {ex.Message}", showInGame: false);
                return true;
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
