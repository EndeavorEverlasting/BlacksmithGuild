using BlacksmithGuild.DevTools.AutoCharacterBuild;

namespace BlacksmithGuild.DevTools
{
    public static class DevToolsConfig
    {
        public static bool DevToolsEnabled = true;
        public const bool AutoRunGoldTestOnDailyTick = false;
        public static bool AutoSkipCharacterCreation = true;
        public static bool AutoLaunchFromMainMenu = true;
        public static bool AutoLoadDevSave = true;
        public static bool AutoLoadDevSaveOnStartNewGame = false;
        public static CharacterLegitimacyMode LegitimacyMode = CharacterLegitimacyMode.VanillaLegit;
        public static bool AssistiveMode = true;
        public static bool CharacterCreationVisibleMode = true;
        public static int CharacterCreationDecisionPauseMs = 750;
        public static bool AutoApplyCharacterBuild = false;
        public static bool CharacterBuildCatalogMode = false;
        public static string CharacterBuildTestSavePrefix = "BSG_ASR_TEST_";
        public static bool HotkeyTraceEnabled = true;
        public static bool HotkeyTraceVisibleKeys = false;
        public static bool LegacyF12MarketHotkey = false;

        public static bool AgentAutoLoop = false;
        public static bool TavernHeroVisibleMode = true;
        public static int TavernHeroDecisionPauseMs = 750;
        public static int TavernHeroSafeGoldReserve = 500;
        public static int TavernHeroMaxRecruitmentsPerCommand = 1;
        public static bool TavernHeroAllowDirectInjection = false;
        public static bool TavernHeroRequireDisposableSaveForRecruit = true;
    }
}

