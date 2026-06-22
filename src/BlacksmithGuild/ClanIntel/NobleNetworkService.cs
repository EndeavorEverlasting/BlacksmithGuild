using System;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.ClanIntel
{
    public static class NobleNetworkService
    {
        public const string AnalyzeNobleNetworkCommand = "AnalyzeNobleNetwork";
        public const string ShowNobleNetworkCommand = "ShowNobleNetwork";

        private static NobleNetworkReport _lastReport;

        public static bool AnalyzeNow(string source = AnalyzeNobleNetworkCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG NOBLE: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            var targets = NobleNetworkScanner.Scan();
            var report = new NobleNetworkReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                Targets = targets,
                TopTarget = targets.Count > 0 ? targets[0] : null,
                Verdict = targets.Count > 0
                    ? $"ranked {targets.Count} noble target(s); top: {targets[0].TargetNoble}"
                    : "no strategic noble targets in scan radius"
            };

            _lastReport = report;
            ClanJsonWriter.WriteNobleNetwork(report);
            var formatter = ReportFormatter.BeginReport("NOBLE NETWORK", source, "noble-network");
            if (report.TopTarget != null)
            {
                formatter.Line("top", $"{report.TopTarget.TargetNoble} ({report.TopTarget.StrategicValue})");
            }

            formatter.SummaryLine(report.Verdict);
            formatter.EndReport();
            InGameNotice.Info($"TBG NOBLE: {report.Verdict}");
            return true;
        }

        public static bool ShowLast()
        {
            if (_lastReport == null)
            {
                return AnalyzeNow(ShowNobleNetworkCommand);
            }

            ClanJsonWriter.WriteNobleNetwork(_lastReport);
            InGameNotice.Info($"TBG NOBLE: {_lastReport.Verdict}");
            return true;
        }

        public static NobleNetworkReport LastReport => _lastReport;
    }
}
