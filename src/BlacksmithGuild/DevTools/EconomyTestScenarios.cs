using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class EconomyTestScenarios
    {
        public const string RichPlayerEconomyTestName = "RichPlayerEconomyTest";
        public const int RichPlayerGoldDelta = 100_000;

        public static DevCommandResult RunRichPlayerEconomyTest()
        {
            Hero hero;
            try
            {
                hero = Hero.MainHero;
            }
            catch
            {
                hero = null;
            }

            if (hero == null)
            {
                DebugLogger.Test("Scenario: RichPlayerEconomyTest");
                DebugLogger.Test("FAIL — MainHero is null.");
                ForgeStatus.SetTest(RichPlayerEconomyTestName, "FAIL", "MainHero is null");
                return DevCommandResult.Failed;
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
                ForgeStatus.SetTest(RichPlayerEconomyTestName, "PASS");
                ForgeStatus.RecordGoldTest(true, goldBefore, goldAfter, actualDelta);
                return DevCommandResult.Success;
            }

            var message = $"expected delta {goldDelta:N0}, actual delta {actualDelta:N0}";
            DebugLogger.Test($"FAIL — {message}.");
            ForgeStatus.SetTest(RichPlayerEconomyTestName, "FAIL", message);
            ForgeStatus.RecordGoldTest(false, goldBefore, goldAfter, actualDelta);
            return DevCommandResult.Failed;
        }
    }
}
