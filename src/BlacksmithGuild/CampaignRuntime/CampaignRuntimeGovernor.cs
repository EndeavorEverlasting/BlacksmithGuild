using System;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Food;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignRuntimeGovernor
    {
        public const string RunCampaignGovernorCycleNowCommand = "RunCampaignGovernorCycleNow";
        public const string ShowCampaignGovernorDecisionCommand = "ShowCampaignGovernorDecision";
        public const string PauseCampaignGovernorAutomationCommand = "PauseCampaignGovernorAutomation";
        public const string ResumeCampaignGovernorAutomationCommand = "ResumeCampaignGovernorAutomation";

        private static DateTime _lastTickDecisionUtc = DateTime.MinValue;
        private static bool _paused;

        public static CampaignRuntimeDecision LastDecision { get; private set; }

        public static bool IsPaused => _paused;

        public static void OnCampaignTick()
        {
            if (!DevToolsConfig.CampaignRuntimeGovernorAutonomousMode || _paused)
            {
                return;
            }

            var interval = Math.Max(1000, DevToolsConfig.CampaignRuntimeGovernorDecisionIntervalMs);
            if ((DateTime.UtcNow - _lastTickDecisionUtc).TotalMilliseconds < interval)
            {
                return;
            }

            _lastTickDecisionUtc = DateTime.UtcNow;
            RunCycleNow("campaign_tick");
        }

        public static bool RunCycleNow(string source = RunCampaignGovernorCycleNowCommand)
        {
            try
            {
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorDecisionStarted, reason: source);
                var decision = BuildDecision(source);
                LastDecision = decision;
                CampaignRuntimeDecisionWriter.Write(decision);
                AutomationRuntimeEventEmitter.Emit(
                    AutomationRuntimeEventEmitter.GovernorDecisionCompleted,
                    reason: decision.SelectedBranch,
                    payloadJson: "{\"cycleId\":\"" + Escape(decision.CycleId) + "\",\"selectedBranch\":\"" + Escape(decision.SelectedBranch) + "\",\"activityId\":\"" + Escape(decision.ProposedActivity?.ActivityId) + "\"}");

                InGameNotice.Info(ModDisplay.CompactLine("Governor", $"{decision.SelectedBranch}: {decision.SelectedReason}"));
                return true;
            }
            catch (Exception ex)
            {
                _paused = true;
                var failed = BuildFailedDecision(source, ex);
                LastDecision = failed;
                TryWriteFailedDecision(failed);
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorDecisionFailed, reason: ex.Message);
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorFailSafePause, reason: ex.Message);
                DebugLogger.Test($"[TBG GOVERNOR] failed and paused: {ex.Message}", showInGame: false);
                InGameNotice.Blocked(ModDisplay.CompactLine("Governor", "failed; automation paused"));
                return false;
            }
        }

        public static bool ShowLastDecision()
        {
            if (LastDecision == null)
            {
                return RunCycleNow(ShowCampaignGovernorDecisionCommand);
            }

            CampaignRuntimeDecisionWriter.Write(LastDecision);
            InGameNotice.Info(ModDisplay.CompactLine(
                "Governor",
                $"{LastDecision.SelectedBranch}: {LastDecision.SelectedReason}"));
            return true;
        }

        public static bool PauseAutomation(string reason = "manual pause")
        {
            _paused = true;
            AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorFailSafePause, reason: reason);
            InGameNotice.Blocked(ModDisplay.CompactLine("Governor", "automation paused"));
            return true;
        }

        public static bool ResumeAutomation(string reason = "manual resume")
        {
            _paused = false;
            InGameNotice.Success(ModDisplay.CompactLine("Governor", "automation resumed"));
            return true;
        }

        private static CampaignRuntimeDecision BuildDecision(string source)
        {
            GameSessionState.Refresh();

            var food = CampaignRuntimeStatusReaders.ReadFood();
            var capacityStatus = CampaignRuntimeStatusReaders.ReadCapacityStatus();
            var horseStatus = CampaignRuntimeStatusReaders.ReadHorseStatus();
            var staminaStatus = CampaignRuntimeStatusReaders.ReadStaminaStatus();
            var materialStatus = CampaignRuntimeStatusReaders.ReadMaterialStatus();
            var smithingStatus = CampaignRuntimeStatusReaders.ReadSmithingStatus(staminaStatus, materialStatus);
            var tradeStatus = CampaignRuntimeStatusReaders.ReadTradeStatus();
            var companionStatus = CampaignRuntimeStatusReaders.ReadCompanionStatus();
            var diplomacyStatus = CampaignRuntimeStatusReaders.ReadDiplomacyStatus();
            var threatStatus = CampaignRuntimeStatusReaders.ReadThreatStatus();

            var decision = new CampaignRuntimeDecision
            {
                CycleId = Guid.NewGuid().ToString("N"),
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Surface = CampaignRuntimeStatusReaders.ReadSurface(),
                GameHealth = CampaignRuntimeStatusReaders.ReadGameHealth(),
                CurrentTown = CampaignRuntimeStatusReaders.ReadCurrentTown(),
                DestinationCandidate = CampaignRuntimeStatusReaders.ReadDestinationCandidate(),
                FoodStatus = food.QuantityStatus + ":" + food.Detail,
                FoodDiversityStatus = food.DiversityStatus + ":uniqueTypes=" + food.UniqueFoodTypes,
                FoodForecastStatus = food.ForecastStatus + ":daysRemaining=" + food.EstimatedDaysRemaining.ToString("0.##") + " daysUntilFloor=" + food.EstimatedDaysUntilFloor.ToString("0.##"),
                CapacityStatus = capacityStatus,
                HorseStatus = horseStatus,
                StaminaStatus = staminaStatus,
                MaterialStatus = materialStatus,
                TradeStatus = tradeStatus,
                SmithingStatus = smithingStatus,
                CompanionStatus = companionStatus,
                DiplomacyStatus = diplomacyStatus,
                ThreatStatus = threatStatus,
                ReportInsufficient = tradeStatus.StartsWith("report_insufficient", StringComparison.OrdinalIgnoreCase),
                MapScanRequired = tradeStatus.StartsWith("report_insufficient", StringComparison.OrdinalIgnoreCase),
                Confidence = "medium",
                Allowed = false
            };

            RankAndSelect(decision, food);
            decision.PriorityRank = CampaignRuntimePolicy.RankForBranch(decision.SelectedBranch);
            AttachProposedActivity(decision);
            return decision;
        }

        private static void RankAndSelect(CampaignRuntimeDecision decision, FoodInventoryStatus food)
        {
            if (!string.Equals(decision.GameHealth, "ok", StringComparison.OrdinalIgnoreCase))
            {
                Select(decision, CampaignRuntimePolicy.BranchGameHealth, decision.GameHealth, false, "game_health_blocked");
                return;
            }

            if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch())
            {
                Select(decision, CampaignRuntimePolicy.BranchSurfaceSafety, MapTransitionGuard.GetDeferReason(), false, "gameplay_surface_unsafe");
                return;
            }

            if (!GameSessionState.IsCampaignMapReady && !GameSessionState.IsSettlementInteriorReady && !GameSessionState.IsSettlementMenuReady)
            {
                Select(decision, CampaignRuntimePolicy.BranchSurfaceSafety, GameSessionState.GetCommandReadyBlockDetail(), false, "gameplay_surface_unsafe");
                return;
            }

            if (IsUnknownOrUnsafeThreat(decision.ThreatStatus))
            {
                AddBlocked(decision, CampaignRuntimePolicy.BranchProfitableTrade, "threat state unsafe or unknown");
                AddBlocked(decision, CampaignRuntimePolicy.BranchTravelOpportunity, "threat state unsafe or unknown");
                Select(decision, CampaignRuntimePolicy.BranchThreatPoliticsSafety, decision.ThreatStatus, false, "threat_state_unknown_blocked");
                return;
            }

            if (food.QuantityStatus == "critical" || food.QuantityStatus == "low" || food.ForecastStatus == "critical" || food.ForecastStatus == "low")
            {
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.FoodQuantityLow, reason: food.Detail);
                AddBlocked(decision, CampaignRuntimePolicy.BranchProfitableTrade, "food runway below planning horizon");
                Select(decision, CampaignRuntimePolicy.BranchFoodQuantity, food.Detail, false, "branch_gate_blocked");
                return;
            }

            if (food.DiversityStatus == "low")
            {
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.FoodDiversityLow, reason: food.Detail);
                AddBlocked(decision, CampaignRuntimePolicy.BranchProfitableTrade, "food diversity below floor");
                Select(decision, CampaignRuntimePolicy.BranchFoodDiversity, food.Detail, false, "branch_gate_blocked");
                return;
            }

            if (decision.CapacityStatus.StartsWith("pressure", StringComparison.OrdinalIgnoreCase))
            {
                Select(decision, CampaignRuntimePolicy.BranchCapacityPressure, decision.CapacityStatus, false, "branch_gate_blocked");
                return;
            }

            if (decision.SmithingStatus == "ready_or_advisory")
            {
                Select(decision, CampaignRuntimePolicy.BranchSmithingReadiness, "smithing appears ready; bounded execution disabled by governor spine", false, null);
                return;
            }

            if (decision.TradeStatus.StartsWith("cached", StringComparison.OrdinalIgnoreCase)
                && decision.TradeStatus.IndexOf("routes=0", StringComparison.OrdinalIgnoreCase) < 0)
            {
                Select(decision, CampaignRuntimePolicy.BranchProfitableTrade, decision.TradeStatus, false, null);
                return;
            }

            if (!string.IsNullOrWhiteSpace(decision.DestinationCandidate))
            {
                Select(decision, CampaignRuntimePolicy.BranchTravelOpportunity, decision.DestinationCandidate, false, null);
                return;
            }

            if (decision.CompanionStatus.StartsWith("available", StringComparison.OrdinalIgnoreCase))
            {
                Select(decision, CampaignRuntimePolicy.BranchCompanionOpportunity, decision.CompanionStatus, false, null);
                return;
            }

            if (decision.ReportInsufficient)
            {
                AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorReportInsufficient, reason: decision.TradeStatus);
                Select(decision, CampaignRuntimePolicy.BranchReportInsufficient, decision.TradeStatus, true, null);
                decision.Confidence = "low";
                return;
            }

            Select(decision, CampaignRuntimePolicy.BranchObserveOnly, "no safe higher-priority action selected", true, null);
            decision.Confidence = "low";
        }

        private static void AttachProposedActivity(CampaignRuntimeDecision decision)
        {
            var mutationAuthorized = DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution && decision.Allowed;
            var branch = decision.SelectedBranch;
            var rank = decision.PriorityRank;
            var reason = decision.SelectedReason;

            switch (branch)
            {
                case CampaignRuntimePolicy.BranchFoodQuantity:
                case CampaignRuntimePolicy.BranchFoodDiversity:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Food, "AcquireFoodBeforeRunwayBreach", reason, rank, mutationAuthorized, decision.CurrentTown, decision.DestinationCandidate);
                    decision.ProposedActivity.RequiresFreshMarketScan = true;
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.RequiresInventoryDelta = true;
                    decision.ProposedActivity.RequiresGoldDelta = true;
                    decision.ProposedActivity.ExpectedProof = "fresh market scan plus vanilla buy inventory/gold delta before food runway breach";
                    return;
                case CampaignRuntimePolicy.BranchCapacityPressure:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.HorseMarket, "AcquirePackAnimalForCapacity", reason, rank, mutationAuthorized, decision.CurrentTown, decision.DestinationCandidate);
                    decision.ProposedActivity.RequiresFreshMarketScan = true;
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.RequiresInventoryDelta = true;
                    decision.ProposedActivity.RequiresGoldDelta = true;
                    decision.ProposedActivity.ExpectedProof = "pack animal buy delta or explicit blocked no-market/no-gold result";
                    return;
                case CampaignRuntimePolicy.BranchSmithingReadiness:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Smithing, "PrepareOrExecuteSafeSmithing", reason, rank, mutationAuthorized, decision.CurrentTown, null);
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.RequiresInventoryDelta = true;
                    decision.ProposedActivity.ExpectedProof = "smithing advisory or bounded refine/smelt delta";
                    return;
                case CampaignRuntimePolicy.BranchProfitableTrade:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Trade, "EvaluateOrExecuteTradeRoute", reason, rank, mutationAuthorized, decision.CurrentTown, decision.DestinationCandidate);
                    decision.ProposedActivity.RequiresFreshMarketScan = false;
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.RequiresInventoryDelta = true;
                    decision.ProposedActivity.RequiresGoldDelta = true;
                    decision.ProposedActivity.ExpectedProof = "trade iteration record with nonfake inventory/gold delta";
                    return;
                case CampaignRuntimePolicy.BranchTravelOpportunity:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.MapTravel, "TravelToBestKnownOpportunity", reason, rank, mutationAuthorized, decision.CurrentTown, decision.DestinationCandidate);
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.ExpectedProof = "party movement observed and destination arrival or blocked safety reason";
                    return;
                case CampaignRuntimePolicy.BranchCompanionOpportunity:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Companion, "EvaluateTavernRecruitment", reason, rank, mutationAuthorized, decision.CurrentTown, null);
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.RequiresGoldDelta = true;
                    decision.ProposedActivity.ExpectedProof = "roster decision report and vanilla recruitment delta if executed";
                    return;
                case CampaignRuntimePolicy.BranchThreatPoliticsSafety:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Cohesion, "HoldOrFindSafeRoute", reason, rank, false, decision.CurrentTown, null);
                    decision.ProposedActivity.RequiresVisibleSurface = true;
                    decision.ProposedActivity.ExpectedProof = "cohesion/threat report with selected safe action or hold reason";
                    return;
                case CampaignRuntimePolicy.BranchReportInsufficient:
                    decision.ProposedActivity = CampaignActivityFactory.Create(decision.CycleId, branch, CampaignActivityEngine.Market, "RefreshMarketScan", reason, rank, false, decision.CurrentTown, null);
                    decision.ProposedActivity.RequiresFreshMarketScan = true;
                    decision.ProposedActivity.ExpectedProof = "fresh market intelligence report written";
                    return;
                default:
                    decision.ProposedActivity = CampaignActivityFactory.ObserveOnly(decision.CycleId, branch, reason, rank);
                    decision.ProposedActivity.ExpectedProof = "decision only; no engine execution authorized";
                    return;
            }
        }

        private static bool IsUnknownOrUnsafeThreat(string threatStatus)
        {
            if (string.IsNullOrWhiteSpace(threatStatus))
            {
                return true;
            }

            return threatStatus.StartsWith("unknown", StringComparison.OrdinalIgnoreCase)
                || threatStatus.Equals("high", StringComparison.OrdinalIgnoreCase);
        }

        private static void Select(
            CampaignRuntimeDecision decision,
            string branch,
            string reason,
            bool allowed,
            string failureClass)
        {
            decision.SelectedBranch = branch;
            decision.SelectedReason = reason ?? branch;
            decision.Allowed = allowed;
            decision.FailureClass = failureClass;
        }

        private static void AddBlocked(CampaignRuntimeDecision decision, string branch, string reason)
        {
            decision.BlockedBranches.Add(new CampaignRuntimeBlockedBranch
            {
                Branch = branch,
                Reason = reason,
                PriorityRank = CampaignRuntimePolicy.RankForBranch(branch)
            });
            AutomationRuntimeEventEmitter.Emit(AutomationRuntimeEventEmitter.GovernorBranchBlocked, reason: reason,
                payloadJson: "{\"branch\":\"" + Escape(branch) + "\"}");
        }

        private static CampaignRuntimeDecision BuildFailedDecision(string source, Exception ex)
        {
            var decision = new CampaignRuntimeDecision
            {
                CycleId = Guid.NewGuid().ToString("N"),
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Surface = "unknown",
                GameHealth = "failed",
                SelectedBranch = CampaignRuntimePolicy.BranchFailSafePause,
                SelectedReason = ex.Message,
                PriorityRank = 1,
                Confidence = "low",
                Allowed = false,
                FailureClass = "governor_exception"
            };
            decision.ProposedActivity = CampaignActivityFactory.ObserveOnly(
                decision.CycleId,
                CampaignRuntimePolicy.BranchFailSafePause,
                ex.Message,
                decision.PriorityRank);
            return decision;
        }

        private static void TryWriteFailedDecision(CampaignRuntimeDecision decision)
        {
            try
            {
                CampaignRuntimeDecisionWriter.Write(decision);
            }
            catch (Exception writeEx)
            {
                DebugLogger.Test($"[TBG GOVERNOR] failed decision write failed: {writeEx.Message}", showInGame: false);
            }
        }

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"");
    }
}
