using System;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Visible feedback via Bannerlord's normal in-game message feed (lower-left log).
    /// Not the cheat/developer console.
    /// </summary>
    public static class InGameNotice
    {
        private static readonly Color InfoColor = new Color(0.9f, 0.9f, 0.9f, 1f);
        private static readonly Color SuccessColor = new Color(0.2f, 1f, 0.2f, 1f);
        private static readonly Color WarnColor = new Color(1f, 0.75f, 0f, 1f);
        private static readonly Color BlockedColor = new Color(1f, 0.75f, 0f, 1f);
        private static readonly Color FailColor = new Color(1f, 0.2f, 0.2f, 1f);

        public static void Info(string message) =>
            Show(message, InfoColor, "TBG NOTICE:");

        public static void Success(string message) =>
            Show(message, SuccessColor, "TBG SUCCESS:");

        public static void Warn(string message) =>
            Show(message, WarnColor, "TBG WARN:");

        public static void Blocked(string message) =>
            Show(message, BlockedColor, "TBG BLOCKED:");

        public static void Fail(string message) =>
            Show(message, FailColor, "TBG FAILED:");

        public static void Ready(string message) =>
            GuildLog.Display($"TBG READY: {message}", color: SuccessColor);

        private static void Show(string message, Color color, string prefix)
        {
            if (ShouldUsePrefix(message, prefix))
            {
                GuildLog.Display($"{prefix} {message}", color: color);
                return;
            }

            GuildLog.Display(message, color: color);
        }

        private static bool ShouldUsePrefix(string message, string prefix)
        {
            if (string.IsNullOrEmpty(message))
            {
                return true;
            }

            if (message.StartsWith("TBG ", StringComparison.Ordinal) ||
                message.StartsWith("TBG:", StringComparison.Ordinal))
            {
                return false;
            }

            return !message.StartsWith(prefix, StringComparison.Ordinal);
        }
    }
}
