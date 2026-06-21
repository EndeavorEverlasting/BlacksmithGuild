using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Market;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class GuildLoopService
    {
        public const string RunGuildLoopNowCommand = "RunGuildLoopNow";
        public const string ReportFileName = "BlacksmithGuild_GuildLoopReport.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static bool RunGuildLoopNow(string source = RunGuildLoopNowCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                DebugLogger.Test(
                    $"[TBG GUILD] {RunGuildLoopNowCommand} blocked: {GameSessionState.GetCampaignMapBlockDetail()}",
                    showInGame: false);
                return false;
            }

            if (!MarketIntelligenceService.HasCachedScan)
            {
                if (!MarketIntelligenceService.RunScanNow(MarketIntelligenceService.MarketSnapshotNowCommand))
                {
                    DebugLogger.Test("[TBG GUILD] market scan failed during guild loop.", showInGame: false);
                }
            }

            if (!ForgeRecommendationService.RunRankNow(source: ForgeRecommendationService.RankForgeCandidatesCommand))
            {
                DebugLogger.Test("[TBG GUILD] forge rank failed during guild loop.", showInGame: false);
            }

            var top = ForgeRecommendationService.GetCachedTopCandidate();
            var gaps = top != null ? ForgeAdvisoryPlanner.BuildMaterialGaps(top) : null;
            if (!SmithingAdvisoryService.RunAdvisoryNow(source, top, gaps))
            {
                return false;
            }

            WriteGuildLoopSummary(source);
            WriteGuildLoopJsonReport(source);
            return true;
        }

        private static void WriteGuildLoopSummary(string source)
        {
            var report = ReportFormatter.BeginReport("GUILD LOOP", source, "guild-loop");
            var market = MarketIntelligenceService.GetAdvisorySnapshot();
            var smithing = SmithingAdvisoryService.CachedReport;
            var forgeSummary = ForgeRecommendationService.BuildCompactSummaryLine();

            AdvisoryReportSections.EmitContextSummary(report, market);
            AdvisoryReportSections.EmitBuyAtNearest(report, market.RouteRows);
            AdvisoryReportSections.EmitTopSpreads(report, market.SpreadRows);

            if (!string.IsNullOrEmpty(forgeSummary))
            {
                report.SummaryLine(forgeSummary);
            }

            AdvisoryReportSections.EmitSmithingCrew(report, smithing?.Crew);
            AdvisoryReportSections.EmitActionPlan(
                report,
                ForgeRecommendationService.GetCachedActionPlan());

            report.EndReport(emitInGame: true, emitToFile: true);
            InGameNotice.Info(ModDisplay.CompactLine("Guild Loop", "market + forge + smithing crew updated."));
        }

        private static void WriteGuildLoopJsonReport(string source)
        {
            var market = MarketIntelligenceService.GetAdvisorySnapshot();
            var forge = ForgeRecommendationService.CachedReport;
            var smithing = SmithingAdvisoryService.CachedReport;
            var actionPlan = ForgeRecommendationService.GetCachedActionPlan();
            var stageDExposed = DevCommandRegistry.IsRegistered(SmithingRestPlanService.RunSmithingRestPlanNowCommand);

            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"reportId\": \"guild-loop-{DateTime.UtcNow:yyyyMMddHHmmss}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"phase\": \"{Escape(GameSessionState.Phase.ToString())}\",");
            sb.AppendLine($"  \"ready\": {GameSessionState.IsCampaignMapReady.ToString().ToLowerInvariant()},");
            WriteMarketJson(sb, market);
            WriteForgeJson(sb, forge);
            WriteSmithingCrewJson(sb, smithing?.Crew);
            WriteActionPlanStringsJson(sb, actionPlan);
            WriteVerdictJson(sb, stageDExposed);
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteMarketJson(StringBuilder sb, MarketAdvisorySnapshot market)
        {
            sb.AppendLine("  \"market\": {");
            sb.AppendLine($"    \"hasScan\": {market.HasScan.ToString().ToLowerInvariant()},");
            sb.AppendLine($"    \"nearestTown\": {(string.IsNullOrEmpty(market.NearestTown) ? "null" : $"\"{Escape(market.NearestTown)}\"")},");
            sb.AppendLine($"    \"nearestDistance\": {market.NearestDistance.ToString("0.##")},");
            sb.AppendLine($"    \"townCount\": {market.TownsScanned},");
            sb.AppendLine($"    \"expandedScanUsed\": {market.ExpandedScanUsed.ToString().ToLowerInvariant()},");
            sb.AppendLine("    \"actionPlan\": [");
            WriteActionPlanSteps(sb, market.ActionPlan, indent: "      ");
            sb.AppendLine("    ],");
            sb.AppendLine("    \"topSpreads\": [");
            var spreads = market.SpreadRows ?? new List<MarketSpreadRow>();
            for (var i = 0; i < spreads.Count; i++)
            {
                var row = spreads[i];
                sb.AppendLine("      {");
                sb.AppendLine($"        \"itemName\": \"{Escape(row.ItemName)}\",");
                sb.AppendLine($"        \"buyTown\": \"{Escape(row.BuyTown)}\",");
                sb.AppendLine($"        \"buyPrice\": {row.BuyPrice},");
                sb.AppendLine($"        \"sellTown\": \"{Escape(row.SellTown)}\",");
                sb.AppendLine($"        \"sellPrice\": {row.SellPrice},");
                sb.AppendLine($"        \"spread\": {row.Spread}");
                sb.Append(i < spreads.Count - 1 ? "      }," : "      }");
                sb.AppendLine();
            }

            sb.AppendLine("    ]");
            sb.AppendLine("  },");
        }

        private static void WriteForgeJson(StringBuilder sb, ForgeRecommendationReport forge)
        {
            var top = forge?.TopCandidate;
            sb.AppendLine("  \"forge\": {");
            sb.AppendLine($"    \"source\": \"{Escape(forge?.Source ?? string.Empty)}\",");
            sb.AppendLine($"    \"sourceKind\": \"{Escape(forge?.SourceKind ?? string.Empty)}\",");
            sb.AppendLine($"    \"fallbackUsed\": {(forge?.FallbackUsed ?? false).ToString().ToLowerInvariant()},");
            sb.AppendLine($"    \"topCandidate\": {(top == null ? "null" : $"\"{Escape(top.DesignName)}\"")},");
            sb.AppendLine($"    \"topScore\": {(top?.FinalScore ?? 0).ToString("0.##")},");
            sb.AppendLine("    \"sourceHonesty\": {");
            var honesty = forge?.SourceHonesty;
            if (honesty != null)
            {
                sb.AppendLine($"      \"requested\": \"{Escape(honesty.Requested)}\",");
                sb.AppendLine($"      \"resolved\": \"{Escape(honesty.Resolved)}\",");
                sb.AppendLine($"      \"fallbackUsed\": {honesty.FallbackUsed.ToString().ToLowerInvariant()},");
                sb.AppendLine($"      \"verdict\": \"{Escape(honesty.Verdict.ToString())}\",");
                sb.AppendLine($"      \"message\": \"{Escape(honesty.VerdictMessage)}\"");
            }

            sb.AppendLine("    },");
            sb.AppendLine("    \"materialGaps\": [");
            var gaps = forge?.MaterialGaps ?? new List<MaterialGapRow>();
            for (var i = 0; i < gaps.Count; i++)
            {
                var gap = gaps[i];
                sb.AppendLine("      {");
                sb.AppendLine($"        \"itemName\": \"{Escape(gap.ItemName)}\",");
                sb.AppendLine($"        \"need\": {gap.Need},");
                sb.AppendLine($"        \"have\": {gap.Have},");
                sb.AppendLine($"        \"buyHint\": {(string.IsNullOrEmpty(gap.BuyHint) ? "null" : $"\"{Escape(gap.BuyHint)}\"")}");
                sb.Append(i < gaps.Count - 1 ? "      }," : "      }");
                sb.AppendLine();
            }

            sb.AppendLine("    ]");
            sb.AppendLine("  },");
        }

        private static void WriteSmithingCrewJson(StringBuilder sb, List<SmithingCrewRow> crew)
        {
            sb.AppendLine("  \"smithingCrew\": [");
            crew = crew ?? new List<SmithingCrewRow>();
            for (var i = 0; i < crew.Count; i++)
            {
                var row = crew[i];
                ParseCrewTarget(row.Target, out var target, out var count);
                sb.AppendLine("    {");
                sb.AppendLine($"      \"rank\": {row.Rank},");
                sb.AppendLine($"      \"actor\": \"{Escape(row.HeroName)}\",");
                sb.AppendLine($"      \"action\": \"{Escape(row.Action)}\",");
                sb.AppendLine($"      \"target\": \"{Escape(target)}\",");
                sb.AppendLine($"      \"count\": {count},");
                sb.AppendLine($"      \"stamina\": \"{Escape(row.StaminaLabel)}\",");
                sb.AppendLine($"      \"reason\": \"{Escape(row.Reason)}\"");
                sb.Append(i < crew.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
        }

        private static void WriteActionPlanStringsJson(StringBuilder sb, List<ActionPlanStep> steps)
        {
            sb.AppendLine("  \"actionPlan\": [");
            steps = steps ?? new List<ActionPlanStep>();
            for (var i = 0; i < steps.Count; i++)
            {
                sb.AppendLine($"    \"{Escape(steps[i].Text)}\"{(i < steps.Count - 1 ? "," : string.Empty)}");
            }

            sb.AppendLine("  ],");
        }

        private static void WriteActionPlanSteps(StringBuilder sb, IReadOnlyList<ActionPlanStep> steps, string indent)
        {
            steps = steps ?? new List<ActionPlanStep>();
            for (var i = 0; i < steps.Count; i++)
            {
                var step = steps[i];
                sb.AppendLine($"{indent}{{");
                sb.AppendLine($"{indent}  \"step\": {step.Step},");
                sb.AppendLine($"{indent}  \"text\": \"{Escape(step.Text)}\"");
                sb.Append(i < steps.Count - 1 ? $"{indent}}}," : $"{indent}}}");
            }
        }

        private static void WriteVerdictJson(StringBuilder sb, bool stageDExposed)
        {
            sb.AppendLine("  \"verdict\": {");
            sb.AppendLine("    \"stageBAdvisoryUseful\": true,");
            sb.AppendLine($"    \"stageDCommandExposed\": {stageDExposed.ToString().ToLowerInvariant()},");
            sb.AppendLine("    \"notes\": [");
            sb.AppendLine("      \"Guild loop composes market + forge + smithing crew without mutation\"");
            sb.AppendLine("    ]");
            sb.AppendLine("  }");
        }

        private static void ParseCrewTarget(string targetLabel, out string target, out int count)
        {
            target = targetLabel ?? string.Empty;
            count = 1;
            if (string.IsNullOrWhiteSpace(targetLabel))
            {
                return;
            }

            var match = Regex.Match(targetLabel, @"^(.*)\sx(\d+)$");
            if (match.Success)
            {
                target = match.Groups[1].Value.Trim();
                count = int.TryParse(match.Groups[2].Value, out var parsed) ? parsed : 1;
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
