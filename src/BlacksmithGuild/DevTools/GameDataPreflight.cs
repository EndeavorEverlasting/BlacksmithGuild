namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Backward-compatible alias for <see cref="GameReadinessService"/>.
    /// </summary>
    public static class GameDataPreflight
    {
        public static PreflightVerdict Verdict => GameReadinessService.Verdict;

        public static string BlockReason => GameReadinessService.BlockReason;

        public static bool BlocksRiskyDevTools => GameReadinessService.Verdict == PreflightVerdict.Fail;

        public static bool HasCompleted => GameReadinessService.HasCompletedPreflight;

        public static void RunOnce()
        {
            GameReadinessService.RunPreflightWhenReady();
        }
    }
}
