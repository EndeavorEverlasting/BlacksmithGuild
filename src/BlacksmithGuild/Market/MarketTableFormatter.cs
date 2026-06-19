using System.Collections.Generic;
using System.Text;

namespace BlacksmithGuild.Market
{
    internal static class MarketTableFormatter
    {
        public static string FormatHeader(params (string label, int width)[] columns)
        {
            var builder = new StringBuilder();
            for (var i = 0; i < columns.Length; i++)
            {
                if (i > 0)
                {
                    builder.Append(' ');
                }

                builder.Append(Pad(columns[i].label, columns[i].width));
            }

            return builder.ToString();
        }

        public static string FormatRow(params (string value, int width, bool rightAlign)[] columns)
        {
            var builder = new StringBuilder();
            for (var i = 0; i < columns.Length; i++)
            {
                if (i > 0)
                {
                    builder.Append(' ');
                }

                builder.Append(Pad(columns[i].value, columns[i].width, columns[i].rightAlign));
            }

            return builder.ToString();
        }

        public static IEnumerable<string> FormatSpreadTable(IReadOnlyList<TradeSpreadRow> rows)
        {
            yield return FormatHeader(
                ("ITEM", 14),
                ("BUY@TOWN", 14),
                ("BUY", 5),
                ("SELL@TOWN", 14),
                ("SELL", 5),
                ("SPREAD", 7));

            foreach (var row in rows)
            {
                yield return FormatRow(
                    (Truncate(row.ItemName, 14), 14, false),
                    (Truncate(row.BuyTown, 14), 14, false),
                    (row.BuyPrice.ToString(), 5, true),
                    (Truncate(row.SellTown, 14), 14, false),
                    (row.SellPrice.ToString(), 5, true),
                    ($"+{row.Spread}", 7, true));
            }
        }

        public static IEnumerable<string> FormatInventoryTable(IReadOnlyList<InventorySellRow> rows)
        {
            yield return FormatHeader(
                ("ITEM", 14),
                ("QTY", 5),
                ("SELL@TOWN", 14),
                ("SELL", 5),
                ("VS-WORST", 8));

            foreach (var row in rows)
            {
                yield return FormatRow(
                    (Truncate(row.ItemName, 14), 14, false),
                    (row.Quantity.ToString(), 5, true),
                    (Truncate(row.BestSellTown, 14), 14, false),
                    (row.BestSellPrice.ToString(), 5, true),
                    ($"+{row.SpreadVsWorst}", 8, true));
            }
        }

        private static string Pad(string value, int width, bool rightAlign = false)
        {
            value = value ?? string.Empty;
            if (value.Length > width)
            {
                return value.Substring(0, width);
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

            return value.Length <= max ? value : value.Substring(0, max);
        }
    }
}
