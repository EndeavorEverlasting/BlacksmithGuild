using System;
using System.IO;
using TaleWorlds.Library;

namespace BlacksmithGuild
{
    public static class GuildLog
    {
        private static readonly string LogPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Phase1.log");

        public static void Info(string message, bool showInGame = true)
        {
            try
            {
                File.AppendAllText(
                    LogPath,
                    $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}{Environment.NewLine}"
                );
            }
            catch
            {
                // Do not crash the game because our log failed.
            }

            if (showInGame)
            {
                InformationManager.DisplayMessage(
                    new InformationMessage($"BlacksmithGuild: {message}")
                );
            }
        }
    }
}
