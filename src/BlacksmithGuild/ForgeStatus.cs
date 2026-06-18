using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
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
        private static int _lastCommandSequence = -1;
        private static DateTime? _lastCommandTime;
        private static GoldTestSnapshot _goldTest;
        private static SessionPhase _sessionPhase = SessionPhase.ModuleOnly;
        private static bool _sessionTimePaused;

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

            if (string.Equals(verdict, "Pass", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnPreflightPass();
            }
            else if (string.Equals(verdict, "Fail", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnPreflightFail(reason);
            }

            Flush(overall: verdict == "Fail" ? "FAIL" : null);
        }

        public static void SetTest(string name, string status, string message = null)
        {
            TestStatuses[name] = status;
            if (!string.IsNullOrEmpty(message))
            {
                TestMessages[name] = message;
            }

            if (string.Equals(name, "forge_lit", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(status, "PASS", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnForgeLit();
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

        public static void UpdateSession(SessionPhase phase, bool timePaused)
        {
            _sessionPhase = phase;
            _sessionTimePaused = timePaused;
            _campaignReady = phase != SessionPhase.ModuleOnly;
            _mainHeroReady = phase != SessionPhase.ModuleOnly && phase != SessionPhase.CampaignLoading;
            Flush();
        }

        public static void RecordCommand(
            string commandName,
            string source,
            string result,
            string detail = null,
            int sequence = -1)
        {
            _lastCommand = commandName;
            _lastCommandSource = source;
            _lastCommandResult = result;
            _lastCommandDetail = detail;
            _lastCommandSequence = sequence;
            _lastCommandTime = DateTime.Now;
            Log($"COMMAND {commandName} source={source} result={result} seq={sequence}{(string.IsNullOrEmpty(detail) ? "" : " - " + detail)}");
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
                var certificationOverall = CertificationTracker.DeriveOverall(_campaignReady, _mainHeroReady);
                var topOverall = overall ?? certificationOverall;

                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"modLoaded\": {_modLoaded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"campaignReady\": {_campaignReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mainHeroReady\": {_mainHeroReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"overall\": \"{Escape(topOverall)}\",");
                builder.AppendLine("  \"session\": {");
                builder.AppendLine($"    \"phase\": \"{Escape(_sessionPhase.ToString())}\",");
                builder.AppendLine($"    \"timePaused\": {_sessionTimePaused.ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"canPollFileInbox\": {GameSessionState.CanPollFileInbox.ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"canPollHotkeys\": {GameSessionState.CanPollHotkeys.ToString().ToLowerInvariant()}");
                builder.AppendLine("  },");

                builder.AppendLine("  \"certification\": {");
                builder.AppendLine($"    \"sprint\": \"{CertificationTracker.SprintId}\",");
                builder.AppendLine($"    \"overall\": \"{Escape(certificationOverall)}\",");
                builder.AppendLine($"    \"completed\": {CertificationTracker.CountPassed()},");
                builder.AppendLine($"    \"required\": {CertificationTracker.RequiredCheckNames.Count},");
                builder.AppendLine($"    \"nextCheck\": \"{Escape(CertificationTracker.GetNextCheck())}\",");
                builder.AppendLine("    \"checks\": {");

                var checkFirst = true;
                foreach (var checkName in CertificationTracker.RequiredCheckNames)
                {
                    CertificationTracker.TryGetCheck(checkName, out var status, out var at, out var message);
                    if (!checkFirst)
                    {
                        builder.AppendLine(",");
                    }

                    checkFirst = false;
                    if (!string.IsNullOrEmpty(at) && !string.IsNullOrEmpty(message))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\", \"message\": \"{Escape(message)}\" }}"
                        );
                    }
                    else if (!string.IsNullOrEmpty(at))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\" }}"
                        );
                    }
                    else
                    {
                        builder.Append($"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\" }}");
                    }
                }

                builder.AppendLine();
                builder.AppendLine("    }");
                builder.AppendLine("  },");

                if (!string.IsNullOrEmpty(_lastCommand))
                {
                    builder.AppendLine("  \"lastCommand\": {");
                    builder.AppendLine($"    \"name\": \"{Escape(_lastCommand)}\",");
                    builder.AppendLine($"    \"source\": \"{Escape(_lastCommandSource ?? "")}\",");
                    builder.AppendLine($"    \"sequence\": {_lastCommandSequence},");
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
                    builder.AppendLine("    \"ran\": true,");
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
                    TestMessages.TryGetValue(entry.Key, out var testMessage);
                    if (!string.IsNullOrEmpty(testMessage))
                    {
                        builder.Append(
                            $"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\", \"message\": \"{Escape(testMessage)}\" }}"
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

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
