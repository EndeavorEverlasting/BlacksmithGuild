using System;
using System.Collections.Generic;

namespace BlacksmithGuild.DevTools
{
    public static class Sprint002CertificationTracker
    {
        public const string SprintId = "002";

        private static readonly string[] RequiredChecks =
        {
            "rich_smithing_progression",
            "add_smithing_xp",
            "add_smithing_focus",
            "add_endurance_attribute"
        };

        private static readonly Dictionary<string, CheckState> Checks =
            new Dictionary<string, CheckState>(StringComparer.OrdinalIgnoreCase);

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
        }

        public static void OnCommandResult(string commandName, DevCommandResult result, string detail = null)
        {
            string checkName = null;
            switch (commandName)
            {
                case CharacterProgressionTestScenarios.RichSmithingProgressionTestName:
                    checkName = "rich_smithing_progression";
                    break;
                case CharacterProgressionTestScenarios.AddSmithingXpCommand:
                    checkName = "add_smithing_xp";
                    break;
                case CharacterProgressionTestScenarios.AddSmithingFocusCommand:
                    checkName = "add_smithing_focus";
                    break;
                case CharacterProgressionTestScenarios.AddEnduranceAttributeCommand:
                    checkName = "add_endurance_attribute";
                    break;
            }

            if (checkName == null)
            {
                return;
            }

            if (result == DevCommandResult.Success)
            {
                RecordCheck(checkName, "PASS");
            }
            else if (result == DevCommandResult.Blocked)
            {
                RecordCheck(checkName, "BLOCKED", detail);
            }
            else if (result == DevCommandResult.Failed)
            {
                RecordCheck(checkName, "FAIL", detail);
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

            int passed = CountPassed();
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
    }
}
