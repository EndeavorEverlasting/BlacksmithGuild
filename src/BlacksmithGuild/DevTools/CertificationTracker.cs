using System;
using System.Collections.Generic;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.DevTools
{
    public static class CertificationTracker
    {
        public const string SprintId = "001";

        private static readonly string[] RequiredChecks =
        {
            "forge_lit",
            "preflight_pass",
            "list_commands",
            "advance_one_day",
            "toggle_fast_forward",
            "gold_test"
        };

        private static readonly Dictionary<string, CheckState> Checks =
            new Dictionary<string, CheckState>(StringComparer.OrdinalIgnoreCase);

        private static int _fastForwardToggleSuccesses;
        private static string _lastOverall = "NOT_STARTED";

        private struct CheckState
        {
            public string Status;
            public string At;
            public string Message;
        }

        public static void RecordCheck(string name, string status, string message = null)
        {
            Checks[name] = new CheckState
            {
                Status = status,
                At = DateTime.Now.ToString("o"),
                Message = message
            };

            MaybeEmitCertReport();
        }

        public static void OnForgeLit()
        {
            RecordCheck("forge_lit", "PASS");
        }

        public static void OnPreflightPass()
        {
            RecordCheck("preflight_pass", "PASS");
        }

        public static void OnPreflightFail(string reason)
        {
            RecordCheck("preflight_pass", "FAIL", reason);
        }

        public static void OnCommandResult(string commandName, DevCommandResult result, string detail = null)
        {
            if (result == DevCommandResult.Blocked &&
                string.Equals(detail, "preflight failed", StringComparison.OrdinalIgnoreCase) == false &&
                detail != null &&
                detail.Contains("preflight"))
            {
                return;
            }

            switch (commandName)
            {
                case DevCommandRegistry.ListScenariosCommand:
                    if (result == DevCommandResult.Success)
                    {
                        RecordCheck("list_commands", "PASS");
                    }
                    else if (result == DevCommandResult.Failed)
                    {
                        RecordCheck("list_commands", "FAIL", detail);
                    }

                    break;
                case DevCommandRegistry.AdvanceOneDayCommand:
                    if (result == DevCommandResult.Success)
                    {
                        RecordCheck("advance_one_day", "PASS");
                    }
                    else if (result == DevCommandResult.Failed || result == DevCommandResult.Blocked)
                    {
                        RecordCheck("advance_one_day", result == DevCommandResult.Blocked ? "BLOCKED" : "FAIL", detail);
                    }

                    break;
                case DevCommandRegistry.ToggleFastForwardCommand:
                    if (result == DevCommandResult.Success)
                    {
                        _fastForwardToggleSuccesses++;
                        if (_fastForwardToggleSuccesses >= 2)
                        {
                            RecordCheck("toggle_fast_forward", "PASS");
                        }
                        else
                        {
                            RecordCheck(
                                "toggle_fast_forward",
                                "IN_PROGRESS",
                                $"toggle {_fastForwardToggleSuccesses}/2"
                            );
                        }
                    }
                    else if (result == DevCommandResult.Failed || result == DevCommandResult.Blocked)
                    {
                        RecordCheck("toggle_fast_forward", result == DevCommandResult.Blocked ? "BLOCKED" : "FAIL", detail);
                    }

                    break;
                case EconomyTestScenarios.RichPlayerEconomyTestName:
                    if (result == DevCommandResult.Success)
                    {
                        RecordCheck("gold_test", "PASS");
                    }
                    else if (result == DevCommandResult.Failed)
                    {
                        RecordCheck("gold_test", "FAIL", detail);
                    }
                    else if (result == DevCommandResult.Blocked)
                    {
                        RecordCheck("gold_test", "BLOCKED", detail);
                    }

                    break;
            }
        }

        public static string DeriveOverall(bool campaignReady, bool mainHeroReady)
        {
            foreach (var check in Checks.Values)
            {
                if (string.Equals(check.Status, "FAIL", StringComparison.OrdinalIgnoreCase))
                {
                    return "FAIL";
                }
            }

            foreach (var check in Checks.Values)
            {
                if (string.Equals(check.Status, "BLOCKED", StringComparison.OrdinalIgnoreCase))
                {
                    return "BLOCKED";
                }
            }

            int passed = 0;
            foreach (var name in RequiredChecks)
            {
                if (Checks.TryGetValue(name, out var state) &&
                    string.Equals(state.Status, "PASS", StringComparison.OrdinalIgnoreCase))
                {
                    passed++;
                }
            }

            if (passed >= RequiredChecks.Length)
            {
                return "PASS";
            }

            if (!campaignReady)
            {
                return "NOT_STARTED";
            }

            if (!mainHeroReady)
            {
                return "WARMUP";
            }

            return passed > 0 ? "IN_PROGRESS" : "WARMUP";
        }

        public static string GetNextCheck()
        {
            foreach (var name in RequiredChecks)
            {
                if (!Checks.TryGetValue(name, out var state) ||
                    !string.Equals(state.Status, "PASS", StringComparison.OrdinalIgnoreCase))
                {
                    return name;
                }
            }

            return string.Empty;
        }

        public static int CountPassed()
        {
            int passed = 0;
            foreach (var name in RequiredChecks)
            {
                if (Checks.TryGetValue(name, out var state) &&
                    string.Equals(state.Status, "PASS", StringComparison.OrdinalIgnoreCase))
                {
                    passed++;
                }
            }

            return passed;
        }

        public static IReadOnlyList<string> RequiredCheckNames => RequiredChecks;

        public static bool TryGetCheck(string name, out string status, out string at, out string message)
        {
            if (Checks.TryGetValue(name, out var state))
            {
                status = state.Status;
                at = state.At;
                message = state.Message;
                return true;
            }

            status = "PENDING";
            at = null;
            message = null;
            return false;
        }

        private static void MaybeEmitCertReport()
        {
            var overall = DeriveOverall(campaignReady: true, mainHeroReady: true);
            if (overall == _lastOverall)
            {
                return;
            }

            _lastOverall = overall;
            if (overall == "PASS" || overall == "FAIL" || overall == "BLOCKED")
            {
                CertificationReporter.WriteSprint001Report();
            }
        }
    }
}
