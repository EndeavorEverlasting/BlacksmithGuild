using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.Forge;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    public static class AutoTravelService
    {
        public const string ShowAutoTravelChoicesCommand = "ShowAutoTravelChoices";
        public const string AutoTravelToRecommendedCommand = "AutoTravelToRecommended";
        public const string AutoTravelChoice1Command = "AutoTravelChoice1";
        public const string AutoTravelChoice2Command = "AutoTravelChoice2";
        public const string AutoTravelChoice3Command = "AutoTravelChoice3";
        public const string AutoTravelChoice4Command = "AutoTravelChoice4";
        public const string AutoTravelChoice5Command = "AutoTravelChoice5";
        public const string AutoTravelPrefix = "AutoTravel:";

        private const int ChoiceCount = 5;
        private const float HostilePreFilterDistance = 10f;
        private const int HostileCheckIntervalTicks = 5;
        private const float AssistMovementThreshold = 0.30f;
        private static readonly List<AutoTravelChoice> _choices = new List<AutoTravelChoice>();
        private static string _lastFailReason;
        private static Settlement _activeDestination;
        private static int _hostileCheckTickCounter;

        private static AssistiveTravelExecutionResult _assistResult;
        private static Vec2 _assistStartPos;
        private static DateTime _assistStartUtc;
        private static double _assistMaxDistance;
        private static bool _assistMovementObserved;

        public static string LastFailReason => _lastFailReason;

        public static bool HasActiveRoute => _activeDestination != null;

        // True while an assistive travel is actively driving the party with the campaign clock
        // running. Heavy diagnostic scans (e.g. faction-power posture) skip while this is set to
        // avoid touching transient parties mid-simulation.
        public static bool IsAssistTravelActive => _assistResult != null && _activeDestination != null;

        public static Settlement ActiveRouteDestination => _activeDestination;

        public static void OnCampaignTick()
        {
            if (_activeDestination == null || !GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                return;
            }

            if (MobileParty.MainParty.GetPosition2D.Distance(_activeDestination.GetPosition2D) <= 1.5f)
            {
                var arrived = _activeDestination.Name?.ToString() ?? _activeDestination.StringId;
                _activeDestination = null;
                FinalizeAssistArrival();
                InGameNotice.Success($"TBG TRAVEL: arrived near {arrived}.");
                DebugLogger.Test($"[TBG TRAVEL] arrived near {arrived}.", showInGame: false);
                return;
            }

            if (!ShouldCheckHostilesThisTick())
            {
                return;
            }

            if (TryDetectBlockingHostiles(MobileParty.MainParty, out var hostileDetail))
            {
                if (TryInvokeHold(MobileParty.MainParty))
                {
                    _activeDestination = null;
                    _assistResult = null;
                    _lastFailReason = hostileDetail;
                    AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.TravelBlocked, reason: hostileDetail);
                    InGameNotice.Blocked($"TBG TRAVEL paused: {hostileDetail}");
                    DebugLogger.Test($"[TBG TRAVEL] paused route monitor: {hostileDetail}", showInGame: false);
                }
                else
                {
                    DebugLogger.Test(
                        $"[TBG TRAVEL] hold failed; route monitor stays active: {hostileDetail}",
                        showInGame: false
                    );
                }
            }
        }

        public static DevCommandResult ShowChoices()
        {
            if (!RefreshChoices())
            {
                return DevCommandResult.Failed;
            }

            InGameNotice.Info("TBG TRAVEL choices: type AutoTravelChoice1-5 or AutoTravel:<town>.");
            foreach (var choice in _choices)
            {
                InGameNotice.Info($"{choice.Number}) {choice.Name} — {choice.Reason}");
                DebugLogger.Test($"[TBG TRAVEL] {choice.Number}) {choice.Name} id={choice.StringId} reason={choice.Reason}", showInGame: false);
            }

            return DevCommandResult.Success;
        }

        public static DevCommandResult TravelToRecommended()
        {
            return TravelByChoiceNumber(1);
        }

        public static DevCommandResult TravelByChoiceNumber(int number)
        {
            if (_choices.Count == 0 && !RefreshChoices())
            {
                return DevCommandResult.Failed;
            }

            var choice = _choices.FirstOrDefault(c => c.Number == number);
            if (choice == null)
            {
                _lastFailReason = $"choice {number} is not available; run {ShowAutoTravelChoicesCommand}";
                return DevCommandResult.Failed;
            }

            return StartTravel(choice.Settlement, $"choice {number}");
        }

        public static bool TryStartTravelToSettlement(
            Settlement destination,
            string selector,
            out string detail,
            AssistiveTravelExecutionResult assistResult = null)
        {
            detail = null;
            if (!GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                detail = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            if (destination == null)
            {
                detail = "destination was not resolved";
                return false;
            }

            if (TryDetectBlockingHostiles(MobileParty.MainParty, out var hostileDetail))
            {
                detail = hostileDetail;
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.TravelBlocked, reason: hostileDetail);
                return false;
            }

            if (!TryInvokeMoveToSettlement(MobileParty.MainParty, destination))
            {
                detail = "travel_api_unavailable";
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.TravelBlocked, reason: detail);
                return false;
            }

            _activeDestination = destination;
            _hostileCheckTickCounter = 0;
            if (assistResult != null)
            {
                BeginAssistTravel(assistResult);
            }

            var name = destination.Name?.ToString() ?? destination.StringId;
            detail = $"SetMoveGoToSettlement ok via {selector} to {name}";
            AutomationRuntimeEventEmitter.Emit(
                AutomationRuntimeEventEmitter.TravelStarted,
                reason: selector,
                payloadJson: "{\"destination\":\"" + EscapeJson(name) + "\"}");
            DebugLogger.Test($"[TBG TRAVEL] assist execute started to {name} via {selector}; cautious route monitor active.", showInGame: false);
            return true;
        }

        // Begins authoritative real-movement observation for an assistive travel command and
        // resumes the campaign clock so the party actually moves on the map (not just route intent).
        private static void BeginAssistTravel(AssistiveTravelExecutionResult result)
        {
            _assistResult = result;
            _assistStartUtc = DateTime.UtcNow;
            _assistStartPos = MobileParty.MainParty != null ? MobileParty.MainParty.GetPosition2D : default(Vec2);
            _assistMaxDistance = 0;
            _assistMovementObserved = false;

            if (result != null)
            {
                result.MovementObservationStartedAtUtc = _assistStartUtc;
                result.MovementObservationEndedAtUtc = _assistStartUtc;
                result.MovementObservationAttempts = 0;
                result.MovementIntentSet = true;
                result.ActualExecutionObserved = false;
                result.MovementObservationPassed = false;
                result.Arrived = false;
                result.PartyMovedDistance = 0;
            }

            ReassertRunningClock();
            if (result != null)
            {
                result.TravelClockRunning = IsClockRunning();
            }
        }

        // Frame-rate observation of REAL party position delta. Only flips ActualExecutionObserved
        // once the party has actually moved on the map, never on route intent alone.
        public static void OnRealtimeTick()
        {
            var result = _assistResult;
            if (result == null || MobileParty.MainParty == null || !GameSessionState.IsCampaignMapReady)
            {
                return;
            }

            var pos = MobileParty.MainParty.GetPosition2D;
            var movedFromStart = pos.Distance(_assistStartPos);
            if (movedFromStart > _assistMaxDistance)
            {
                _assistMaxDistance = movedFromStart;
            }

            var now = DateTime.UtcNow;
            result.PartyMovedDistance = _assistMaxDistance;
            result.MovementObservationEndedAtUtc = now;
            result.MovementObservationMs = (int)Math.Max(0, (now - _assistStartUtc).TotalMilliseconds);
            result.MovementObservationAttempts++;
            result.TravelClockRunning = IsClockRunning();

            var changed = false;

            if (!_assistMovementObserved && _assistMaxDistance >= AssistMovementThreshold)
            {
                _assistMovementObserved = true;
                result.MovementIntentSet = true;
                result.ActualExecutionObserved = true;
                result.MovementObservationPassed = true;
                result.MovementObservationFailureReason = null;
                result.Steps.Add(new AssistiveTravelStep
                {
                    Name = "MovementObservation",
                    Method = "PositionDelta",
                    Status = "Observed",
                    Detail = $"distance={_assistMaxDistance.ToString("0.###", CultureInfo.InvariantCulture)} clockRunning={IsClockRunning().ToString().ToLowerInvariant()}"
                });
                changed = true;
            }

            var dest = _activeDestination;
            if (dest != null && pos.Distance(dest.GetPosition2D) <= 1.5f)
            {
                result.Arrived = true;
                changed = true;
            }

            if (!result.Arrived && _activeDestination != null)
            {
                ReassertRunningClock();
            }

            if (changed)
            {
                AssistiveTravelEvidenceWriter.Write(result);
                if (result.Arrived)
                {
                    _assistResult = null;
                }
            }
        }

        private static void FinalizeAssistArrival()
        {
            var result = _assistResult;
            if (result == null)
            {
                return;
            }

            if (MobileParty.MainParty != null)
            {
                var moved = MobileParty.MainParty.GetPosition2D.Distance(_assistStartPos);
                if (moved > _assistMaxDistance)
                {
                    _assistMaxDistance = moved;
                }
            }

            result.Arrived = true;
            result.PartyMovedDistance = _assistMaxDistance;
            if (_assistMaxDistance >= AssistMovementThreshold)
            {
                result.MovementIntentSet = true;
                result.ActualExecutionObserved = true;
                result.MovementObservationPassed = true;
                result.MovementObservationFailureReason = null;
            }

            AutomationRuntimeEventEmitter.Emit(
                AutomationRuntimeEventEmitter.TravelCompleted,
                reason: "arrived",
                payloadJson: "{\"partyMovedDistance\":" + _assistMaxDistance.ToString("0.###", CultureInfo.InvariantCulture) + "}");

            AssistiveTravelEvidenceWriter.Write(result);
            _assistResult = null;
        }

        private static string EscapeJson(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");

        private static bool IsClockRunning()
        {
            return CampaignClockResumeHelper.IsClockRunning();
        }

        private static void ReassertRunningClock()
        {
            CampaignClockResumeHelper.EnsureClockRunning("AutoTravelService");
        }

        public static DevCommandResult TravelByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                _lastFailReason = "destination name was empty";
                return DevCommandResult.Failed;
            }

            var destination = FindSettlement(name.Trim());
            if (destination == null)
            {
                _lastFailReason = $"could not find town/village named '{name}'";
                InGameNotice.Fail($"TBG TRAVEL: {_lastFailReason}.");
                ShowChoices();
                return DevCommandResult.Failed;
            }

            return StartTravel(destination, "name");
        }

        public static bool AbortNow()
        {
            if (_activeDestination == null)
            {
                return false;
            }

            var destination = _activeDestination.Name?.ToString() ?? _activeDestination.StringId;
            TryInvokeHold(MobileParty.MainParty);
            _activeDestination = null;
            _assistResult = null;
            _lastFailReason = "Aborted by command";
            InGameNotice.Blocked($"TBG TRAVEL: route to {destination} aborted.");
            DebugLogger.Test("[TBG TRAVEL] route aborted by command.", showInGame: false);
            return true;
        }

        private static bool ShouldCheckHostilesThisTick()
        {
            _hostileCheckTickCounter++;
            return _hostileCheckTickCounter % HostileCheckIntervalTicks == 0;
        }

        private static bool RefreshChoices()
        {
            _choices.Clear();
            _lastFailReason = null;

            if (!GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                _lastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            var main = MobileParty.MainParty;
            var ranked = Settlement.All
                .Where(IsTownOrVillage)
                .Select(s => new { Settlement = s, Score = ScoreSettlement(s, main), Reason = BuildReason(s) })
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Settlement.Name?.ToString())
                .Take(ChoiceCount)
                .ToList();

            var number = 1;
            foreach (var item in ranked)
            {
                _choices.Add(new AutoTravelChoice
                {
                    Number = number++,
                    Settlement = item.Settlement,
                    Name = item.Settlement.Name?.ToString() ?? item.Settlement.StringId,
                    StringId = item.Settlement.StringId,
                    Reason = item.Reason
                });
            }

            if (_choices.Count == 0)
            {
                _lastFailReason = "no towns or villages found";
                return false;
            }

            return true;
        }

        private static DevCommandResult StartTravel(Settlement destination, string selector)
        {
            if (!GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                _lastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                return DevCommandResult.Failed;
            }

            if (destination == null)
            {
                _lastFailReason = "destination was not resolved";
                return DevCommandResult.Failed;
            }

            if (TryDetectBlockingHostiles(MobileParty.MainParty, out var hostileDetail))
            {
                _lastFailReason = hostileDetail;
                InGameNotice.Blocked($"TBG TRAVEL blocked: {hostileDetail}");
                return DevCommandResult.Blocked;
            }

            if (!TryInvokeMoveToSettlement(MobileParty.MainParty, destination))
            {
                _lastFailReason = "Bannerlord move-to-settlement API was unavailable";
                return DevCommandResult.Failed;
            }

            var name = destination.Name?.ToString() ?? destination.StringId;
            _activeDestination = destination;
            _hostileCheckTickCounter = 0;
            DebugLogger.Test($"[TBG TRAVEL] auto-travel started to {name} via {selector}; cautious route monitor active.", showInGame: false);
            InGameNotice.Success($"TBG TRAVEL: heading to {name}. Travel pauses if war-hostiles block the route.");
            return DevCommandResult.Success;
        }

        private static bool TryInvokeHold(MobileParty party)
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
                DebugLogger.Test($"[TBG TRAVEL] SetMoveModeHold failed: {ex.Message}", showInGame: false);
            }

            return TryInvokeParameterless(party, "SetMoveModeHold");
        }

        private static bool TryInvokeMoveToSettlement(MobileParty party, Settlement destination)
        {
            if (party == null || destination == null)
            {
                return false;
            }

            try
            {
                party.SetMoveGoToSettlement(destination, MobileParty.NavigationType.Default, false);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG TRAVEL] direct SetMoveGoToSettlement failed: {ex.Message}", showInGame: false);
            }

            if (TryInvokeOnTarget(party.Ai, destination, "SetMoveGoToSettlement"))
            {
                return true;
            }

            if (TryInvokeOnTarget(party, destination, "SetMoveGoToSettlement"))
            {
                return true;
            }

            if (TryInvokeOnTarget(party, destination, "SetMoveGoToSettlementWithShorterPath"))
            {
                return true;
            }

            DebugLogger.Test("[TBG TRAVEL] all movement methods failed", showInGame: false);
            return false;
        }

        private static bool TryInvokeOnTarget(object target, Settlement destination, string methodName)
        {
            if (target == null)
            {
                return false;
            }

            var targetType = target.GetType();
            var methods = targetType.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic)
                .Where(m => string.Equals(m.Name, methodName, StringComparison.Ordinal))
                .ToList();

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
                    $"[TBG TRAVEL] {method.Name} invoke failed: {ex.InnerException?.Message ?? ex.Message}",
                    showInGame: false
                );
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG TRAVEL] {method.Name} invoke failed: {ex.Message}", showInGame: false);
            }

            return false;
        }

        private static bool TryDetectBlockingHostiles(MobileParty main, out string detail)
        {
            detail = null;
            foreach (var party in MobileParty.All)
            {
                if (party == null || party == main || party.MapFaction == null || main.MapFaction == null ||
                    !party.MapFaction.IsAtWarWith(main.MapFaction))
                {
                    continue;
                }

                var distance = main.GetPosition2D.Distance(party.GetPosition2D);
                if (distance > HostilePreFilterDistance)
                {
                    continue;
                }

                var hostileStrength = party.Party == null ? 0 : party.Party.NumberOfAllMembers;
                var mainStrength = main.Party == null ? 0 : main.Party.NumberOfAllMembers;
                if (distance <= 6f && hostileStrength >= mainStrength)
                {
                    detail = $"nearby war-hostile {party.Name} is too close/strong; wait or move manually";
                    return true;
                }
            }

            return false;
        }

        private static Settlement FindSettlement(string name)
        {
            var normalized = Normalize(name);
            if (string.IsNullOrEmpty(normalized))
            {
                return null;
            }

            return Settlement.All.Where(IsTownOrVillage).FirstOrDefault(s =>
                string.Equals(Normalize(s.Name?.ToString()), normalized, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(Normalize(s.StringId), normalized, StringComparison.OrdinalIgnoreCase));
        }

        private static bool IsTownOrVillage(Settlement settlement)
        {
            return settlement != null && (settlement.IsTown || settlement.IsVillage);
        }

        private static float ScoreSettlement(Settlement settlement, MobileParty main)
        {
            var distancePenalty = main == null ? 0f : main.GetPosition2D.Distance(settlement.GetPosition2D) * 2f;
            var townBonus = settlement.IsTown ? 100f : 35f;
            var forgeBonus = ForgeRecommendationService.Summary.HasRankings ? 25f : 0f;
            return townBonus + forgeBonus - distancePenalty;
        }

        private static string BuildReason(Settlement settlement)
        {
            if (settlement.IsTown && ForgeRecommendationService.Summary.HasRankings)
            {
                return "trade/forge engine-friendly town";
            }

            return settlement.IsTown ? "nearby town market" : "nearby village stop";
        }

        private static string Normalize(string value)
        {
            return (value ?? string.Empty).Trim().Replace(" ", string.Empty).Replace("-", string.Empty).ToLowerInvariant();
        }

        private sealed class AutoTravelChoice
        {
            public int Number { get; set; }
            public Settlement Settlement { get; set; }
            public string Name { get; set; }
            public string StringId { get; set; }
            public string Reason { get; set; }
        }
    }
}
