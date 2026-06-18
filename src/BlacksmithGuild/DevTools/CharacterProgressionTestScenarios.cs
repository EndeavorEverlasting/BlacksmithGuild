using BlacksmithGuild;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    public static class CharacterProgressionTestScenarios
    {
        public const string RichSmithingProgressionTestName = "RichSmithingProgressionTest";
        public const string AddSmithingXpCommand = "AddSmithingXp";
        public const string AddSmithingFocusCommand = "AddSmithingFocus";
        public const string AddEnduranceAttributeCommand = "AddEnduranceAttribute";
        public const int SmithingXpDelta = 10_000;
        public const int SmithingFocusDelta = 3;
        public const int EnduranceAttributeDelta = 1;

        public static DevCommandResult RunRichSmithingProgressionTest()
        {
            var hero = Hero.MainHero;

            DebugLogger.Test($"Scenario: {RichSmithingProgressionTestName}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "MainHero is null");
                return DevCommandResult.Failed;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            before.Log("Smithing before");

            if (!HeroProgressionDevTools.AddSmithingXp(hero, SmithingXpDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing XP.");
                ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "HeroDeveloper unavailable");
                return DevCommandResult.Failed;
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
                ForgeStatus.RecordProgressionTest(
                    true,
                    before.SmithingXpAvailable ? before.SmithingXp : 0,
                    after.SmithingXpAvailable ? after.SmithingXp : 0,
                    before.SmithingFocusAvailable ? before.SmithingFocus : 0,
                    after.SmithingFocusAvailable ? after.SmithingFocus : 0,
                    before.EnduranceAvailable ? before.Endurance : 0,
                    after.EnduranceAvailable ? after.Endurance : 0
                );
                return DevCommandResult.Success;
            }

            DebugLogger.Test("FAIL — no expected progression values changed.");
            ForgeStatus.SetTest(RichSmithingProgressionTestName, "FAIL", "No progression change detected");
            ForgeStatus.RecordProgressionTest(
                false,
                before.SmithingXpAvailable ? before.SmithingXp : 0,
                after.SmithingXpAvailable ? after.SmithingXp : 0,
                before.SmithingFocusAvailable ? before.SmithingFocus : 0,
                after.SmithingFocusAvailable ? after.SmithingFocus : 0,
                before.EnduranceAvailable ? before.Endurance : 0,
                after.EnduranceAvailable ? after.Endurance : 0
            );
            return DevCommandResult.Failed;
        }

        public static DevCommandResult RunAddSmithingXpOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {AddSmithingXpCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return DevCommandResult.Failed;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing XP before: {(before.SmithingXpAvailable ? before.SmithingXp.ToString("N0") : "unavailable")}");

            if (!HeroProgressionDevTools.AddSmithingXp(hero, SmithingXpDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing XP.");
                return DevCommandResult.Failed;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing XP added: {SmithingXpDelta:N0}");
            DebugLogger.Test($"Smithing XP after: {(after.SmithingXpAvailable ? after.SmithingXp.ToString("N0") : "unavailable")}");

            if (before.SmithingXpAvailable && after.SmithingXpAvailable && before.SmithingXp != after.SmithingXp)
            {
                DebugLogger.Test("PASS");
                return DevCommandResult.Success;
            }

            DebugLogger.Test("FAIL — smithing XP unchanged.");
            return DevCommandResult.Failed;
        }

        public static DevCommandResult RunAddSmithingFocusOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {AddSmithingFocusCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return DevCommandResult.Failed;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing focus before: {(before.SmithingFocusAvailable ? before.SmithingFocus.ToString() : "unavailable")}");

            if (!HeroProgressionDevTools.AddSmithingFocus(hero, SmithingFocusDelta))
            {
                DebugLogger.Test("FAIL — could not add smithing focus.");
                return DevCommandResult.Failed;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Smithing focus added: {SmithingFocusDelta}");
            DebugLogger.Test($"Smithing focus after: {(after.SmithingFocusAvailable ? after.SmithingFocus.ToString() : "unavailable")}");

            if (before.SmithingFocusAvailable && after.SmithingFocusAvailable &&
                before.SmithingFocus != after.SmithingFocus)
            {
                DebugLogger.Test("PASS");
                return DevCommandResult.Success;
            }

            DebugLogger.Test("FAIL — smithing focus unchanged.");
            return DevCommandResult.Failed;
        }

        public static DevCommandResult RunAddEnduranceAttributeOnly()
        {
            var hero = Hero.MainHero;
            DebugLogger.Test($"Command: {AddEnduranceAttributeCommand}");

            if (hero == null)
            {
                DebugLogger.Test("FAIL — MainHero is null.");
                return DevCommandResult.Failed;
            }

            var before = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Endurance before: {(before.EnduranceAvailable ? before.Endurance.ToString() : "unavailable")}");

            if (!HeroProgressionDevTools.AddEnduranceAttribute(hero, EnduranceAttributeDelta))
            {
                DebugLogger.Test("FAIL — could not add endurance attribute.");
                return DevCommandResult.Failed;
            }

            var after = CharacterProgressionSnapshot.Capture(hero);
            DebugLogger.Test($"Endurance attribute added: {EnduranceAttributeDelta}");
            DebugLogger.Test($"Endurance after: {(after.EnduranceAvailable ? after.Endurance.ToString() : "unavailable")}");

            if (before.EnduranceAvailable && after.EnduranceAvailable && before.Endurance != after.Endurance)
            {
                DebugLogger.Test("PASS");
                return DevCommandResult.Success;
            }

            DebugLogger.Test("FAIL — endurance unchanged.");
            return DevCommandResult.Failed;
        }
    }
}
