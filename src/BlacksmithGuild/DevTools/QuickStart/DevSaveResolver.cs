using System;
using System.Linq;
using TaleWorlds.Core;
using TaleWorlds.SaveSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class DevSaveResolver
    {
        public const string DevSavePrefix = "BlacksmithGuild_DevStart";

        public static bool TryGetLatest(out SaveGameFileInfo saveInfo)
        {
            saveInfo = null;

            try
            {
                var candidates = MBSaveLoad.GetSaveFiles(info =>
                        info != null
                        && !string.IsNullOrEmpty(info.Name)
                        && info.Name.StartsWith(DevSavePrefix, StringComparison.OrdinalIgnoreCase))
                    .OrderByDescending(info => info.Name, StringComparer.OrdinalIgnoreCase)
                    .ToList();

                if (candidates.Count == 0)
                {
                    var names = MBSaveLoad.GetSaveFileNames()
                        ?.Where(name => name.StartsWith(DevSavePrefix, StringComparison.OrdinalIgnoreCase))
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
