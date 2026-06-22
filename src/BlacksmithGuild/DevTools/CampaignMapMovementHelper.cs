using System;
using System.Reflection;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.DevTools
{
    public static class CampaignMapMovementHelper
    {
        public static bool TryMoveToSettlement(MobileParty party, Settlement destination, out string detail)
        {
            detail = null;
            if (party == null || destination == null)
            {
                detail = "party or destination null";
                return false;
            }

            try
            {
                party.SetMoveGoToSettlement(destination, MobileParty.NavigationType.Default, false);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MOVE] SetMoveGoToSettlement failed: {ex.Message}", showInGame: false);
            }

            if (TryInvokeOnTarget(party.Ai, destination, "SetMoveGoToSettlement")
                || TryInvokeOnTarget(party, destination, "SetMoveGoToSettlement")
                || TryInvokeOnTarget(party, destination, "SetMoveGoToSettlementWithShorterPath"))
            {
                return true;
            }

            detail = "Bannerlord move-to-settlement API unavailable";
            return false;
        }

        public static bool TryHold(MobileParty party)
        {
            if (party == null)
            {
                return false;
            }

            try
            {
                party.SetMoveModeHold();
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MOVE] SetMoveModeHold failed: {ex.Message}", showInGame: false);
            }

            return TryInvokeParameterless(party, "SetMoveModeHold");
        }

        public static bool HasArrived(MobileParty party, Settlement destination, float threshold = 1.5f)
        {
            if (party == null || destination == null)
            {
                return false;
            }

            return party.GetPosition2D.Distance(destination.GetPosition2D) <= threshold;
        }

        public static float Distance(MobileParty a, MobileParty b)
        {
            if (a == null || b == null)
            {
                return float.MaxValue;
            }

            return a.GetPosition2D.Distance(b.GetPosition2D);
        }

        public static float Distance(MobileParty party, Settlement settlement)
        {
            if (party == null || settlement == null)
            {
                return float.MaxValue;
            }

            return party.GetPosition2D.Distance(settlement.GetPosition2D);
        }

        public static float EstimateEtaHours(float distance, float speed)
        {
            if (speed <= 0.01f)
            {
                return float.MaxValue;
            }

            return distance / speed;
        }

        public static int PartyStrength(MobileParty party)
        {
            return party?.Party?.NumberOfAllMembers ?? 0;
        }

        private static bool TryInvokeOnTarget(object target, Settlement destination, string methodName)
        {
            if (target == null)
            {
                return false;
            }

            var targetType = target.GetType();
            var methods = targetType.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            foreach (var method in methods)
            {
                if (!string.Equals(method.Name, methodName, StringComparison.Ordinal))
                {
                    continue;
                }

                var parameters = method.GetParameters();
                if (parameters.Length == 0)
                {
                    continue;
                }

                if (!typeof(Settlement).IsAssignableFrom(parameters[0].ParameterType))
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

                if (TryInvokeMethod(method, target, args))
                {
                    return true;
                }
            }

            return false;
        }

        private static bool TryInvokeParameterless(object target, string methodName)
        {
            if (target == null)
            {
                return false;
            }

            var method = target.GetType().GetMethod(
                methodName,
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic,
                null,
                Type.EmptyTypes,
                null);

            return method != null && TryInvokeMethod(method, target, Array.Empty<object>());
        }

        private static bool TryInvokeMethod(MethodInfo method, object target, object[] args)
        {
            try
            {
                method.Invoke(target, args);
                return true;
            }
            catch (TargetInvocationException ex)
            {
                DebugLogger.Test(
                    $"[TBG MOVE] {method.Name} invoke failed: {ex.InnerException?.Message ?? ex.Message}",
                    showInGame: false);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MOVE] {method.Name} invoke failed: {ex.Message}", showInGame: false);
            }

            return false;
        }
    }
}
