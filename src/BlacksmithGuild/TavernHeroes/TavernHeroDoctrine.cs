namespace BlacksmithGuild.TavernHeroes
{
    public enum TavernHeroDoctrineKind
    {
        SmithingCrew,
        ScoutQuartermaster,
        CombatEscort
    }

    public static class TavernHeroDoctrine
    {
        public const string SetSmithingCrewCommand = "SetTavernHeroDoctrineSmithingCrew";
        public const string SetScoutQuartermasterCommand = "SetTavernHeroDoctrineScoutQuartermaster";
        public const string SetCombatEscortCommand = "SetTavernHeroDoctrineCombatEscort";

        public static TavernHeroDoctrineKind ActiveDoctrine { get; private set; } = TavernHeroDoctrineKind.SmithingCrew;

        public static bool SetDoctrine(TavernHeroDoctrineKind kind)
        {
            ActiveDoctrine = kind;
            return true;
        }

        public static string GetDoctrineLabel()
        {
            switch (ActiveDoctrine)
            {
                case TavernHeroDoctrineKind.ScoutQuartermaster:
                    return "ScoutQuartermaster";
                case TavernHeroDoctrineKind.CombatEscort:
                    return "CombatEscort";
                default:
                    return "SmithingCrew";
            }
        }
    }
}
