using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Shared elapsed-time gate for every recurring runtime worker. Campaign tick and frame rates
    /// may vary; worker cadence and its evidence must not.
    /// </summary>
    public static class RuntimeCadenceGate
    {
        public const string ShowRuntimeCadenceCommand = "ShowRuntimeCadence";
        public const string ReportFileName = "BlacksmithGuild_RuntimeCadence.json";

        private static readonly object Sync = new object();
        private static readonly Dictionary<string, GateState> Gates =
            new Dictionary<string, GateState>(StringComparer.Ordinal);
        private static long _lastReportWriteTimestamp;

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);

        public static bool TryEnter(string worker, int intervalMs, int hardMinimumMs = 25)
        {
            if (string.IsNullOrWhiteSpace(worker))
            {
                return false;
            }

            var now = DateTime.UtcNow;
            var timestamp = Stopwatch.GetTimestamp();
            var interval = Math.Max(hardMinimumMs, intervalMs);
            var shouldWrite = false;
            lock (Sync)
            {
                var state = GetOrCreate(worker);
                state.AttemptedCount++;
                state.ConfiguredIntervalMs = interval;
                state.LastAttemptUtc = now;
                if (timestamp < state.NextDueTimestamp)
                {
                    state.ThrottledCount++;
                    return false;
                }

                state.ExecutedCount++;
                state.LastExecutedUtc = now;
                state.NextDueTimestamp = AddMilliseconds(timestamp, interval);
                state.NextDueUtc = now.AddMilliseconds(interval);
                shouldWrite = ElapsedMilliseconds(_lastReportWriteTimestamp, timestamp)
                    >= Math.Max(1000, DevToolsConfig.RuntimeCadenceReportWriteIntervalMs);
                if (shouldWrite)
                {
                    _lastReportWriteTimestamp = timestamp;
                }
            }

            if (shouldWrite)
            {
                WriteReportSafe();
            }

            return true;
        }

        public static void DeferNext(string worker, int intervalMs, int hardMinimumMs = 25)
        {
            if (string.IsNullOrWhiteSpace(worker))
            {
                return;
            }

            var now = DateTime.UtcNow;
            var timestamp = Stopwatch.GetTimestamp();
            lock (Sync)
            {
                var state = GetOrCreate(worker);
                state.ConfiguredIntervalMs = Math.Max(hardMinimumMs, intervalMs);
                state.NextDueTimestamp = AddMilliseconds(timestamp, state.ConfiguredIntervalMs);
                state.NextDueUtc = now.AddMilliseconds(state.ConfiguredIntervalMs);
            }
        }

        public static void Reset(string worker)
        {
            if (string.IsNullOrWhiteSpace(worker))
            {
                return;
            }

            lock (Sync)
            {
                GetOrCreate(worker).NextDueTimestamp = 0;
                GetOrCreate(worker).NextDueUtc = DateTime.MinValue;
            }
        }

        public static void ResetAll()
        {
            lock (Sync)
            {
                Gates.Clear();
                _lastReportWriteTimestamp = 0;
            }
        }

        public static bool ShowNow()
        {
            WriteReportSafe();
            InGameNotice.Info("TBG cadence report refreshed.");
            return true;
        }

        private static GateState GetOrCreate(string worker)
        {
            if (!Gates.TryGetValue(worker, out var state))
            {
                state = new GateState { Worker = worker };
                Gates[worker] = state;
            }

            return state;
        }

        private static void WriteReportSafe()
        {
            try
            {
                List<GateState> states;
                lock (Sync)
                {
                    states = Gates.Values
                        .OrderBy(state => state.Worker)
                        .Select(state => state.Clone())
                        .ToList();
                }

                RuntimeProofContext.WriteAllTextAtomic(ReportPath, Serialize(states));
            }
            catch (Exception ex)
            {
                DebugLogger.Test("[TBG CADENCE] report write failed: " + ex.Message, showInGame: false);
            }
        }

        private static string Serialize(List<GateState> states)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("  \"schemaVersion\": \"TbgRuntimeCadence.v1\",");
            sb.AppendLine("  \"generatedUtc\": \"" + DateTime.UtcNow.ToString("o") + "\",");
            sb.AppendLine("  \"reportWriteIntervalMs\": " + DevToolsConfig.RuntimeCadenceReportWriteIntervalMs + ",");
            sb.AppendLine("  \"workers\": [");
            for (var index = 0; index < states.Count; index++)
            {
                var state = states[index];
                sb.AppendLine("    {");
                sb.AppendLine("      \"worker\": \"" + Escape(state.Worker) + "\",");
                sb.AppendLine("      \"configuredIntervalMs\": " + state.ConfiguredIntervalMs + ",");
                sb.AppendLine("      \"attemptedCount\": " + state.AttemptedCount + ",");
                sb.AppendLine("      \"executedCount\": " + state.ExecutedCount + ",");
                sb.AppendLine("      \"throttledCount\": " + state.ThrottledCount + ",");
                sb.AppendLine("      \"lastAttemptUtc\": " + JsonDate(state.LastAttemptUtc) + ",");
                sb.AppendLine("      \"lastExecutedUtc\": " + JsonDate(state.LastExecutedUtc) + ",");
                sb.AppendLine("      \"nextDueUtc\": " + JsonDate(state.NextDueUtc));
                sb.Append(index < states.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string JsonDate(DateTime value)
        {
            return value == DateTime.MinValue ? "null" : "\"" + value.ToString("o") + "\"";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private static long AddMilliseconds(long timestamp, int milliseconds)
        {
            return timestamp + (long)(milliseconds * (double)Stopwatch.Frequency / 1000d);
        }

        private static double ElapsedMilliseconds(long startedAt, long endedAt)
        {
            if (startedAt <= 0 || endedAt < startedAt)
            {
                return double.MaxValue;
            }

            return (endedAt - startedAt) * 1000d / Stopwatch.Frequency;
        }

        private sealed class GateState
        {
            public string Worker;
            public int ConfiguredIntervalMs;
            public long AttemptedCount;
            public long ExecutedCount;
            public long ThrottledCount;
            public DateTime LastAttemptUtc;
            public DateTime LastExecutedUtc;
            public DateTime NextDueUtc;
            public long NextDueTimestamp;

            public GateState Clone()
            {
                return (GateState)MemberwiseClone();
            }
        }
    }
}
