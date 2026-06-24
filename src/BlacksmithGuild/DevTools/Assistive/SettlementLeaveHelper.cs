using System;
using System.Collections.Generic;
using System.Reflection;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class SettlementLeaveHelper
    {
        private static readonly string[] LeaveOptionIds =
        {
            "leave",
            "town_leave",
            "back_to_map",
            "continue",
            "town_back"
        };

        public static bool TryLeaveTown(
            List<AssistiveTravelStep> steps,
            out bool leaveTownAttempted,
            out bool leaveTownSucceeded,
            out string reason)
        {
            leaveTownAttempted = false;
            leaveTownSucceeded = false;
            reason = null;

            if (!AssistReadinessEvaluator.CanAcceptAssistiveCommand)
            {
                reason = "assist_command_blocked";
                DebugLogger.Test($"[TBG ASSIST] travel stage=leave_town skipped reason={reason}", showInGame: false);
                return false;
            }

            if (!AssistReadinessEvaluator.IsTownMenuReady
                || !GameSessionState.IsMapMenuOpen
                || string.IsNullOrEmpty(GameSessionState.CurrentSettlementStringId))
            {
                reason = "not_at_settlement_menu";
                DebugLogger.Test($"[TBG ASSIST] travel stage=leave_town skipped reason={reason}", showInGame: false);
                return false;
            }

            leaveTownAttempted = true;

            foreach (var optionId in LeaveOptionIds)
            {
                if (TryRunMenuOption(steps, optionId, out _))
                {
                    GameSessionState.Refresh();
                    if (IsLeaveSucceeded())
                    {
                        leaveTownSucceeded = true;
                        DebugLogger.Test("[TBG ASSIST] travel stage=leave_town ok", showInGame: false);
                        return true;
                    }
                }
            }

            if (TryReflectionLeave(steps, out var reflectionDetail))
            {
                GameSessionState.Refresh();
                if (IsLeaveSucceeded())
                {
                    leaveTownSucceeded = true;
                    DebugLogger.Test($"[TBG ASSIST] travel stage=leave_town ok reason={reflectionDetail}", showInGame: false);
                    return true;
                }
            }

            reason = GameSessionState.IsMapMenuOpen ? "leave_town_incomplete" : "leave_town_failed";
            DebugLogger.Test($"[TBG ASSIST] travel stage=leave_town failed reason={reason}", showInGame: false);
            return false;
        }

        private static bool IsLeaveSucceeded()
        {
            return !GameSessionState.IsMapMenuOpen && AssistReadinessEvaluator.IsOpenMapReady;
        }

        private static bool TryRunMenuOption(List<AssistiveTravelStep> steps, string optionId, out string detail)
        {
            detail = null;
            try
            {
                var context = Campaign.Current?.CurrentMenuContext;
                var manager = Campaign.Current?.GameMenuManager;
                if (context == null || manager == null)
                {
                    detail = "menu context unavailable";
                    return false;
                }

                var count = manager.GetVirtualMenuOptionAmount(context);
                for (var i = 0; i < count; i++)
                {
                    if (!manager.GetVirtualMenuOptionConditionsHold(context, i))
                    {
                        continue;
                    }

                    var optionIdString = manager.GetMenuOptionIdString(context, i);
                    if (string.IsNullOrEmpty(optionIdString)
                        || optionIdString.IndexOf(optionId, StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        continue;
                    }

                    manager.RunConsequencesOfMenuOption(context, i);
                    steps.Add(Step("LeaveTown", "VanillaMenuOption", "Success", optionIdString));
                    return true;
                }

                detail = $"menu option '{optionId}' not found among {count} options";
                return false;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                steps.Add(Step("LeaveTown", "VanillaMenuOption", "Failed", detail));
                return false;
            }
        }

        private static bool TryReflectionLeave(List<AssistiveTravelStep> steps, out string detail)
        {
            detail = null;
            var encounterType = Type.GetType("TaleWorlds.CampaignSystem.Encounters.PlayerEncounter, TaleWorlds.CampaignSystem");
            if (encounterType == null)
            {
                return false;
            }

            foreach (var methodName in new[] { "LeaveSettlement", "FinishSettlement" })
            {
                var method = encounterType.GetMethod(
                    methodName,
                    BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic);
                if (method == null || method.GetParameters().Length != 0)
                {
                    continue;
                }

                try
                {
                    method.Invoke(null, null);
                    steps.Add(Step("LeaveTown", "PlayerEncounterReflection", "Success", methodName));
                    detail = methodName;
                    return true;
                }
                catch (Exception ex)
                {
                    steps.Add(Step("LeaveTown", "PlayerEncounterReflection", "Failed", $"{methodName}: {ex.Message}"));
                }
            }

            return false;
        }

        private static AssistiveTravelStep Step(string name, string method, string status, string detail)
        {
            return new AssistiveTravelStep
            {
                Name = name,
                Method = method,
                Status = status,
                Detail = detail
            };
        }
    }
}
