using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild
{
    public static class ForgeStatus
    {
        private static readonly string StatusPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Status.json");

        private static readonly string ForgeLogPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Forge.log");

        private static readonly Dictionary<string, string> TestStatuses =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        public static void Log(string message)
        {
            try
            {
                File.AppendAllText(
                    ForgeLogPath,
                    $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}{Environment.NewLine}"
                );
            }
            catch
            {
            }
        }

        public static void SetStep(string name, string status, string message = null)
        {
            Log($"STEP {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            Flush(source: "in-game", overall: status == "FAIL" ? "FAIL" : null);
        }

        public static void SetPreflight(string verdict, string reason)
        {
            Log($"PREFLIGHT {verdict} - {reason}");
            Flush(source: "in-game", overall: verdict == "Fail" ? "FAIL" : null, preflightVerdict: verdict, preflightReason: reason);
        }

        public static void SetTest(string name, string status, string message = null)
        {
            TestStatuses[name] = status;
            Log($"TEST {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            Flush(source: "in-game", overall: status == "FAIL" ? "FAIL" : null);
        }

        public static void RecordError(string message)
        {
            Log($"ERROR {message}");
            Flush(source: "in-game", overall: "FAIL", error: message);
        }

        private static void Flush(
            string source = null,
            string overall = null,
            string preflightVerdict = null,
            string preflightReason = null,
            string error = null)
        {
            try
            {
                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"source\": \"{Escape(source ?? "in-game")}\",");
                builder.AppendLine($"  \"overall\": \"{Escape(overall ?? DeriveOverall())}\",");

                if (!string.IsNullOrEmpty(preflightVerdict))
                {
                    builder.AppendLine("  \"preflight\": {");
                    builder.AppendLine($"    \"verdict\": \"{Escape(preflightVerdict)}\",");
                    builder.AppendLine($"    \"reason\": \"{Escape(preflightReason ?? "")}\"");
                    builder.AppendLine("  },");
                }

                builder.AppendLine("  \"tests\": {");
                var first = true;
                foreach (var entry in TestStatuses)
                {
                    if (!first)
                    {
                        builder.AppendLine(",");
                    }

                    first = false;
                    builder.Append($"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\" }}");
                }

                builder.AppendLine();
                builder.AppendLine("  }");

                if (!string.IsNullOrEmpty(error))
                {
                    builder.AppendLine(",");
                    builder.AppendLine("  \"errors\": [");
                    builder.AppendLine($"    {{ \"message\": \"{Escape(error)}\" }}");
                    builder.AppendLine("  ]");
                }

                builder.AppendLine("}");
                File.WriteAllText(StatusPath, builder.ToString());
            }
            catch
            {
            }
        }

        private static string DeriveOverall()
        {
            foreach (var status in TestStatuses.Values)
            {
                if (string.Equals(status, "FAIL", StringComparison.OrdinalIgnoreCase))
                {
                    return "FAIL";
                }
            }

            return "RUNNING";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
