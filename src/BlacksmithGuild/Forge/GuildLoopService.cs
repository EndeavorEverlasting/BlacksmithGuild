using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Market;

namespace BlacksmithGuild.Forge
{
    public static class GuildLoopService
    {
        public const string RunGuildLoopNowCommand = "RunGuildLoopNow";

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
    }
}
