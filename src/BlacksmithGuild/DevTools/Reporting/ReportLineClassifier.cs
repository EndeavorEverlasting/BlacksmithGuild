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
        Verdict,
        HorseBuy,
        HorseSell,
        HorseHold,
        HorseWatch,
        HorseCapacityWarn,
        HorseBlocked,
        HorsePremium
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
                || line == AdvisoryReportText.MaterialGapsHeader
                || line == AdvisoryReportText.SmithingCrewHeader)
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

            if (line.StartsWith("TBG HORSE BUY:", StringComparison.Ordinal))
            {
                return ReportLineKind.HorseBuy;
            }

            if (line.StartsWith("TBG HORSE SELL:", StringComparison.Ordinal))
            {
                return ReportLineKind.HorseSell;
            }

            if (line.StartsWith("TBG HORSE HOLD:", StringComparison.Ordinal))
            {
                return line.IndexOf("[NOBLE]", StringComparison.OrdinalIgnoreCase) >= 0
                    ? ReportLineKind.HorsePremium
                    : ReportLineKind.HorseHold;
            }

            if (line.StartsWith("TBG HORSE WATCH:", StringComparison.Ordinal))
            {
                return ReportLineKind.HorseWatch;
            }

            if (line.StartsWith("TBG HORSE BLOCKED:", StringComparison.Ordinal))
            {
                return ReportLineKind.HorseBlocked;
            }

            if (line.StartsWith("TBG HORSE:", StringComparison.Ordinal)
                && line.IndexOf("buy pack animals first", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return ReportLineKind.HorseCapacityWarn;
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
                case ReportLineKind.HorseBuy:
                    return ReportColors.Success;
                case ReportLineKind.HorseSell:
                case ReportLineKind.HorseCapacityWarn:
                    return ReportColors.Warn;
                case ReportLineKind.HorseHold:
                    return ReportColors.Hold;
                case ReportLineKind.HorseWatch:
                    return ReportColors.Info;
                case ReportLineKind.HorseBlocked:
                    return ReportColors.Fail;
                case ReportLineKind.HorsePremium:
                    return ReportColors.Premium;
                default:
                    return ReportColors.Info;
            }
        }

        public static Color ColorFor(ReportLineStyle style)
        {
            switch (style)
            {
                case ReportLineStyle.Buy:
                    return ReportColors.Success;
                case ReportLineStyle.Sell:
                case ReportLineStyle.CapacityWarn:
                    return ReportColors.Warn;
                case ReportLineStyle.Hold:
                    return ReportColors.Hold;
                case ReportLineStyle.Watch:
                case ReportLineStyle.Info:
                    return ReportColors.Info;
                case ReportLineStyle.Blocked:
                    return ReportColors.Fail;
                case ReportLineStyle.Premium:
                    return ReportColors.Premium;
                default:
                    return ReportColors.Info;
            }
        }
    }
}
