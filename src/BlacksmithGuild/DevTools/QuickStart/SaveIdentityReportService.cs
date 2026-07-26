using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class SaveIdentityReportService
    {
        public const string ReportSaveIdentityNowCommand = "ReportSaveIdentityNow";
        public const string FileName = "BlacksmithGuild_SaveIdentity.json";

        public static bool ReportNow(
            AssistiveCommandInboxPayload context,
            string source = ReportSaveIdentityNowCommand)
        {
            GameSessionState.Refresh();

            var loadedSaveId = CampaignSetupStateTracker.DevSaveName;
            var explicitLoadObserved = CampaignSetupStateTracker.DevSaveLoadStartedExplicitly;
            var identityVerified = explicitLoadObserved
                && !string.IsNullOrWhiteSpace(loadedSaveId)
                && loadedSaveId.StartsWith(
                    DevSaveResolver.DevSavePrefix,
                    StringComparison.OrdinalIgnoreCase);

            var process = Process.GetCurrentProcess();
            var json = new StringBuilder()
                .AppendLine("{")
                .AppendLine("  \"schemaVersion\": \"TbgSaveIdentity.v2\",")
                .AppendLine($"  \"observedAtUtc\": \"{DateTime.UtcNow:o}\",")
                .AppendLine($"  \"source\": \"{Escape(source)}\",")
                .AppendLine($"  \"commandId\": {JsonString(context?.CommandId)},")
                .AppendLine($"  \"runId\": {JsonString(context?.RunId)},")
                .AppendLine($"  \"correlationId\": {JsonString(context?.CorrelationId)},")
                .AppendLine($"  \"requestedUtc\": {JsonString(context?.RequestedUtc)},")
                .AppendLine($"  \"processId\": {process.Id},")
                .AppendLine($"  \"processStartTimeUtc\": \"{process.StartTime.ToUniversalTime():o}\",")
                .AppendLine($"  \"loadedSaveId\": {JsonString(loadedSaveId)},")
                .AppendLine($"  \"activeSaveSlotName\": {JsonString(loadedSaveId)},")
                .AppendLine($"  \"devSaveLoadUsed\": {(CampaignSetupStateTracker.DevSaveLoadUsed ? "true" : "false")},")
                .AppendLine($"  \"explicitLoadObserved\": {(explicitLoadObserved ? "true" : "false")},")
                .AppendLine($"  \"identityVerified\": {(identityVerified ? "true" : "false")},")
                .AppendLine($"  \"campaignReady\": {(GameSessionState.IsCampaignSessionReady ? "true" : "false")}")
                .AppendLine("}")
                .ToString();

            File.WriteAllText(
                Path.Combine(BasePath.Name, FileName),
                json,
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));

            GuildLog.Info(
                $"[TBG SAVE IDENTITY] loaded={loadedSaveId ?? "unknown"}"
                + $" explicit={explicitLoadObserved}"
                + $" verified={identityVerified}"
                + $" runId={context?.RunId ?? "none"}",
                showInGame: false);

            if (identityVerified)
            {
                InGameNotice.Success(ModDisplay.CompactLine("DevSave", $"verified {loadedSaveId}"));
            }
            else
            {
                InGameNotice.Blocked(ModDisplay.CompactLine("DevSave", "identity not verified"));
            }

            return identityVerified;
        }

        private static string JsonString(string value) =>
            value == null ? "null" : "\"" + Escape(value) + "\"";

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"");
    }
}
