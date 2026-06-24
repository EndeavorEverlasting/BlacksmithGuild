using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveSessionWriter
    {
        private static readonly string SessionPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_AssistiveSession.json");

        public static void WriteSnapshot(
            string nextTownRecommendation = null,
            string tradeExecution = null,
            string travelCommandMode = null,
            string currentSettlement = null,
            string reason = null)
        {
            try
            {
                var settlement = currentSettlement
                    ?? GameSessionState.CurrentSettlementName
                    ?? GameSessionState.CurrentSettlementStringId
                    ?? "";

                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"assistiveCertReady\": {AssistReadinessEvaluator.IsInGameAssistReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"inGameAssistReady\": {AssistReadinessEvaluator.IsInGameAssistReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"canPollFileInbox\": {GameSessionState.CanPollFileInbox.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"canAcceptAssistiveCommand\": {AssistReadinessEvaluator.CanAcceptAssistiveCommand.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"readinessSurface\": \"{Escape(GameSessionState.ReadinessSurface ?? ReadinessSurfaceKinds.Unknown)}\",");
                builder.AppendLine($"  \"currentSettlement\": \"{Escape(settlement)}\",");
                builder.AppendLine($"  \"openMapReady\": {AssistReadinessEvaluator.IsOpenMapReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"townMenuReady\": {AssistReadinessEvaluator.IsTownMenuReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"nextTownRecommendation\": {(nextTownRecommendation == null ? "null" : $"\"{Escape(nextTownRecommendation)}\"")},");
                builder.AppendLine($"  \"tradeExecution\": {(tradeExecution == null ? "null" : $"\"{Escape(tradeExecution)}\"")},");
                builder.AppendLine($"  \"travelCommandMode\": {(travelCommandMode == null ? "null" : $"\"{Escape(travelCommandMode)}\"")},");
                builder.AppendLine($"  \"reason\": {(reason == null ? "null" : $"\"{Escape(reason)}\"")}");
                builder.AppendLine("}");
                File.WriteAllText(SessionPath, builder.ToString());
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG ASSIST] session write failed: {ex.Message}", showInGame: false);
            }
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
