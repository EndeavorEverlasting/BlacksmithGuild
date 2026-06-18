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

        private static readonly Dictionary<string, string> TestMessages =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        private static bool _modLoaded = true;
        private static bool _campaignReady;
        private static bool _mainHeroReady;
        private static string _preflightVerdict;
        private static string _preflightReason;
        private static string _lastCommand;
        private static string _lastCommandSource;
        private static string _lastCommandResult;
        private static string _lastCommandDetail;
        private static DateTime? _lastCommandTime;
        private static GoldTestSnapshot _goldTest;

        private struct GoldTestSnapshot
        {
            public bool Ran;
            public bool Passed;
            public int GoldBefore;
            public int GoldAfter;
            public int Delta;
        }

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

        public static void SetModLoaded(bool loaded)
        {
            _modLoaded = loaded;
            Flush();
        }

        public static void SetStep(string name, string status, string message = null)
        {
            Log($"STEP {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            Flush(overall: status == "FAIL" ? "FAIL" : null);
        }

        public static void SetPreflight(string verdict, string reason)
        {
            _preflightVerdict = verdict;
            _preflightReason = reason;
            Log($"PREFLIGHT {verdict} - {reason}");
            Flush(overall: verdict == "Fail" ? "FAIL" : null);
        }

        public static void SetTest(string name, string status, string message = null)
        {
            TestStatuses[name] = status;
            if (!string.IsNullOrEmpty(message))
            {
                TestMessages[name] = message;
            }

            Log($"TEST {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            Flush(overall: status == "FAIL" ? "FAIL" : null);
        }

        public static void RecordGoldTest(bool passed, int goldBefore, int goldAfter, int delta)
        {
            _goldTest = new GoldTestSnapshot
            {
                Ran = true,
                Passed = passed,
                GoldBefore = goldBefore,
                GoldAfter = goldAfter,
                Delta = delta
            };
            Flush();
        }

        public static void UpdateReadiness(bool campaignReady, bool mainHeroReady)
        {
            _campaignReady = campaignReady;
            _mainHeroReady = mainHeroReady;
            Flush();
        }

        public static void RecordCommand(
            string commandName,
            string source,
            string result,
            string detail = null)
        {
            _lastCommand = commandName;
            _lastCommandSource = source;
            _lastCommandResult = result;
            _lastCommandDetail = detail;
            _lastCommandTime = DateTime.Now;
            Log($"COMMAND {commandName} source={source} result={result}{(string.IsNullOrEmpty(detail) ? "" : " - " + detail)}");
            Flush(overall: result == "FAIL" ? "FAIL" : null);
        }

        public static void RecordError(string message)
        {
            Log($"ERROR {message}");
            Flush(overall: "FAIL", error: message);
        }

        private static void Flush(
            string overall = null,
            string error = null)
        {
            try
            {
                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"modLoaded\": {_modLoaded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"campaignReady\": {_campaignReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mainHeroReady\": {_mainHeroReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"overall\": \"{Escape(overall ?? DeriveOverall())}\",");

                if (!string.IsNullOrEmpty(_lastCommand))
                {
                    builder.AppendLine("  \"lastCommand\": {");
                    builder.AppendLine($"    \"name\": \"{Escape(_lastCommand)}\",");
                    builder.AppendLine($"    \"source\": \"{Escape(_lastCommandSource ?? "")}\",");
                    builder.AppendLine($"    \"time\": \"{(_lastCommandTime ?? DateTime.Now):o}\",");
                    builder.AppendLine($"    \"result\": \"{Escape(_lastCommandResult ?? "")}\"");
                    if (!string.IsNullOrEmpty(_lastCommandDetail))
                    {
                        builder.AppendLine(",");
                        builder.AppendLine($"    \"detail\": \"{Escape(_lastCommandDetail)}\"");
                    }

                    builder.AppendLine("  },");
                }

                if (!string.IsNullOrEmpty(_preflightVerdict))
                {
                    builder.AppendLine("  \"preflight\": {");
                    builder.AppendLine($"    \"verdict\": \"{Escape(_preflightVerdict)}\",");
                    builder.AppendLine($"    \"reason\": \"{Escape(_preflightReason ?? "")}\"");
                    builder.AppendLine("  },");
                }

                if (_goldTest.Ran)
                {
                    builder.AppendLine("  \"goldTest\": {");
                    builder.AppendLine($"    \"ran\": true,");
                    builder.AppendLine($"    \"passed\": {_goldTest.Passed.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"goldBefore\": {_goldTest.GoldBefore},");
                    builder.AppendLine($"    \"goldAfter\": {_goldTest.GoldAfter},");
                    builder.AppendLine($"    \"delta\": {_goldTest.Delta}");
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
                    TestMessages.TryGetValue(entry.Key, out var message);
                    if (!string.IsNullOrEmpty(message))
                    {
                        builder.Append(
                            $"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\", \"message\": \"{Escape(message)}\" }}"
                        );
                    }
                    else
                    {
                        builder.Append($"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\" }}");
                    }
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

            if (_goldTest.Ran && _goldTest.Passed)
            {
                return "PASS";
            }

            return "RUNNING";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
