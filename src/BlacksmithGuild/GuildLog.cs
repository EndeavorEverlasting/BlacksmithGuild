using System;
using System.IO;
using TaleWorlds.Library;

namespace BlacksmithGuild
{
    public static class GuildLog
    {
        private static readonly string LogPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Phase1.log");

        public static void Display(string message, bool showInGame = true, Color? color = null)
        {
            WriteToFile(message);

            if (showInGame)
            {
                if (color.HasValue)
                {
                    InformationManager.DisplayMessage(new InformationMessage(message, color.Value));
                }
                else
                {
                    InformationManager.DisplayMessage(new InformationMessage(message));
                }
            }
        }

        public static void Info(string message, bool showInGame = true)
        {
            WriteToFile(message);

            if (showInGame)
            {
                InformationManager.DisplayMessage(
                    new InformationMessage($"BlacksmithGuild: {message}")
                );
            }
        }

        private static void WriteToFile(string message)
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
        }
    }
}
