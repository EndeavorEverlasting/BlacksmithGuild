using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Conversation;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroIntelService
    {
        public const string AnalyzeTavernHeroesCommand = "AnalyzeTavernHeroes";
        public const string ShowTavernHeroIntelCommand = "ShowTavernHeroIntel";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TavernHeroIntel.json");

        private static TavernHeroIntelReport _lastReport;

        public static bool RunAnalyzeNow(string source = AnalyzeTavernHeroesCommand)
        {
            GameSessionState.Refresh();
            if (Campaign.Current == null || Hero.MainHero == null)
            {
                DebugLogger.Test("[TBG TAVERN] analyze blocked: campaign not ready.", showInGame: false);
                return false;
            }

            if (!GameSessionState.IsSettlementInteriorReady && !GameSessionState.IsCampaignMapReady)
            {
                var detail = GameSessionState.GetCommandReadyBlockDetail();
                DebugLogger.Test($"[TBG TAVERN] analyze blocked: {detail}", showInGame: false);
                InGameNotice.Blocked($"TBG TAVERN: {detail}");
                return false;
            }

            try
            {
                var report = BuildReport(source);
                _lastReport = report;
                WriteJsonReport(report);
                WriteStructuredReport(source, report);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG TAVERN] analyze failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool ShowLastIntel()
        {
            if (_lastReport == null)
            {
                return RunAnalyzeNow(ShowTavernHeroIntelCommand);
            }

            WriteStructuredReport(ShowTavernHeroIntelCommand, _lastReport);
            return true;
        }

        public static TavernHeroIntelReport BuildReport(string source)
        {
            var settlement = TavernHeroScanner.BuildSettlementSnapshot();
            var player = TavernHeroScanner.BuildPlayerSnapshot(Hero.MainHero);
            var companionState = TavernHeroScanner.BuildCompanionSnapshot(MobileParty.MainParty);
            var settlementEntity = GameSessionState.ResolveCurrentSettlement();
            var candidates = settlementEntity == null
                ? new List<TavernHeroCandidate>()
                : TavernHeroScanner.ScanCandidates(settlementEntity);
            var recommendations = TavernHeroScorer.BuildRecommendations(candidates, player, companionState, settlement);
            var top = recommendations.FirstOrDefault();

            var blockedReason = ResolveBlockedReason(settlement, candidates, player, companionState);
            var verdict = blockedReason == null
                ? $"found {candidates.Count} tavern hero candidate(s)"
                : blockedReason;

            return new TavernHeroIntelReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = TavernHeroDoctrine.GetDoctrineLabel(),
                Settlement = settlement,
                Player = player,
                CompanionState = companionState,
                Candidates = candidates,
                Recommendations = recommendations,
                TopRecommendation = top,
                BlockedReason = blockedReason,
                Verdict = verdict
            };
        }

        public static Hero ResolveHero(string heroId)
        {
            if (string.IsNullOrEmpty(heroId))
            {
                return null;
            }

            return Hero.AllAliveHeroes?.FirstOrDefault(h => string.Equals(h.StringId, heroId, StringComparison.OrdinalIgnoreCase));
        }

        private static string ResolveBlockedReason(
            TavernHeroSettlementSnapshot settlement,
            List<TavernHeroCandidate> candidates,
            TavernHeroPlayerSnapshot player,
            TavernHeroCompanionStateSnapshot companionState)
        {
            if (!string.IsNullOrEmpty(settlement?.BlockedReason))
            {
                return settlement.BlockedReason;
            }

            if (candidates.Count == 0)
            {
                return "no tavern hero candidates found";
            }

            if (companionState.RemainingSlots == 0)
            {
                return "companion limit full";
            }

            var top = candidates.OrderByDescending(c => c.Score).FirstOrDefault();
            if (top?.RecruitmentCost != null && top.RecruitmentCost.Value > player.SpendableGold)
            {
                return "top candidate would break safe gold reserve";
            }

            return null;
        }

        private static void WriteJsonReport(TavernHeroIntelReport report)
        {
            File.WriteAllText(ReportPath, TavernHeroJsonWriter.SerializeIntel(report), Encoding.UTF8);
            MirrorEvidence(ReportPath, "BlacksmithGuild_TavernHeroIntel.json");
        }

        private static void WriteStructuredReport(string source, TavernHeroIntelReport report)
        {
            var formatter = ReportFormatter.BeginReport("TBG TAVERN", source, "tavern-hero-intel");
            formatter.Section("Context");
            formatter.Line("doctrine", report.Doctrine);
            formatter.Line("readOnly", "true");
            formatter.Line("settlement", report.Settlement?.Name ?? "none");
            formatter.Line("inTavern", report.Settlement?.PlayerInTavern.ToString() ?? "false");
            formatter.Line("candidates", report.Candidates.Count.ToString());
            formatter.Line("blocked", report.BlockedReason ?? "none");
            if (report.TopRecommendation != null)
            {
                formatter.Line(
                    "pick",
                    $"[{report.TopRecommendation.Label}] {report.TopRecommendation.Name} score={report.TopRecommendation.Score:0.#} cost={report.TopRecommendation.RecruitmentCost}");
            }

            formatter.EndReport(emitInGame: true, emitToFile: true);

            if (report.Candidates.Count > 0)
            {
                InGameNotice.Info($"TBG TAVERN: found {report.Candidates.Count} recruitable heroes in {report.Settlement?.Name ?? "settlement"}.");
            }

            if (report.TopRecommendation != null)
            {
                InGameNotice.Info(
                    $"TBG TAVERN PICK: [{report.TopRecommendation.Label}] {report.TopRecommendation.Name} | cost {report.TopRecommendation.RecruitmentCost}.");
            }

            if (!string.IsNullOrEmpty(report.BlockedReason))
            {
                InGameNotice.Blocked($"TBG TAVERN: {report.BlockedReason}.");
            }
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

    public static class TavernHeroRecruitmentProbeService
    {
        public const string ProbeTavernRecruitmentApiCommand = "ProbeTavernRecruitmentApi";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TavernHeroRecruitmentProbe.json");

        public static bool RunProbeNow(string source = ProbeTavernRecruitmentApiCommand)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine("  \"hints\": [");
            AppendHint(sb, "PlayerEncounter.EnterSettlement", typeof(TaleWorlds.CampaignSystem.Encounters.PlayerEncounter).GetMethod("EnterSettlement", BindingFlags.Public | BindingFlags.Static) != null);
            AppendHint(sb, "GameMenu.ActivateGameMenu", typeof(TaleWorlds.CampaignSystem.GameMenus.GameMenu).GetMethod("ActivateGameMenu", BindingFlags.Public | BindingFlags.Static) != null);
            AppendHint(sb, "ConversationManager.OpenMapConversation", typeof(ConversationManager).GetMethod("OpenMapConversation", BindingFlags.Public | BindingFlags.Instance) != null);
            AppendHint(sb, "ConversationManager.DoOption", typeof(ConversationManager).GetMethod("DoOption", BindingFlags.Public | BindingFlags.Instance, null, new[] { typeof(string) }, null) != null);
            AppendHint(sb, "CompanionHiringPriceCalculationModel.GetCompanionHiringPrice", Campaign.Current?.Models?.CompanionHiringPriceCalculationModel != null);
            sb.AppendLine("  ]");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
            DebugLogger.Test("[TBG TAVERN] recruitment probe written.", showInGame: false);
            InGameNotice.Info("TBG TAVERN: recruitment API probe written.");
            return true;
        }

        private static void AppendHint(StringBuilder sb, string name, bool available)
        {
            sb.AppendLine($"    {{ \"name\": \"{Escape(name)}\", \"available\": {(available ? "true" : "false")} }},");
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
