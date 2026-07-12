using System;
using System.Linq;
using TaleWorlds.Core;
using TaleWorlds.SaveSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class DevSaveResolver
    {
        public const string DevSavePrefix = "BlacksmithGuild_DevStart";
        public const string FlatDevSavePrefix = "BlacksmithGuildDevStart";

        public static bool IsApprovedDevSaveName(string name)
        {
            return !string.IsNullOrWhiteSpace(name)
                && (name.StartsWith(DevSavePrefix, StringComparison.OrdinalIgnoreCase)
                    || name.StartsWith(FlatDevSavePrefix, StringComparison.OrdinalIgnoreCase));
        }

        public static bool TryGetExactApproved(string requestedSaveId, out SaveGameFileInfo saveInfo)
        {
            saveInfo = null;
            if (!IsApprovedDevSaveName(requestedSaveId))
            {
                return false;
            }

            try
            {
                var exact = MBSaveLoad.GetSaveFileWithName(requestedSaveId);
                if (exact != null
                    && string.Equals(exact.Name, requestedSaveId, StringComparison.OrdinalIgnoreCase))
                {
                    saveInfo = exact;
                    return true;
                }

                saveInfo = MBSaveLoad.GetSaveFiles(info =>
                        info != null
                        && string.Equals(info.Name, requestedSaveId, StringComparison.OrdinalIgnoreCase))
                    .FirstOrDefault();
                return saveInfo != null;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] exact dev save lookup failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool TryGetLatest(out SaveGameFileInfo saveInfo)
        {
            saveInfo = null;

            try
            {
                var candidates = MBSaveLoad.GetSaveFiles(info =>
                        info != null
                        && IsApprovedDevSaveName(info.Name))
                    .OrderByDescending(info => info.Name, StringComparer.OrdinalIgnoreCase)
                    .ToList();

                if (candidates.Count == 0)
                {
                    var names = MBSaveLoad.GetSaveFileNames()
                        ?.Where(IsApprovedDevSaveName)
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
    }
}
