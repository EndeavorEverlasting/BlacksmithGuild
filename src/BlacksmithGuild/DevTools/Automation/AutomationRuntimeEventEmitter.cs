using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Automation
{
    // Emits append-only dotted-"type" runtime events into the shared AutomationEvents.jsonl stream.
    // Runtime events are evidence, not proof: they carry an "envelope":"runtime_event" marker and a
    // free-form payload so the offline economic-loop certifier can correlate command/trade/travel/
    // boundary activity. They never satisfy PASS on their own.
    //
    // Type constants intentionally match scripts/automation-checkpoint-contract.ps1
    // ($script:AutomationRuntimeEventTypes) so runner and mod share one allowlist.
    public static class AutomationRuntimeEventEmitter
    {
        public const int SchemaVersion = 1;

        public const string BoundaryStarted = "boundary.started";
        public const string BoundaryCompleted = "boundary.completed";
        public const string BoundaryFailed = "boundary.failed";
        public const string BoundaryBlocked = "boundary.blocked";
        public const string BoundarySkipped = "boundary.skipped";
        public const string CommandReceived = "command.received";
        public const string CommandStarted = "command.started";
        public const string CommandCompleted = "command.completed";
        public const string CommandFailed = "command.failed";
        public const string TravelStarted = "travel.started";
        public const string TravelProgress = "travel.progress";
        public const string TravelBlocked = "travel.blocked";
        public const string TravelCompleted = "travel.completed";
        public const string TradeStarted = "trade.started";
        public const string TradeCompleted = "trade.completed";
        public const string TradeBlocked = "trade.blocked";
        public const string HorseAcquisitionStarted = "horse_acquisition.started";
        public const string HorseAcquisitionCompleted = "horse_acquisition.completed";
        public const string HorseAcquisitionBlocked = "horse_acquisition.blocked";
        public const string InventoryChanged = "inventory.changed";
        public const string InventoryBlocked = "inventory.blocked";
        public const string SmithingStarted = "smithing.started";
        public const string SmithingCompleted = "smithing.completed";
        public const string SmithingBlocked = "smithing.blocked";
        public const string RestWaitStarted = "rest_wait.started";
        public const string RestWaitCompleted = "rest_wait.completed";
        public const string RecursiveBranchStateChanged = "recursiveBranchState.changed";
        public const string GovernorDecisionStarted = "governor.decision.started";
        public const string GovernorDecisionCompleted = "governor.decision.completed";
        public const string GovernorDecisionFailed = "governor.decision.failed";
        public const string GovernorBranchBlocked = "governor.branch.blocked";
        public const string GovernorReportInsufficient = "governor.report_insufficient";
        public const string GovernorFailSafePause = "governor.failsafe_pause";
        public const string FoodQuantityLow = "food.quantity.low";
        public const string FoodDiversityLow = "food.diversity.low";
        public const string CityCompletionStarted = "city_completion.started";
        public const string CityCompletionCompleted = "city_completion.completed";
        public const string CityCompletionBlocked = "city_completion.blocked";

        private static readonly object Sync = new object();
        private static readonly string EventPath =
            Path.Combine(BasePath.Name, AutomationCheckpointEvent.FileName);

        private static string _lastBranchStateSignature;

        public static string PathForTests => EventPath;

        public static void Emit(
            string type,
            string sessionId = null,
            int? cycleId = null,
            string boundaryId = null,
            string reason = null,
            string payloadJson = null,
            string source = "mod")
        {
            if (string.IsNullOrWhiteSpace(type))
            {
                return;
            }

            try
            {
                var line = Serialize(type, sessionId, cycleId, boundaryId, reason, payloadJson, source);
                lock (Sync)
                {
                    var dir = Path.GetDirectoryName(EventPath);
                    if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
                    {
                        Directory.CreateDirectory(dir);
                    }

                    File.AppendAllText(EventPath, line + Environment.NewLine, Encoding.UTF8);
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG RUNTIME] runtime event write failed: {ex.Message}", showInGame: false);
            }
        }

        // Emits recursiveBranchState.changed only when the supplied signature differs from the last
        // emitted one, so repeated identical Status.json writes do not spam the event stream.
        public static void EmitRecursiveBranchStateChanged(string signature, string sessionId = null)
        {
            if (signature == null)
            {
                return;
            }

            lock (Sync)
            {
                if (string.Equals(_lastBranchStateSignature, signature, StringComparison.Ordinal))
                {
                    return;
                }

                _lastBranchStateSignature = signature;
            }

            Emit(RecursiveBranchStateChanged, sessionId: sessionId,
                payloadJson: "{\"signature\":\"" + Escape(signature) + "\"}");
        }

        private static string Serialize(
            string type,
            string sessionId,
            int? cycleId,
            string boundaryId,
            string reason,
            string payloadJson,
            string source)
        {
            var sb = new StringBuilder();
            sb.Append("{");
            sb.Append("\"schemaVersion\":").Append(SchemaVersion);
            AppendString(sb, "eventId", Guid.NewGuid().ToString());
            AppendString(sb, "envelope", "runtime_event");
            AppendString(sb, "sessionId", sessionId);
            AppendString(sb, "atUtc", DateTime.UtcNow.ToString("o"));
            AppendString(sb, "type", type);
            AppendString(sb, "source", source);
            AppendString(sb, "boundaryId", boundaryId);
            AppendString(sb, "reason", reason);
            if (cycleId.HasValue)
            {
                sb.Append(",\"cycleId\":").Append(cycleId.Value);
            }

            sb.Append(",\"payload\":").Append(string.IsNullOrWhiteSpace(payloadJson) ? "null" : payloadJson);
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
