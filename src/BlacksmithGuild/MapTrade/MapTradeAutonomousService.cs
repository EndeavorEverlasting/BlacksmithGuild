using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeAutonomousService
    {
        public const string RunAutonomousVisibleTradeRouteNowCommand = "RunAutonomousVisibleTradeRouteNow";
        public const string AbortMapTradeRouteNowCommand = "AbortMapTradeRouteNow";
        public const string ShowMapTradeRouteStatusCommand = "ShowMapTradeRouteStatus";
        public const string AnalyzeTacticalConvergenceCommand = "AnalyzeTacticalConvergence";
        public const string ShowTacticalConvergenceCommand = "ShowTacticalConvergence";

        private const string BranchRouteSource = "campaign_tick_recursive_branch_travel";
        private const string StatusFileName = "BlacksmithGuild_Status.json";
        private const string BranchPollCadenceWorker = "MapTrade.BranchStatePoll";
        private const string ActiveMonitorCadenceWorker = "MapTrade.ActiveMonitor";
        private static MapTradeCertReport _activeReport;
        private static bool _abortRequested;
        private static string _lastBranchAutoStartKey;
        private static string _lastBranchBlockEvidenceKey;
        private static Vec2 _routeStartPosition;
        private static bool _routeStartPositionRecorded;
        private static long _campaignTickSerial;
        private static long _routeStartedTickSerial = -1;
        private static MapTradeRouteState _lastTerminalState = MapTradeRouteState.Idle;
        private static string _lastTerminalVerdict;

        public static string LastFailReason { get; private set; }
        public static MapTradeCertReport ActiveReport => _activeReport;
        public static MapTradeRouteState LastTerminalState => _lastTerminalState;
        public static string LastTerminalVerdict => _lastTerminalVerdict;

        public static bool IsRunning =>
            _activeReport != null
            && _activeReport.State != MapTradeRouteState.Complete
            && _activeReport.State != MapTradeRouteState.Blocked
            && _activeReport.State != MapTradeRouteState.Aborted
            && _activeReport.State != MapTradeRouteState.Failed;

        public static bool IsTerminal =>
            !IsRunning
            && (_activeReport == null
                || _activeReport.State == MapTradeRouteState.Complete
                || _activeReport.State == MapTradeRouteState.Blocked
                || _activeReport.State == MapTradeRouteState.Aborted
                || _activeReport.State == MapTradeRouteState.Failed);

        public static MapTradeStatusSnapshot GetStatusSnapshot()
        {
            return new MapTradeStatusSnapshot
            {
                State = _activeReport?.State ?? MapTradeRouteState.Idle,
                Verdict = _activeReport?.Verdict,
                BlockedReason = _activeReport?.BlockedReason,
                IsRunning = IsRunning,
                IsTerminal = IsTerminal,
                Mission = _activeReport?.Mission
            };
        }

        public static bool ShowStatusNow()
        {
            var snapshot = GetStatusSnapshot();
            InGameNotice.Info(
                $"TBG MAP TRADE STATUS: {snapshot.State} | {snapshot.Verdict ?? "NoReport"}");
            if (_activeReport != null)
            {
                MapTradeEvidenceWriter.WriteCert(_activeReport);
            }

            return true;
        }

        public static bool StartRouteNow(string source = RunAutonomousVisibleTradeRouteNowCommand)
        {
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.MapTrade))
            {
                LastFailReason = "MapTrade engine disabled by authority";
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                LastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            if (IsRunning)
            {
                LastFailReason = "map trade route already in progress";
                return false;
            }

            PauseIfVisible("starting map trade route");
            _activeReport = new MapTradeCertReport
            {
                RunId = RuntimeProofContext.RunId,
                HeadSha = RuntimeProofContext.ExpectedHeadSha,
                RuntimeSessionId = RuntimeProofContext.RuntimeSessionId,
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                StartedAtUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                VisibleModeEnabled = DevToolsConfig.MapTradeVisibleMode,
                DecisionPauseMs = DevToolsConfig.MapTradeDecisionPauseMs,
                MutationApplied = false,
                State = MapTradeRouteState.Preflight,
                StartPosition = DescribePartyPosition(),
                LatestPosition = DescribePartyPosition(),
                InitialTimePaused = TryReadStatusBoolean("timePaused", out var paused) && paused,
                AttemptedUnpause = false,
                TravelCommandIssued = false,
                RouteStarted = false,
                RuntimeProofClaim = "market_selected_route_preflight"
            };
            RuntimeCadenceGate.Reset(ActiveMonitorCadenceWorker);

            if (!MarketIntelligenceService.EnsureFreshScan(source))
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", "market scan failed");
                return false;
            }

            _activeReport.Steps.Add("MarketScan:Success");
            _activeReport.Mission = MapTradeMissionSelector.SelectBestMission();
            _activeReport.State = MapTradeRouteState.SelectMission;

            if (_activeReport.Mission.MissionType == MapTradeMissionType.BlockedNoSafeMission)
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", _activeReport.Mission.BlockReason);
                return false;
            }

            if (MapTradeMissionSelector.NeedsCohesionCheck(_activeReport.Mission))
            {
                return RunCohesionCheck(source);
            }

            return BeginTravel(source);
        }

        public static bool StartBranchRouteNow(string targetSettlementName, string source = BranchRouteSource)
        {
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.MapTrade))
            {
                LastFailReason = "MapTrade engine disabled by authority";
                WriteBlockedBranchRouteCert(source, targetSettlementName, LastFailReason);
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                LastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                WriteBlockedBranchRouteCert(source, targetSettlementName, LastFailReason);
                return false;
            }

            if (IsRunning)
            {
                LastFailReason = "map trade route already in progress";
                return false;
            }

            if (string.IsNullOrWhiteSpace(targetSettlementName))
            {
                LastFailReason = "target settlement missing from recursive branch state";
                WriteBlockedBranchRouteCert(source, targetSettlementName, LastFailReason);
                return false;
            }

            var destination = ResolveSettlementByName(targetSettlementName);
            if (destination == null)
            {
                LastFailReason = "target settlement not found: " + targetSettlementName;
                WriteBlockedBranchRouteCert(source, targetSettlementName, LastFailReason);
                return false;
            }

            var now = DateTime.UtcNow.ToString("o");
            var destinationName = destination.Name?.ToString() ?? destination.StringId;
            var initiallyPaused = TryReadStatusBoolean("timePaused", out var paused) && paused;

            _activeReport = new MapTradeCertReport
            {
                RunId = RuntimeProofContext.RunId,
                HeadSha = RuntimeProofContext.ExpectedHeadSha,
                RuntimeSessionId = RuntimeProofContext.RuntimeSessionId,
                GeneratedUtc = now,
                StartedAtUtc = now,
                Source = source,
                VisibleModeEnabled = DevToolsConfig.MapTradeVisibleMode,
                DecisionPauseMs = DevToolsConfig.MapTradeDecisionPauseMs,
                MutationApplied = false,
                State = MapTradeRouteState.Preflight,
                Mission = new MapTradeMission
                {
                    MissionType = MapTradeMissionType.TravelOnlySafetyCert,
                    TargetSettlement = destination,
                    TargetSettlementName = destinationName,
                    Distance = 0f
                },
                DestinationSettlement = destinationName,
                TargetSettlementId = destination.StringId,
                StartPosition = DescribePartyPosition(),
                LatestPosition = DescribePartyPosition(),
                InitialTimePaused = initiallyPaused,
                AttemptedUnpause = true,
                TravelCommandIssued = false,
                RouteStarted = false,
                RuntimeProofClaim = "branch_route_preflight"
            };
            RuntimeCadenceGate.Reset(ActiveMonitorCadenceWorker);

            _activeReport.Steps.Add("RecursiveBranchState:travel");
            _activeReport.Steps.Add("TargetSettlement:" + destinationName);
            _lastBranchBlockEvidenceKey = null;
            DebugLogger.Test($"[TBG MAP TRADE] branch route start requested target={destinationName} source={source}", showInGame: false);

            return BeginTravel(source);
        }

        public static bool AbortNow()
        {
            if (_activeReport == null)
            {
                ReleaseManualHold();
                InGameNotice.Info("TBG MAP TRADE: no active route.");
                return true;
            }

            _abortRequested = true;
            MapTradeVisibleMovementDriver.Hold();
            Finish(MapTradeRouteState.Aborted, "Aborted", "Aborted by command");
            ReleaseManualHold();
            InGameNotice.Blocked("TBG MAP TRADE: route aborted.");
            return true;
        }

        public static void ReleaseManualHold()
        {
            _abortRequested = false;
            _lastBranchAutoStartKey = null;
            _lastBranchBlockEvidenceKey = null;
            RuntimeCadenceGate.Reset(BranchPollCadenceWorker);
            RuntimeCadenceGate.Reset(ActiveMonitorCadenceWorker);
        }

        public static void ResetForNewCampaign()
        {
            _activeReport = null;
            _abortRequested = false;
            _lastBranchAutoStartKey = null;
            _lastBranchBlockEvidenceKey = null;
            _routeStartPositionRecorded = false;
            _campaignTickSerial = 0;
            _routeStartedTickSerial = -1;
            _lastTerminalState = MapTradeRouteState.Idle;
            _lastTerminalVerdict = null;
            RuntimeCadenceGate.Reset(BranchPollCadenceWorker);
            RuntimeCadenceGate.Reset(ActiveMonitorCadenceWorker);
        }

        public static void OnCampaignTick()
        {
            _campaignTickSerial++;
            if ((_activeReport == null || !IsRunning)
                && !_abortRequested
                && !RuntimeProofContext.HasVisibleTradeCycleRequest
                && EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.MapTrade)
                && TryStartFromRecursiveBranchState())
            {
                // BeginTravel can change the live menu state. End this tick so the
                // pre-start IsMapMenuOpen snapshot below cannot cancel the new order.
                MarkAutoStartTickReturn();
                return;
            }

            if (_activeReport == null || !IsRunning || _abortRequested)
            {
                return;
            }

            if (!RuntimeCadenceGate.TryEnter(
                ActiveMonitorCadenceWorker,
                DevToolsConfig.MapTradeActiveMonitorIntervalMs,
                hardMinimumMs: 100))
            {
                return;
            }
            GameSessionState.RefreshForRealtimeTick();

            if (GameSessionState.IsMapMenuOpen)
            {
                if (_routeStartedTickSerial == _campaignTickSerial)
                {
                    _activeReport.SameTickHoldObserved = true;
                    _activeReport.Steps.Add("RouteAutoStart:SameTickHoldObserved");
                    MapTradeEvidenceWriter.WriteCert(_activeReport);
                }

                MapTradeVisibleMovementDriver.Hold();
                return;
            }

            if (MapTradeVisibleMovementDriver.ShouldHoldForHostiles())
            {
                if (DevToolsConfig.MapTradeAllowDuckIntoTown)
                {
                    MapTradeVisibleMovementDriver.TryDuckToNearestSafeTown(out _);
                }
                else
                {
                    MapTradeVisibleMovementDriver.Hold();
                }

                return;
            }

            switch (_activeReport.State)
            {
                case MapTradeRouteState.TravelToTarget:
                case MapTradeRouteState.WaitForArrival:
                    TickTravel();
                    break;
            }
        }

        private static bool TryStartFromRecursiveBranchState()
        {
            if (!RuntimeCadenceGate.TryEnter(
                BranchPollCadenceWorker,
                DevToolsConfig.MapTradeBranchStatePollIntervalMs,
                hardMinimumMs: 1000))
            {
                return false;
            }

            if (!TryReadStatusTravelTarget(out var targetSettlement, out var detail))
            {
                LastFailReason = detail;
                WriteBlockedBranchRouteCert(BranchRouteSource, targetSettlement, detail ?? "recursive branch route target not readable");
                return false;
            }

            var key = "travel:" + targetSettlement;
            if (string.Equals(_lastBranchAutoStartKey, key, StringComparison.Ordinal))
            {
                return false;
            }

            if (!StartBranchRouteNow(targetSettlement, BranchRouteSource))
            {
                return false;
            }

            _lastBranchAutoStartKey = key;
            return true;
        }

        private static bool TryReadStatusTravelTarget(out string targetSettlement, out string detail)
        {
            targetSettlement = null;
            detail = null;

            try
            {
                var path = Path.Combine(BasePath.Name, StatusFileName);
                if (!File.Exists(path))
                {
                    detail = "status file missing";
                    return false;
                }

                var json = File.ReadAllText(path);
                if (!Regex.IsMatch(json, "\"safeToExecuteTravel\"\\s*:\\s*true", RegexOptions.IgnoreCase))
                {
                    detail = "safeToExecuteTravel is not true";
                    return false;
                }

                if (!Regex.IsMatch(json, "\"nextPlannedBranch\"\\s*:\\s*\"travel\"", RegexOptions.IgnoreCase))
                {
                    detail = "nextPlannedBranch is not travel";
                    return false;
                }

                var match = Regex.Match(
                    json,
                    "\"targetSettlement\"\\s*:\\s*\"(?<target>[^\"]+)\"",
                    RegexOptions.IgnoreCase);
                if (!match.Success || string.IsNullOrWhiteSpace(match.Groups["target"].Value))
                {
                    detail = "targetSettlement missing";
                    return false;
                }

                targetSettlement = match.Groups["target"].Value.Trim();
                detail = "recursive branch route ready";
                return true;
            }
            catch (Exception ex)
            {
                detail = "status read failed: " + ex.Message;
                return false;
            }
        }

        private static bool TryReadStatusBoolean(string fieldName, out bool value)
        {
            value = false;

            try
            {
                var path = Path.Combine(BasePath.Name, StatusFileName);
                if (!File.Exists(path))
                {
                    return false;
                }

                var json = File.ReadAllText(path);
                var pattern = "\"" + Regex.Escape(fieldName) + "\"\\s*:\\s*(true|false)";
                var match = Regex.Match(json, pattern, RegexOptions.IgnoreCase);
                if (!match.Success)
                {
                    return false;
                }

                value = string.Equals(match.Groups[1].Value, "true", StringComparison.OrdinalIgnoreCase);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static Settlement ResolveSettlementByName(string settlementName)
        {
            var wanted = NormalizeSettlementKey(settlementName);
            if (string.IsNullOrWhiteSpace(wanted))
            {
                return null;
            }

            foreach (var settlement in Settlement.All)
            {
                if (settlement == null)
                {
                    continue;
                }

                var name = settlement.Name?.ToString();
                if (NormalizeSettlementKey(name) == wanted || NormalizeSettlementKey(settlement.StringId) == wanted)
                {
                    return settlement;
                }
            }

            return null;
        }

        private static string NormalizeSettlementKey(string value)
        {
            return (value ?? string.Empty)
                .Trim()
                .Replace(" ", string.Empty)
                .Replace("-", string.Empty)
                .Replace("_", string.Empty)
                .ToLowerInvariant();
        }

        private static string DescribePartyPosition()
        {
            try
            {
                var party = MobileParty.MainParty;
                return party?.GetPosition2D.ToString();
            }
            catch
            {
                return null;
            }
        }

        private static void WriteBlockedBranchRouteCert(string source, string targetSettlementName, string reason)
        {
            var evidenceKey = string.Join(
                "|",
                source ?? string.Empty,
                targetSettlementName ?? string.Empty,
                reason ?? string.Empty);
            if (string.Equals(_lastBranchBlockEvidenceKey, evidenceKey, StringComparison.Ordinal))
            {
                return;
            }

            _lastBranchBlockEvidenceKey = evidenceKey;
            var now = DateTime.UtcNow.ToString("o");
            var report = new MapTradeCertReport
            {
                RunId = RuntimeProofContext.RunId,
                HeadSha = RuntimeProofContext.ExpectedHeadSha,
                RuntimeSessionId = RuntimeProofContext.RuntimeSessionId,
                GeneratedUtc = now,
                StartedAtUtc = now,
                Source = source,
                State = MapTradeRouteState.Blocked,
                Verdict = "Blocked",
                BlockedReason = reason,
                DestinationSettlement = targetSettlementName,
                InitialTimePaused = TryReadStatusBoolean("timePaused", out var paused) && paused,
                AttemptedUnpause = false,
                TravelCommandIssued = false,
                RouteStarted = false,
                RuntimeProofClaim = "blocked_before_route_start",
                LatestPosition = DescribePartyPosition()
            };

            report.Steps.Add("RecursiveBranchState:blocked:" + reason);
            MapTradeEvidenceWriter.WriteCert(report);
        }

        private static bool RunCohesionCheck(string source)
        {
            _activeReport.State = MapTradeRouteState.CohesionCheck;
            var objective = BuildObjectiveForMission(_activeReport.Mission);
            var opportunity = CohesionEngine.BuildPlanForObjective(objective);
            _activeReport.CohesionDecisions.Add(new MapTradeCohesionDecision
            {
                Phase = "MapTradeRoute",
                RecommendedAction = opportunity?.RecommendedAction.ToString() ?? "None",
                Score = opportunity?.Score ?? 0f,
                BlockedReason = opportunity?.BlockedReason
            });

            if (opportunity != null
                && opportunity.RecommendedAction.ToString().StartsWith("Blocked", StringComparison.Ordinal))
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", opportunity.BlockedReason ?? "cohesion blocked");
                return false;
            }

            _activeReport.Steps.Add("CohesionCheck:Success");
            return BeginTravel(source);
        }

        private static bool BeginTravel(string source)
        {
            if (!MapTradeVisibleMovementDriver.TryStartTravel(_activeReport.Mission, out var detail))
            {
                Finish(MapTradeRouteState.Blocked, "BlockedNoMovementApi", detail);
                return false;
            }

            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            if (string.IsNullOrWhiteSpace(_activeReport.StartedAtUtc))
            {
                _activeReport.StartedAtUtc = _activeReport.GeneratedUtc;
            }

            _activeReport.DestinationSettlement = _activeReport.Mission?.TargetSettlementName;
            _activeReport.TargetSettlementId = _activeReport.Mission?.TargetSettlement?.StringId;
            _activeReport.LatestPosition = DescribePartyPosition();
            _activeReport.AttemptedUnpause = true;
            _activeReport.TravelCommandIssued = true;
            _activeReport.RouteStarted = true;
            _activeReport.RuntimeProofClaim = "main_party_move_to_settlement_order_issued";

            _activeReport.RouteClockEvidence = new MapTradeRouteClockEvidence
            {
                CommandAck = "Success",
                RouteTarget = _activeReport.Mission?.TargetSettlementName,
                RouteIntent = "assigned",
                RouteOwner = "MapTrade",
                ClockStateBefore = "unknown_before_route_assignment",
                ClockResumeAttempted = true,
                ClockResumeResult = "attempted_by_CampaignMapMovementHelper",
                AuthorityMode = EngineToggleAuthority.GetMode(EngineToggleKey.MapTrade).ToString(),
                MovementObservation = "not_observed_yet",
                ArrivalBlockedIndeterminate = "route_started_checkpoint",
                NextOwner = "MapTradeAutonomousService.OnCampaignTick",
                RuntimeProofClaim = false
            };

            _activeReport.Steps.Add("RouteClockEvidence:runtimeProofClaim=false");
            var party = MobileParty.MainParty;
            _routeStartPositionRecorded = party != null;
            if (_routeStartPositionRecorded)
            {
                _routeStartPosition = party.GetPosition2D;
            }

            _routeStartedTickSerial = string.Equals(source, BranchRouteSource, StringComparison.Ordinal)
                ? _campaignTickSerial
                : -1;
            _activeReport.State = MapTradeRouteState.TravelToTarget;
            _activeReport.Steps.Add("RouteLifeCert:travelCommandIssued=true");
            _activeReport.Steps.Add($"TravelToTarget:{_activeReport.Mission.TargetSettlementName}");
            InGameNotice.Info($"TBG MAP TRADE MOVE: riding toward {_activeReport.Mission.TargetSettlementName}.");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            return true;
        }

        private static void TickTravel()
        {
            _activeReport.LatestPosition = DescribePartyPosition();
            ObserveRouteMovement();
            if (!MapTradeVisibleMovementDriver.HasArrived(_activeReport.Mission))
            {
                _activeReport.State = MapTradeRouteState.WaitForArrival;
                return;
            }

            _activeReport.State = MapTradeRouteState.EnterSettlement;
            _activeReport.ArrivalObserved = true;
            _activeReport.ArrivedSettlement =
                MobileParty.MainParty?.CurrentSettlement?.Name?.ToString()
                ?? MobileParty.MainParty?.CurrentSettlement?.StringId
                ?? _activeReport.Mission?.TargetSettlementName;
            _activeReport.Steps.Add("ArrivedAtTarget");
            TryTradeAndFinish();
        }

        private static void MarkAutoStartTickReturn()
        {
            if (_activeReport == null || _activeReport.RouteClockEvidence == null)
            {
                return;
            }

            _activeReport.AutoStartTickReturnObserved = true;
            _activeReport.SameTickHoldObserved = false;
            _activeReport.RouteClockEvidence.ArrivalBlockedIndeterminate = "same_tick_return_before_menu_hold";
            _activeReport.Steps.Add("RouteAutoStart:SameTickReturnObserved");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
        }

        private static void ObserveRouteMovement()
        {
            var party = MobileParty.MainParty;
            if (_activeReport == null || party == null || !_routeStartPositionRecorded)
            {
                return;
            }

            var distance = party.GetPosition2D.Distance(_routeStartPosition);
            if (distance > _activeReport.PartyMovedDistance)
            {
                _activeReport.PartyMovedDistance = distance;
            }

            if (_activeReport.MovementObserved || distance < 0.05f)
            {
                return;
            }

            _activeReport.MovementObserved = true;
            _activeReport.RuntimeProofClaim = "party_position_delta_observed";
            if (_activeReport.RouteClockEvidence != null)
            {
                _activeReport.RouteClockEvidence.MovementObservation = "party_position_delta_observed";
                _activeReport.RouteClockEvidence.ArrivalBlockedIndeterminate = "movement_observed_arrival_pending";
                _activeReport.RouteClockEvidence.RuntimeProofClaim = true;
            }

            _activeReport.Steps.Add($"RouteMovementObserved:{distance:0.###}");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
        }

        private static void TryTradeAndFinish()
        {
            _activeReport.State = MapTradeRouteState.ExecuteTrade;
            MapTradeVanillaTradeDriver.ProbeTradeApi(out var probeDetail);
            _activeReport.TradeDriverAvailable = MapTradeVanillaTradeDriver.LastProbeAvailable;
            _activeReport.TradeDriverMethod = MapTradeVanillaTradeDriver.LastProbeMethod;

            if (_activeReport.Mission.MissionType == MapTradeMissionType.TravelOnlySafetyCert)
            {
                _activeReport.Steps.Add("TravelOnlySafetyCert:Complete");
                RunForgeHandoffIfConfigured();
                Finish(MapTradeRouteState.Complete, "Complete", null);
                return;
            }

            if (MapTradeVanillaTradeDriver.TryExecuteBuy(_activeReport.Mission, out var buyDetail))
            {
                _activeReport.TradeSurface = MapTradeVanillaTradeDriver.LastTradeSurfaceEvidence;
                var successStep = _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? "ExecutePackAnimalBuy:Success"
                    : "ExecuteTrade:Success";
                _activeReport.Steps.Add(successStep);
                _activeReport.TradeExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                _activeReport.MutationApplied = _activeReport.TradeExecution != null;
                RunForgeHandoffIfConfigured();
                Finish(MapTradeRouteState.Complete, "Complete", null);
                return;
            }

            _activeReport.TradeSurface = MapTradeVanillaTradeDriver.LastTradeSurfaceEvidence;

            _activeReport.Steps.Add(
                _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? $"ExecutePackAnimalBuy:Blocked:{buyDetail ?? probeDetail}"
                    : $"ExecuteTrade:Blocked:{buyDetail ?? probeDetail}");
            Finish(
                MapTradeRouteState.Blocked,
                "BlockedTrade",
                buyDetail ?? "visible trade delta was not proven");
        }

        private static void RunForgeHandoffIfConfigured()
        {
            if (!DevToolsConfig.MapTradeAutoRunForgeHandoff)
            {
                return;
            }

            _activeReport.State = MapTradeRouteState.ForgeHandoff;
            MapTradeForgeHandoffService.RunHandoffNow(_activeReport.Source);
        }

        private static CohesionObjective BuildObjectiveForMission(MapTradeMission mission)
        {
            var objective = CohesionDoctrine.BuildDefaultObjective();
            if (mission?.TargetSettlement != null)
            {
                objective.TargetSettlementId = mission.TargetSettlement.StringId;
                objective.TargetSettlementName = mission.TargetSettlementName;
            }

            if (!string.IsNullOrEmpty(mission?.ItemId))
            {
                objective.RequiredItemIds.Add(mission.ItemId);
            }

            return objective;
        }

        private static void Finish(MapTradeRouteState state, string verdict, string reason)
        {
            if (_activeReport == null)
            {
                return;
            }

            _activeReport.State = state;
            _activeReport.Verdict = verdict;
            _activeReport.BlockedReason = state == MapTradeRouteState.Complete ? reason : reason;
            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            _activeReport.LatestPosition = DescribePartyPosition();
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            MapTradeEvidenceWriter.WriteArmyPressure(MapTradeArmyPressureAnalyzer.AnalyzeNow());
            VisibleTradeCycleEvidenceWriter.WriteTerminal(_activeReport);

            _lastTerminalState = state;
            _lastTerminalVerdict = verdict;

            if (state == MapTradeRouteState.Complete)
            {
                InGameNotice.Success($"TBG MAP TRADE DONE: {verdict}.");
            }
            else
            {
                InGameNotice.Blocked($"TBG MAP TRADE {verdict}: {reason}");
            }

            _activeReport = null;
        }

        private static void PauseIfVisible(string label)
        {
            if (!DevToolsConfig.MapTradeVisibleMode || DevToolsConfig.MapTradeDecisionPauseMs <= 0)
            {
                return;
            }

            InGameNotice.Info($"TBG MAP TRADE: {label}...");
            Thread.Sleep(DevToolsConfig.MapTradeDecisionPauseMs);
        }
    }
}
