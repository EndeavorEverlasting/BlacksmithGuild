using System;
using System.Collections.Generic;
using System.Text;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.CharacterDevelopment;
using TaleWorlds.CampaignSystem.Settlements.Buildings;
using TaleWorlds.Core;
using TaleWorlds.Library;
using TaleWorlds.ObjectSystem;

namespace BlacksmithGuild.DevTools
{
    public enum PreflightVerdict
    {
        Unknown,
        Pass,
        Warn,
        Fail
    }

    public static class GameReadinessService
    {
        private static bool _preflightCompleted;
        private static bool _loggedWaitingForMainHero;
        private static readonly string[] DependencyModuleIds =
        {
            "Native",
            "SandBoxCore",
            "Sandbox",
            "StoryMode",
            "BlacksmithGuild"
        };

        public static PreflightVerdict Verdict { get; private set; } = PreflightVerdict.Unknown;

        public static string BlockReason { get; private set; } = "preflight not run";

        public static bool HasCompletedPreflight => _preflightCompleted;

        public static bool IsCampaignReady
        {
            get
            {
                try
                {
                    return Campaign.Current != null;
                }
                catch
                {
                    return false;
                }
            }
        }

        public static bool IsMainHeroReady
        {
            get
            {
                try
                {
                    return Hero.MainHero != null;
                }
                catch
                {
                    return false;
                }
            }
        }

        public static bool CanRunRiskyCommands(out string reason)
        {
            GameSessionState.Refresh();
            RunPreflightWhenReady();

            if (!GameSessionState.IsCampaignMapReady)
            {
                var detail = GameSessionState.GetCampaignMapBlockDetail();
                DebugLogger.Test(
                    $"Risky command blocked: campaign map not ready ({detail})",
                    showInGame: false
                );
                reason = "campaign map not ready.";
                return false;
            }

            if (!IsCampaignReady)
            {
                reason = "campaign not ready";
                return false;
            }

            if (!IsMainHeroReady)
            {
                reason = "MainHero not ready";
                return false;
            }

            if (!_preflightCompleted)
            {
                reason = "data preflight not completed";
                return false;
            }

            if (Verdict == PreflightVerdict.Fail)
            {
                reason = BlockReason;
                return false;
            }

            reason = null;
            return true;
        }

        public static void RunPreflightWhenReady()
        {
            if (_preflightCompleted)
            {
                return;
            }

            if (!IsCampaignReady)
            {
                return;
            }

            if (!IsMainHeroReady)
            {
                if (!_loggedWaitingForMainHero)
                {
                    _loggedWaitingForMainHero = true;
                    DebugLogger.Test("Preflight: waiting for MainHero", showInGame: false);
                }

                return;
            }

            _preflightCompleted = true;
            var missingLists = new List<string>();
            var unknownLists = new List<string>();

            try
            {
                GuildLog.Info("[TBG PREFLIGHT] Starting game data preflight.", showInGame: false);
                GuildLog.Info("[TBG PREFLIGHT] BlacksmithGuild version: v0.0.4", showInGame: false);
                GuildLog.Info(
                    $"[TBG PREFLIGHT] Campaign active: {IsCampaignReady}",
                    showInGame: false
                );
                GuildLog.Info(
                    $"[TBG PREFLIGHT] MainHero available: {IsMainHeroReady}",
                    showInGame: false
                );

                LogModuleVersions();
                LogBeardTagNote();

                GuildLog.Info("[TBG PREFLIGHT] Critical list checks:", showInGame: false);
                CheckList("Craftingpieces", () => MBObjectManager.Instance?.GetObjectTypeList<CraftingPiece>(), missingLists, unknownLists);
                CheckList("Perks", () => MBObjectManager.Instance?.GetObjectTypeList<PerkObject>(), missingLists, unknownLists);
                CheckList("Traits", () => MBObjectManager.Instance?.GetObjectTypeList<TraitObject>(), missingLists, unknownLists);
                CheckList("BuildingTypes", () => MBObjectManager.Instance?.GetObjectTypeList<BuildingType>(), missingLists, unknownLists);
                CheckList("Policies", () => MBObjectManager.Instance?.GetObjectTypeList<PolicyObject>(), missingLists, unknownLists);
                CheckBasicCharacterObjectCount(missingLists, unknownLists);

                Verdict = ResolveVerdict(missingLists, unknownLists);
                BlockReason = BuildBlockReason(missingLists, unknownLists);
                GuildLog.Info($"[TBG PREFLIGHT] Result: {Verdict}", showInGame: false);

                if (missingLists.Count > 0)
                {
                    GuildLog.Info(
                        $"[TBG PREFLIGHT] Missing lists: {string.Join(", ", missingLists)}",
                        showInGame: false
                    );
                }

                if (unknownLists.Count > 0)
                {
                    GuildLog.Info(
                        $"[TBG PREFLIGHT] Unknown checks: {string.Join(", ", unknownLists)}",
                        showInGame: false
                    );
                }

                ForgeStatus.SetPreflight(Verdict.ToString(), BlockReason);
            }
            catch (Exception ex)
            {
                Verdict = PreflightVerdict.Unknown;
                BlockReason = $"preflight exception: {ex.Message}";
                GuildLog.Info($"[TBG PREFLIGHT] Exception: {ex.Message}", showInGame: false);
                GuildLog.Info("[TBG PREFLIGHT] Result: Unknown", showInGame: false);
                ForgeStatus.SetPreflight(Verdict.ToString(), BlockReason);
            }

            ForgeStatus.UpdateReadiness(IsCampaignReady, IsMainHeroReady);
        }

