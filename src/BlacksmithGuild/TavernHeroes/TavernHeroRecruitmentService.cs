using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroRecruitmentService
    {
        public const string RecruitTavernHeroVisibleNowCommand = "RecruitTavernHeroVisibleNow";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TavernHeroRecruitment.json");

        public static bool LastWasGuardrailBlock { get; private set; }
        public static string LastBlockedReason { get; private set; }
        public static string LastFailReason { get; private set; }

        public static bool RunRecruitVisibleNow(string source = RecruitTavernHeroVisibleNowCommand)
        {
            LastWasGuardrailBlock = false;
            LastBlockedReason = null;
            LastFailReason = null;

            GameSessionState.Refresh();
            if (!CanRunRecruitment(out var blockReason))
            {
                return GuardrailBlock(blockReason, source);
            }

            if (!TavernHeroIntelService.RunAnalyzeNow(source))
            {
                LastFailReason = "AnalyzeTavernHeroes failed before recruitment";
                WriteBlockedReport(source, LastFailReason, new List<TavernHeroRecruitmentActionStep>());
                return false;
            }

            var intel = TavernHeroIntelService.BuildReport(source);
            var top = intel.TopRecommendation;
            if (top == null || string.IsNullOrEmpty(top.HeroId))
            {
                return GuardrailBlock(intel.BlockedReason ?? "no recruitable candidate", source);
            }

            var hero = TavernHeroIntelService.ResolveHero(top.HeroId);
            if (hero == null)
            {
                return GuardrailBlock("selected candidate no longer available", source);
            }

            var actions = new List<TavernHeroRecruitmentActionStep>();
            if (!GameSessionState.IsTavernLocationReady)
            {
                if (!SettlementNavigationService.TryNavigateToTavernNow(out var navDetail, actions))
                {
                    return GuardrailBlock(navDetail ?? "could not reach tavern", source, actions);
                }
            }

            var before = CaptureState(hero);
            InGameNotice.Warn("TBG TAVERN RECRUIT: visible recruitment started.");

            if (!TavernHeroVisibleRecruitmentDriver.TryRecruitVisible(hero, actions, out var recruitDetail))
            {
                LastFailReason = recruitDetail ?? "visible recruitment failed";
                WriteReport(source, top, before, CaptureState(hero), actions, blockedReason: LastFailReason, success: false);
                InGameNotice.Fail($"TBG TAVERN BLOCKED: {LastFailReason}");
                DebugLogger.Test($"[TBG TAVERN] blocked: {LastFailReason}", showInGame: false);
                return false;
            }

            var after = CaptureState(hero);
            var success = after.CandidateInParty == true;
            var verdict = success
                ? $"Hero recruited through visible vanilla tavern path: {top.Name}"
                : recruitDetail ?? "recruitment attempt finished without companion confirmation";

            WriteReport(source, top, before, after, actions, blockedReason: success ? null : verdict, success: success);

            if (success)
            {
                InGameNotice.Success($"TBG TAVERN SUCCESS: {top.Name} joined the party | paid {Math.Abs(after.GoldDelta ?? 0)}.");
                DebugLogger.Test($"[TBG TAVERN SUCCESS] {top.Name} joined; goldDelta={after.GoldDelta}", showInGame: false);
                return true;
            }

            LastFailReason = verdict;
            InGameNotice.Fail($"TBG TAVERN BLOCKED: {verdict}");
            return false;
        }

        private static bool CanRunRecruitment(out string reason)
        {
            reason = null;
            if (Campaign.Current == null || Hero.MainHero == null)
            {
                reason = "campaign not ready";
                return false;
            }

            if (GameSessionState.IsMissionActiveForTrace())
            {
                reason = "mission active";
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady && !GameSessionState.IsSettlementInteriorReady)
            {
                reason = GameSessionState.GetCommandReadyBlockDetail();
                return false;
            }

            return true;
        }

        private static bool GuardrailBlock(
            string reason,
            string source,
            List<TavernHeroRecruitmentActionStep> actions = null)
        {
            LastWasGuardrailBlock = true;
            LastBlockedReason = reason;
            LastFailReason = reason;
            WriteBlockedReport(source, reason, actions ?? new List<TavernHeroRecruitmentActionStep>());
            InGameNotice.Blocked($"TBG TAVERN BLOCKED: {reason}");
            DebugLogger.Test($"[TBG TAVERN] blocked: {reason}", showInGame: false);
            return false;
        }

        private static TavernHeroRecruitmentStateSnapshot CaptureState(Hero candidate)
        {
            var snapshot = new TavernHeroRecruitmentStateSnapshot
            {
                Gold = Hero.MainHero?.Gold ?? 0,
                CompanionCount = Clan.PlayerClan?.Companions?.Count,
                CandidateInParty = candidate?.IsPlayerCompanion
            };

            if (MobileParty.MainParty?.MemberRoster != null)
            {
                foreach (var element in MobileParty.MainParty.MemberRoster.GetTroopRoster())
                {
                    var hero = element.Character?.HeroObject;
                    if (hero != null)
                    {
                        snapshot.PartyHeroes.Add(hero.Name?.ToString() ?? hero.StringId);
                    }
                }
            }

            return snapshot;
        }

        private static void WriteBlockedReport(
            string source,
            string blockedReason,
            List<TavernHeroRecruitmentActionStep> actions)
        {
            var before = CaptureState(null);
            WriteReport(source, null, before, before, actions, blockedReason, success: false);
        }

        private static void WriteReport(
            string source,
            TavernHeroRecommendation selected,
            TavernHeroRecruitmentStateSnapshot before,
            TavernHeroRecruitmentStateSnapshot after,
            List<TavernHeroRecruitmentActionStep> actions,
            string blockedReason,
            bool success)
        {
            after.GoldDelta = after.Gold - before.Gold;
            var report = new TavernHeroRecruitmentReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                VisibleModeEnabled = DevToolsConfig.TavernHeroVisibleMode,
                DecisionPauseMs = DevToolsConfig.TavernHeroDecisionPauseMs,
                SelectedCandidate = selected,
                Before = before,
                After = after,
                Actions = actions ?? new List<TavernHeroRecruitmentActionStep>(),
                BlockedReason = blockedReason,
                Verdict = blockedReason ?? "Hero recruited through visible vanilla tavern path",
                MutationAudit = new TavernHeroRecruitmentAudit
                {
                    GoldMutatedByVanillaRecruitment = after.GoldDelta != 0,
                    PartyChangedByVanillaRecruitment = success,
                    DirectHeroInjectionUsed = false,
                    FreeRecruitmentUsed = success && after.GoldDelta == 0
                }
            };

            File.WriteAllText(ReportPath, TavernHeroJsonWriter.SerializeRecruitment(report), Encoding.UTF8);
            MirrorEvidence(ReportPath, "BlacksmithGuild_TavernHeroRecruitment.json");

            var formatter = ReportFormatter.BeginReport("TBG TAVERN RECRUIT", source, "tavern-hero-recruit");
            formatter.Section("Result");
            formatter.Line("visible", report.VisibleModeEnabled.ToString());
            formatter.Line("directInjection", "false");
            formatter.Line("verdict", report.Verdict ?? string.Empty);
            formatter.EndReport(emitInGame: false, emitToFile: true);
        }

        private static void MirrorEvidence(string sourcePath, string fileName)
        {
            try
            {
                var repoRoot = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", ".."));
                var mirrorDir = Path.Combine(repoRoot, "docs", "evidence", "latest");
                if (!Directory.Exists(mirrorDir))
                {
                    return;
                }

                File.Copy(sourcePath, Path.Combine(mirrorDir, fileName), overwrite: true);
            }
            catch
            {
            }
        }
    }
}
