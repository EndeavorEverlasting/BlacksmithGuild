using System.Globalization;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class AdvisoryReportText
    {
        public const string ActionPlanHeader = "--- ACTION PLAN ---";
        public const string BuyAtNearestHeader = "--- BUY@NEAREST ---";
        public const string TopSpreadsHeader = "--- TOP SPREADS ---";
        public const string SourceHonestyHeader = "--- SOURCE HONESTY ---";
        public const string CraftNextHeader = "--- CRAFT NEXT ---";
        public const string MaterialGapsHeader = "--- MATERIAL GAPS ---";
        public const string SmithingCrewHeader = "--- SMITHING CREW ---";

        public static string FormatRefineCharcoalStep(
            string heroName,
            int units,
            int hardwoodHave,
            string staminaLabel) =>
            $"{heroName}: refine hardwood→charcoal x{units} at smithy ({staminaLabel}; hardwood {hardwoodHave})";

        public static string FormatRefineCharcoalGap(string heroName, int units, int hardwoodHave) =>
            $"Charcoal: need more → {heroName} refine {units} hardwood→charcoal (hardwood {hardwoodHave})";

        public static string FormatBuyHardwoodForCharcoalStep(
            string townName,
            int buyPrice,
            int stock,
            int charcoalDeficit) =>
            $"Buy hardwood @ {townName} {buyPrice} (stock {stock}) to refine {charcoalDeficit} charcoal";

        public static string FormatSmithingCrewRow(
            int rank,
            string heroName,
            string action,
            string target,
            string staminaLabel,
            string reason) =>
            $"[{rank}] {heroName} | {action} | {target} | {staminaLabel} — {reason}";

        public static string FormatContextLine(string nearestTown, float nearestDistance, int townsScanned) =>
            $"nearest={nearestTown} ({nearestDistance.ToString("0.0", CultureInfo.InvariantCulture)}u) towns={townsScanned}";

        public static string FormatExpandedScanNote() =>
            "expanded scan (no routes in 30u)";

        public static string FormatNumberedStep(int step, string text) =>
            $"{step}. {text}";

        public static string FormatBuyAtNearestRow(
            string itemName,
            int buyPrice,
            string sellTown,
            int sellPrice,
            int spread,
            string smithTag)
        {
            return $"{itemName}: buy {buyPrice} -> {sellTown} {sellPrice} (+{spread}){smithTag}";
        }

        public static string FormatSmithTag(bool isSmithingInput) =>
            isSmithingInput ? " [smith]" : string.Empty;

        public static string FormatInventorySellRow(
            string itemName,
            int quantity,
            string bestSellTown,
            int bestSellPrice,
            int spreadVsWorst) =>
            $"{itemName} x{quantity} -> Sell@{bestSellTown} {bestSellPrice} (+{spreadVsWorst})";

        public static string FormatTopSpreadRow(
            string itemName,
            string buyTown,
            int buyPrice,
            string sellTown,
            int sellPrice,
            int spread) =>
            $"{itemName}: buy@{buyTown} {buyPrice} -> sell@{sellTown} {sellPrice} (+{spread})";

        public static string FormatBuyMaterialStep(
            string townName,
            string itemName,
            int buyPrice,
            int stock,
            int need,
            int have) =>
            $"Buy {itemName} x{MathMax(need - have, 1)} @ {townName} {buyPrice} (stock {stock}) — need {need}, have {have}";

        public static string FormatBuyMaterialHintStep(string nearestTown, string itemName) =>
            $"Run Ctrl+Alt+M for {itemName} prices near {nearestTown}";

        public static string FormatCraftStep(string itemName, int netProfit, string stubLabel) =>
            string.IsNullOrEmpty(stubLabel)
                ? $"Enter smithy: craft {itemName} (net +{netProfit})"
                : $"Enter smithy: craft {itemName} (net +{netProfit}) {stubLabel}";

        public static string FormatSellCraftedHint(string itemName, int estimatedValue) =>
            $"Sell {itemName} at next town (~{estimatedValue}) or keep for orders — advisory only";

        public static string FormatSourceHonestyLine(SourceHonestyInfo info)
        {
            var fallback = info.FallbackUsed ? " fallback=true" : " fallback=false";
            var marker = FormatVerdictMarker(info.Verdict);
            var message = string.IsNullOrEmpty(info.VerdictMessage) ? string.Empty : $" {info.VerdictMessage}";
            return
                $"{marker} requested={info.Requested} resolved={info.Resolved}{fallback}{message}";
        }

        public static string FormatCraftNextRow(CraftCandidateRow row)
        {
            var tag = row.IsStub ? " [stub]" : string.Empty;
            return $"{row.Name} | score {row.FinalScore:0} | net +{row.NetProfit}{tag}";
        }

        public static string FormatMaterialGap(MaterialGapRow gap)
        {
            if (!string.IsNullOrEmpty(gap.BuyHint))
            {
                return gap.BuyHint;
            }

            if (gap.Need <= gap.Have)
            {
                return $"{gap.ItemName}: need {gap.Need} have {gap.Have} — OK";
            }

            if (!string.IsNullOrEmpty(gap.BuyTown) && gap.BuyPrice.HasValue)
            {
                return
                    $"{gap.ItemName}: need {gap.Need} have {gap.Have} → buy @ {gap.BuyTown} {gap.BuyPrice.Value} (stock {gap.Stock ?? 0})";
            }

            return $"{gap.ItemName}: need {gap.Need} have {gap.Have} — shortage";
        }

        public static string FormatStubMaterialSummary(int estimatedMaterialCost) =>
            $"Materials: ~{estimatedMaterialCost} total (stub oracle — SetForgeCandidateSourceReal for real breakdown)";

        public static string FormatVerdictMarker(ReportVerdict verdict)
        {
            switch (verdict)
            {
                case ReportVerdict.Pass:
                    return "[PASS]";
                case ReportVerdict.Warn:
                    return "[WARN]";
                case ReportVerdict.Fail:
                    return "[FAIL]";
                case ReportVerdict.Unknown:
                    return "[UNKNOWN]";
                default:
                    return "[INFO]";
            }
        }

        private static int MathMax(int a, int b) => a > b ? a : b;
    }
}