        private static void LogModuleVersions()
        {
            GuildLog.Info("[TBG PREFLIGHT] Bannerlord module versions detected:", showInGame: false);

            foreach (var moduleId in DependencyModuleIds)
            {
                GuildLog.Info(
                    $"[TBG PREFLIGHT] {moduleId}: {TryGetModuleVersion(moduleId)}",
                    showInGame: false
                );
            }
        }

        private static string TryGetModuleVersion(string moduleId)
        {
            try
            {
                var moduleHelperType = Type.GetType(
                    "TaleWorlds.ModuleManager.ModuleHelper, TaleWorlds.ModuleManager"
                );
                if (moduleHelperType == null)
                {
                    return "unknown";
                }

                var getModuleInfo = moduleHelperType.GetMethod(
                    "GetModuleInfo",
                    new[] { typeof(string) }
                );
                if (getModuleInfo == null)
                {
                    return "unknown";
                }

                var moduleInfo = getModuleInfo.Invoke(null, new object[] { moduleId });
                if (moduleInfo == null)
                {
                    return "missing";
                }

                var version = moduleInfo.GetType().GetProperty("Version")?.GetValue(moduleInfo) as string;
                return string.IsNullOrWhiteSpace(version) ? "present" : version;
            }
            catch
            {
                return "unknown";
            }
        }

        private static void LogBeardTagNote()
        {
            GuildLog.Info(
                "[TBG PREFLIGHT] Beard tag validation: unsupported in-mod; check engine logs for \"has missing beard tag\"",
                showInGame: false
            );
        }

        private static void CheckList<T>(
            string label,
            Func<MBReadOnlyList<T>> getList,
            List<string> missingLists,
            List<string> unknownLists)
            where T : MBObjectBase
        {
            try
            {
                var list = getList();
                if (list == null)
                {
                    unknownLists.Add(label);
                    GuildLog.Info($"[TBG PREFLIGHT] {label}: unknown", showInGame: false);
                    return;
                }

                if (list.Count > 0)
                {
                    GuildLog.Info($"[TBG PREFLIGHT] {label}: present", showInGame: false);
                    return;
                }

                missingLists.Add(label);
                GuildLog.Info($"[TBG PREFLIGHT] {label}: missing", showInGame: false);
            }
            catch
            {
                unknownLists.Add(label);
                GuildLog.Info($"[TBG PREFLIGHT] {label}: unknown", showInGame: false);
            }
        }

        private static void CheckBasicCharacterObjectCount(
            List<string> missingLists,
            List<string> unknownLists)
        {
            const string label = "BasicCharacterObject";

            try
            {
                var list = MBObjectManager.Instance?.GetObjectTypeList<BasicCharacterObject>();
                if (list == null)
                {
                    unknownLists.Add(label);
                    GuildLog.Info($"[TBG PREFLIGHT] {label}: unknown", showInGame: false);
                    return;
                }

                if (list.Count > 0)
                {
                    GuildLog.Info($"[TBG PREFLIGHT] {label}: present ({list.Count})", showInGame: false);
                    return;
                }

                missingLists.Add(label);
                GuildLog.Info($"[TBG PREFLIGHT] {label}: missing", showInGame: false);
            }
            catch
            {
                unknownLists.Add(label);
                GuildLog.Info($"[TBG PREFLIGHT] {label}: unknown", showInGame: false);
            }
        }

        private static PreflightVerdict ResolveVerdict(
            List<string> missingLists,
            List<string> unknownLists)
        {
            if (missingLists.Count > 0)
            {
                return PreflightVerdict.Fail;
            }

            if (unknownLists.Count > 0)
            {
                return PreflightVerdict.Warn;
            }

            return PreflightVerdict.Pass;
        }

        private static string BuildBlockReason(List<string> missingLists, List<string> unknownLists)
        {
            if (missingLists.Count > 0)
            {
                return $"Missing: {string.Join(", ", missingLists)}";
            }

            if (unknownLists.Count > 0)
            {
                var builder = new StringBuilder();
                builder.Append("Unknown checks: ");
                builder.Append(string.Join(", ", unknownLists));
                return builder.ToString();
            }

            return string.Empty;
        }
    }
}
