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
            if (!DevToolsConfig.AutoSkipCharacterCreation || _applied)
            {
                return _applied;
            }

            try
            {
                if (!CharacterCreationReflection.IsAvailable)
                {
                    GuildLog.Info("[TBG QUICKSTART] CharacterCreationState API not found — intro skip only.", showInGame: false);
                }

                _harmony = new Harmony(HarmonyId);
                ApplySandBoxGameManagerPatch();
                ApplyCharacterCreationStatePatch();
                SkipIntroVideoIfConfigured();
                _applied = true;
                CampaignSetupStateTracker.ResetForNewSession();
                GuildLog.Info("[TBG QUICKSTART] Character creation automation enabled.", showInGame: false);
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] patch apply failed: {ex.Message}", showInGame: false);
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

        private static void ApplySandBoxGameManagerPatch()
        {
            var target = AccessTools.Method(typeof(SandBoxGameManager), "OnLoadFinished");
            var prefix = AccessTools.Method(typeof(AutoCharacterCreationPatches), nameof(OnLoadFinishedPrefix));
            _harmony.Patch(target, prefix: new HarmonyMethod(prefix));
        }

        private static void ApplyCharacterCreationStatePatch()
        {
            var stateType = CharacterCreationReflection.StateType;
            if (stateType == null)
            {
                return;
            }

            var target = AccessTools.DeclaredMethod(stateType, "NextStage");
            var postfix = AccessTools.Method(typeof(AutoCharacterCreationPatches), nameof(NextStagePostfix));
            _harmony.Patch(target, postfix: new HarmonyMethod(postfix));
        }

        private static bool OnLoadFinishedPrefix(SandBoxGameManager __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation || !CharacterCreationReflection.IsAvailable)
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
                    return true;
                }

                if (IsStoryModeGameManager(__instance))
                {
                    CampaignSetupStateTracker.MarkStoryModeBlocked();
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

                CampaignSetupStateTracker.MarkSandboxSetupStarted();
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

        private static void NextStagePostfix(object __instance)
        {
            if (!DevToolsConfig.AutoSkipCharacterCreation)
            {
                return;
            }

            if (CharacterCreationReflection.IsStoryModeContent(__instance))
            {
                CampaignSetupStateTracker.MarkStoryModeBlocked();
                return;
            }

            CampaignSetupStateTracker.OnCharacterCreationStage(__instance);
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
