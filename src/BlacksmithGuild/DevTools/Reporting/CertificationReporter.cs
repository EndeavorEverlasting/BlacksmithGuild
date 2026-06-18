using System;
using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class CertificationReporter
    {
        private delegate bool TryGetCheckDelegate(
            string name,
            out string status,
            out string at,
            out string message);

        public static void WriteSprint001Report(string source = "CertificationTracker")
        {
            WriteCertReport(
                $"SPRINT {CertificationTracker.SprintId} CERTIFICATION",
                source,
                $"cert-{CertificationTracker.SprintId}",
                CertificationTracker.RequiredCheckNames,
                CertificationTracker.TryGetCheck,
                CertificationTracker.CountPassed(),
                CertificationTracker.RequiredCheckNames.Count);
        }

        public static void WriteSprint002Report(string source = "Sprint002CertificationTracker")
        {
            WriteCertReport(
                $"SPRINT {Sprint002CertificationTracker.SprintId} CERTIFICATION",
                source,
                $"cert-{Sprint002CertificationTracker.SprintId}",
                Sprint002CertificationTracker.RequiredCheckNames,
                Sprint002CertificationTracker.TryGetCheck,
                Sprint002CertificationTracker.CountPassed(),
                Sprint002CertificationTracker.RequiredCheckNames.Count);
        }

        public static void WriteTreasuryRetestReport(
            bool snapshotSucceeded,
            int snapshotGeneration,
            int deltaCount,
            int suspiciousCount,
            int criticalCount,
            string source = "TreasurySnapshotNow")
        {
            var report = ReportFormatter.BeginCertReport("003B TREASURY RETEST", source, "cert-003b");

            if (snapshotSucceeded)
            {
                report.Verdict(ReportVerdict.Pass, "TreasurySnapshotNow completed");
                report.Verdict(ReportVerdict.Pass, $"snapshotGeneration={snapshotGeneration}");
            }
            else
            {
                report.Verdict(ReportVerdict.Fail, "TreasurySnapshotNow blocked or failed");
            }

            if (deltaCount == 0)
            {
                report.Verdict(ReportVerdict.Warn, "No treasury deltas detected");
            }
            else if (criticalCount > 0)
            {
                report.Verdict(ReportVerdict.Warn, $"{criticalCount} critical anomal{(criticalCount == 1 ? "y" : "ies")} detected");
            }
            else if (suspiciousCount > 0)
            {
                report.Verdict(ReportVerdict.Warn, $"{suspiciousCount} suspicious delta(s) detected");
            }
            else
            {
                report.Verdict(ReportVerdict.Pass, $"{deltaCount} treasury delta(s) within observed thresholds");
            }

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_TreasuryWatch.json");

            report.EndReport(emitInGame: false, emitToFile: true);
        }

        private static void WriteCertReport(
            string title,
            string source,
            string reportIdSlug,
            IReadOnlyList<string> checkNames,
            TryGetCheckDelegate tryGetCheck,
            int passed,
            int required)
        {
            var report = ReportFormatter.BeginCertReport(title, source, reportIdSlug);

            report.Section("Summary");
            report.Line("completed", $"{passed}/{required}");

            report.Section("Checks");
            foreach (var checkName in checkNames)
            {
                if (tryGetCheck(checkName, out var status, out _, out var message))
                {
                    var detail = string.IsNullOrEmpty(message) ? checkName : $"{checkName}: {message}";
                    report.Verdict(MapStatusToVerdict(status), detail);
                }
                else
                {
                    report.Verdict(ReportVerdict.Unknown, $"{checkName}: PENDING");
                }
            }

            report.EndReport(emitInGame: false, emitToFile: true);
        }

        private static ReportVerdict MapStatusToVerdict(string status)
        {
            if (string.Equals(status, "PASS", StringComparison.OrdinalIgnoreCase))
            {
                return ReportVerdict.Pass;
            }

            if (string.Equals(status, "FAIL", StringComparison.OrdinalIgnoreCase))
            {
                return ReportVerdict.Fail;
            }

            if (string.Equals(status, "BLOCKED", StringComparison.OrdinalIgnoreCase))
            {
                return ReportVerdict.Warn;
            }

            if (string.Equals(status, "IN_PROGRESS", StringComparison.OrdinalIgnoreCase))
            {
                return ReportVerdict.Info;
            }

            return ReportVerdict.Unknown;
        }
    }
}
