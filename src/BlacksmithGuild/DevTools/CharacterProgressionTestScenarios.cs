using BlacksmithGuild;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class CharacterProgressionTestScenarios
    {
        public const string RichSmithingProgressionTestName = "RichSmithingProgressionTest";
        public const int SmithingXpDelta = 10_000;
        public const int SmithingFocusDelta = 3;
        public const int EnduranceAttributeDelta = 1;

        public static void RunRichSmithingProgressionTest()
        {
            var hero = Hero.MainHero;

            DebugLogger.Test($"Scenario: {RichSmithingProgressionTestName}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "MainHero is null");
                return;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            before.Log("Smithing before");

            if (!HeroProgressionDevTools.AddSmithingXp(hero, SmithingXpDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing XP.");
                ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "HeroDeveloper unavailable");
                return;
            }

            DebugLogger.Test($"Smithing XP added: {SmithingXpDelta:N0}");

            if (!HeroProgressionDevTools.AddSmithingFocus(hero, SmithingFocusDelta))
            {
                DebugLogger.Test("WARN — could not add smithing focus.");
            }
            else
            {
                DebugLogger.Test($"Smithing focus added: {SmithingFocusDelta}");
            }

            if (!HeroProgressionDevTools.AddEnduranceAttribute(hero, EnduranceAttributeDelta))
            {
                DebugLogger.Test("WARN — could not add endurance attribute.");
            }
            else
            {
                DebugLogger.Test($"Endurance attribute added: {EnduranceAttributeDelta}");
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            after.Log("Smithing after");

            if (before.AnyProgressionChanged(after))
            {
                DebugLogger.Test("PASS");
                ForgeStatus.SetTest(RichSmithingProgressionTestName, "PASS");
                return;
            }

            DebugLogger.Test("FAIL — no expected progression values changed.");
            ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "No progression change detected");
        }

        public static void RunAddSmithingXpOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {DevCommandRegistry.AddSmithingXpCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing XP before: {(before.SmithingXpAvailable ? before.SmithingXp.ToString("N0") : "unavailable")}");

            if (!HeroProgressionDevTools.AddSmithingXp(hero, SmithingXpDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing XP.");
                return;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing XP added: {SmithingXpDelta:N0}");
            DebugLogger.Test($"Smithing XP after: {(after.SmithingXpAvailable ? after.SmithingXp.ToString("N0") : "unavailable")}");
            DebugLogger.Test(before.SmithingXp != after.SmithingXp ? "PASS" : "FAIL — smithing XP unchanged.");
        }

        public static void RunAddSmithingFocusOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {DevCommandRegistry.AddSmithingFocusCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing focus before: {(before.SmithingFocusAvailable ? before.SmithingFocus.ToString() : "unavailable")}");

            if (!HeroProgressionDevTools.AddSmithingFocus(hero, SmithingFocusDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing focus.");
                return;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing focus added: {SmithingFocusDelta}");
            DebugLogger.Test($"Smithing focus after: {(after.SmithingFocusAvailable ? after.SmithingFocus.ToString() : "unavailable")}");
            DebugLogger.Test(before.SmithingFocus != after.SmithingFocus ? "PASS" : "FAIL — smithing focus unchanged.");
        }

        public static void RunAddEnduranceAttributeOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {DevCommandRegistry.AddEnduranceAttributeCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Endurance before: {(before.EnduranceAvailable ? before.Endurance.ToString() : "unavailable")}");

            if (!HeroProgressionDevTools.AddEnduranceAttribute(hero, EnduranceAttributeDelta))
            {
                DebugLogger.Test("FAIL — could not add endurance attribute.");
                return;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Endurance attribute added: {EnduranceAttributeDelta}");
            DebugLogger.Test($"Endurance after: {(after.EnduranceAvailable ? after.Endurance.ToString() : "unavailable")}");
            DebugLogger.Test(before.Endurance != after.Endurance ? "PASS" : "FAIL — endurance unchanged.");
        }
    }
}
