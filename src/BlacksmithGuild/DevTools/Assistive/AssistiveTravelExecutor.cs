using System;
using System.IO;
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
                FakeGameplayDelta = false
            };

            var current = GameSessionState.ResolveCurrentSettlement();
            AssistiveTravelSettlementIdentity.ApplyCurrent(result, current);

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
            AssistiveTravelSettlementIdentity.ApplyCurrent(result, GameSessionState.ResolveCurrentSettlement());

            var targetName = ResolveTargetName(payload);
            var target = AssistiveLeaveTownTravelService.ResolveTargetSettlement(targetName);
            AssistiveTravelSettlementIdentity.ApplyTarget(result, target, targetName);

            if (string.IsNullOrWhiteSpace(targetName) || target == null)
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.InvalidTarget;
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            current = GameSessionState.ResolveCurrentSettlement();
            if (current != null && target == current)
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.TargetIsCurrentSettlement;
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            var readiness = AssistiveLeaveTownTravelService.AssessTravelReadiness();
            AssistiveTownToTownProbeService.WriteTravelEvidence(readiness);

            if (!executeRequested)
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.ExecuteNotRequested;
                result.TravelCommandMode = "advisory_only";
                result.ExecuteAllowed = false;
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (GameSessionState.IsMissionActiveForTrace())
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.MissionActive;
                result.TravelCommandMode = "advisory_only";
                Finish(result, source);
                return DevCommandResult.Success;
            }

            if (!AssistReadinessEvaluator.IsAssistSurfaceEligible())
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.SurfaceNotExecuteEligible(
                    GameSessionState.ReadinessSurface);
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
                    ? AssistiveTravelFallbackReasons.SurfaceNotExecuteEligible(GameSessionState.ReadinessSurface)
                    : AssistiveTravelFallbackReasons.NormalizeTravelApiDetail(travelApiDetail, callAttempted: false);
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
                    result.FallbackReason = NormalizeLeaveReason(leaveReason);
                    result.TravelCommandMode = "advisory_only";
                    Finish(result, source);
                    return DevCommandResult.Success;
                }

                result.LeaveTownAttempted = leaveAttempted;
                result.LeaveTownSucceeded = leaveSucceeded;

                GameSessionState.Refresh();
                if (GameSessionState.IsMapMenuOpen)
                {
                    result.FallbackReason = AssistiveTravelFallbackReasons.LeaveTownIncomplete;
                    result.TravelCommandMode = "advisory_only";
                    Finish(result, source);
                    return DevCommandResult.Success;
                }
            }

            if (!AssistReadinessEvaluator.IsOpenMapReady)
            {
                result.FallbackReason = result.LeaveTownAttempted
                    ? AssistiveTravelFallbackReasons.MapSurfaceNotReached
                    : AssistiveTravelFallbackReasons.SurfaceNotExecuteEligible(GameSessionState.ReadinessSurface);
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
            DebugLogger.Test(
                $"[TBG ASSIST] travel stage=map_travel target={target.Name} id={target.StringId}",
                showInGame: false);

            result.TravelApiCallSucceeded = AutoTravelService.TryStartTravelToSettlement(
                target,
                "assist",
                out var detail,
                result);

            if (!result.TravelApiCallSucceeded)
            {
                result.FallbackReason = AssistiveTravelFallbackReasons.NormalizeTravelApiDetail(detail, callAttempted: true);
                result.TravelCommandMode = "advisory_only";
                AssistiveLeaveTownTravelService.NoteFailReason(result.FallbackReason);
                Finish(result, source);
                return DevCommandResult.Failed;
            }

            // Travel is now genuinely in flight on the campaign map with the clock running.
            // Real party movement is verified asynchronously by AutoTravelService.OnRealtimeTick,
            // which flips ActualExecutionObserved/PartyMovedDistance only after the party actually
            // moves (never on route intent alone) and re-writes the execution evidence.
            result.TravelCommandMode = "execute";
            result.MovementIntentSet = true;
            result.FallbackReason = null;

            Finish(result, source);
            return DevCommandResult.Success;
        }

        private static string NormalizeLeaveReason(string leaveReason)
        {
            if (string.IsNullOrWhiteSpace(leaveReason))
            {
                return AssistiveTravelFallbackReasons.LeaveTownFailed;
            }

            if (leaveReason == AssistiveTravelFallbackReasons.LeaveTownIncomplete
                || leaveReason == AssistiveTravelFallbackReasons.LeaveTownFailed
                || leaveReason == AssistiveTravelFallbackReasons.MapSurfaceNotReached)
            {
                return leaveReason;
            }

            if (leaveReason == "leave_town_incomplete")
            {
                return AssistiveTravelFallbackReasons.LeaveTownIncomplete;
            }

            if (leaveReason == "not_at_settlement_menu")
            {
                return AssistiveTravelFallbackReasons.MapSurfaceNotReached;
            }

            return AssistiveTravelFallbackReasons.LeaveTownFailed;
        }

        private static void Finish(AssistiveTravelExecutionResult result, string source)
        {
            AssistiveTravelEvidenceWriter.Write(result);
            DebugLogger.Test(
                $"[TBG ASSIST] {source} travel mode={result.TravelCommandMode} executeRequested={result.ExecuteRequested} travelApi={result.TravelApiCallSucceeded} movementIntent={result.MovementIntentSet} observed={result.ActualExecutionObserved} fallback={result.FallbackReason ?? "none"}",
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
                detail = AssistiveTravelFallbackReasons.TravelApiUnavailable + ": " + ex.Message;
                return false;
            }
        }
    }
}
