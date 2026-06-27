using System;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools.AutoCharacterBuild;

namespace BlacksmithGuild.DevTools
{
    public static class DevToolsConfig
    {
        public static bool DevToolsEnabled = true;

        /// <summary>When true, forge smoke / treasury / character-build hooks run on the tick after map-ready.</summary>
        public static bool MapReadyDeferHeavyHooks = true;

        /// <summary>Bisect mask; override with env TBG_MAP_READY_HOOK_MASK (hex, e.g. 0x1FF).</summary>
        public static MapReadyHookFlags MapReadyHookMask = MapReadyHookFlags.All;

        public static void TryLoadMapReadyBisectFromEnvironment()
        {
            var raw = Environment.GetEnvironmentVariable("TBG_MAP_READY_HOOK_MASK");
            if (string.IsNullOrWhiteSpace(raw))
            {
                return;
            }

            raw = raw.Trim();
            if (raw.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
            {
                raw = raw.Substring(2);
            }

            if (int.TryParse(raw, System.Globalization.NumberStyles.HexNumber, null, out var hexValue))
            {
                MapReadyHookMask = (MapReadyHookFlags)hexValue;
                return;
            }

            if (Enum.TryParse(raw, true, out MapReadyHookFlags named))
            {
                MapReadyHookMask = named;
            }
        }
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

        public static bool MapTradeAutonomousMode = true;
        public static bool MapTradeVisibleMode = true;
        public static int MapTradeDecisionPauseMs = 500;
        public static int MapTradeMaxTradeHops = 3;
        public static int MapTradeMaxItemTypesPerHop = 2;
        public static float MapTradeMaxTravelDurationHours = 72f;
        public static float MapTradeMaxRouteDistance = 160f;
        public static int MapTradeSafeGoldReserve = 500;
        public static int MapTradeMaxGoldSpendPercent = 50;
        public static int MapTradeTargetCapacityBufferPercent = 25;
        public static bool MapTradePreferSmithingInputs = true;
        public static bool MapTradeAllowMaterialProcurementAtSmallLoss = true;
        public static int MapTradeMaxMaterialProcurementLoss = 150;
        public static int MapTradeMinimumProfitForNonSmithingTrade = 25;
        public static bool MapTradeUseArmyPressureWindows = true;
        public static bool MapTradeAllowLikelyArmyWindows = true;
        public static bool MapTradeUseTacticalConvergence = true;
        public static bool MapTradeConvergenceStrictSafety = false;
        public static float MapTradeMinimumStrengthRatioToEngage = 1.05f;
        public static float MapTradeMinimumStrengthRatioToHold = 0.85f;
        public static float MapTradeMaxConvergenceWindowHours = 8f;
        public static float MapTradeMaxRendezvousDistance = 35f;
        public static float MapTradeAvoidHostileRadius = 14f;
        public static float MapTradeAbortHostileRadius = 6f;
        public static float MapTradeArmyPressureScanRadius = 30f;
        public static float MapTradeMinimumProtectorStrengthRatio = 1.75f;
        public static bool MapTradeAllowWaitForSafetyWindow = true;
        public static float MapTradeMaxWaitForSafetyWindowHours = 8f;
        public static bool MapTradeAllowDuckIntoTown = true;
        public static bool MapTradeAllowReroute = true;
        public static bool MapTradeAllowReturnToOrigin = true;
        public static bool MapTradeAllowDirectInventoryMutation = false;
        public static bool MapTradeAllowDirectGoldMutation = false;
        public static bool MapTradeAllowTeleport = false;
        public static bool MapTradeAutoRunForgeHandoff = true;

        public static float CohesionMinimumEngageRatio = 1.05f;
        public static float CohesionMinimumSurvivalRatio = 0.85f;
        public static float CohesionMinimumShadowRatio = 0.50f;
        public static float CohesionMaxWindowHours = 8f;
        public static float CohesionMaxRallyDistance = 35f;
        public static float CohesionMinEscapeMarginHours = 0.25f;
        public static float CohesionScanRadius = 35f;
        public static bool CohesionAllowLikelyWindows = true;
        public static bool CohesionAllowPlayerOnlyExecution = true;
        public static bool CohesionAllowClanPartyCommands = true;
        public static bool CohesionAutoCombat = false;
        public static int CohesionDecisionPauseMs = 500;
        public static CohesionDoctrineKind CohesionDefaultDoctrine = CohesionDoctrineKind.TradeForge;

        public static bool GuildLoopAutonomousMode = true;
        // Default 1 cycle per RunAutonomousGuildLoopNow; set 2–3 for multi-cycle cert.
        public static int GuildLoopMaxCyclesPerCommand = 1;
        public static bool GuildLoopAutoRunForgeHandoff = true;
        public static bool GuildLoopPreferSmithingInputs = true;
        public static bool GuildLoopAllowTravelOnlyIfTradeBlocked = true;
        public static bool GuildLoopProbeWeaponSmeltOnStart = true;
        // 006C-4b: after buy at buy town, auto-ride to SellSettlement for spread missions.
        public static bool GuildLoopAutoTravelToSellTown = true;
        public static bool MapTradeAutoTravelToSellTown = true;

        // Governor spine ships disabled for autonomous takeover until live cert proves branch policy.
        public static bool CampaignRuntimeGovernorAutonomousMode = false;
        public static int CampaignRuntimeGovernorDecisionIntervalMs = 4000;
        public static bool CampaignRuntimeGovernorAllowBoundedExecution = false;

        public static int SmithingSmeltMaxWeaponTier = 2;
        public static int SmithingSmeltMaxPerInvocation = 1;
        public static bool SmithingSmeltRequireLootOnly = true;
    }
}
