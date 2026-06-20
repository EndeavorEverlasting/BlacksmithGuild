using System.Collections.Generic;
using System.Text;

namespace BlacksmithGuild.Market
{
    internal static class MarketTableFormatter
    {
        private const int ItemColumnWidth = 16;
        private const int TownColumnWidth = 18;
        private const int PriceColumnWidth = 5;
        private const int SpreadColumnWidth = 7;
        private const int QtyColumnWidth = 5;
        private const int VsWorstColumnWidth = 8;

        public static string FormatHeader(params (string label, int width)[] columns)
        {
            var normalized = new (string value, int width, bool rightAlign)[columns.Length];
            for (var i = 0; i < columns.Length; i++)
            {
                normalized[i] = (columns[i].label, columns[i].width, rightAlign: false);
            }

            return FormatAlignedRow(normalized);
        }

        public static string FormatRow(params (string value, int width, bool rightAlign)[] columns)
        {
            return FormatAlignedRow(columns);
        }

        public static IEnumerable<string> FormatSpreadTable(IReadOnlyList<TradeSpreadRow> rows)
        {
            yield return FormatHeader(
                ("ITEM", ItemColumnWidth),
                ("BUY@TOWN", TownColumnWidth),
                ("BUY", PriceColumnWidth),
                ("SELL@TOWN", TownColumnWidth),
                ("SELL", PriceColumnWidth),
                ("SPREAD", SpreadColumnWidth));

            foreach (var row in rows)
            {
                yield return FormatRow(
                    (Truncate(row.ItemName, ItemColumnWidth), ItemColumnWidth, false),
                    (Truncate(row.BuyTown, TownColumnWidth), TownColumnWidth, false),
                    (row.BuyPrice.ToString(), PriceColumnWidth, true),
                    (Truncate(row.SellTown, TownColumnWidth), TownColumnWidth, false),
                    (row.SellPrice.ToString(), PriceColumnWidth, true),
                    ($"+{row.Spread}", SpreadColumnWidth, true));
            }
        }

        public static IEnumerable<string> FormatInventoryTable(IReadOnlyList<InventorySellRow> rows)
        {
            yield return FormatHeader(
                ("ITEM", ItemColumnWidth),
                ("QTY", QtyColumnWidth),
                ("SELL@TOWN", TownColumnWidth),
                ("SELL", PriceColumnWidth),
                ("VS-WORST", VsWorstColumnWidth));

            foreach (var row in rows)
            {
                yield return FormatRow(
                    (Truncate(row.ItemName, ItemColumnWidth), ItemColumnWidth, false),
                    (row.Quantity.ToString(), QtyColumnWidth, true),
                    (Truncate(row.BestSellTown, TownColumnWidth), TownColumnWidth, false),
                    (row.BestSellPrice.ToString(), PriceColumnWidth, true),
                    ($"+{row.SpreadVsWorst}", VsWorstColumnWidth, true));
            }
        }

        private static string FormatAlignedRow(
            (string value, int width, bool rightAlign)[] columns)
        {
            var builder = new StringBuilder();
            for (var i = 0; i < columns.Length; i++)
            {
                if (i > 0)
                {
                    builder.Append(columns[i].rightAlign ? ' ' : "  ");
                }

                var column = columns[i];
                builder.Append(Pad(column.value, column.width, column.rightAlign));
            }

            return builder.ToString();
        }

        private static string Pad(string value, int width, bool rightAlign = false)
        {
            value = value ?? string.Empty;
            if (value.Length > width)
            {
                return Truncate(value, width);
            }

            return rightAlign
                ? value.PadLeft(width)
                : value.PadRight(width);
        }

        private static string Truncate(string value, int max)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            if (value.Length <= max)
            {
                return value;
            }

            if (max <= 1)
            {
                return value.Substring(0, max);
            }

            var candidate = value.Substring(0, max - 1);
            var lastSpace = candidate.LastIndexOf(' ');
            if (lastSpace > max / 2)
            {
                candidate = candidate.Substring(0, lastSpace);
            }

            return candidate + "\u2026";
        }
    }
}
