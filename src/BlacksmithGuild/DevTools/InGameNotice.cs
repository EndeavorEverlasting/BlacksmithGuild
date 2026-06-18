namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Visible feedback via Bannerlord's normal in-game message feed (lower-left log).
    /// Not the cheat/developer console.
    /// </summary>
    public static class InGameNotice
    {
        public static void Info(string message) => GuildLog.Display(message);

        public static void Success(string message) => GuildLog.Display(message);

        public static void Warn(string message) => GuildLog.Display(message);

        public static void Blocked(string message) => GuildLog.Display(message);

        public static void Fail(string message) => GuildLog.Display(message);
    }
}
