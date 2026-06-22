using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.ClanIntel
{
    public static class MarriageCandidateService
    {
        public const string AnalyzeMarriageCandidatesCommand = "AnalyzeMarriageCandidates";

        private static MarriageCandidatesReport _lastReport;

        public static bool AnalyzeNow(string source = AnalyzeMarriageCandidatesCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG MARRIAGE: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            var candidates = MarriageCandidateScanner.Scan();
            var report = new MarriageCandidatesReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                Candidates = candidates,
                TopCandidate = candidates.Count > 0 ? candidates[0] : null,
                Verdict = candidates.Count > 0
                    ? $"found {candidates.Count} candidate(s); top: {candidates[0].Candidate} ({candidates[0].Category})"
                    : "no eligible marriage candidates in scan radius"
            };

            _lastReport = report;
            ClanJsonWriter.WriteMarriageCandidates(report);
            var formatter = ReportFormatter.BeginReport("MARRIAGE CANDIDATES", source, "marriage-candidates");
            foreach (var c in candidates.Take(3))
            {
                formatter.TableLine($"- {c.Candidate}: {c.Category} ({c.RouteSafety})");
            }

            formatter.SummaryLine(report.Verdict);
            formatter.EndReport();
            InGameNotice.Info($"TBG MARRIAGE: {report.Verdict}");
            return true;
        }

        public static MarriageCandidatesReport LastReport => _lastReport;
    }
}
