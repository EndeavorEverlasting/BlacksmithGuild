using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Automation
{
    // Append-only writer for BlacksmithGuild_BoundaryEvents.jsonl. Mirrors AutomationCheckpointEventWriter:
    // best-effort, never throws into gameplay, one compact JSON object per line.
    public static class BoundaryEventWriter
    {
        private static readonly object Sync = new object();
        private static readonly string EventPath =
            Path.Combine(BasePath.Name, BoundaryEvent.FileName);

        public static string PathForTests => EventPath;

        public static void Append(BoundaryEvent boundaryEvent)
        {
            if (boundaryEvent == null)
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

                    File.AppendAllText(EventPath, Serialize(boundaryEvent) + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG BOUNDARY] boundary event write failed: {ex.Message}", showInGame: false);
            }
        }

        private static string Serialize(BoundaryEvent e)
        {
            var sb = new StringBuilder();
            sb.Append("{");
            sb.Append("\"schemaVersion\":").Append(BoundaryEvent.SchemaVersion);
            AppendString(sb, "boundaryId", e.BoundaryId);
            AppendString(sb, "sessionId", e.SessionId);
            AppendString(sb, "sectionName", e.SectionName);
            AppendString(sb, "branchName", e.BranchName);
            if (e.CycleId.HasValue)
            {
                sb.Append(",\"cycleId\":").Append(e.CycleId.Value);
            }
            AppendString(sb, "status", e.Status);
            AppendString(sb, "startedAtUtc", e.StartedAtUtc.ToString("o"));
            AppendString(sb, "endedAtUtc", e.EndedAtUtc.HasValue ? e.EndedAtUtc.Value.ToString("o") : null);
            AppendString(sb, "failureClass", e.FailureClass);
            AppendString(sb, "reason", e.Reason);
            AppendString(sb, "source", e.Source);
            AppendRaw(sb, "evidenceFiles", string.IsNullOrWhiteSpace(e.EvidenceFilesJson) ? "[]" : e.EvidenceFilesJson);
            AppendRaw(sb, "eventIds", string.IsNullOrWhiteSpace(e.EventIdsJson) ? "[]" : e.EventIdsJson);
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

        private static void AppendRaw(StringBuilder sb, string name, string rawJson)
        {
            sb.Append(",\"").Append(Escape(name)).Append("\":").Append(rawJson);
        }

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
    }
}
