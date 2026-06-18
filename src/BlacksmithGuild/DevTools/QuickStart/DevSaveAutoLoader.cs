using System;
using HarmonyLib;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;
using TaleWorlds.SaveSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class DevSaveAutoLoader
    {
        public static bool TryLoad(SaveGameFileInfo saveInfo)
        {
            if (saveInfo == null)
            {
                return false;
            }

            try
            {
                var loadResult = MBSaveLoad.LoadSaveGameData(saveInfo.Name);
                if (loadResult == null)
                {
                    GuildLog.Info($"[TBG QUICKSTART] dev save '{saveInfo.Name}' could not be loaded.", showInGame: false);
                    return false;
                }

                MBSaveLoad.OnStartGame(loadResult);
                CampaignSetupStateTracker.MarkDevSaveLoadStarted(saveInfo.Name);
                GuildLog.Info($"[TBG QUICKSTART] auto-loading dev save '{saveInfo.Name}'.", showInGame: false);
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] dev save auto-load failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool TryApplyStartNewGamePatch(Harmony harmony)
        {
            try
            {
                var target = AccessTools.Method(typeof(MBGameManager), "StartNewGame", new[] { typeof(MBGameManager) });
                if (target == null)
                {
                    GuildLog.Info("[TBG QUICKSTART] MBGameManager.StartNewGame patch target missing.", showInGame: false);
                    return false;
                }

                var prefix = AccessTools.Method(typeof(DevSaveAutoLoader), nameof(StartNewGamePrefix));
                harmony.Patch(target, prefix: new HarmonyMethod(prefix));
                return true;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] StartNewGame patch failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool StartNewGamePrefix(MBGameManager gameLoader)
        {
            if (!DevToolsConfig.AutoLoadDevSave || gameLoader == null)
            {
                return true;
            }

            if (IsStoryModeGameManager(gameLoader))
            {
                return true;
            }

            if (!DevSaveResolver.TryGetLatest(out var saveInfo))
            {
                return true;
            }

            return !TryLoad(saveInfo);
        }

        private static bool IsStoryModeGameManager(MBGameManager instance)
        {
            return instance.GetType().FullName?.IndexOf("StoryMode", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
