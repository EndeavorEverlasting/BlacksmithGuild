using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class TickCostProfiler
    {
        public const string ReportFileName = "BlacksmithGuild_TickCostProfiler.json";

        private static readonly object Sync = new object();
        private static readonly Dictionary<string, SegmentStats> Segments = new Dictionary<string, SegmentStats>();
        private static DateTime _lastWriteUtc = DateTime.MinValue;
        private static int _slowObservationSerial;

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);

        public static long Start()
        {
            return DevToolsConfig.TickCostProfilerEnabled
                ? Stopwatch.GetTimestamp()
                : 0L;
        }

        public static void Stop(string segmentName, long startedAt)
        {
            if (!DevToolsConfig.TickCostProfilerEnabled || startedAt <= 0L || string.IsNullOrWhiteSpace(segmentName))
            {
                return;
            }

            var elapsedTicks = Stopwatch.GetTimestamp() - startedAt;
            var elapsedMs = elapsedTicks * 1000.0 / Stopwatch.Frequency;
            Record(segmentName, elapsedMs);
        }

        public static void Reset()
        {
            lock (Sync)
            {
                Segments.Clear();
                _lastWriteUtc = DateTime.MinValue;
                _slowObservationSerial = 0;
            }
        }

        private static void Record(string segmentName, double elapsedMs)
        {
            var thresholdMs = Math.Max(0.1, DevToolsConfig.TickCostProfilerSlowThresholdMs);
            var shouldWrite = false;
            lock (Sync)
            {
                SegmentStats stats;
                if (!Segments.TryGetValue(segmentName, out stats))
                {
                    stats = new SegmentStats { Name = segmentName };
                    Segments.Add(segmentName, stats);
                }

                stats.Count++;
                stats.TotalMs += elapsedMs;
                stats.LastMs = elapsedMs;
                stats.LastObservedUtc = DateTime.UtcNow.ToString("o");
                if (elapsedMs > stats.MaxMs)
                {
                    stats.MaxMs = elapsedMs;
                    stats.MaxObservedUtc = stats.LastObservedUtc;
                }

                if (elapsedMs >= thresholdMs)
                {
                    stats.SlowCount++;
                    stats.LastSlowMs = elapsedMs;
                    stats.LastSlowObservedUtc = stats.LastObservedUtc;
                    _slowObservationSerial++;
                    shouldWrite = ShouldWriteNow();
                }

                if (DevToolsConfig.TickCostProfilerWritePeriodicSnapshots && ShouldWriteNow())
                {
                    shouldWrite = true;
                }
            }

            if (shouldWrite)
            {
                WriteReportSafe();
            }
        }

        private static bool ShouldWriteNow()
        {
            var intervalMs = Math.Max(250, DevToolsConfig.TickCostProfilerMinWriteIntervalMs);
            return (DateTime.UtcNow - _lastWriteUtc).TotalMilliseconds >= intervalMs;
        }

        private static void WriteReportSafe()
        {
            try
            {
                lock (Sync)
                {
                    File.WriteAllText(ReportPath, Serialize(), Encoding.UTF8);
                    _lastWriteUtc = DateTime.UtcNow;
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test("[TBG TICK PROFILER] write failed: " + ex.Message, showInGame: false);
            }
        }

        private static string Serialize()
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("  \"generatedUtc\": \"" + Escape(DateTime.UtcNow.ToString("o")) + "\",");
            sb.AppendLine("  \"report\": \"campaign_tick_cost_profiler\",");
            sb.AppendLine("  \"slowThresholdMs\": " + Number(DevToolsConfig.TickCostProfilerSlowThresholdMs) + ",");
            sb.AppendLine("  \"minWriteIntervalMs\": " + DevToolsConfig.TickCostProfilerMinWriteIntervalMs + ",");
            sb.AppendLine("  \"slowObservationSerial\": " + _slowObservationSerial + ",");
            sb.AppendLine("  \"segments\": [");

            var index = 0;
            foreach (var pair in Segments)
            {
                var stats = pair.Value;
                sb.AppendLine("    {");
                sb.AppendLine("      \"name\": \"" + Escape(stats.Name) + "\",");
                sb.AppendLine("      \"count\": " + stats.Count + ",");
                sb.AppendLine("      \"slowCount\": " + stats.SlowCount + ",");
                sb.AppendLine("      \"totalMs\": " + Number(stats.TotalMs) + ",");
                sb.AppendLine("      \"averageMs\": " + Number(stats.Count == 0 ? 0.0 : stats.TotalMs / stats.Count) + ",");
                sb.AppendLine("      \"maxMs\": " + Number(stats.MaxMs) + ",");
                sb.AppendLine("      \"lastMs\": " + Number(stats.LastMs) + ",");
                sb.AppendLine("      \"lastSlowMs\": " + Number(stats.LastSlowMs) + ",");
                sb.AppendLine("      \"lastObservedUtc\": \"" + Escape(stats.LastObservedUtc) + "\",");
                sb.AppendLine("      \"lastSlowObservedUtc\": \"" + Escape(stats.LastSlowObservedUtc) + "\",");
                sb.AppendLine("      \"maxObservedUtc\": \"" + Escape(stats.MaxObservedUtc) + "\"");
                sb.Append(index < Segments.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
                index++;
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string Number(double value)
        {
            return value.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
        }

        private sealed class SegmentStats
        {
            public string Name;
            public long Count;
            public long SlowCount;
            public double TotalMs;
            public double MaxMs;
            public double LastMs;
            public double LastSlowMs;
            public string LastObservedUtc;
            public string LastSlowObservedUtc;
            public string MaxObservedUtc;
        }
    }
}
