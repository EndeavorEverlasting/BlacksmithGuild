using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools.QuickStart;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class CrashContextWriter
    {
        public const string FileName = "BlacksmithGuild_CrashContext.json";

        private static readonly string ContextPath = Path.Combine(BasePath.Name, FileName);

        private static string _lastBeginArea;
        private static string _lastBeginOperation;
        private static int _lastBeginSequence;
        private static string _lastBeginPath;

        private static string _lastSuccessArea;
        private static string _lastSuccessOperation;
        private static int _lastSuccessSequence;
        private static string _lastSuccessPath;

        private static string _lastExceptionType;
        private static string _lastExceptionMessage;

        public static void RecordBegin(int sequence, string area, string operation, string path)
        {
            _lastBeginArea = area;
            _lastBeginOperation = operation;
            _lastBeginSequence = sequence;
            _lastBeginPath = path;
            WriteSnapshot(sequence, area, operation, "begin", path);
        }

        public static void RecordOk(int sequence, string area, string operation, string path)
        {
            _lastSuccessArea = area;
            _lastSuccessOperation = operation;
            _lastSuccessSequence = sequence;
            _lastSuccessPath = path;
            WriteSnapshot(sequence, area, operation, "ok", path);
        }

        public static void RecordFail(int sequence, string area, string operation, Exception ex, string path)
        {
            _lastExceptionType = ex?.GetType().Name ?? "unknown";
            _lastExceptionMessage = Sanitize(ex?.Message);
            WriteSnapshot(sequence, area, operation, "fail", path, _lastExceptionType, _lastExceptionMessage);
        }

        public static void RecordDefer(int sequence, string area, string operation, string reason, string path)
        {
            WriteSnapshot(sequence, area, operation, "defer", path, deferReason: reason);
        }

        private static void WriteSnapshot(
            int sequence,
            string area,
            string operation,
            string stage,
            string path,
            string exceptionType = null,
            string exceptionMessage = null,
            string deferReason = null)
        {
            try
            {
                var stabilizationActive = CampaignMapReadyOrchestrator.IsPostMapReadyStabilizationWindow;
                var immediateDone = CampaignMapReadyOrchestrator.ImmediateHooksCompleted;
                var driversBlocked = LaunchPathInference.AreAutonomousDriversBlocked(immediateDone, stabilizationActive);

                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.UtcNow:o}\",");
                builder.AppendLine($"  \"sequence\": {sequence},");
                builder.AppendLine($"  \"area\": \"{Escape(area)}\",");
                builder.AppendLine($"  \"operation\": \"{Escape(operation)}\",");
                builder.AppendLine($"  \"stage\": \"{Escape(stage)}\",");
                if (!string.IsNullOrEmpty(deferReason))
                {
                    builder.AppendLine($"  \"deferReason\": \"{Escape(deferReason)}\",");
                }

                builder.AppendLine($"  \"inferredLaunchPath\": \"{Escape(path)}\",");
                builder.AppendLine($"  \"activeState\": \"{Escape(Safe(() => GameSessionState.GetActiveStateName()))}\",");
                builder.AppendLine($"  \"setupPhase\": \"{Escape(CampaignSetupStateTracker.Phase.ToString())}\",");
                builder.AppendLine($"  \"campaignReady\": {GameSessionState.IsCampaignMapReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mainHeroReady\": {GameSessionState.IsMainHeroReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"stabilizationActive\": {stabilizationActive.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"autonomousDriversBlocked\": {driversBlocked.ToString().ToLowerInvariant()},");
                builder.AppendLine("  \"lastBegin\": {");
                builder.AppendLine($"    \"area\": \"{Escape(_lastBeginArea ?? "")}\",");
                builder.AppendLine($"    \"operation\": \"{Escape(_lastBeginOperation ?? "")}\",");
                builder.AppendLine($"    \"sequence\": {_lastBeginSequence},");
                builder.AppendLine($"    \"path\": \"{Escape(_lastBeginPath ?? "")}\"");
                builder.AppendLine("  },");
                builder.AppendLine("  \"lastSuccess\": {");
                builder.AppendLine($"    \"area\": \"{Escape(_lastSuccessArea ?? "")}\",");
                builder.AppendLine($"    \"operation\": \"{Escape(_lastSuccessOperation ?? "")}\",");
                builder.AppendLine($"    \"sequence\": {_lastSuccessSequence},");
                builder.AppendLine($"    \"path\": \"{Escape(_lastSuccessPath ?? "")}\"");
                builder.AppendLine("  },");

                if (!string.IsNullOrEmpty(exceptionType))
                {
                    builder.AppendLine("  \"lastException\": {");
                    builder.AppendLine($"    \"type\": \"{Escape(exceptionType)}\",");
                    builder.AppendLine($"    \"message\": \"{Escape(exceptionMessage ?? "")}\"");
                    builder.AppendLine("  },");
                }

                builder.AppendLine($"  \"assemblyVersion\": \"{Escape(PendingReloadWatcher.LoadedModuleVersion ?? "")}\",");
                builder.AppendLine($"  \"dllUtc\": \"{Escape(PendingReloadWatcher.LoadedDllWriteUtcIso ?? "")}\"");
                builder.AppendLine("}");

                var tempPath = ContextPath + ".tmp";
                File.WriteAllText(tempPath, builder.ToString());
                if (File.Exists(ContextPath))
                {
                    File.Delete(ContextPath);
                }

                File.Move(tempPath, ContextPath);
            }
            catch
            {
            }
        }

        private static string Safe(Func<string> getter)
        {
            try
            {
                return getter() ?? "";
            }
            catch
            {
                return "";
            }
        }

        private static string Sanitize(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                return "";
            }

            return message.Length > 240 ? message.Substring(0, 240) : message;
        }

        private static string Escape(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return "";
            }

            return value.Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", " ").Replace("\n", " ");
        }
    }
}
