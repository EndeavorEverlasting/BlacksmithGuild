using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Core;
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

            var activeSaveSlotName = NormalizeSaveSlotName(TryGetActiveSaveSlotName());
            var hasActiveSaveSlot = !string.IsNullOrWhiteSpace(activeSaveSlotName);
            var activeSlotVerified = IsAllowedDisposableSave(activeSaveSlotName);

            var explicitTrackerSaveId = CampaignSetupStateTracker.DevSaveLoadStartedExplicitly
                ? NormalizeSaveSlotName(CampaignSetupStateTracker.DevSaveName)
                : null;
            var explicitTrackerAllowed = IsAllowedDisposableSave(explicitTrackerSaveId);
            var explicitTrackerVerified = !hasActiveSaveSlot && explicitTrackerAllowed;

            // An active slot is authoritative and must never be overridden by stale tracker state.
            // The tracker is only a fallback while an explicitly initiated load has no active slot yet.
            var identityVerified = activeSlotVerified || explicitTrackerVerified;
            var loadedSaveId = hasActiveSaveSlot ? activeSaveSlotName : explicitTrackerSaveId;
            var devSaveLoadUsed = identityVerified;
            var explicitLoadObserved = explicitTrackerAllowed
                && (!hasActiveSaveSlot
                    || string.Equals(
                        activeSaveSlotName,
                        explicitTrackerSaveId,
                        StringComparison.OrdinalIgnoreCase));

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
                .AppendLine($"  \"activeSaveSlotName\": {JsonString(activeSaveSlotName)},")
                .AppendLine($"  \"devSaveLoadUsed\": {(devSaveLoadUsed ? "true" : "false")},")
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

        internal static bool IsAllowedDisposableSave(string saveSlotName)
        {
            var normalized = NormalizeSaveSlotName(saveSlotName);
            return DevSaveResolver.IsDisposableSaveName(normalized);
        }

        internal static string NormalizeSaveSlotName(string saveSlotName)
        {
            if (string.IsNullOrWhiteSpace(saveSlotName))
            {
                return null;
            }

            var normalized = Path.GetFileName(saveSlotName.Trim());
            return normalized.EndsWith(".sav", StringComparison.OrdinalIgnoreCase)
                ? normalized.Substring(0, normalized.Length - 4)
                : normalized;
        }

        private static string TryGetActiveSaveSlotName()
        {
            try
            {
                return MBSaveLoad.ActiveSaveSlotName;
            }
            catch (Exception ex)
            {
                GuildLog.Info(
                    $"[TBG SAVE IDENTITY] active save slot unavailable: {ex.Message}",
                    showInGame: false);
                return null;
            }
        }

        private static string JsonString(string value) =>
            value == null ? "null" : "\"" + Escape(value) + "\"";

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"");
    }
}
