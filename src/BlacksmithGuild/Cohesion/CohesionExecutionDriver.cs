using System;
using System.Threading;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionExecutionDriver
    {
        public const string RunVisibleCohesionMoveNowCommand = "RunVisibleCohesionMoveNow";
        public const string AbortCohesionMoveNowCommand = "AbortCohesionMoveNow";

        private static CohesionMoveReport _activeReport;
        private static CohesionOpportunity _activeOpportunity;
        private static Settlement _moveTarget;
        private static int _waitTicks;
        private static bool _abortRequested;

        public static string LastFailReason { get; private set; }
        public static CohesionMoveReport ActiveReport => _activeReport;
        public static bool IsRunning => _activeReport != null
            && _activeReport.State != CohesionExecutionState.Complete
            && _activeReport.State != CohesionExecutionState.Blocked
            && _activeReport.State != CohesionExecutionState.Aborted
            && _activeReport.State != CohesionExecutionState.Failed;

        public static bool StartMoveNow(string source = RunVisibleCohesionMoveNowCommand)
        {
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!GameSessionState.IsCampaignMapReady)
            {
                LastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                WriteTerminal(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                return false;
            }

            if (IsRunning)
            {
                LastFailReason = "cohesion move already in progress";
                return false;
            }

            if (!CohesionEngine.AnalyzeNow(source))
            {
                LastFailReason = "cohesion analyze failed";
                return false;
            }

            _activeOpportunity = CohesionEngine.LastReport?.SelectedOpportunity;
            if (_activeOpportunity == null)
            {
                LastFailReason = CohesionEngine.LastReport?.Verdict ?? "no selected opportunity";
                WriteTerminal(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                return false;
            }

            if (_activeOpportunity.BlockedReason != null
                && _activeOpportunity.RecommendedAction.ToString().StartsWith("Blocked", StringComparison.Ordinal))
            {
                LastFailReason = _activeOpportunity.BlockedReason;
                WriteTerminal(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                InGameNotice.Blocked($"TBG COHESION BLOCKED: {LastFailReason}");
                return false;
            }

            _activeReport = new CohesionMoveReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                VisibleModeEnabled = DevToolsConfig.MapTradeVisibleMode,
                DecisionPauseMs = DevToolsConfig.CohesionDecisionPauseMs,
                MutationApplied = true,
                SelectedOpportunityId = _activeOpportunity.OpportunityId,
                Objective = CohesionEngine.LastReport.CurrentObjective,
                State = CohesionExecutionState.SelectCohesionPlan,
                HelperMovementReason = "Player-only execution; helper movement not directly controllable"
            };

            PauseIfVisible("starting cohesion move");
            return BeginExecution(source);
        }

        public static bool AbortNow()
        {
            if (_activeReport == null)
            {
                InGameNotice.Info("TBG COHESION: no active cohesion move.");
                return true;
            }

            _abortRequested = true;
            CampaignMapMovementHelper.TryHold(MobileParty.MainParty);
            _activeReport.State = CohesionExecutionState.Aborted;
            _activeReport.Verdict = "Aborted";
            _activeReport.BlockedReason = "Aborted by command";
            CohesionJsonWriter.WriteMove(_activeReport);
            InGameNotice.Blocked("TBG COHESION: move aborted.");
            ClearActive();
            return true;
        }

        public static void OnCampaignTick()
        {
            if (_activeReport == null || !IsRunning)
            {
                return;
            }

            GameSessionState.Refresh();
            if (ShouldStopForEncounter())
            {
                Finish(_activeReport.Source, CohesionExecutionState.Failed, "Failed", "EncounterInterrupted");
                InGameNotice.Blocked("TBG COHESION: encounter interrupted automation.");
                return;
            }

            if (_abortRequested)
            {
                return;
            }

            switch (_activeReport.State)
            {
                case CohesionExecutionState.MoveTowardCohesion:
                case CohesionExecutionState.ShadowProtector:
                case CohesionExecutionState.AdvanceThroughWindow:
                    TickMovement();
                    break;
                case CohesionExecutionState.WaitForCohesionWindow:
                    TickWait();
                    break;
            }
        }

        private static bool BeginExecution(string source)
        {
            var action = _activeOpportunity.RecommendedAction;
            switch (action)
            {
                case CohesionRecommendedAction.ShadowProtector:
                case CohesionRecommendedAction.MoveTowardHelper:
                case CohesionRecommendedAction.AdvanceDuringProtectorPressure:
                case CohesionRecommendedAction.ContinueTradeRoute:
                case CohesionRecommendedAction.ContinueForgeProcurement:
                    return StartMovement(source, action);
                case CohesionRecommendedAction.WaitForCohesionWindow:
                    _activeReport.State = CohesionExecutionState.WaitForCohesionWindow;
                    _waitTicks = 0;
                    InGameNotice.Warn("TBG COHESION HOLD: waiting for friendly army to close distance.");
                    CohesionJsonWriter.WriteMove(_activeReport);
                    return true;
                case CohesionRecommendedAction.DuckIntoSettlement:
                    return DuckIntoTown(source);
                case CohesionRecommendedAction.RallyAtSafeSettlement:
                case CohesionRecommendedAction.RallyAtConvergencePoint:
                    return StartRally(source);
                default:
                    LastFailReason = _activeOpportunity.BlockedReason ?? action.ToString();
                    Finish(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                    return false;
            }
        }

        private static bool StartMovement(string source, CohesionRecommendedAction action)
        {
            var settlement = ResolveMoveTarget();
            if (settlement == null)
            {
                LastFailReason = "no movement target settlement";
                Finish(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                return false;
            }

            if (!CampaignMapMovementHelper.TryMoveToSettlement(MobileParty.MainParty, settlement, out var detail))
            {
                LastFailReason = detail;
                Finish(source, CohesionExecutionState.Blocked, "BlockedNoMovementApi", detail);
                return false;
            }

            _moveTarget = settlement;
            _activeReport.State = action == CohesionRecommendedAction.ShadowProtector
                ? CohesionExecutionState.ShadowProtector
                : CohesionExecutionState.MoveTowardCohesion;
            _activeReport.Steps.Add(new CohesionMoveStep
            {
                State = _activeReport.State.ToString(),
                Action = "MovePlayerPartyTowardHelper",
                Mode = "VanillaMapMovement",
                Result = "Success"
            });

            InGameNotice.Info($"TBG COHESION MOVE: riding toward {settlement.Name} | {action}.");
            CohesionJsonWriter.WriteMove(_activeReport);
            return true;
        }

        private static bool StartRally(string source)
        {
            var rally = CohesionRoutePlanner.FindRallySettlement(
                MobileParty.MainParty,
                _activeOpportunity.HelperParties);
            if (rally == null)
            {
                LastFailReason = "no rally settlement found";
                Finish(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                return false;
            }

            return StartMovement(source, CohesionRecommendedAction.RallyAtSafeSettlement);
        }

        private static bool DuckIntoTown(string source)
        {
            var town = CohesionPartyScanner.FindNearestSafeTown(MobileParty.MainParty);
            if (town == null)
            {
                LastFailReason = "no safe town to duck into";
                Finish(source, CohesionExecutionState.Blocked, "Blocked", LastFailReason);
                return false;
            }

            _activeReport.State = CohesionExecutionState.DuckIntoSettlement;
            InGameNotice.Warn($"TBG COHESION DUCK: entering {town.Name} until hostile passes.");
            return StartMovement(source, CohesionRecommendedAction.DuckIntoSettlement);
        }

        private static void TickMovement()
        {
            if (_moveTarget == null)
            {
                return;
            }

            if (CampaignMapMovementHelper.HasArrived(MobileParty.MainParty, _moveTarget))
            {
                Finish(_activeReport.Source, CohesionExecutionState.Complete, "Complete", "Cohesion movement complete");
                InGameNotice.Success("TBG COHESION DONE: route safety improved.");
            }
        }

        private static void TickWait()
        {
            _waitTicks++;
            if (_waitTicks < 20)
            {
                return;
            }

            var refreshed = CohesionEngine.BuildPlanForObjective(_activeReport.Objective);
            if (refreshed != null && refreshed.RecommendedAction != CohesionRecommendedAction.WaitForCohesionWindow)
            {
                _activeOpportunity = refreshed;
                _activeReport.CohesionWindowsUsed.Add("Likely");
                InGameNotice.Info("TBG COHESION WINDOW: helper and player can coalesce before hostile contact.");
                BeginExecution(_activeReport.Source);
                return;
            }

            if (_waitTicks > 120)
            {
                Finish(_activeReport.Source, CohesionExecutionState.Blocked, "Blocked", "Cohesion window did not open in time");
                InGameNotice.Blocked("TBG COHESION BLOCKED: window did not open.");
            }
        }

        private static Settlement ResolveMoveTarget()
        {
            var objectiveSettlement = CohesionRoutePlanner.ResolveSettlement(_activeReport.Objective);
            if (objectiveSettlement != null)
            {
                return objectiveSettlement;
            }

            return CohesionPartyScanner.FindNearestSafeTown(MobileParty.MainParty);
        }

        private static bool ShouldStopForEncounter()
        {
            return GameSessionState.IsMapMenuOpen;
        }

        private static void Finish(string source, CohesionExecutionState state, string verdict, string reason)
        {
            if (_activeReport == null)
            {
                return;
            }

            _activeReport.State = state;
            _activeReport.Verdict = verdict;
            _activeReport.BlockedReason = state == CohesionExecutionState.Complete ? null : reason;
            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            CohesionJsonWriter.WriteMove(_activeReport);
            ClearActive();
        }

        private static void WriteTerminal(string source, CohesionExecutionState state, string verdict, string reason)
        {
            var report = new CohesionMoveReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                State = state,
                Verdict = verdict,
                BlockedReason = reason,
                VisibleModeEnabled = DevToolsConfig.MapTradeVisibleMode,
                DecisionPauseMs = DevToolsConfig.CohesionDecisionPauseMs
            };
            CohesionJsonWriter.WriteMove(report);
        }

        private static void ClearActive()
        {
            _activeReport = null;
            _activeOpportunity = null;
            _moveTarget = null;
            _waitTicks = 0;
        }

        private static void PauseIfVisible(string label)
        {
            if (!DevToolsConfig.MapTradeVisibleMode || DevToolsConfig.CohesionDecisionPauseMs <= 0)
            {
                return;
            }

            InGameNotice.Info($"TBG COHESION: {label}...");
            Thread.Sleep(DevToolsConfig.CohesionDecisionPauseMs);
        }
    }
}
