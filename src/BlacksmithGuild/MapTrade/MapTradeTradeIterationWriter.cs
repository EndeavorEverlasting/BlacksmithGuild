using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    // One proven buy/sell iteration. A trade iteration is only "proven" when both a real gold delta
    // and a real inventory delta are observed and FakeGameplayDelta is false. The offline economic-loop
    // certifier counts proven iterations toward the 10-trade target; faked or zero-delta rows are rejected.
    public sealed class MapTradeIterationRecord
    {
        public const int SchemaVersion = 1;

        public int Iteration { get; set; }
        public string SessionId { get; set; }
        public int? CycleId { get; set; }
        public string ItemName { get; set; }
        public string Direction { get; set; }
        public int GoldBefore { get; set; }
        public int GoldAfter { get; set; }
        public int InventoryBefore { get; set; }
        public int InventoryAfter { get; set; }
        public bool FakeGameplayDelta { get; set; }

        public int GoldDelta => GoldAfter - GoldBefore;
        public int InventoryDelta => InventoryAfter - InventoryBefore;
    }

    // Append-only writer for BlacksmithGuild_TradeIterations.jsonl (best-effort, never throws).
    public static class MapTradeTradeIterationWriter
    {
        public const string FileName = "BlacksmithGuild_TradeIterations.jsonl";

        private static readonly object Sync = new object();
        private static readonly string EventPath = Path.Combine(BasePath.Name, FileName);

        public static string PathForTests => EventPath;

        public static void Append(MapTradeIterationRecord record)
        {
            if (record == null)
            {
                return;
            }

            try
            {
                lock (Sync)
                {
                    var dir = Path.GetDirectoryName(EventPath);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                    }

                    File.AppendAllText(EventPath, Serialize(record) + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                DevTools.DebugLogger.Test($"[TBG TRADE] trade iteration write failed: {ex.Message}", showInGame: false);
            }
        }

        private static string Serialize(MapTradeIterationRecord r)
        {
            var sb = new StringBuilder();
            sb.Append("{");
            sb.Append("\"schemaVersion\":").Append(MapTradeIterationRecord.SchemaVersion);
            sb.Append(",\"iteration\":").Append(r.Iteration);
            AppendString(sb, "sessionId", r.SessionId);
            if (r.CycleId.HasValue)
            {
                sb.Append(",\"cycleId\":").Append(r.CycleId.Value);
            }

            AppendString(sb, "atUtc", DateTime.UtcNow.ToString("o"));
            AppendString(sb, "itemName", r.ItemName);
            AppendString(sb, "direction", r.Direction);
            sb.Append(",\"goldBefore\":").Append(r.GoldBefore);
            sb.Append(",\"goldAfter\":").Append(r.GoldAfter);
            sb.Append(",\"goldDelta\":").Append(r.GoldDelta);
            sb.Append(",\"inventoryBefore\":").Append(r.InventoryBefore);
            sb.Append(",\"inventoryAfter\":").Append(r.InventoryAfter);
            sb.Append(",\"inventoryDelta\":").Append(r.InventoryDelta);
            sb.Append(",\"fakeGameplayDelta\":").Append(r.FakeGameplayDelta.ToString().ToLowerInvariant());
            sb.Append("}");
            return sb.ToString();
        }

        private static void AppendString(StringBuilder sb, string name, string value)
        {
            sb.Append(",\"").Append(Escape(name)).Append("\":");
            if (value == null)
            {
                sb.Append("null");
                return;
            }

            sb.Append("\"").Append(Escape(value)).Append("\"");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
    }
}
