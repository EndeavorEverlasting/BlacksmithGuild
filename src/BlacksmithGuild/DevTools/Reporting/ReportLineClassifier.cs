using System;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Reporting
{
    public enum ReportLineKind
    {
        Body,
        ReportHeader,
        ReportFooter,
        SectionHeader,
        ActionStep,
        Verdict
    }

    public static class ReportLineClassifier
    {
        public static ReportLineKind Classify(string line)
        {
            if (string.IsNullOrEmpty(line))
            {
                return ReportLineKind.Body;
            }

            if (line.StartsWith("========== ", StringComparison.Ordinal)
                && line.EndsWith(" ==========", StringComparison.Ordinal))
            {
                return ReportLineKind.ReportHeader;
            }

            if (string.Equals(line, ModDisplay.ReportEnd, StringComparison.Ordinal)
                || string.Equals(line, ModDisplay.CertReportEnd, StringComparison.Ordinal))
            {
                return ReportLineKind.ReportFooter;
            }

            if (line == AdvisoryReportText.ActionPlanHeader
                || line == AdvisoryReportText.BuyAtNearestHeader
                || line == AdvisoryReportText.TopSpreadsHeader
                || line == AdvisoryReportText.SourceHonestyHeader
                || line == AdvisoryReportText.CraftNextHeader
                || line == AdvisoryReportText.MaterialGapsHeader)
            {
                return ReportLineKind.SectionHeader;
            }

            if (line.Length >= 3
                && char.IsDigit(line[0])
                && line[1] == '.'
                && line[2] == ' ')
            {
                return ReportLineKind.ActionStep;
            }

            if (line.StartsWith("[PASS]", StringComparison.Ordinal)
                || line.StartsWith("[WARN]", StringComparison.Ordinal)
                || line.StartsWith("[FAIL]", StringComparison.Ordinal)
                || line.StartsWith("[INFO]", StringComparison.Ordinal)
                || line.StartsWith("[UNKNOWN]", StringComparison.Ordinal))
            {
                return ReportLineKind.Verdict;
            }

            return ReportLineKind.Body;
        }

        public static Color ColorFor(ReportLineKind kind)
        {
            switch (kind)
            {
                case ReportLineKind.ReportHeader:
                    return ReportColors.Header;
                case ReportLineKind.ReportFooter:
                    return ReportColors.Footer;
                case ReportLineKind.SectionHeader:
                    return ReportColors.Section;
                case ReportLineKind.ActionStep:
                    return ReportColors.ActionStep;
                case ReportLineKind.Verdict:
                    return ReportColors.Warn;
                default:
                    return ReportColors.Info;
            }
        }
    }
}
