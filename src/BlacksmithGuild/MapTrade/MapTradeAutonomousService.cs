using System;
using System.Collections.Generic;
using System.Threading;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeAutonomousService
    {
        public const string RunAutonomousVisibleTradeRouteNowCommand = "RunAutonomousVisibleTradeRouteNow";
        public const string AbortMapTradeRouteNowCommand = "AbortMapTradeRouteNow";
        public const string ShowMapTradeRouteStatusCommand = "ShowMapTradeRouteStatus";
        public const string AnalyzeTacticalConvergenceCommand = "AnalyzeTacticalConvergence";
        public const string ShowTacticalConvergenceCommand = "ShowTacticalConvergence";

        private static MapTradeCertReport _activeReport;
        private static MapTradeMission _originalRouteMission;
        private static bool _routeSellLegPending;
        private static bool _abortRequested;

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

        public static bool StartRouteNow(string source = RunAutonomousVisibleTradeRouteNowCommand)
        {
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!DevToolsConfig.MapTradeAutonomousMode)
            {
                LastFailReason = "MapTradeAutonomousMode disabled";
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
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                VisibleModeEnabled = DevToolsConfig.MapTradeVisibleMode,
                DecisionPauseMs = DevToolsConfig.MapTradeDecisionPauseMs,
                MutationApplied = false,
                State = MapTradeRouteState.Preflight
            };

            if (!MarketIntelligenceService.RunScanNow(source))
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", "market scan failed");
                return false;
            }

            _activeReport.Steps.Add("MarketScan:Success");
            _activeReport.Mission = MapTradeMissionSelector.SelectBestMission();
            _originalRouteMission = _activeReport.Mission;
            _routeSellLegPending = false;
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

        public static bool AbortNow()
        {
            if (_activeReport == null)
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
            if (_activeReport == null || !IsRunning || _abortRequested)
            {
                return;
            }

            GameSessionState.Refresh();
            if (GameSessionState.IsMapMenuOpen)
            {
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

            _activeReport.State = MapTradeRouteState.TravelToTarget;
            _activeReport.Steps.Add($"TravelToTarget:{_activeReport.Mission.TargetSettlementName}");
            InGameNotice.Info($"TBG MAP TRADE MOVE: riding toward {_activeReport.Mission.TargetSettlementName}.");
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            return true;
        }

        private static void TickTravel()
        {
            if (!MapTradeVisibleMovementDriver.HasArrived(_activeReport.Mission))
            {
                _activeReport.State = MapTradeRouteState.WaitForArrival;
                return;
            }

            _activeReport.State = MapTradeRouteState.EnterSettlement;
            _activeReport.Steps.Add(_routeSellLegPending ? "ArrivedAtSellTarget" : "ArrivedAtTarget");

            if (_routeSellLegPending)
            {
                TrySellAndFinish();
                return;
            }

            TryBuyLegAndMaybeTravelToSell();
        }

        private static void TryBuyLegAndMaybeTravelToSell()
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
                var successStep = _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? "ExecutePackAnimalBuy:Success"
                    : "ExecuteTrade:Success";
                _activeReport.Steps.Add(successStep);
                _activeReport.TradeExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                _activeReport.MutationApplied = _activeReport.TradeExecution != null;

                var current = MobileParty.MainParty?.CurrentSettlement;
                if (DevToolsConfig.MapTradeAutoTravelToSellTown
                    && MapTradeMissionSelector.NeedsSecondLegSellTravel(_originalRouteMission, current))
                {
                    var sellLeg = MapTradeMissionSelector.TryBuildSellLegTravelMission(_originalRouteMission);
                    string travelDetail = null;
                    if (sellLeg?.TargetSettlement != null
                        && MapTradeVisibleMovementDriver.TryStartTravel(sellLeg, out travelDetail))
                    {
                        _routeSellLegPending = true;
                        _activeReport.Mission = sellLeg;
                        _activeReport.State = MapTradeRouteState.TravelToTarget;
                        _activeReport.Steps.Add($"TravelToSellTarget:{sellLeg.TargetSettlementName}");
                        InGameNotice.Info($"TBG MAP TRADE MOVE: riding toward sell town {sellLeg.TargetSettlementName}.");
                        MapTradeEvidenceWriter.WriteCert(_activeReport);
                        return;
                    }

                    _activeReport.Steps.Add($"TravelToSellTarget:Blocked:{travelDetail ?? "sell leg travel failed"}");
                }

                TrySellAtCurrentSettlement();
                RunForgeHandoffIfConfigured();
                Finish(MapTradeRouteState.Complete, "Complete", null);
                return;
            }

            _activeReport.Steps.Add(
                _activeReport.Mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                    ? $"ExecutePackAnimalBuy:Blocked:{buyDetail ?? probeDetail}"
                    : $"ExecuteTrade:Blocked:{buyDetail ?? probeDetail}");
            if (DevToolsConfig.MapTradeAllowDirectInventoryMutation)
            {
                Finish(MapTradeRouteState.Blocked, "Blocked", buyDetail);
                return;
            }

            _activeReport.Steps.Add("TravelOnlyFallback");
            RunForgeHandoffIfConfigured();
            Finish(
                MapTradeRouteState.Complete,
                "Complete",
                buyDetail ?? "VisibleTradeDriverUnavailable");
        }

        private static void TrySellAndFinish()
        {
            _activeReport.State = MapTradeRouteState.ExecuteTrade;
            TrySellAtCurrentSettlement();
            RunForgeHandoffIfConfigured();
            Finish(MapTradeRouteState.Complete, "Complete", null);
        }

        private static void TrySellAtCurrentSettlement()
        {
            if (!MapTradeMissionSelector.ShouldAttemptSell(_originalRouteMission, out var sellMission))
            {
                _activeReport.Steps.Add("ExecuteSell:Skipped");
                return;
            }

            if (MapTradeVanillaTradeDriver.TryExecuteSell(sellMission, out var sellDetail))
            {
                _activeReport.Steps.Add("ExecuteSell:Success");
                _activeReport.SellExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                _activeReport.MutationApplied = true;
            }
            else
            {
                _activeReport.Steps.Add($"ExecuteSell:Blocked:{sellDetail ?? "sell driver unavailable"}");
            }
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
            MapTradeEvidenceWriter.WriteCert(_activeReport);
            MapTradeEvidenceWriter.WriteArmyPressure(MapTradeArmyPressureAnalyzer.AnalyzeNow());

            if (state == MapTradeRouteState.Complete)
            {
                InGameNotice.Success($"TBG MAP TRADE DONE: {verdict}.");
            }
            else
            {
                InGameNotice.Blocked($"TBG MAP TRADE {verdict}: {reason}");
            }

            _activeReport = null;
            _originalRouteMission = null;
            _routeSellLegPending = false;
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
