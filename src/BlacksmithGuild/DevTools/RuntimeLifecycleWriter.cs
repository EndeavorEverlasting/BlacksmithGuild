using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    public static class RuntimeLifecycleWriter
    {
        private static readonly string LifecyclePath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_RuntimeLifecycle.json");

        private static DateTime? _moduleLoadedAtUtc;
        private static DateTime _lastHeartbeatUtc = DateTime.MinValue;
        private static string _lastKnownGameplaySurface = GameplaySurfaceKinds.Unknown;
        private static string _lastKnownGameLifecycle = GameLifecycleKinds.Unknown;
        private static string _lastCommandName;
        private static int _lastCommandSequence = -1;
        private static DateTime? _lastCommandStartedAtUtc;
        private static DateTime? _lastCommandFinishedAtUtc;
        private static string _lastCommandResult;
        private static string _lastCommandFallbackReason;
        private static bool _gracefulShutdownObserved;
        private static DateTime? _shutdownObservedAtUtc;
        private static string _shutdownReason;

        public static void OnModuleLoaded()
        {
            _moduleLoadedAtUtc = DateTime.UtcNow;
            _lastKnownGameLifecycle = GameLifecycleKinds.ModuleLoaded;
            WriteLifecycleFile();
        }

        public static void OnHeartbeat(GameplaySurfaceSnapshot snapshot)
        {
            _lastHeartbeatUtc = DateTime.UtcNow;
            if (snapshot != null)
            {
                _lastKnownGameplaySurface = snapshot.GameplaySurface ?? GameplaySurfaceKinds.Unknown;
                _lastKnownGameLifecycle = snapshot.GameLifecycle ?? GameLifecycleKinds.Unknown;
            }

            WriteLifecycleFile();
        }

        public static void RecordCommandStarted(string commandName, int sequence = -1)
        {
            _lastCommandName = commandName;
            _lastCommandSequence = sequence;
            _lastCommandStartedAtUtc = DateTime.UtcNow;
            _lastCommandFinishedAtUtc = null;
            _lastCommandResult = "Started";
            _lastCommandFallbackReason = null;
            WriteLifecycleFile();
        }

        public static void RecordCommandFinished(
            string commandName,
            int sequence,
            string result,
            string fallbackReason = null)
        {
            _lastCommandName = commandName;
            _lastCommandSequence = sequence;
            _lastCommandFinishedAtUtc = DateTime.UtcNow;
            _lastCommandResult = result;
            _lastCommandFallbackReason = fallbackReason;
            WriteLifecycleFile();
        }

        public static void RecordGracefulShutdown(string reason)
        {
            _gracefulShutdownObserved = true;
            _shutdownObservedAtUtc = DateTime.UtcNow;
            _shutdownReason = reason;
            _lastKnownGameLifecycle = GameLifecycleKinds.Terminated;
            WriteLifecycleFile();
        }

        public static void AppendStateMachine(StringBuilder builder, GameplaySurfaceSnapshot snapshot)
        {
            snapshot = snapshot ?? new GameplaySurfaceSnapshot();
            builder.AppendLine("  \"stateMachine\": {");
            builder.AppendLine($"    \"schemaVersion\": {GameplaySurfaceSnapshot.SchemaVersion},");
            builder.AppendLine($"    \"updatedAtUtc\": \"{snapshot.UpdatedAtUtc:o}\",");
            builder.AppendLine($"    \"heartbeatUtc\": \"{snapshot.HeartbeatUtc:o}\",");
            builder.AppendLine($"    \"activeStateName\": \"{Escape(snapshot.ActiveStateName)}\",");
            builder.AppendLine($"    \"gameLifecycle\": \"{Escape(snapshot.GameLifecycle)}\",");
            builder.AppendLine($"    \"gameplayMode\": \"{Escape(snapshot.GameplayMode)}\",");
            builder.AppendLine($"    \"gameplaySurface\": \"{Escape(snapshot.GameplaySurface)}\",");
            builder.AppendLine($"    \"missionKind\": {JsonString(snapshot.MissionKind)},");
            builder.AppendLine($"    \"menuId\": {JsonString(snapshot.MenuId)},");
            builder.AppendLine($"    \"locationId\": {JsonString(snapshot.LocationId)},");
            builder.AppendLine($"    \"settlementId\": {JsonString(snapshot.SettlementId)},");
            builder.AppendLine($"    \"settlementName\": {JsonString(snapshot.SettlementName)},");
            builder.AppendLine($"    \"isCampaignLoaded\": {snapshot.IsCampaignLoaded.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isMainHeroReady\": {snapshot.IsMainHeroReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isMapStateActive\": {snapshot.IsMapStateActive.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isMapMenuOpen\": {snapshot.IsMapMenuOpen.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isMissionActive\": {snapshot.IsMissionActive.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isConversation\": {snapshot.IsConversation.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isTournament\": {snapshot.IsTournament.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isBattle\": {snapshot.IsBattle.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isSmithing\": {snapshot.IsSmithing.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"isTrading\": {snapshot.IsTrading.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"canPollFileInbox\": {snapshot.CanPollFileInbox.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"canAcceptAssistiveCommand\": {snapshot.CanAcceptAssistiveCommand.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"safeToWait\": {snapshot.SafeToWait.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"safeToCancel\": {snapshot.SafeToCancel.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"safeToExecuteTravel\": {snapshot.SafeToExecuteTravel.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"safeToExecuteSmithing\": {snapshot.SafeToExecuteSmithing.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"safeToExecuteTrade\": {snapshot.SafeToExecuteTrade.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"blockReason\": {JsonString(snapshot.BlockReason)},");
            builder.AppendLine($"    \"lastStableSurface\": {JsonString(snapshot.LastStableSurface)},");
            builder.AppendLine($"    \"stableSinceUtc\": {JsonString(snapshot.StableSinceUtc?.ToString("o"))}");
            builder.AppendLine("  },");
        }

        private static void WriteLifecycleFile()
        {
            try
            {
                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine("  \"schemaVersion\": 1,");
                builder.AppendLine($"  \"moduleLoadedAtUtc\": {JsonString(_moduleLoadedAtUtc?.ToString("o"))},");
                builder.AppendLine($"  \"lastHeartbeatUtc\": {JsonString(_lastHeartbeatUtc == DateTime.MinValue ? null : _lastHeartbeatUtc.ToString("o"))},");
                builder.AppendLine($"  \"lastKnownGameplaySurface\": {JsonString(_lastKnownGameplaySurface)},");
                builder.AppendLine($"  \"lastKnownGameLifecycle\": {JsonString(_lastKnownGameLifecycle)},");
                builder.AppendLine($"  \"lastCommandName\": {JsonString(_lastCommandName)},");
                builder.AppendLine($"  \"lastCommandSequence\": {_lastCommandSequence},");
                builder.AppendLine($"  \"lastCommandStartedAtUtc\": {JsonString(_lastCommandStartedAtUtc?.ToString("o"))},");
                builder.AppendLine($"  \"lastCommandFinishedAtUtc\": {JsonString(_lastCommandFinishedAtUtc?.ToString("o"))},");
                builder.AppendLine($"  \"lastCommandResult\": {JsonString(_lastCommandResult)},");
                builder.AppendLine($"  \"lastCommandFallbackReason\": {JsonString(_lastCommandFallbackReason)},");
                builder.AppendLine($"  \"gracefulShutdownObserved\": {_gracefulShutdownObserved.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"shutdownObservedAtUtc\": {JsonString(_shutdownObservedAtUtc?.ToString("o"))},");
                builder.AppendLine($"  \"shutdownReason\": {JsonString(_shutdownReason)}");
                builder.AppendLine("}");
                File.WriteAllText(LifecyclePath, builder.ToString());
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG LIFECYCLE] write failed: {ex.Message}", showInGame: false);
            }
        }

        private static string JsonString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
