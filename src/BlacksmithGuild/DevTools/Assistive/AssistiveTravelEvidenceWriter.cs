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

            try
            {
                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"commandAccepted\": {result.CommandAccepted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"executeRequested\": {result.ExecuteRequested.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"executeAllowed\": {result.ExecuteAllowed.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"travelCommandMode\": \"{Escape(result.TravelCommandMode)}\",");
                builder.AppendLine($"  \"fallbackReason\": {(result.FallbackReason == null ? "null" : $"\"{Escape(result.FallbackReason)}\"")},");
                builder.AppendLine($"  \"currentSettlement\": \"{Escape(result.CurrentSettlement)}\",");
                builder.AppendLine($"  \"targetSettlement\": {(result.TargetSettlement == null ? "null" : $"\"{Escape(result.TargetSettlement)}\"")},");
                builder.AppendLine($"  \"leaveTownAttempted\": {result.LeaveTownAttempted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"leaveTownSucceeded\": {result.LeaveTownSucceeded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mapTravelAttempted\": {result.MapTravelAttempted.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"movementIntentSet\": {result.MovementIntentSet.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"actualExecutionObserved\": {result.ActualExecutionObserved.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"fakeGameplayDelta\": false,");
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

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
