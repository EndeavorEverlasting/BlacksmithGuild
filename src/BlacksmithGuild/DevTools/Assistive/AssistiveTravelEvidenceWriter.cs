using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelEvidenceWriter
    {
        private static readonly string ExecutionPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_AssistiveTravelExecution.json");

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
                builder.AppendLine($"  \"fakeGameplayDelta\": false,");
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
                File.WriteAllText(ExecutionPath, builder.ToString());
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

        private static string FormatUtc(DateTime? value) =>
            value?.ToString("o");

        private static string JsonString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
