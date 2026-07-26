using System;
using System.Linq;
using TaleWorlds.Core;
using TaleWorlds.SaveSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class DevSaveResolver
    {
        public const string DevSavePrefix = "BlacksmithGuild_DevStart";
        public const string LegacyDevSaveName = "BlacksmithGuildDevStart";

        public static bool TryGetLatest(out SaveGameFileInfo saveInfo)
        {
            saveInfo = null;

            try
            {
                var candidates = MBSaveLoad.GetSaveFiles(info =>
                        info != null
                        && !string.IsNullOrEmpty(info.Name)
                        && IsDisposableSaveName(info.Name))
                    .OrderByDescending(info => info.Name, StringComparer.OrdinalIgnoreCase)
                    .ToList();

                if (candidates.Count == 0)
                {
                    var names = MBSaveLoad.GetSaveFileNames()
                    ?.Where(IsDisposableSaveName)
                        .OrderByDescending(name => name, StringComparer.OrdinalIgnoreCase)
                        .ToList();

                    if (names == null || names.Count == 0)
                    {
                        return false;
                    }

                    saveInfo = MBSaveLoad.GetSaveFileWithName(names[0]);
                    return saveInfo != null;
                }

                saveInfo = candidates[0];
                return saveInfo != null;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] dev save lookup failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool TryGetUnique(out SaveGameFileInfo saveInfo)
        {
            saveInfo = null;

            try
            {
                var candidates = MBSaveLoad.GetSaveFiles(info =>
                        info != null
                        && !string.IsNullOrEmpty(info.Name)
                        && IsDisposableSaveName(info.Name))
                    .ToList();

                if (candidates.Count > 1)
                {
                    GuildLog.Info(
                        $"[TBG QUICKSTART] dev save auto-load blocked: expected one {DevSavePrefix}* save, found {candidates.Count}.",
                        showInGame: false);
                    return false;
                }

                if (candidates.Count == 1)
                {
                    saveInfo = candidates[0];
                    return true;
                }

                var names = MBSaveLoad.GetSaveFileNames()
                        ?.Where(IsDisposableSaveName)
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .ToList();

                if (names == null || names.Count != 1)
                {
                    if (names != null && names.Count > 1)
                    {
                        GuildLog.Info(
                            $"[TBG QUICKSTART] dev save auto-load blocked: expected one {DevSavePrefix}* save, found {names.Count}.",
                            showInGame: false);
                    }

                    return false;
                }

                saveInfo = MBSaveLoad.GetSaveFileWithName(names[0]);
                return saveInfo != null;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] unique dev save lookup failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool IsDisposableSaveName(string saveName)
        {
            return !string.IsNullOrWhiteSpace(saveName)
                && (saveName.StartsWith(DevSavePrefix, StringComparison.OrdinalIgnoreCase)
                    || string.Equals(
                        saveName,
                        LegacyDevSaveName,
                        StringComparison.OrdinalIgnoreCase));
        }
    }
}
