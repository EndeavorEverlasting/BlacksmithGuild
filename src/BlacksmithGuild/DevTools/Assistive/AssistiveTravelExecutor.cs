using System;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelExecutor
    {
        private static readonly string ProbePath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TownToTownTradeProbe.json");

        public static DevCommandResult Run(AssistiveCommandInboxPayload payload, string source)
        {
            var executeRequested = payload?.ExecuteRequested == true;
            var result = new AssistiveTravelExecutionResult
            {
                ExecuteRequested = executeRequested,
                FakeGameplayDelta = false,
                CurrentSettlement = GameSessionState.CurrentSettlementName
                    ?? GameSessionState.CurrentSettlementStringId
                    ?? ""
            };

            if (!AssistReadinessEvaluator.CanAcceptAssistiveCommand)
            {
                result.CommandAccepted = false;
                result.FallbackReason = AssistReadinessEvaluator.IsInGameAssistReady
                    ? "assist_command_blocked"
                    : GameSessionState.GetCommandReadyBlockDetail();
                result.TravelCommandMode = "advisory_only";
                AssistiveLeaveTownTravelService.NoteFailReason(result.FallbackReason);
                Finish(result, source);
                return DevCommandResult.Blocked;
            }

            result.CommandAccepted = true;
            GameSessionState.Refresh();
            AssistReadinessEvaluator.ApplyInboxAndAssistFlags(trace: false);

            var targetName = ResolveTargetName(payload);
            result.TargetSettlement = targetName;

            var target = AssistiveLeaveTownTravelService.ResolveTargetSettlement(targetName);
            var current = GameSessionState.ResolveCurrentSettlement();
            if (string.IsNullOrWhiteSpace(targetName) || target == null)
            {
                result.FallbackReason = "invalid_target";
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (current != null && target == current)
            {
                result.FallbackReason = "target_is_current_settlement";
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            var readiness = AssistiveLeaveTownTravelService.AssessTravelReadiness();
            AssistiveTownToTownProbeService.WriteTravelEvidence(readiness);

            if (!executeRequested)
            {
                result.FallbackReason = "execute_not_requested";
                result.TravelCommandMode = "advisory_only";
                result.ExecuteAllowed = false;
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (GameSessionState.IsMissionActiveForTrace())
            {
                result.FallbackReason = "mission_active";
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (!AssistReadinessEvaluator.IsAssistSurfaceEligible())
            {
                result.FallbackReason = $"surface_not_execute_eligible:{GameSessionState.ReadinessSurface}";
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            string travelApiDetail = null;
            var canSetTravelTarget = MobileParty.MainParty != null
                && ProbeTravelApi(MobileParty.MainParty, target, out travelApiDetail);
            var canLeave = AssistReadinessEvaluator.IsTownMenuReady
                && GameSessionState.IsMapMenuOpen
                && !string.IsNullOrEmpty(result.CurrentSettlement);

            result.ExecuteAllowed = canSetTravelTarget
                && (AssistReadinessEvaluator.IsOpenMapReady || canLeave);

            if (!result.ExecuteAllowed)
            {
                result.FallbackReason = canSetTravelTarget
                    ? "surface_not_execute_eligible"
                    : "travel_api_unavailable";
                if (!string.IsNullOrEmpty(travelApiDetail))
                {
                    result.FallbackReason = travelApiDetail;
                }

                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (AssistReadinessEvaluator.IsTownMenuReady && GameSessionState.IsMapMenuOpen)
            {
                var leaveAttempted = false;
                var leaveSucceeded = false;
                if (!SettlementLeaveHelper.TryLeaveTown(
                        result.Steps,
                        out leaveAttempted,
                        out leaveSucceeded,
                        out var leaveReason))
                {
                    result.LeaveTownAttempted = leaveAttempted;
                    result.LeaveTownSucceeded = leaveSucceeded;
                    result.FallbackReason = leaveReason ?? "leave_town_failed";
                    result.TravelCommandMode = "advisory_only";
                    Finish(result, source);
                    return DevCommandResult.Success;
                }

                result.LeaveTownAttempted = leaveAttempted;
                result.LeaveTownSucceeded = leaveSucceeded;

                GameSessionState.Refresh();
                if (GameSessionState.IsMapMenuOpen)
                {
                    result.FallbackReason = "leave_town_incomplete";
                    result.TravelCommandMode = "advisory_only";
                    Finish(result, source);
                    return DevCommandResult.Success;
                }
            }

            if (!AssistReadinessEvaluator.IsOpenMapReady)
            {
                result.FallbackReason = $"surface_not_execute_eligible:{GameSessionState.ReadinessSurface}";
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            return AttemptMapTravel(result, target, source);
        }

        private static DevCommandResult AttemptMapTravel(
            AssistiveTravelExecutionResult result,
            Settlement target,
            string source)
        {
            result.MapTravelAttempted = true;
            DebugLogger.Test($"[TBG ASSIST] travel stage=map_travel target={target.Name}", showInGame: false);

            if (!AutoTravelService.TryStartTravelToSettlement(target, "assist", out var detail))
            {
                result.FallbackReason = string.IsNullOrWhiteSpace(detail) ? "travel_api_unavailable" : detail;
                result.TravelCommandMode = "advisory_only";
                AssistiveLeaveTownTravelService.NoteFailReason(result.FallbackReason);
                Finish(result, source);
                return DevCommandResult.Failed;
            }

            result.MovementIntentSet = true;
            result.ActualExecutionObserved = AutoTravelService.HasActiveRoute;
            if (result.MovementIntentSet && result.ActualExecutionObserved)
            {
                result.TravelCommandMode = "execute";
                result.FallbackReason = null;
            }
            else
            {
                result.TravelCommandMode = "advisory_only";
                result.FallbackReason = "movement_intent_not_observed";
            }

            Finish(result, source);
            return result.TravelCommandMode == "execute"
                ? DevCommandResult.Success
                : DevCommandResult.Failed;
        }

        private static void Finish(AssistiveTravelExecutionResult result, string source)
        {
            AssistiveTravelEvidenceWriter.Write(result);
            DebugLogger.Test(
                $"[TBG ASSIST] {source} travel mode={result.TravelCommandMode} executeRequested={result.ExecuteRequested} fallback={result.FallbackReason ?? "none"}",
                showInGame: false);
        }

        private static string ResolveTargetName(AssistiveCommandInboxPayload payload)
        {
            if (!string.IsNullOrWhiteSpace(payload?.TargetSettlement))
            {
                return payload.TargetSettlement.Trim();
            }

            var fromProbe = TryReadProbeRecommendedNextTown();
            if (!string.IsNullOrWhiteSpace(fromProbe))
            {
                return fromProbe;
            }

            return AssistiveLeaveTownTravelService.ResolveRecommendedTarget();
        }

        private static string TryReadProbeRecommendedNextTown()
        {
            try
            {
                if (!File.Exists(ProbePath))
                {
                    return null;
                }

                var json = File.ReadAllText(ProbePath);
                var match = Regex.Match(
                    json,
                    "\"recommendedNextTown\"\\s*:\\s*\"([^\"]+)\"",
                    RegexOptions.IgnoreCase);
                return match.Success ? match.Groups[1].Value : null;
            }
            catch
            {
                return null;
            }
        }

        private static bool ProbeTravelApi(MobileParty party, Settlement target, out string detail)
        {
            detail = null;
            if (party == null || target == null || !GameSessionState.IsCampaignMapReady)
            {
                detail = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            try
            {
                party.SetMoveGoToSettlement(target, MobileParty.NavigationType.Default, false);
                party.SetMoveModeHold();
                detail = "SetMoveGoToSettlement probe ok";
                return true;
            }
            catch (Exception ex)
            {
                detail = $"travel_api_unavailable: {ex.Message}";
                return false;
            }
        }
    }
}
