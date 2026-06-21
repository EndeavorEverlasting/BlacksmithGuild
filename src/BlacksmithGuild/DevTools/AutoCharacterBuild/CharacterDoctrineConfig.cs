using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterDoctrineConfig
    {
        public const string DefaultBuildId = "AseraiTradeSmith";

        public static CharacterLegitimacyMode LegitimacyMode => DevToolsConfig.LegitimacyMode;

        public static bool AssistiveMode => DevToolsConfig.AssistiveMode;

        public static string PreferredCultureId => "aserai";

        public static IReadOnlyList<string> FallbackCultureIds { get; } = new[]
        {
            "khuzait",
            "empire",
            "vlandia",
            "battania",
            "sturgia"
        };

        public static IReadOnlyList<string> PrimaryAxis { get; } = new[]
        {
            "Trade",
            "Smithing",
            "Riding"
        };

        public static IReadOnlyList<string> SecondaryAxis { get; } = new[]
        {
            "Steward",
            "Charm",
            "Leadership"
        };

        public static IReadOnlyList<string> CombatSupport { get; } = new[]
        {
            "Bow",
            "Polearm"
        };

        public static IReadOnlyList<string> EconomicDoctrine { get; } = new[]
        {
            "Caravans",
            "TownTrade",
            "Hardwood",
            "Charcoal",
            "Ore"
        };

        public static bool PostMapProfileApplyEnabled =>
            LegitimacyMode == CharacterLegitimacyMode.DevOverride && DevToolsConfig.AutoApplyCharacterBuild;
    }
}
