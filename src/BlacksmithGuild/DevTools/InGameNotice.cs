using System;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Visible feedback via Bannerlord's normal in-game message feed (lower-left log).
    /// Not the cheat/developer console.
    /// </summary>
    public static class InGameNotice
    {
        public static void Info(string message) =>
            Show(message, ReportColors.Info, ModNoticeKind.Info);

        public static void Success(string message) =>
            Show(message, ReportColors.Success, ModNoticeKind.Success);

        public static void Warn(string message) =>
            Show(message, ReportColors.Warn, ModNoticeKind.Warn);

        public static void Blocked(string message) =>
            Show(message, ReportColors.Warn, ModNoticeKind.Blocked);

        public static void Fail(string message) =>
            Show(message, ReportColors.Fail, ModNoticeKind.Fail);

        public static void Ready(string message) =>
            GuildLog.Display($"{ModDisplay.NoticePrefix(ModNoticeKind.Ready)} {message}", color: ReportColors.Success);

        private static void Show(string message, Color color, ModNoticeKind kind)
        {
            var prefix = ModDisplay.NoticePrefix(kind);
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

            if (message.StartsWith($"{ModDisplay.Name}", StringComparison.Ordinal)
                || message.StartsWith("TBG ", StringComparison.Ordinal)
                || message.StartsWith("TBG:", StringComparison.Ordinal))
            {
                return false;
            }

            return !message.StartsWith(prefix, StringComparison.Ordinal);
        }
    }
}
