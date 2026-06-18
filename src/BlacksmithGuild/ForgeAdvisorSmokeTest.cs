using BlacksmithGuild.Forge;

namespace BlacksmithGuild
{
    public static class ForgeAdvisorSmokeTest
    {
        public static void Run()
        {
            GuildLog.Info("campaign detected. Running Phase 1 fake forge advisor.");

            if (ForgeRecommendationService.RunRankNow(source: "campaign-smoke"))
            {
                var summary = ForgeRecommendationService.Summary;
                GuildLog.Info(
                    $"Top fake candidate: {summary.TopCandidateName} | Score {summary.TopFinalScore:0} | source={summary.Source}"
                );
            }
            else
            {
                GuildLog.Info("No fake candidates found.");
            }
        }
    }
}
