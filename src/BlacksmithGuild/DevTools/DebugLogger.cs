namespace BlacksmithGuild.DevTools
{
    public static class DebugLogger
    {
        public static void Test(string message, bool showInGame = false)
        {
            GuildLog.Info($"[TBG TEST] {message}", showInGame);
        }
    }
}
