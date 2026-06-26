using System;
using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.Automation
{
    public static class AutomationUserMessageService
    {
        private static readonly Dictionary<string, DateTime> LastShownAtUtc =
            new Dictionary<string, DateTime>(StringComparer.Ordinal);

        public static void Checkpoint(
            string checkpointName,
            string message = null,
            string phase = null,
            string reason = null,
            string detailsJson = null,
            int throttleSeconds = 5)
        {
            var shown = TryShowCheckpointMessage(checkpointName, message, throttleSeconds);
            AutomationCheckpointEventWriter.Append(new AutomationCheckpointEvent
            {
                EventType = AutomationCheckpointEvent.EventCheckpointReached,
                CheckpointName = checkpointName,
                Phase = phase,
                Reason = reason,
                MessageShownInGame = shown,
                MessageText = shown ? message : null,
                DetailsJson = detailsJson
            });
        }

        public static void Terminal(
            string eventType,
            string terminalState,
            string message,
            string reason = null,
            string relatedEventId = null,
            string detailsJson = null)
        {
            ShowTerminalMessage(terminalState, message);
            AutomationCheckpointEventWriter.Append(new AutomationCheckpointEvent
            {
                EventType = eventType,
                CheckpointName = eventType,
                IsTerminal = true,
                TerminalState = terminalState,
                Reason = reason,
                MessageShownInGame = true,
                MessageText = message,
                RelatedEventId = relatedEventId,
                DetailsJson = detailsJson
            });
        }

        private static bool TryShowCheckpointMessage(string checkpointName, string message, int throttleSeconds)
        {
            if (string.IsNullOrWhiteSpace(message))
            {
                return false;
            }

            var now = DateTime.UtcNow;
            DateTime lastShown;
            if (throttleSeconds > 0
                && LastShownAtUtc.TryGetValue(checkpointName ?? string.Empty, out lastShown)
                && (now - lastShown).TotalSeconds < throttleSeconds)
            {
                return false;
            }

            LastShownAtUtc[checkpointName ?? string.Empty] = now;
            InGameNotice.Info(message);
            return true;
        }

        private static void ShowTerminalMessage(string terminalState, string message)
        {
            if (string.IsNullOrWhiteSpace(message))
            {
                return;
            }

            if (string.Equals(terminalState, "pass", StringComparison.Ordinal))
            {
                InGameNotice.Success(message);
            }
            else if (string.Equals(terminalState, "fail", StringComparison.Ordinal))
            {
                InGameNotice.Fail(message);
            }
            else
            {
                InGameNotice.Warn(message);
            }
        }
    }
}
