using System;
using System.IO;
using System.Text.RegularExpressions;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Automation
{
    public static class AutomationPreviousRunNotice
    {
        public static void TryShow()
        {
            try
            {
                var path = Path.Combine(BasePath.Name, AutomationCheckpointEvent.FileName);
                if (!File.Exists(path))
                {
                    return;
                }

                var lines = File.ReadAllLines(path);
                var terminalLine = default(string);
                var terminalEventId = default(string);

                foreach (var line in lines)
                {
                    if (!IsTerminalLine(line))
                    {
                        continue;
                    }

                    terminalLine = line;
                    terminalEventId = MatchString(line, "eventId");
                }

                if (string.IsNullOrEmpty(terminalLine) || string.IsNullOrEmpty(terminalEventId))
                {
                    return;
                }

                foreach (var line in lines)
                {
                    if (line.IndexOf(AutomationCheckpointEvent.PreviousRunTerminalNotice, StringComparison.Ordinal) >= 0
                        && string.Equals(MatchString(line, "relatedEventId"), terminalEventId, StringComparison.Ordinal))
                    {
                        return;
                    }
                }

                var state = MatchString(terminalLine, "terminalState") ?? "unknown";
                var reason = MatchString(terminalLine, "reason") ?? MatchString(terminalLine, "checkpointName") ?? "unknown";
                var message = $"Previous automation run ended: {state} ({reason})";
                InGameNotice.Warn(message);
                AutomationCheckpointEventWriter.Append(new AutomationCheckpointEvent
                {
                    EventType = AutomationCheckpointEvent.EventCheckpointReached,
                    CheckpointName = AutomationCheckpointEvent.PreviousRunTerminalNotice,
                    Reason = reason,
                    MessageShownInGame = true,
                    MessageText = message,
                    RelatedEventId = terminalEventId
                });
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG AUTOMATION] previous-run notice failed: {ex.Message}", showInGame: false);
            }
        }

        private static bool IsTerminalLine(string line)
        {
            return line != null
                && line.IndexOf("\"isTerminal\":true", StringComparison.OrdinalIgnoreCase) >= 0
                && line.IndexOf("\"eventType\":\"finalized_", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static string MatchString(string json, string field)
        {
            if (string.IsNullOrEmpty(json))
            {
                return null;
            }

            var match = Regex.Match(
                json,
                "\"" + Regex.Escape(field) + "\"\\s*:\\s*\"([^\"]*)\"",
                RegexOptions.IgnoreCase);
            return match.Success ? match.Groups[1].Value : null;
        }
    }
}
