using System.Collections.Generic;
using System.Linq;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class AdvisoryReportSections
    {
        public static void EmitContextSummary(ReportFormatter report, MarketAdvisorySnapshot snapshot)
        {
            if (!snapshot.HasScan)
            {
                return;
            }

            report.SummaryLine(
                AdvisoryReportText.FormatContextLine(
                    snapshot.NearestTown,
                    snapshot.NearestDistance,
                    snapshot.TownsScanned));

            if (snapshot.ExpandedScanUsed)
            {
                report.SummaryLine(AdvisoryReportText.FormatExpandedScanNote());
            }
        }

        public static void EmitActionPlan(ReportFormatter report, IReadOnlyList<ActionPlanStep> steps)
        {
            if (steps == null || steps.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.ActionPlanHeader);
            foreach (var step in steps)
            {
                report.SummaryLine(AdvisoryReportText.FormatNumberedStep(step.Step, step.Text));
            }
        }

        public static void EmitBuyAtNearest(
            ReportFormatter report,
            IReadOnlyList<MarketBuyAtNearestRow> rows,
            int maxRows = 3)
        {
            if (rows == null || rows.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.BuyAtNearestHeader);
            foreach (var row in rows.Take(maxRows))
            {
                report.SummaryLine(
                    AdvisoryReportText.FormatBuyAtNearestRow(
                        row.ItemName,
                        row.BuyPrice,
                        row.SellTown,
                        row.SellPrice,
                        row.Spread,
                        AdvisoryReportText.FormatSmithTag(row.IsSmithingInput)));
            }
        }

        public static void EmitInventorySells(
            ReportFormatter report,
            IReadOnlyList<MarketInventorySellRow> rows,
            int maxRows = 2)
        {
            if (rows == null)
            {
                return;
            }

            foreach (var row in rows.Where(r => r.SpreadVsWorst > 0).Take(maxRows))
            {
                report.SummaryLine(
                    AdvisoryReportText.FormatInventorySellRow(
                        row.ItemName,
                        row.Quantity,
                        row.BestSellTown,
                        row.BestSellPrice,
                        row.SpreadVsWorst));
            }
        }

        public static void EmitTopSpreads(
            ReportFormatter report,
            IReadOnlyList<MarketSpreadRow> rows,
            int maxRows = 3)
        {
            if (rows == null || rows.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.TopSpreadsHeader);
            foreach (var row in rows.Take(maxRows))
            {
                report.SummaryLine(
                    AdvisoryReportText.FormatTopSpreadRow(
                        row.ItemName,
                        row.BuyTown,
                        row.BuyPrice,
                        row.SellTown,
                        row.SellPrice,
                        row.Spread));
            }
        }

        public static void EmitSourceHonesty(ReportFormatter report, SourceHonestyInfo info)
        {
            if (info == null)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.SourceHonestyHeader);
            report.SummaryLine(AdvisoryReportText.FormatSourceHonestyLine(info));
        }

        public static void EmitCraftNext(
            ReportFormatter report,
            IReadOnlyList<CraftCandidateRow> rows,
            int maxRows = 3)
        {
            if (rows == null || rows.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.CraftNextHeader);
            foreach (var row in rows.Take(maxRows))
            {
                report.SummaryLine(AdvisoryReportText.FormatCraftNextRow(row));
            }
        }

        public static void EmitMaterialGaps(
            ReportFormatter report,
            IReadOnlyList<MaterialGapRow> gaps)
        {
            if (gaps == null || gaps.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.MaterialGapsHeader);
            foreach (var gap in gaps)
            {
                report.SummaryLine(AdvisoryReportText.FormatMaterialGap(gap));
            }
        }

        public static void EmitSmithingCrew(
            ReportFormatter report,
            IReadOnlyList<Forge.SmithingCrewRow> crew)
        {
            if (crew == null || crew.Count == 0)
            {
                return;
            }

            report.SummaryLine(AdvisoryReportText.SmithingCrewHeader);
            foreach (var row in crew)
            {
                report.SummaryLine(
                    AdvisoryReportText.FormatSmithingCrewRow(
                        row.Rank,
                        row.HeroName,
                        row.Action,
                        row.Target,
                        row.StaminaLabel,
                        row.Reason));
            }
        }
    }
}
