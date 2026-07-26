using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;
using System.Threading;
using BlacksmithGuild.CampaignRuntime;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.DevTools.Diagnostics;
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
        private const int MaxSettlementTradeAttempts = 12;
        private static readonly TimeSpan BranchAutoStartCooldown = TimeSpan.FromSeconds(2);
        private static readonly TimeSpan SettlementTradeRetryInterval = TimeSpan.FromMilliseconds(750);

        private static MapTradeCertReport _activeReport;
        private static CampaignActivityRequest _governorActivity;
        private static bool _abortRequested;
        private static DateTime _nextBranchAutoStartUtc = DateTime.MinValue;
        private static DateTime _nextSettlementTradeAttemptUtc = DateTime.MinValue;
        private static int _settlementTradeAttempts;
        private static string _lastBranchAutoStartKey;

        public static string LastFailReason { get; private set; }
        public static MapTradeCertReport ActiveReport => _activeReport;

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

        public static bool StartRouteNow(
            string source = RunAutonomousVisibleTradeRouteNowCommand,
            bool requireTradeMission = false)
        {
            var span = AutomationRuntimeEventEmitter.BeginSpan(
                "MapTradeAutonomousService.StartRouteNow",
                expectedSignal: "route_preflight_completed_or_blocked",
                preState: RuntimeStateSnapshot.Capture(source));
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.MapTrade))
            {
                LastFailReason = "MapTrade engine disabled by authority";
                AutomationRuntimeEventEmitter.BlockSpan(span, LastFailReason, RuntimeStateSnapshot.Capture(source));
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                LastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                AutomationRuntimeEventEmitter.BlockSpan(span, LastFailReason, RuntimeStateSnapshot.Capture(source));
                return false;
            }

            if (IsRunning)
            {
                LastFailReason = "map trade route already in progress";
                AutomationRuntimeEventEmitter.BlockSpan(span, LastFailReason, RuntimeStateSnapshot.Capture(source));
                return false;
            }

            PauseIfVisible("starting map trade route");
            _activeReport = new MapTradeCertReport
            {
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

            if (!MarketIntelligenceService.RunScanNow(source))
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", "market scan failed");
                AutomationRuntimeEventEmitter.BlockSpan(span, "market scan failed", RuntimeStateSnapshot.Capture(source));
                return false;
            }

            _activeReport.Steps.Add("MarketScan:Success");
            _activeReport.Mission = MapTradeMissionSelector.SelectBestMission();
            _activeReport.State = MapTradeRouteState.SelectMission;

            if (_activeReport.Mission.MissionType == MapTradeMissionType.BlockedNoSafeMission)
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", _activeReport.Mission.BlockReason);
                AutomationRuntimeEventEmitter.BlockSpan(span, _activeReport.Mission.BlockReason, RuntimeStateSnapshot.Capture(source));
                return false;
            }

            if (requireTradeMission
                && _activeReport.Mission.MissionType == MapTradeMissionType.TravelOnlySafetyCert)
            {
                const string reason = "no executable trade mission selected; travel-only fallback is not trade proof";
                Finish(MapTradeRouteState.Blocked, "BlockedNoTradeMission", reason);
                AutomationRuntimeEventEmitter.BlockSpan(span, reason, RuntimeStateSnapshot.Capture(source));
                return false;
            }

            if (MapTradeMissionSelector.NeedsCohesionCheck(_activeReport.Mission))
            {
                var cohesionResult = RunCohesionCheck(source);
                if (cohesionResult)
                    AutomationRuntimeEventEmitter.CompleteSpan(span, "cohesion_preflight_completed", RuntimeStateSnapshot.Capture(source));
                else
                    AutomationRuntimeEventEmitter.BlockSpan(span, _activeReport?.BlockedReason ?? "cohesion blocked", RuntimeStateSnapshot.Capture(source));
                return cohesionResult;
            }

            var travelResult = BeginTravel(source);
            if (travelResult)
                AutomationRuntimeEventEmitter.CompleteSpan(span, "route_preflight_completed", RuntimeStateSnapshot.Capture(source));
            else
                AutomationRuntimeEventEmitter.BlockSpan(span, _activeReport?.BlockedReason ?? "travel blocked", RuntimeStateSnapshot.Capture(source));
            return travelResult;
        }

        public static bool TryStartGovernorTradeActivity(
            CampaignActivityRequest request,
            out string detail)
        {
            if (!CanStartGovernorActivity(request, out detail))
            {
                return false;
            }

            var source = "governor:" + request.ActivityId;
            if (!StartRouteNow(source, requireTradeMission: true))
            {
                detail = LastFailReason
                    ?? _activeReport?.BlockedReason
                    ?? "MapTrade trade route did not start";
                return false;
            }

            _governorActivity = request;
            _activeReport.Steps.Add("GovernorActivity:Trade:" + request.ActivityId);
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            detail = "MapTrade trade route started"
                + " activityId=" + request.ActivityId
                + " state=" + _activeReport.State;
            return true;
        }

        public static bool TryStartGovernorTravelActivity(
            CampaignActivityRequest request,
            out string detail)
        {
            if (!CanStartGovernorActivity(request, out detail))
            {
                return false;
            }

            if (string.IsNullOrWhiteSpace(request.TargetTown))
            {
                detail = "governor travel target is missing";
                LastFailReason = detail;
                return false;
            }

            var source = "governor:" + request.ActivityId;
            if (!StartBranchRouteNow(request.TargetTown, source))
            {
                detail = LastFailReason
                    ?? _activeReport?.BlockedReason
                    ?? "MapTrade travel route did not start";
                return false;
            }

            _governorActivity = request;
            _activeReport.Steps.Add("GovernorActivity:Travel:" + request.ActivityId);
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            detail = "MapTrade visible travel started"
                + " activityId=" + request.ActivityId
                + " target=" + request.TargetTown;
            return true;
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

            _activeReport.Steps.Add("RecursiveBranchState:travel");
            _activeReport.Steps.Add("TargetSettlement:" + destinationName);
            DebugLogger.Test($"[TBG MAP TRADE] branch route start requested target={destinationName} source={source}", showInGame: false);

            return BeginTravel(source);
        }

        public static bool AbortNow()
        {
            if (_activeReport == null || !IsRunning)
            {
                InGameNotice.Info("TBG MAP TRADE: no active route.");
                return true;
            }

            _abortRequested = true;
            MapTradeVisibleMovementDriver.Hold();
            Finish(MapTradeRouteState.Aborted, "Aborted", "Aborted by command");
            InGameNotice.Blocked("TBG MAP TRADE: route aborted.");
            return true;
        }

        public static void OnCampaignTick()
        {
            GameSessionState.Refresh();

            if (!EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.MapTrade))
            {
                if (IsRunning)
                {
                    AbortNow();
                }

                return;
            }

            if ((_activeReport == null || !IsRunning)
                && !_abortRequested
                && EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.MapTrade))
            {
                TryStartFromRecursiveBranchState();
            }

            if (_activeReport == null || !IsRunning || _abortRequested)
            {
                return;
            }

            if (GameSessionState.IsMapMenuOpen
                && _activeReport.State != MapTradeRouteState.EnterSettlement
                && _activeReport.State != MapTradeRouteState.ExecuteTrade)
            {
                if ((_activeReport.State == MapTradeRouteState.TravelToTarget
                        || _activeReport.State == MapTradeRouteState.WaitForArrival)
                    && IsAtTargetSettlement())
                {
                    BeginSettlementEntry();
                    TickSettlementAndTrade();
                    return;
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
                case MapTradeRouteState.EnterSettlement:
                case MapTradeRouteState.ExecuteTrade:
                    TickSettlementAndTrade();
                    break;
            }
        }

        private static bool CanStartGovernorActivity(
            CampaignActivityRequest request,
            out string detail)
        {
            detail = null;
            if (request == null)
            {
                detail = "governor activity request is missing";
                return false;
            }

            if (!request.MutationAuthorized
                || !EngineToggleAuthority.IsBoundedExecutionAllowed(EngineToggleKey.Governor))
            {
                detail = "governor bounded execution is not authorized";
                return false;
            }

            if (!EngineToggleAuthority.IsAutomationEnabled(EngineToggleKey.MapTrade))
            {
                detail = "MapTrade automation authority is required for governor dispatch";
                return false;
            }

            if (IsRunning)
            {
                detail = "map trade route already in progress";
                return false;
            }

            return true;
        }

        private static bool TryStartFromRecursiveBranchState()
        {
            var now = DateTime.UtcNow;
            if (now < _nextBranchAutoStartUtc)
            {
                return false;
            }

            _nextBranchAutoStartUtc = now.Add(BranchAutoStartCooldown);

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
            var now = DateTime.UtcNow.ToString("o");
            var report = new MapTradeCertReport
            {
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
            var span = AutomationRuntimeEventEmitter.BeginSpan(
                "MapTradeAutonomousService.BeginTravel",
                expectedSignal: "travel_command_issued_or_blocked",
                preState: RuntimeStateSnapshot.Capture(source, destination: _activeReport?.Mission?.TargetSettlementName));
            if (!MapTradeVisibleMovementDriver.TryStartTravel(_activeReport.Mission, out var detail))
            {
                Finish(MapTradeRouteState.Blocked, "BlockedNoMovementApi", detail);
                AutomationRuntimeEventEmitter.BlockSpan(span, detail, RuntimeStateSnapshot.Capture(source, destination: _activeReport?.Mission?.TargetSettlementName));
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
            _activeReport.State = MapTradeRouteState.TravelToTarget;
            ResetSettlementTradeRetry();
            _activeReport.Steps.Add("RouteLifeCert:travelCommandIssued=true");
            _activeReport.Steps.Add($"TravelToTarget:{_activeReport.Mission.TargetSettlementName}");
            InGameNotice.Info($"TBG MAP TRADE MOVE: riding toward {_activeReport.Mission.TargetSettlementName}.");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            AutomationRuntimeEventEmitter.CompleteSpan(span, "travel_command_issued", RuntimeStateSnapshot.Capture(source, destination: _activeReport.Mission.TargetSettlementName));
            return true;
        }

        private static void TickTravel()
        {
            _activeReport.LatestPosition = DescribePartyPosition();
            if (!MapTradeVisibleMovementDriver.HasArrived(_activeReport.Mission))
            {
                _activeReport.State = MapTradeRouteState.WaitForArrival;
                return;
            }

            BeginSettlementEntry();
            TickSettlementAndTrade();
        }

        private static void BeginSettlementEntry()
        {
            if (_activeReport.State != MapTradeRouteState.EnterSettlement)
            {
                _activeReport.Steps.Add("ArrivedAtTargetDistance");
            }

            _activeReport.State = MapTradeRouteState.EnterSettlement;
            _nextSettlementTradeAttemptUtc = DateTime.MinValue;
        }

        private static void TickSettlementAndTrade()
        {
            var now = DateTime.UtcNow;
            if (now < _nextSettlementTradeAttemptUtc)
            {
                return;
            }

            _nextSettlementTradeAttemptUtc = now.Add(SettlementTradeRetryInterval);
            _settlementTradeAttempts++;
            GameSessionState.Refresh();

            if (!IsAtTargetSettlement())
            {
                SettlementNavigationHelper.TryEnsureSettlementInterior(out var arrivalDetail);
                RetrySettlementOrTrade(
                    "SettlementEntry",
                    arrivalDetail ?? "target settlement identity not confirmed");
                return;
            }

            if (!SettlementNavigationHelper.TryEnsureSettlementInterior(out var entryDetail))
            {
                RetrySettlementOrTrade(
                    "SettlementEntry",
                    entryDetail ?? "settlement interior not ready");
                return;
            }

            if (_activeReport.Steps.Count == 0
                || !_activeReport.Steps.Contains("TargetSettlementConfirmed"))
            {
                _activeReport.Steps.Add("TargetSettlementConfirmed");
            }

            TryTradeAndFinish();
        }

        private static void TryTradeAndFinish()
        {
            _activeReport.State = MapTradeRouteState.ExecuteTrade;

            if (_activeReport.Mission.MissionType == MapTradeMissionType.TravelOnlySafetyCert)
            {
                _activeReport.Steps.Add("TravelOnlySafetyCert:Complete");
                _activeReport.RuntimeProofClaim = "target_settlement_arrival_confirmed";
                RunForgeHandoffIfConfigured();
                Finish(MapTradeRouteState.Complete, "Complete", null);
                return;
            }

            MapTradeVanillaTradeDriver.ProbeTradeApi(out var probeDetail);
            _activeReport.TradeDriverAvailable = MapTradeVanillaTradeDriver.LastProbeAvailable;
            _activeReport.TradeDriverMethod = MapTradeVanillaTradeDriver.LastProbeMethod;

            if (MapTradeVanillaTradeDriver.TryExecuteBuy(_activeReport.Mission, out var buyDetail))
            {
                var successStep = _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? "ExecutePackAnimalBuy:Success"
                    : "ExecuteTrade:Success";
                _activeReport.Steps.Add(successStep);
                _activeReport.TradeExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                _activeReport.MutationApplied = _activeReport.TradeExecution != null;
                _activeReport.RuntimeProofClaim = "vanilla_trade_inventory_gold_delta_observed";
                RunForgeHandoffIfConfigured();
                Finish(MapTradeRouteState.Complete, "Complete", null);
                return;
            }

            RetrySettlementOrTrade(
                _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? "ExecutePackAnimalBuy"
                    : "ExecuteTrade",
                buyDetail ?? probeDetail ?? "vanilla trade delta not proven");
        }

        private static void RetrySettlementOrTrade(string stage, string detail)
        {
            var attemptDetail = stage
                + ":Retry:"
                + _settlementTradeAttempts
                + "/"
                + MaxSettlementTradeAttempts
                + ":"
                + detail;
            _activeReport.Steps.Add(attemptDetail);
            _activeReport.BlockedReason = detail;

            if (_settlementTradeAttempts >= MaxSettlementTradeAttempts)
            {
                Finish(
                    MapTradeRouteState.Blocked,
                    "BlockedAfterBoundedRetry",
                    stage + " failed after " + MaxSettlementTradeAttempts + " attempts: " + detail);
                return;
            }

            _activeReport.State = MapTradeRouteState.EnterSettlement;
            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
        }

        private static bool IsAtTargetSettlement()
        {
            var target = _activeReport?.Mission?.TargetSettlement;
            if (target == null)
            {
                return false;
            }

            var current = MobileParty.MainParty?.CurrentSettlement
                ?? GameSessionState.ResolveCurrentSettlement();
            return current != null
                && (ReferenceEquals(current, target)
                    || string.Equals(current.StringId, target.StringId, StringComparison.OrdinalIgnoreCase));
        }

        private static void ResetSettlementTradeRetry()
        {
            _settlementTradeAttempts = 0;
            _nextSettlementTradeAttemptUtc = DateTime.MinValue;
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
            _activeReport.BlockedReason = state == MapTradeRouteState.Complete ? null : reason;
            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            _activeReport.LatestPosition = DescribePartyPosition();
            if (state != MapTradeRouteState.Complete)
            {
                LastFailReason = reason;
                _activeReport.RuntimeProofClaim = "route_terminal_without_completion";
            }

            MapTradeEvidenceWriter.WriteCert(_activeReport);
            MapTradeEvidenceWriter.WriteArmyPressure(MapTradeArmyPressureAnalyzer.AnalyzeNow());
            ReconcileGovernorActivity(state, verdict, reason);

            if (state == MapTradeRouteState.Complete)
            {
                InGameNotice.Success($"TBG MAP TRADE DONE: {verdict}.");
            }
            else
            {
                InGameNotice.Blocked($"TBG MAP TRADE {verdict}: {reason}");
            }

            // Retain the terminal report in memory so ShowMapTradeRouteStatus and the
            // governor can distinguish a completed/blocked route from an idle service.
        }

        private static void ReconcileGovernorActivity(
            MapTradeRouteState state,
            string verdict,
            string reason)
        {
            var request = _governorActivity;
            if (request == null)
            {
                return;
            }

            CampaignActivityResult result;
            var detail = "MapTrade terminal state=" + state
                + " verdict=" + verdict
                + " evidence=BlacksmithGuild_MapTradeCert.json"
                + (string.IsNullOrWhiteSpace(reason) ? string.Empty : " reason=" + reason);
            if (state == MapTradeRouteState.Complete)
            {
                var execution = _activeReport?.TradeExecution;
                var inventoryDeltaObserved = execution != null
                    && execution.InventoryAfter != execution.InventoryBefore;
                var goldDeltaObserved = execution != null
                    && execution.GoldDelta != 0;
                result = CampaignActivityDispatcher.Completed(
                    request,
                    detail,
                    inventoryDeltaObserved,
                    goldDeltaObserved);
            }
            else
            {
                result = CampaignActivityDispatcher.Blocked(
                    request,
                    detail,
                    "map_trade_" + state.ToString().ToLowerInvariant());
            }

            CampaignRuntimeGovernor.ReconcileActivityResult(request, result);
            _governorActivity = null;
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
