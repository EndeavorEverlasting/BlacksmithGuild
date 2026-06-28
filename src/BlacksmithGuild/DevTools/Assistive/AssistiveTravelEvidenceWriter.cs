using System;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools.Automation;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelEvidenceWriter
    {
        private static readonly string ExecutionPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_AssistiveTravelExecution.json");
        private static string _lastMovementCheckpointAttemptId;

        public static void Write(AssistiveTravelExecutionResult result)
        {
            if (result == null)
            {
                return;
            }

            var certSummary = AssistiveTravelCertSummary.Build(result);

            try
            {
                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"commandAccepted\": {result.CommandAccepted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"executeRequested\": {result.ExecuteRequested.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"executeAllowed\": {result.ExecuteAllowed.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"travelCommandMode\": \"{Escape(result.TravelCommandMode)}\",");
                builder.AppendLine($"  \"fallbackReason\": {JsonString(result.FallbackReason)},");
                builder.AppendLine($"  \"currentSettlement\": \"{Escape(result.CurrentSettlement)}\",");
                builder.AppendLine($"  \"currentSettlementId\": \"{Escape(result.CurrentSettlementId)}\",");
                builder.AppendLine($"  \"currentSettlementName\": \"{Escape(result.CurrentSettlementName)}\",");
                builder.AppendLine($"  \"targetSettlement\": {JsonString(result.TargetSettlement)},");
                builder.AppendLine($"  \"targetSettlementId\": \"{Escape(result.TargetSettlementId)}\",");
                builder.AppendLine($"  \"targetSettlementName\": \"{Escape(result.TargetSettlementName)}\",");
                builder.AppendLine($"  \"routeTargetSettlement\": {JsonString(result.RouteTargetSettlement)},");
                builder.AppendLine($"  \"routeTargetSettlementId\": {JsonString(result.RouteTargetSettlementId)},");
                builder.AppendLine($"  \"leaveTownAttempted\": {result.LeaveTownAttempted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"leaveTownSucceeded\": {result.LeaveTownSucceeded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mapTravelAttempted\": {result.MapTravelAttempted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"travelApiCallSucceeded\": {result.TravelApiCallSucceeded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"movementIntentSet\": {result.MovementIntentSet.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"actualExecutionObserved\": {result.ActualExecutionObserved.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"movementObservationStartedAtUtc\": {JsonString(FormatUtc(result.MovementObservationStartedAtUtc))},");
                builder.AppendLine($"  \"movementObservationEndedAtUtc\": {JsonString(FormatUtc(result.MovementObservationEndedAtUtc))},");
                builder.AppendLine($"  \"movementObservationMs\": {result.MovementObservationMs},");
                builder.AppendLine($"  \"movementObservationAttempts\": {result.MovementObservationAttempts},");
                builder.AppendLine($"  \"movementObservationPassed\": {result.MovementObservationPassed.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"movementObservationFailureReason\": {JsonString(result.MovementObservationFailureReason)},");
                builder.AppendLine($"  \"fakeGameplayDelta\": {result.FakeGameplayDelta.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"travelClockRunning\": {result.TravelClockRunning.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"partyMovedDistance\": {result.PartyMovedDistance.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture)},");
                builder.AppendLine($"  \"movementProofClassification\": {JsonString(result.MovementProofClassification)},");
                builder.AppendLine($"  \"movementProofReason\": {JsonString(result.MovementProofReason)},");
                builder.AppendLine($"  \"movementMetricDisagreement\": {result.MovementMetricDisagreement.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"movementCheckpointObserved\": {result.MovementCheckpointObserved.ToString().ToLowerInvariant()},");
                AppendMovementProof(builder, result.MovementProof);
                builder.AppendLine($"  \"arrived\": {result.Arrived.ToString().ToLowerInvariant()},");
                AppendCertSummary(builder, certSummary);
                builder.Append("  \"steps\": [");
                for (var i = 0; i < result.Steps.Count; i++)
                {
                    var step = result.Steps[i];
                    if (i > 0)
                    {
                        builder.Append(',');
                    }

                    builder.AppendLine();
                    builder.AppendLine("    {");
                    builder.AppendLine($"      \"name\": \"{Escape(step.Name)}\",");
                    builder.AppendLine($"      \"method\": \"{Escape(step.Method)}\",");
                    builder.AppendLine($"      \"status\": \"{Escape(step.Status)}\",");
                    builder.AppendLine($"      \"detail\": \"{Escape(step.Detail)}\"");
                    builder.Append("    }");
                }

                if (result.Steps.Count > 0)
                {
                    builder.AppendLine();
                }

                builder.AppendLine("  ]");
                builder.AppendLine("}");
                File.WriteAllText(ExecutionPath, builder.ToString(), Encoding.UTF8);
                if (HasDurableMovementProof(result))
                {
                    var deltas = result.MovementProof?.Deltas;
                    var attemptId = result.MovementProof?.AttemptId;
                    if (!string.Equals(_lastMovementCheckpointAttemptId, attemptId, StringComparison.Ordinal)) {
                    AutomationUserMessageService.Checkpoint(
                        AutomationCheckpointEvent.PartyMovementObserved,
                        "Party movement observed.",
                        phase: "travel",
                        detailsJson: "{\"movementProofClassification\":" + JsonString(result.MovementProofClassification)
                            + ",\"partyMovedDistance\":" + result.PartyMovedDistance.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture)
                            + ",\"positionChanged\":" + JsonBool(deltas?.PositionChanged == true)
                            + ",\"distanceToTargetChanged\":" + JsonBool(deltas?.DistanceToTargetChanged == true)
                            + ",\"mapTimeAdvanced\":" + JsonBool(deltas?.MapTimeAdvanced == true)
                            + ",\"currentSettlementChanged\":" + JsonBool(deltas?.CurrentSettlementChanged == true)
                            + ",\"nearestSettlementChanged\":" + JsonBool(deltas?.NearestSettlementChanged == true)
                            + "}");
                        _lastMovementCheckpointAttemptId = attemptId;
                    }
                }
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG ASSIST] travel execution evidence write failed: {ex.Message}", showInGame: false);
            }

            var tradeExecution = result.TravelCommandMode == "execute" ? "execute" : "advisory_only";
            AssistiveSessionWriter.WriteSnapshot(
                nextTownRecommendation: result.TargetSettlement,
                tradeExecution: tradeExecution,
                travelCommandMode: result.TravelCommandMode,
                currentSettlement: result.CurrentSettlement,
                reason: result.FallbackReason,
                targetSettlement: result.TargetSettlement,
                fallbackReason: result.FallbackReason,
                executeRequested: result.ExecuteRequested);
        }

        private static void AppendCertSummary(StringBuilder builder, AssistiveTravelCertSummary certSummary)
        {
            builder.AppendLine("  \"certSummary\": {");
            if (certSummary == null)
            {
                builder.AppendLine("    \"passCandidate\": false");
                builder.AppendLine("  },");
                return;
            }

            builder.AppendLine($"    \"executeRequested\": {certSummary.ExecuteRequested.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"executeAllowed\": {certSummary.ExecuteAllowed.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"travelCommandMode\": \"{Escape(certSummary.TravelCommandMode)}\",");
            builder.AppendLine($"    \"passCandidate\": {certSummary.PassCandidate.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"blockingReason\": {JsonString(certSummary.BlockingReason)},");
            builder.AppendLine($"    \"routeOwner\": {JsonString(certSummary.RouteOwner)},");
            builder.AppendLine($"    \"nextRouteOnFail\": {JsonString(certSummary.NextRouteOnFail)}");
            builder.AppendLine("  },");
        }

        private static void AppendMovementProof(StringBuilder builder, MovementProofLedger ledger)
        {
            builder.AppendLine("  \"movementProof\": {");
            if (ledger == null)
            {
                builder.AppendLine("    \"classification\": null");
                builder.AppendLine("  },");
                return;
            }

            builder.AppendLine($"    \"schemaVersion\": {ledger.SchemaVersion},");
            builder.AppendLine($"    \"attemptId\": {JsonString(ledger.AttemptId)},");
            builder.AppendLine($"    \"classification\": {JsonString(ledger.Classification.ToString())},");
            builder.AppendLine($"    \"classificationReason\": {JsonString(ledger.ClassificationReason)},");
            builder.AppendLine($"    \"partyMovedDistanceReliable\": {JsonBool(ledger.PartyMovedDistanceReliable)},");
            builder.AppendLine($"    \"partyMovedDistance\": {ledger.PartyMovedDistance.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture)},");
            builder.AppendLine("    \"deltas\": {");
            builder.AppendLine($"      \"positionChanged\": {JsonBool(ledger.Deltas?.PositionChanged == true)},");
            builder.AppendLine($"      \"currentSettlementChanged\": {JsonBool(ledger.Deltas?.CurrentSettlementChanged == true)},");
            builder.AppendLine($"      \"nearestSettlementChanged\": {JsonBool(ledger.Deltas?.NearestSettlementChanged == true)},");
            builder.AppendLine($"      \"targetChanged\": {JsonBool(ledger.Deltas?.TargetChanged == true)},");
            builder.AppendLine($"      \"distanceToTargetChanged\": {JsonBool(ledger.Deltas?.DistanceToTargetChanged == true)},");
            builder.AppendLine($"      \"mapTimeAdvanced\": {JsonBool(ledger.Deltas?.MapTimeAdvanced == true)},");
            builder.AppendLine($"      \"partyMovedDistanceChanged\": {JsonBool(ledger.Deltas?.PartyMovedDistanceChanged == true)},");
            builder.AppendLine($"      \"maxDistanceFromStart\": {(ledger.Deltas?.MaxDistanceFromStart ?? 0d).ToString("0.###", System.Globalization.CultureInfo.InvariantCulture)},");
            builder.AppendLine($"      \"startDistanceToTarget\": {JsonNullableDouble(ledger.Deltas?.StartDistanceToTarget)},");
            builder.AppendLine($"      \"lastDistanceToTarget\": {JsonNullableDouble(ledger.Deltas?.LastDistanceToTarget)}");
            builder.AppendLine("    },");
            builder.AppendLine("    \"samples\": [");
            var samples = ledger.Samples ?? new System.Collections.Generic.List<MovementProofSample>();
            for (var i = 0; i < samples.Count; i++)
            {
                var sample = samples[i];
                builder.AppendLine("      {");
                builder.AppendLine($"        \"phase\": {JsonString(sample.Phase)},");
                builder.AppendLine($"        \"reason\": {JsonString(sample.Reason)},");
                builder.AppendLine($"        \"timestampUtc\": {JsonString(sample.TimestampUtc)},");
                builder.AppendLine($"        \"currentSettlementId\": {JsonString(sample.CurrentSettlementId)},");
                builder.AppendLine($"        \"nearestSettlementId\": {JsonString(sample.NearestSettlementId)},");
                builder.AppendLine($"        \"distanceFromStart\": {JsonNullableDouble(sample.DistanceFromStart)},");
                builder.AppendLine($"        \"distanceToTarget\": {JsonNullableDouble(sample.DistanceToTarget)},");
                builder.AppendLine($"        \"mapTimeText\": {JsonString(sample.MapTimeText)},");
                builder.AppendLine($"        \"campaignClockRunning\": {JsonBool(sample.CampaignClockRunning)},");
                builder.AppendLine($"        \"movementIntentSet\": {JsonBool(sample.MovementIntentSet)}");
                builder.Append(i < samples.Count - 1 ? "      }," : "      }");
                builder.AppendLine();
            }

            builder.AppendLine("    ]");
            builder.AppendLine("  },");
        }

        private static bool HasDurableMovementProof(AssistiveTravelExecutionResult result)
        {
            if (result == null)
            {
                return false;
            }

            return result.PartyMovedDistance > 0
                || result.MovementCheckpointObserved
                || result.MovementMetricDisagreement
                || string.Equals(result.MovementProofClassification, MovementProofClassification.MovementDistanceObserved.ToString(), StringComparison.Ordinal)
                || string.Equals(result.MovementProofClassification, MovementProofClassification.MovementCheckpointObserved.ToString(), StringComparison.Ordinal)
                || string.Equals(result.MovementProofClassification, MovementProofClassification.MovementMetricDisagreement.ToString(), StringComparison.Ordinal);
        }

        private static string FormatUtc(DateTime? value) =>
            value?.ToString("o");

        private static string JsonString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string JsonBool(bool value) =>
            value ? "true" : "false";

        private static string JsonNullableDouble(double? value) =>
            value.HasValue ? value.Value.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture) : "null";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
