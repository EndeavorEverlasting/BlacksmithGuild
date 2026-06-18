namespace BlacksmithGuild.DevTools
{
    public static class DevCommandRunner
    {
        public static void Run(string commandName)
        {
            DevCommandBus.TryRun(commandName, "legacy");
        }
    }
}
