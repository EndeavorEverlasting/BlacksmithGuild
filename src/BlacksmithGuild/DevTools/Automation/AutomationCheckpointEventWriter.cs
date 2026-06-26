using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Automation
{
    public static class AutomationCheckpointEventWriter
    {
        private static readonly object Sync = new object();
        private static readonly string EventPath =
            Path.Combine(BasePath.Name, AutomationCheckpointEvent.FileName);

        public static string PathForTests => EventPath;

        public static void Append(AutomationCheckpointEvent checkpointEvent)
        {
            if (checkpointEvent == null)
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

                    File.AppendAllText(EventPath, Serialize(checkpointEvent) + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG AUTOMATION] checkpoint event write failed: {ex.Message}", showInGame: false);
            }
        }

        private static string Serialize(AutomationCheckpointEvent e)
        {
            var sb = new StringBuilder();
            sb.Append("{");
            AppendNumber(sb, "schemaVersion", AutomationCheckpointEvent.SchemaVersion, true);
            AppendString(sb, "eventId", e.EventId);
            AppendString(sb, "sessionId", e.SessionId);
            AppendString(sb, "runId", e.RunId);
            AppendString(sb, "atUtc", e.AtUtc.ToString("o"));
            AppendString(sb, "eventType", e.EventType);
            AppendString(sb, "checkpointName", e.CheckpointName);
            AppendBool(sb, "isTerminal", e.IsTerminal);
            AppendString(sb, "terminalState", e.TerminalState);
            AppendString(sb, "phase", e.Phase);
            AppendString(sb, "source", e.Source);
            AppendString(sb, "reason", e.Reason);
            AppendBool(sb, "messageShownInGame", e.MessageShownInGame);
            AppendString(sb, "messageText", e.MessageText);
            AppendString(sb, "relatedEventId", e.RelatedEventId);
            if (!string.IsNullOrWhiteSpace(e.DetailsJson))
            {
                sb.Append(",\"details\":").Append(e.DetailsJson);
            }
            sb.Append("}");
            return sb.ToString();
        }

        private static void AppendString(StringBuilder sb, string name, string value, bool first = false)
        {
            if (!first)
            {
                sb.Append(",");
            }

            sb.Append("\"").Append(Escape(name)).Append("\":");
            if (value == null)
            {
                sb.Append("null");
                return;
            }

            sb.Append("\"").Append(Escape(value)).Append("\"");
        }

        private static void AppendBool(StringBuilder sb, string name, bool value)
        {
            sb.Append(",\"").Append(Escape(name)).Append("\":").Append(value.ToString().ToLowerInvariant());
        }

        private static void AppendNumber(StringBuilder sb, string name, int value, bool first = false)
        {
            if (!first)
            {
                sb.Append(",");
            }

            sb.Append("\"").Append(Escape(name)).Append("\":").Append(value);
        }

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
    }
}
