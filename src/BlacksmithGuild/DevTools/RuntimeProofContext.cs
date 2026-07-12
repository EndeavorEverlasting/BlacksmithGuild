using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Correlates a local harness request with the exact live game process, loaded assembly,
    /// campaign generation, and active save slot. Disk hashes alone never prove what a process loaded.
    /// </summary>
    public static class RuntimeProofContext
    {
        public const string ReportSaveIdentityNowCommand = "ReportSaveIdentityNow";
        public const string RequestFileName = "BlacksmithGuild_VisibleTradeCycleRequest.json";
        public const string SaveIdentityFileName = "BlacksmithGuild_SaveIdentity.json";

        private static string _runtimeSessionId = Guid.NewGuid().ToString("N");
        private static DateTime _runtimeSessionStartedUtc = DateTime.UtcNow;
        private static string _runId;
        private static string _expectedHeadSha;
        private static string _requestedSaveId;
        private static DateTime _requestWriteUtc = DateTime.MinValue;

        public static string RuntimeSessionId => _runtimeSessionId;
        public static DateTime RuntimeSessionStartedUtc => _runtimeSessionStartedUtc;
        public static string RunId { get { RefreshRequest(); return _runId; } }
        public static string ExpectedHeadSha { get { RefreshRequest(); return _expectedHeadSha; } }
        public static string RequestedSaveId { get { RefreshRequest(); return _requestedSaveId; } }
        public static bool HasVisibleTradeCycleRequest =>
            !string.IsNullOrWhiteSpace(RunId) && !string.IsNullOrWhiteSpace(RequestedSaveId);
        public static string ActiveSaveSlotName => MBSaveLoad.ActiveSaveSlotName;
        public static string LoadedAssemblySha256 => ComputeAssemblySha256();

        public static void ResetForNewCampaign()
        {
            _runtimeSessionId = Guid.NewGuid().ToString("N");
            _runtimeSessionStartedUtc = DateTime.UtcNow;
            _requestWriteUtc = DateTime.MinValue;
            _runId = null;
            _expectedHeadSha = null;
            _requestedSaveId = null;
            RefreshRequest();
        }

        public static bool ReportSaveIdentityNow(string source = ReportSaveIdentityNowCommand)
        {
            RefreshRequest();
            var loadedSave = MBSaveLoad.ActiveSaveSlotName;
            var identityVerified = !string.IsNullOrWhiteSpace(_requestedSaveId)
                && !string.IsNullOrWhiteSpace(loadedSave)
                && string.Equals(NormalizeSaveId(_requestedSaveId), NormalizeSaveId(loadedSave), StringComparison.OrdinalIgnoreCase);

            var process = Process.GetCurrentProcess();
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine("  \"schemaVersion\": \"TbgSaveIdentity.v1\",");
            builder.AppendLine("  \"observedAtUtc\": \"" + DateTime.UtcNow.ToString("o") + "\",");
            builder.AppendLine("  \"source\": \"" + Escape(source) + "\",");
            builder.AppendLine("  \"runId\": " + NullableString(_runId) + ",");
            builder.AppendLine("  \"runtimeSessionId\": \"" + Escape(_runtimeSessionId) + "\",");
            builder.AppendLine("  \"runtimeSessionStartedUtc\": \"" + _runtimeSessionStartedUtc.ToString("o") + "\",");
            builder.AppendLine("  \"processId\": " + process.Id + ",");
            builder.AppendLine("  \"processStartTimeUtc\": \"" + process.StartTime.ToUniversalTime().ToString("o") + "\",");
            builder.AppendLine("  \"requestedSaveId\": " + NullableString(_requestedSaveId) + ",");
            builder.AppendLine("  \"loadedSaveId\": " + NullableString(loadedSave) + ",");
            builder.AppendLine("  \"activeSaveSlotName\": " + NullableString(loadedSave) + ",");
            builder.AppendLine("  \"identityVerified\": " + Boolean(identityVerified) + ",");
            builder.AppendLine("  \"headSha\": " + NullableString(_expectedHeadSha) + ",");
            builder.AppendLine("  \"loadedAssemblyPath\": " + NullableString(Assembly.GetExecutingAssembly().Location) + ",");
            builder.AppendLine("  \"loadedAssemblySha256\": " + NullableString(LoadedAssemblySha256));
            builder.AppendLine("}");

            WriteAllTextAtomic(Path.Combine(BasePath.Name, SaveIdentityFileName), builder.ToString());
            DebugLogger.Test(
                "[TBG SAVE] identity requested=" + (_requestedSaveId ?? "none")
                + " loaded=" + (loadedSave ?? "none")
                + " verified=" + identityVerified,
                showInGame: false);
            if (identityVerified)
            {
                InGameNotice.Success("TBG SAVE: verified " + loadedSave + ".");
            }
            else
            {
                InGameNotice.Blocked("TBG SAVE: requested save does not match the active slot.");
            }

            return identityVerified;
        }

        public static void WriteAllTextAtomic(string path, string content)
        {
            var tempPath = path + ".tmp-" + Process.GetCurrentProcess().Id;
            File.WriteAllText(tempPath, content, new UTF8Encoding(false));
            if (File.Exists(path))
            {
                File.Replace(tempPath, path, null);
            }
            else
            {
                File.Move(tempPath, path);
            }
        }

        private static void RefreshRequest()
        {
            try
            {
                var path = Path.Combine(BasePath.Name, RequestFileName);
                if (!File.Exists(path))
                {
                    return;
                }

                var writeUtc = File.GetLastWriteTimeUtc(path);
                if ((_runtimeSessionStartedUtc - writeUtc).TotalMinutes > 10d)
                {
                    _runId = null;
                    _expectedHeadSha = null;
                    _requestedSaveId = null;
                    _requestWriteUtc = writeUtc;
                    return;
                }
                if (writeUtc == _requestWriteUtc)
                {
                    return;
                }

                var json = File.ReadAllText(path);
                _runId = ReadString(json, "runId");
                _expectedHeadSha = ReadString(json, "headSha");
                _requestedSaveId = ReadString(json, "requestedSaveId");
                _requestWriteUtc = writeUtc;
            }
            catch (Exception ex)
            {
                DebugLogger.Test("[TBG SAVE] request read failed: " + ex.Message, showInGame: false);
            }
        }

        private static string ComputeAssemblySha256()
        {
            try
            {
                using (var stream = File.OpenRead(Assembly.GetExecutingAssembly().Location))
                using (var sha = SHA256.Create())
                {
                    var bytes = sha.ComputeHash(stream);
                    var builder = new StringBuilder(bytes.Length * 2);
                    foreach (var value in bytes)
                    {
                        builder.Append(value.ToString("x2"));
                    }

                    return builder.ToString();
                }
            }
            catch
            {
                return null;
            }
        }

        private static string ReadString(string json, string key)
        {
            var match = Regex.Match(
                json ?? string.Empty,
                "\\\"" + Regex.Escape(key) + "\\\"\\s*:\\s*\\\"(?<value>(?:\\\\.|[^\\\"])*)\\\"",
                RegexOptions.IgnoreCase);
            if (!match.Success)
            {
                return null;
            }

            return Regex.Unescape(match.Groups["value"].Value);
        }

        private static string NormalizeSaveId(string value)
        {
            var normalized = (value ?? string.Empty).Trim();
            return normalized.EndsWith(".sav", StringComparison.OrdinalIgnoreCase)
                ? normalized.Substring(0, normalized.Length - 4)
                : normalized;
        }

        private static string Boolean(bool value) => value ? "true" : "false";
        private static string NullableString(string value) => value == null ? "null" : "\"" + Escape(value) + "\"";
        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
