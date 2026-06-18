using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class EconomyTestScenarios
    {
        public const string RichPlayerEconomyTestName = "RichPlayerEconomyTest";
        public const int RichPlayerGoldDelta = 100_000;

        public static void RunRichPlayerEconomyTest()
        {
            var hero = Hero.MainHero;

            if (hero == null)
            {
                DebugLogger.Test("Scenario: RichPlayerEconomyTest");
                DebugLogger.Test("FAIL — MainHero is null.");
                return;
            }

            int goldBefore = hero.Gold;
            int goldDelta = RichPlayerGoldDelta;

            DebugLogger.Test($"Scenario: {RichPlayerEconomyTestName}");
            DebugLogger.Test($"Gold before: {goldBefore:N0}");

            hero.ChangeHeroGold(goldDelta);

            int goldAfter = hero.Gold;
            int actualDelta = goldAfter - goldBefore;

            DebugLogger.Test($"Gold added: {goldDelta:N0}");
            DebugLogger.Test($"Gold after: {goldAfter:N0}");

            if (actualDelta == goldDelta)
            {
                DebugLogger.Test("PASS");
            }
            else
            {
                DebugLogger.Test(
                    $"FAIL — expected delta {goldDelta:N0}, actual delta {actualDelta:N0}."
                );
            }
        }
    }
}
