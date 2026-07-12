using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
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

        private static readonly string AckPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_CommandAck.json");

        private static long _lastSeenWriteTicks = -1;
        private static int _lastSeenSequence = -1;
        private static bool _loggedWaitingForHero;

        public static void Poll()
        {
            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch())
            {
                RuntimeTrace.LogDeferOnce(
                    "inbox_sync_forge",
                    "DevCommandFileInbox",
                    "SyncForgeStatus",
                    MapTransitionGuard.GetDeferReason());
                return;
            }

            if (!TryGetPendingInboxWrite(out var writeTicks))
            {
                return;
            }

            RuntimeTrace.RunSafe("DevCommandFileInbox", "SyncForgeStatus", () => GameSessionState.SyncForgeStatus());

            AssistReadinessEvaluator.ApplyInboxAndAssistFlags();

            if (!GameSessionState.CanPollFileInbox)
            {
                if (GameSessionState.IsCampaignLoaded && !GameSessionState.IsMainHeroReady && !_loggedWaitingForHero)
                {
                    _loggedWaitingForHero = true;
                    DebugLogger.Test("[TBG INBOX] waiting: MainHero not ready", showInGame: false);
                }

                return;
            }

            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow)
            {
                return;
            }

            _loggedWaitingForHero = false;

            try
            {
                var json = File.ReadAllText(InboxPath);
                if (!TryParseInbox(json, out var sequence, out var command, out var source))
                {
                    return;
                }

                AssistiveCommandInboxPayload.TryParseFromJson(json, out var payload);

                if (sequence <= _lastSeenSequence && _lastSeenSequence >= 0)
                {
                    _lastSeenWriteTicks = writeTicks;
                    return;
                }

                _lastSeenWriteTicks = writeTicks;
                _lastSeenSequence = sequence;

                var commandSource = string.IsNullOrWhiteSpace(source) ? "file-inbox" : source;
                var result = DevCommandBus.TryRun(command, commandSource, sequence: sequence, payload: payload);
                WriteAck(sequence, command, result.ToString());
                EmitCommandCheckpoint(sequence, command, result.ToString());
                TryClearInboxAfterConsume(sequence, command, result);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG INBOX] Failed to read command inbox: {ex.Message}", showInGame: false);
            }
        }

        private static bool TryGetPendingInboxWrite(out long writeTicks)
        {
            writeTicks = -1;
            try
            {
                if (!File.Exists(InboxPath))
                {
                    return false;
                }

                writeTicks = File.GetLastWriteTimeUtc(InboxPath).Ticks;
                return writeTicks != _lastSeenWriteTicks;
            }
            catch
            {
                return false;
            }
        }

        private static void TryClearInboxAfterConsume(int sequence, string command, DevCommandResult result)
        {
            try
            {
                if (File.Exists(InboxPath))
                {
                    File.Delete(InboxPath);
                }

                _lastSeenWriteTicks = -1;
                DebugLogger.Test(
                    $"[TBG INBOX] consumed sequence={sequence} command={command} result={result}; inbox cleared",
                    showInGame: false);
            }
            catch (Exception ex)
            {
                DebugLogger.Test(
                    $"[TBG INBOX] consumed sequence={sequence} command={command} result={result}; inbox delete failed: {ex.Message}",
                    showInGame: false);
            }
        }

        private static void WriteAck(int sequence, string command, string result)
        {
            try
            {
                var json =
                    "{" +
                    $"\"sequence\": {sequence}," +
                    $"\"command\": \"{command}\"," +
                    $"\"result\": \"{result}\"," +
                    $"\"time\": \"{DateTime.Now:o}\"" +
                    "}";
                File.WriteAllText(AckPath, json);
            }
            catch
            {
            }
        }

        private static void EmitCommandCheckpoint(int sequence, string command, string result)
        {
            var checkpointName = default(string);
            if (!string.IsNullOrEmpty(command)
                && command.IndexOf("Probe", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                checkpointName = AutomationCheckpointEvent.ProbeAck;
            }
            else if (!string.IsNullOrEmpty(command)
                && (command.IndexOf("Travel", StringComparison.OrdinalIgnoreCase) >= 0
                    || command.IndexOf("Execute", StringComparison.OrdinalIgnoreCase) >= 0))
            {
                checkpointName = AutomationCheckpointEvent.ExecuteAck;
            }
            else if (!string.IsNullOrEmpty(command)
                && command.IndexOf("Toggle", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                checkpointName = AutomationCheckpointEvent.ToggleReceived;
            }

            if (string.IsNullOrEmpty(checkpointName))
            {
                return;
            }

            AutomationUserMessageService.Checkpoint(
                checkpointName,
                null,
                phase: "command",
                reason: result,
                detailsJson: "{\"sequence\":" + sequence + ",\"command\":\"" + Escape(command) + "\"}");
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

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
