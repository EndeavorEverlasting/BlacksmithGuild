using System;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.DevTools.Assistive;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.DevTools.Assistive
{
    public sealed class AssistiveTravelReadiness
    {
        public bool CanLeaveSettlement { get; set; }
        public bool CanSetTravelTarget { get; set; }
        public string CurrentSettlement { get; set; }
        public string TargetSettlement { get; set; }
        public string TravelCommandMode { get; set; }
        public string Reason { get; set; }
    }

    public static class AssistiveLeaveTownTravelService
    {
        public const string Command = "AssistiveLeaveTownAndTravel";

        public static string LastFailReason { get; private set; }

        public static AssistiveTravelReadiness AssessTravelReadiness()
        {
            GameSessionState.Refresh();
            AssistReadinessEvaluator.ApplyInboxAndAssistFlags(trace: false);

            var result = new AssistiveTravelReadiness
            {
                CurrentSettlement = GameSessionState.CurrentSettlementName
                    ?? GameSessionState.CurrentSettlementStringId
                    ?? "",
                TravelCommandMode = "unavailable",
                Reason = "campaign not ready"
            };

            if (Campaign.Current == null || Hero.MainHero == null || MobileParty.MainParty == null)
            {
                return result;
            }

            result.CanLeaveSettlement = GameSessionState.IsMapMenuOpen
                && GameSessionState.IsCampaignMapReady
                && !string.IsNullOrEmpty(result.CurrentSettlement);

            result.TargetSettlement = ResolveRecommendedTarget();
            result.CanSetTravelTarget = ProbeTravelApi(MobileParty.MainParty, out var travelDetail);

            if (GameSessionState.IsMissionActiveForTrace())
            {
                result.TravelCommandMode = "unavailable";
                result.Reason = "mission_active";
                return result;
            }

            if (AssistReadinessEvaluator.IsOpenMapReady && result.CanSetTravelTarget)
            {
                result.TravelCommandMode = "execute";
                result.Reason = travelDetail ?? "open map surface with travel API";
                return result;
            }

            if (result.CanLeaveSettlement)
            {
                result.TravelCommandMode = "advisory_only";
                result.Reason = "at settlement menu; leave town before travel execute";
                return result;
            }

            result.TravelCommandMode = "unavailable";
            result.Reason = GameSessionState.GetCommandReadyBlockDetail();
            return result;
        }

        public static DevCommandResult RunNow(AssistiveCommandInboxPayload payload = null, string source = Command)
        {
            return AssistiveTravelExecutor.Run(payload, source);
        }

        public static void NoteFailReason(string reason)
        {
            LastFailReason = reason;
        }

        public static string ResolveRecommendedTarget()
        {
            var main = MobileParty.MainParty;
            if (main == null)
            {
                return null;
            }

            var ranked = Settlement.All
                .Where(s => s != null && s.IsTown)
                .Select(s => new
                {
                    Settlement = s,
                    Distance = main.GetPosition2D.Distance(s.GetPosition2D)
                })
                .Where(x => x.Settlement.StringId != GameSessionState.CurrentSettlementStringId)
                .OrderBy(x => x.Distance)
                .FirstOrDefault();

            return ranked?.Settlement?.Name?.ToString() ?? ranked?.Settlement?.StringId;
        }

        public static Settlement ResolveTargetSettlement(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                return null;
            }

            return Settlement.All.FirstOrDefault(s =>
                string.Equals(s.Name?.ToString(), name, StringComparison.OrdinalIgnoreCase)
                || string.Equals(s.StringId, name, StringComparison.OrdinalIgnoreCase));
        }

        private static bool ProbeTravelApi(MobileParty party, out string detail)
        {
            detail = null;
            if (party == null || !GameSessionState.IsCampaignMapReady)
            {
                detail = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            var probeTarget = ResolveTargetSettlement(ResolveRecommendedTarget())
                ?? GameSessionState.ResolveCurrentSettlement();
            if (probeTarget == null)
            {
                detail = "no probe destination";
                return false;
            }

            try
            {
                party.SetMoveGoToSettlement(probeTarget, MobileParty.NavigationType.Default, false);
                party.SetMoveModeHold();
                detail = "SetMoveGoToSettlement probe ok";
                return true;
            }
            catch (Exception ex)
            {
                detail = $"SetMoveGoToSettlement probe failed: {ex.Message}";
            }

            if (TryInvokeOnTarget(party.Ai, probeTarget, "SetMoveGoToSettlement"))
            {
                TryInvokeHold(party);
                detail = "party.Ai.SetMoveGoToSettlement probe ok";
                return true;
            }

            return false;
        }

        private static bool TryInvokeHold(MobileParty party)
        {
            try
            {
                party.SetMoveModeHold();
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool TryInvokeOnTarget(object target, Settlement destination, string methodName)
        {
            if (target == null || destination == null)
            {
                return false;
            }

            var methods = target.GetType().GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
                .Where(m => string.Equals(m.Name, methodName, StringComparison.Ordinal));
            foreach (var method in methods)
            {
                var parameters = method.GetParameters();
                if (parameters.Length == 0 || parameters[0].ParameterType != typeof(Settlement))
                {
                    continue;
                }

                var args = new object[parameters.Length];
                args[0] = destination;
                for (var i = 1; i < parameters.Length; i++)
                {
                    var parameterType = parameters[i].ParameterType;
                    if (parameterType == typeof(bool))
                    {
                        args[i] = false;
                    }
                    else if (parameterType.IsEnum)
                    {
                        args[i] = Enum.GetValues(parameterType).GetValue(0);
                    }
                    else
                    {
                        args[i] = parameterType.IsValueType ? Activator.CreateInstance(parameterType) : null;
                    }
                }

                try
                {
                    method.Invoke(target, args);
                    return true;
                }
                catch
                {
                }
            }

            return false;
        }
    }
}
