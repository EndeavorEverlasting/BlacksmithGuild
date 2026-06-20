using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class SmithingAdvisoryService
    {
        public const string RunSmithingAdvisoryNowCommand = "RunSmithingAdvisoryNow";
        public const string ReportFileName = "BlacksmithGuild_SmithingAdvisory.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        private static SmithingAdvisoryReport _cachedReport = new SmithingAdvisoryReport();

        public static SmithingAdvisoryReport CachedReport => _cachedReport;

        public static bool RunAdvisoryNow(
            string source = RunSmithingAdvisoryNowCommand,
            ForgeCandidate topCandidate = null,
            System.Collections.Generic.List<MaterialGapRow> materialGaps = null)
        {
            try
            {
                if (CampaignNotReady(out var blockDetail))
                {
                    DebugLogger.Test($"[TBG SMITHING] {RunSmithingAdvisoryNowCommand} blocked: {blockDetail}", showInGame: false);
                    return false;
                }

                if (topCandidate == null)
                {
                    var summary = ForgeRecommendationService.Summary;
                    topCandidate = summary.HasRankings
                        ? ForgeRecommendationService.GetCachedTopCandidate()
                        : null;
                }

                if (materialGaps == null && topCandidate != null)
                {
                    materialGaps = ForgeAdvisoryPlanner.BuildMaterialGaps(topCandidate);
                }

                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
                SmithingAdvisoryPlanner.EnrichMaterialGaps(
                    materialGaps,
                    reserve,
                    SmithingWorkerSelector.SelectGruntWorker(workers));

                _cachedReport = SmithingAdvisoryPlanner.BuildAdvisoryReport(source, topCandidate, materialGaps);
                WriteJsonReport(_cachedReport);
                WriteStructuredReport(source, topCandidate, materialGaps, _cachedReport);

                InGameNotice.Info(
                    ModDisplay.CompactLine(
                        "Smithing Advisory",
                        $"crew={_cachedReport.Crew.Count} charcoal={reserve.CharcoalHave} hardwood={reserve.HardwoodHave}"));
                InGameNotice.Info(ModDisplay.CompactLine("Smithing Advisory", $"json={ReportFileName}"));

                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG SMITHING] {RunSmithingAdvisoryNowCommand} failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool CampaignNotReady(out string detail)
        {
            detail = null;
            if (!GameSessionState.IsCampaignMapReady)
            {
                detail = GameSessionState.GetCampaignMapBlockDetail();
                return true;
            }

            return false;
        }

        private static void WriteStructuredReport(
            string source,
            ForgeCandidate topCandidate,
            System.Collections.Generic.List<MaterialGapRow> materialGaps,
            SmithingAdvisoryReport report)
        {
            var formatter = ReportFormatter.BeginReport("SMITHING ADVISORY", source, "smithing-advisory");

            formatter.Section("Reserve");
            formatter.Line("charcoal", $"{report.ReserveHealth.CharcoalHave} ({report.ReserveHealth.CharcoalStatus})");
            formatter.Line("hardwood", $"{report.ReserveHealth.HardwoodHave} ({report.ReserveHealth.HardwoodStatus})");

            AdvisoryReportSections.EmitSmithingCrew(formatter, report.Crew);
            AdvisoryReportSections.EmitMaterialGaps(formatter, materialGaps);

            if (topCandidate != null)
            {
                formatter.SummaryLine(
                    ModDisplay.CompactLine(
                        "Smithing",
                        $"top craft={topCandidate.DesignName} crew={report.Crew.Count}"));
            }

            formatter.EndReport(emitInGame: true, emitToFile: true);
        }

        private static void WriteJsonReport(SmithingAdvisoryReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"status\": \"{Escape(report.Status)}\",");
            sb.AppendLine($"  \"detail\": \"{Escape(report.Detail)}\",");
            sb.AppendLine("  \"reserveHealth\": {");
            sb.AppendLine($"    \"charcoalHave\": {report.ReserveHealth.CharcoalHave},");
            sb.AppendLine($"    \"charcoalFloor\": {report.ReserveHealth.CharcoalFloor},");
            sb.AppendLine($"    \"hardwoodHave\": {report.ReserveHealth.HardwoodHave},");
            sb.AppendLine($"    \"hardwoodFloor\": {report.ReserveHealth.HardwoodFloor},");
            sb.AppendLine($"    \"charcoalStatus\": \"{Escape(report.ReserveHealth.CharcoalStatus)}\",");
            sb.AppendLine($"    \"hardwoodStatus\": \"{Escape(report.ReserveHealth.HardwoodStatus)}\"");
            sb.AppendLine("  },");
            WriteCrewJson(sb, report);
            WriteRecommendationsJson(sb, report);
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteCrewJson(StringBuilder sb, SmithingAdvisoryReport report)
        {
            sb.AppendLine("  \"crew\": [");
            for (var i = 0; i < report.Crew.Count; i++)
            {
                var row = report.Crew[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"rank\": {row.Rank},");
                sb.AppendLine($"      \"heroName\": \"{Escape(row.HeroName)}\",");
                sb.AppendLine($"      \"action\": \"{Escape(row.Action)}\",");
                sb.AppendLine($"      \"target\": \"{Escape(row.Target)}\",");
                sb.AppendLine($"      \"reason\": \"{Escape(row.Reason)}\",");
                sb.AppendLine($"      \"staminaLabel\": \"{Escape(row.StaminaLabel)}\"");
                sb.Append(i < report.Crew.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
        }

        private static void WriteRecommendationsJson(StringBuilder sb, SmithingAdvisoryReport report)
        {
            sb.AppendLine("  \"recommendations\": [");
            for (var i = 0; i < report.Recommendations.Count; i++)
            {
                var row = report.Recommendations[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"priority\": {row.Priority},");
                sb.AppendLine($"      \"heroName\": \"{Escape(row.HeroName)}\",");
                sb.AppendLine($"      \"action\": \"{Escape(row.Action)}\",");
                sb.AppendLine($"      \"target\": \"{Escape(row.Target)}\",");
                sb.AppendLine($"      \"reason\": \"{Escape(row.Reason)}\",");
                sb.AppendLine($"      \"reserveImpact\": \"{Escape(row.ReserveImpact)}\"");
                sb.Append(i < report.Recommendations.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ]");
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
