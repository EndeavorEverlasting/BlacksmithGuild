using System;
using System.IO;
using System.Text;
using BlacksmithGuild.GuildLoop;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Converts an explicit in-game authority change into practical operator behavior.
    /// Ctrl+Alt+T reaching Automation is an intent event, not a cosmetic label:
    /// resume campaign time and start or preserve the bounded autonomous guild loop.
    /// </summary>
    public static class OperatorAutomationContextController
    {
        public const string EvidenceFileName = "BlacksmithGuild_OperatorAutomationContext.json";

        public static bool HandleGlobalModeChanged(string source)
        {
            var requestedBy = string.IsNullOrWhiteSpace(source) ? "operator_mode_change" : source;
            GameSessionState.Refresh();

            var mode = EngineToggleAuthority.GlobalMode;
            var resumeAttempted = false;
            var resumeResult = DevCommandResult.Unknown;
            var loopStartAttempted = false;
            var loopAlreadyRunning = AutonomousGuildLoopService.IsRunning;
            var loopResult = loopAlreadyRunning ? DevCommandResult.Success : DevCommandResult.Unknown;
            string blockedReason = null;

            if (mode != EngineToggleMode.Automation)
            {
                WriteEvidence(
                    requestedBy,
                    mode,
                    resumeAttempted,
                    resumeResult,
                    loopStartAttempted,
                    loopAlreadyRunning,
                    loopResult,
                    blockedReason);
                return true;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                blockedReason = GameSessionState.GetCampaignMapBlockDetail();
                DebugLogger.Test(
                    $"[TBG OPERATOR CONTEXT] Automation follow-through blocked: {blockedReason}",
                    showInGame: false);
                InGameNotice.Blocked($"Automation set; movement blocked: {blockedReason}");
                WriteEvidence(
                    requestedBy,
                    mode,
                    resumeAttempted,
                    resumeResult,
                    loopStartAttempted,
                    loopAlreadyRunning,
                    loopResult,
                    blockedReason);
                return false;
            }

            resumeAttempted = true;
            resumeResult = DevCommandBus.TryRun(
                DevCommandRegistry.ResumeCampaignClockCommand,
                requestedBy + "/automation_follow_through");

            if (!loopAlreadyRunning)
            {
                loopStartAttempted = true;
                loopResult = DevCommandBus.TryRun(
                    AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand,
                    requestedBy + "/automation_follow_through");
            }

            if (resumeResult == DevCommandResult.Success && loopResult == DevCommandResult.Success)
            {
                var action = loopAlreadyRunning ? "guild loop already active" : "guild loop started";
                InGameNotice.Success($"Automation active: clock resumed; {action}.");
            }
            else
            {
                blockedReason = BuildBlockedReason(resumeResult, loopResult, loopAlreadyRunning);
                InGameNotice.Blocked($"Automation follow-through blocked: {blockedReason}");
            }

            WriteEvidence(
                requestedBy,
                mode,
                resumeAttempted,
                resumeResult,
                loopStartAttempted,
                loopAlreadyRunning,
                loopResult,
                blockedReason);

            return resumeResult == DevCommandResult.Success && loopResult == DevCommandResult.Success;
        }

        private static string BuildBlockedReason(
            DevCommandResult resumeResult,
            DevCommandResult loopResult,
            bool loopAlreadyRunning)
        {
            if (resumeResult != DevCommandResult.Success)
            {
                return TimeDevTools.LastFailReason ?? "campaign clock did not resume";
            }

            if (!loopAlreadyRunning && loopResult != DevCommandResult.Success)
            {
                return AutonomousGuildLoopService.LastFailReason ?? "autonomous guild loop did not start";
            }

            return "operator automation context did not complete";
        }

        private static void WriteEvidence(
            string source,
            EngineToggleMode mode,
            bool resumeAttempted,
            DevCommandResult resumeResult,
            bool loopStartAttempted,
            bool loopAlreadyRunning,
            DevCommandResult loopResult,
            string blockedReason)
        {
            try
            {
                var sb = new StringBuilder();
                sb.AppendLine("{");
                sb.AppendLine("  \"schemaVersion\": \"TbgOperatorAutomationContext.v1\",");
                sb.AppendLine("  \"updatedAtUtc\": \"" + DateTime.UtcNow.ToString("o") + "\",");
                sb.AppendLine("  \"source\": \"" + Escape(source) + "\",");
                sb.AppendLine("  \"globalMode\": \"" + mode + "\",");
                sb.AppendLine("  \"campaignReady\": " + Boolean(GameSessionState.IsCampaignMapReady) + ",");
                sb.AppendLine("  \"sessionPhase\": \"" + GameSessionState.Phase + "\",");
                sb.AppendLine("  \"timePausedAfter\": " + Boolean(GameSessionState.IsTimePaused) + ",");
                sb.AppendLine("  \"resumeAttempted\": " + Boolean(resumeAttempted) + ",");
                sb.AppendLine("  \"resumeResult\": \"" + resumeResult + "\",");
                sb.AppendLine("  \"loopStartAttempted\": " + Boolean(loopStartAttempted) + ",");
                sb.AppendLine("  \"loopAlreadyRunning\": " + Boolean(loopAlreadyRunning) + ",");
                sb.AppendLine("  \"loopResult\": \"" + loopResult + "\",");
                sb.AppendLine("  \"blockedReason\": " + NullableString(blockedReason));
                sb.AppendLine("}");

                RuntimeProofContext.WriteAllTextAtomic(
                    Path.Combine(BasePath.Name, EvidenceFileName),
                    sb.ToString());
            }
            catch (Exception ex)
            {
                DebugLogger.Test(
                    "[TBG OPERATOR CONTEXT] evidence failed: " + ex.Message,
                    showInGame: false);
            }
        }

        private static string Boolean(bool value) => value ? "true" : "false";

        private static string NullableString(string value) =>
            value == null ? "null" : "\"" + Escape(value) + "\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
