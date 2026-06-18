using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class ForgeRecommendationService
    {
        public const string RankForgeCandidatesCommand = "RankForgeCandidates";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_ForgeRecommendations.json");

        private static ForgeRecommendationSummary _summary = new ForgeRecommendationSummary();
        private static ForgeRecommendationReport _cachedReport = new ForgeRecommendationReport();
        private static bool _summaryRecorded;

        public static ForgeRecommendationSummary Summary => _summary;

        public static bool RunRankNow(ForgeDoctrine doctrine = ForgeDoctrine.ProfitForge, string source = RankForgeCandidatesCommand)
        {
            try
            {
                var candidates = StubForgeCandidateSource.GetCandidates();
                var advisor = new ForgeAdvisor(new MaterialReservePolicy());
                var ranked = advisor.RankCandidates(candidates, doctrine).ToList();

                _cachedReport = new ForgeRecommendationReport
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = StubForgeCandidateSource.SourceName,
                    Doctrine = doctrine.ToString(),
                    TopCandidate = ranked.FirstOrDefault(),
                    Ranked = ranked
                };

                WriteJsonReport(_cachedReport);
                UpdateSummary(_cachedReport);
                WriteStructuredReport(source);
                ForgeStatus.RecordForgeRecommendations(_summary);

                DebugLogger.Test(
                    $"[TBG FORGE] RankForgeCandidates complete source={_cachedReport.Source} doctrine={_cachedReport.Doctrine} top={_summary.TopCandidateName} score={_summary.TopFinalScore:0}",
                    showInGame: false);

                return ranked.Count > 0;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] RankForgeCandidates failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Forge Recommendations");
            if (!_summaryRecorded || !_summary.HasRankings)
            {
                report.Line("status", "no rankings cached (run RankForgeCandidates)");
                report.Verdict(ReportVerdict.Info, "Top candidate cached from stub source after RankForgeCandidates");
                return;
            }

            report.Line("top", _summary.TopCandidateName);
            report.Line("score", _summary.TopFinalScore.ToString("0"));
            report.Line("doctrine", _summary.Doctrine);
            report.Line("source", _summary.Source);
            report.Line("ranked", _summary.RankedCount.ToString());
            report.Line("json", _summary.ReportPath);
        }

        public static string BuildCompactSummaryLine()
        {
            if (!_summaryRecorded || !_summary.HasRankings)
            {
                return null;
            }

            return
                $"TBG FORGE: top={_summary.TopCandidateName} score={_summary.TopFinalScore:0} doctrine={_summary.Doctrine} source={_summary.Source}";
        }

        private static void UpdateSummary(ForgeRecommendationReport report)
        {
            var top = report.TopCandidate;
            _summary = new ForgeRecommendationSummary
            {
                HasRankings = report.Ranked != null && report.Ranked.Count > 0,
                Source = report.Source,
                Doctrine = report.Doctrine,
                TopCandidateId = top?.Id,
                TopCandidateName = top?.DesignName,
                TopFinalScore = top?.FinalScore ?? 0,
                RankedCount = report.Ranked?.Count ?? 0,
                ReportPath = "BlacksmithGuild_ForgeRecommendations.json",
                GeneratedAt = DateTime.Now
            };
            _summaryRecorded = _summary.HasRankings;
        }

        private static void WriteStructuredReport(string source)
        {
            var report = ReportFormatter.BeginReport("FORGE RECOMMENDATIONS", source, "forge-recommendations");
            var top = _cachedReport.TopCandidate;

            report.Section("Doctrine");
            report.Line("active", _cachedReport.Doctrine);
            report.Line("source", _cachedReport.Source);

            if (top != null)
            {
                report.Section("Top Candidate");
                report.Line("id", top.Id);
                report.Line("name", top.DesignName);
                report.Line("class", top.WeaponClass);
                report.Line("netProfit", top.EstimatedNetProfit.ToString());
                report.Line("doctrineScore", top.DoctrineScore.ToString());
                report.Line("finalScore", top.FinalScore.ToString("0"));
            }

            report.Section("Top 3");
            var index = 1;
            foreach (var candidate in _cachedReport.Ranked.Take(3))
            {
                report.Line(
                    index.ToString(),
                    $"{candidate.DesignName} | score {candidate.FinalScore:0}");
                index++;
            }

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_ForgeRecommendations.json");

            if (top != null)
            {
                report.SummaryLine(
                    $"top={top.DesignName} score={top.FinalScore:0} doctrine={_cachedReport.Doctrine} source={_cachedReport.Source}");
            }

            report.EndReport(emitInGame: string.Equals(source, RankForgeCandidatesCommand, StringComparison.Ordinal), emitToFile: true);
        }

        private static void WriteJsonReport(ForgeRecommendationReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, SerializeReport(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] Failed to write recommendations JSON: {ex.Message}", showInGame: false);
            }
        }

        private static string SerializeReport(ForgeRecommendationReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");

            if (report.TopCandidate != null)
            {
                AppendCandidateJson(builder, "topCandidate", report.TopCandidate, trailingComma: true);
            }

            builder.AppendLine("  \"ranked\": [");
            for (var i = 0; i < report.Ranked.Count; i++)
            {
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                builder.Append("    ");
                AppendCandidateObject(builder, report.Ranked[i]);
            }

            builder.AppendLine();
            builder.AppendLine("  ]");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendCandidateJson(
            StringBuilder builder,
            string propertyName,
            ForgeCandidate candidate,
            bool trailingComma)
        {
            builder.Append($"  \"{propertyName}\": ");
            AppendCandidateObject(builder, candidate);
            builder.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static void AppendCandidateObject(StringBuilder builder, ForgeCandidate candidate)
        {
            builder.AppendLine("{");
            builder.AppendLine($"    \"id\": \"{Escape(candidate.Id)}\",");
            builder.AppendLine($"    \"name\": \"{Escape(candidate.DesignName)}\",");
            builder.AppendLine($"    \"class\": \"{Escape(candidate.WeaponClass)}\",");
            builder.AppendLine($"    \"source\": \"{Escape(candidate.Source)}\",");
            builder.AppendLine($"    \"estimatedValue\": {candidate.EstimatedValue},");
            builder.AppendLine($"    \"estimatedMaterialCost\": {candidate.EstimatedMaterialCost},");
            builder.AppendLine($"    \"rareMaterialPenalty\": {candidate.RareMaterialPenalty},");
            builder.AppendLine($"    \"netProfit\": {candidate.EstimatedNetProfit},");
            builder.AppendLine($"    \"doctrineScore\": {candidate.DoctrineScore},");
            builder.AppendLine($"    \"finalScore\": {candidate.FinalScore},");
            builder.AppendLine($"    \"reason\": \"{Escape(candidate.Reason)}\"");
            builder.Append("  }");
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
