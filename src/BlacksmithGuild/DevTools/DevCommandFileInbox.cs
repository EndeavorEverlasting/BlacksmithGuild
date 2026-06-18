using System;
using System.IO;
using System.Text.RegularExpressions;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    public static class DevCommandFileInbox
    {
        private static readonly string InboxPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_CommandInbox.json");

        private static long _lastSeenWriteTicks = -1;
        private static int _lastSeenSequence = -1;

        public static void Poll()
        {
            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            try
            {
                if (!File.Exists(InboxPath))
                {
                    return;
                }

                var writeTicks = File.GetLastWriteTimeUtc(InboxPath).Ticks;
                if (writeTicks == _lastSeenWriteTicks)
                {
                    return;
                }

                var json = File.ReadAllText(InboxPath);
                if (!TryParseInbox(json, out var sequence, out var command, out var source))
                {
                    return;
                }

                if (sequence <= _lastSeenSequence && _lastSeenSequence >= 0)
                {
                    _lastSeenWriteTicks = writeTicks;
                    return;
                }

                _lastSeenWriteTicks = writeTicks;
                _lastSeenSequence = sequence;

                var commandSource = string.IsNullOrWhiteSpace(source) ? "file-inbox" : source;
                DevCommandBus.TryRun(command, commandSource);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG INBOX] Failed to read command inbox: {ex.Message}", showInGame: false);
            }
        }

        private static bool TryParseInbox(string json, out int sequence, out string command, out string source)
        {
            sequence = -1;
            command = null;
            source = null;

            if (string.IsNullOrWhiteSpace(json))
            {
                return false;
            }

            var sequenceMatch = Regex.Match(json, "\"sequence\"\\s*:\\s*(\\d+)", RegexOptions.IgnoreCase);
            if (sequenceMatch.Success)
            {
                int.TryParse(sequenceMatch.Groups[1].Value, out sequence);
            }

            var commandMatch = Regex.Match(json, "\"command\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.IgnoreCase);
            if (!commandMatch.Success)
            {
                return false;
            }

            command = commandMatch.Groups[1].Value;

            var sourceMatch = Regex.Match(json, "\"source\"\\s*:\\s*\"([^\"]+)\"", RegexOptions.IgnoreCase);
            if (sourceMatch.Success)
            {
                source = sourceMatch.Groups[1].Value;
            }

            return !string.IsNullOrWhiteSpace(command);
        }
    }
}
