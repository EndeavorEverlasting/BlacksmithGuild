using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.ClanIntel;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Forge;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.GuildLoop
{
    public static class AutonomousGuildLoopService
    {
        public const string RunAutonomousGuildLoopNowCommand = "RunAutonomousGuildLoopNow";
        public const string AbortAutonomousGuildLoopNowCommand = "AbortAutonomousGuildLoopNow";
        public const string ReportFileName = "BlacksmithGuild_AutonomousGuildLoop.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        private static GuildLoopRunReport _activeReport;
        private static MapTradeMission _mission;
        private static MapTradeMission _originalMission;
        private static MapTradeMission _sellTravelMission;
        private static bool _abortRequested;

        public static string LastFailReason { get; private set; }

        public static bool IsRunning =>
            _activeReport != null
            && _activeReport.Verdict == null;

        public static bool IsTerminal =>
            _activeReport == null || _activeReport.Verdict != null;

        public static bool StartNow(string source = RunAutonomousGuildLoopNowCommand)
        {
            LastFailReason = null;
            _abortRequested = false;
            GameSessionState.Refresh();

            if (!DevToolsConfig.GuildLoopAutonomousMode)
            {
                LastFailReason = "GuildLoopAutonomousMode disabled";
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                LastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                WriteTerminal(source, "Blocked", LastFailReason);
                return false;
            }

            if (IsRunning)
            {
                LastFailReason = "autonomous guild loop already in progress";
                return false;
            }

            PauseIfVisible("starting autonomous guild loop");
            _activeReport = new GuildLoopRunReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Capabilities = ProbeCapabilities(),
                MaxCycles = Math.Max(1, DevToolsConfig.GuildLoopMaxCyclesPerCommand),
                CycleIndex = 0,
                CyclesCompleted = 0
            };

            AddStep("Preflight", "Success", "campaign map ready");
            return ContinueFromFactionPosture(source);
        }

        private static bool ContinueFromFactionPosture(string source)
        {
            var posture = FactionPowerPostureScanner.Scan();
            var summary = $"{posture.AllegianceMode} power={posture.PowerVerdict} hostiles={posture.HostileCountInRadius}";
            AddStep("FactionPosture", "Success", summary);
            return ContinueFromMarketScan(source);
        }

        public static void OnCampaignTick()
        {
            if (_activeReport == null || IsTerminal || _abortRequested)
            {
                return;
            }

            GameSessionState.Refresh();
            if (GameSessionState.IsMapMenuOpen)
            {
                MapTradeVisibleMovementDriver.Hold();
                return;
            }

            if (_activeReport.Phase == GuildLoopPhase.TravelToTown
                && _mission != null
                && MapTradeVisibleMovementDriver.HasArrived(_mission))
            {
                ContinueFromBuyLegArrival(_activeReport.Source);
                return;
            }

            if (_activeReport.Phase == GuildLoopPhase.TravelToSellTown
                && _sellTravelMission != null
                && MapTradeVisibleMovementDriver.HasArrived(_sellTravelMission))
            {
                ContinueFromSellLegArrival(_activeReport.Source);
            }
        }

        public static bool AbortNow()
        {
            if (_activeReport == null)
            {
                return false;
            }

            _abortRequested = true;
            MapTradeVisibleMovementDriver.Hold();
            Complete("Aborted", "Aborted by command");
            InGameNotice.Blocked("TBG GUILD LOOP: aborted.");
            return true;
        }

        private static bool ContinueFromMarketScan(string source)
        {
            _activeReport.Phase = GuildLoopPhase.MarketScan;
            if (!MarketIntelligenceService.RunScanNow(source))
            {
                AddStep("MarketScan", "Blocked", "market scan failed");
                Complete("Blocked", "market scan failed");
                return false;
            }

            AddStep("MarketScan", "Success", MarketIntelligenceService.Summary?.NearestTown ?? "scan ok");
            _activeReport.Phase = GuildLoopPhase.SelectMission;
            _mission = MapTradeMissionSelector.SelectBestMission();
            _originalMission = _mission;
            _sellTravelMission = null;
            if (_mission.MissionType == MapTradeMissionType.BlockedNoSafeMission)
            {
                AddStep("SelectMission", "Blocked", _mission.BlockReason);
                Complete("Blocked", _mission.BlockReason);
                return false;
            }

            AddStep("SelectMission", "Success", $"{_mission.MissionType} -> {_mission.TargetSettlementName}");

            if (MapTradeMissionSelector.NeedsCohesionCheck(_mission))
            {
                return RunCohesionStep(source);
            }

            return BeginTravel(source);
        }

        private static bool RunCohesionStep(string source)
        {
            _activeReport.Phase = GuildLoopPhase.CohesionCheck;
            var objective = CohesionDoctrine.BuildDefaultObjective();
            if (_mission.TargetSettlement != null)
            {
                objective.TargetSettlementId = _mission.TargetSettlement.StringId;
                objective.TargetSettlementName = _mission.TargetSettlementName;
            }

            var opportunity = CohesionEngine.BuildPlanForObjective(objective);
            _activeReport.CohesionSummary = new GuildLoopCohesionSummary
            {
                RecommendedAction = opportunity?.RecommendedAction.ToString(),
                Score = opportunity?.Score ?? 0f,
                BlockedReason = opportunity?.BlockedReason
            };

            if (opportunity != null
                && opportunity.RecommendedAction.ToString().StartsWith("Blocked", StringComparison.Ordinal))
            {
                AddStep("CohesionCheck", "Blocked", opportunity.BlockedReason);
                Complete("Blocked", opportunity.BlockedReason);
                return false;
            }

            AddStep("CohesionCheck", "Success", opportunity?.RecommendedAction.ToString() ?? "None");
            return BeginTravel(source);
        }

        private static bool BeginTravel(string source)
        {
            _activeReport.Phase = GuildLoopPhase.TravelToTown;
            if (!MapTradeVisibleMovementDriver.TryStartTravel(_mission, out var detail))
            {
                AddStep("TravelToTown", "Blocked", detail);
                Complete("Blocked", detail);
                return false;
            }

            AddStep("TravelToTown", "Started", _mission.TargetSettlementName);
            InGameNotice.Info($"TBG GUILD LOOP MOVE: riding toward {_mission.TargetSettlementName}.");
            WriteReport();
            return true;
        }

        private static void ContinueFromBuyLegArrival(string source)
        {
            AddStep("TravelToTown", "Success", "arrived at buy town");
            _activeReport.Phase = GuildLoopPhase.EnterTown;

            MapTradeVanillaTradeDriver.ProbeTradeApi(out var probeDetail);
            _activeReport.Capabilities.TradeDriver = MapTradeVanillaTradeDriver.LastProbeAvailable;
            _activeReport.Capabilities.TradeDriverMethod = MapTradeVanillaTradeDriver.LastProbeMethod;

            MapTradeVanillaTradeDriver.ProbePackAnimalBuyApi(out var capacityDetail);
            _activeReport.Capabilities.PackAnimalBuy = MapTradeVanillaTradeDriver.LastPackAnimalProbeAvailable;
            _activeReport.Capabilities.PackAnimalBuyDetail = capacityDetail;

            if (DevToolsConfig.GuildLoopProbeWeaponSmeltOnStart)
            {
                var smeltAvailable = MapTradeVanillaTradeDriver.ProbeSmithingSmeltApi(out var smeltDetail);
                _activeReport.Capabilities.WeaponSmelt = smeltAvailable;
                _activeReport.Capabilities.WeaponSmeltDetail = smeltDetail;
            }

            _activeReport.Capabilities.HeadlessCraft = false;

            if (_mission.MissionType != MapTradeMissionType.TravelOnlySafetyCert)
            {
                if (MapTradeVanillaTradeDriver.TryExecuteBuy(_mission, out var buyDetail))
                {
                    _activeReport.TradeExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                    var step = _mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                        ? "TryPackAnimalBuy"
                        : "TryVanillaBuy";
                    AddStep(step, "Success", buyDetail);
                }
                else
                {
                    var step = _mission.MissionType == MapTradeMissionType.BuyPackAnimalForCapacityThenTrade
                        ? "TryPackAnimalBuy"
                        : "TryVanillaBuy";
                    AddStep(step, "Blocked", buyDetail ?? probeDetail ?? "VisibleTradeDriverUnavailable");
                    if (!DevToolsConfig.GuildLoopAllowTravelOnlyIfTradeBlocked)
                    {
                        Complete("Blocked", buyDetail ?? "trade driver unavailable");
                        return;
                    }

                    AddStep("TravelOnlyCert", "Success", "trade blocked; travel-only cert path");
                }
            }

            var current = MobileParty.MainParty?.CurrentSettlement;
            if (DevToolsConfig.GuildLoopAutoTravelToSellTown
                && MapTradeMissionSelector.NeedsSecondLegSellTravel(_originalMission ?? _mission, current))
            {
                BeginSellLegTravel(source);
                return;
            }

            RunSellStep(source);
        }

        private static bool BeginSellLegTravel(string source)
        {
            _sellTravelMission = MapTradeMissionSelector.TryBuildSellLegTravelMission(_originalMission ?? _mission);
            if (_sellTravelMission?.TargetSettlement == null)
            {
                AddStep("TravelToSellTown", "Blocked", "sell leg settlement not resolved");
                RunSellStep(source);
                return false;
            }

            _activeReport.Phase = GuildLoopPhase.TravelToSellTown;
            if (!MapTradeVisibleMovementDriver.TryStartTravel(_sellTravelMission, out var detail))
            {
                AddStep("TravelToSellTown", "Blocked", detail ?? "sell leg travel failed");
                RunSellStep(source);
                return false;
            }

            AddStep("TravelToSellTown", "Started", _sellTravelMission.TargetSettlementName);
            InGameNotice.Info($"TBG GUILD LOOP MOVE: riding toward sell town {_sellTravelMission.TargetSettlementName}.");
            WriteReport();
            return true;
        }

        private static void ContinueFromSellLegArrival(string source)
        {
            AddStep("TravelToSellTown", "Success", "arrived at sell town");
            RunSellStep(source);
        }

        private static void RunSellStep(string source)
        {
            _activeReport.Phase = GuildLoopPhase.TryVanillaSell;

            var missionForSell = _originalMission ?? _mission;
            if (!MapTradeMissionSelector.ShouldAttemptSell(missionForSell, out var sellMission))
            {
                RunForgeHandoff(source);
                return;
            }

            MapTradeVanillaTradeDriver.ProbeTradeApi(out var sellProbeDetail);
            _activeReport.Capabilities.TradeSell = MapTradeVanillaTradeDriver.LastProbeAvailable;
            _activeReport.Capabilities.TradeSellDetail = sellProbeDetail;

            if (MapTradeVanillaTradeDriver.TryExecuteSell(sellMission, out var sellDetail))
            {
                _activeReport.SellExecution = MapTradeVanillaTradeDriver.LastExecutionResult;
                AddStep("TryVanillaSell", "Success", sellDetail);
            }
            else
            {
                AddStep("TryVanillaSell", "Blocked", sellDetail ?? sellProbeDetail ?? "sell driver unavailable");
            }

            RunForgeHandoff(source);
        }

        private static void RunForgeHandoff(string source)
        {
            _activeReport.Phase = GuildLoopPhase.ForgeHandoff;
            _activeReport.ForgeHandoff = new GuildLoopForgeHandoffBlock
            {
                BeforeCharcoal = SmithingAdvisoryPlanner.BuildReserveHealth().CharcoalHave,
                BeforeHardwood = SmithingAdvisoryPlanner.BuildReserveHealth().HardwoodHave
            };

            if (DevToolsConfig.GuildLoopAutoRunForgeHandoff
                && SmithingSmeltService.TrySmeltOneLootWeaponNow(source))
            {
                var smelt = SmithingSmeltService.LastExecutionResult;
                _activeReport.ForgeHandoff.Result = "RunWeaponSmeltNow";
                AddStep("TryWeaponSmelt", "Success", smelt?.WeaponName ?? "smelt ok");
            }
            else if (!string.IsNullOrWhiteSpace(SmithingSmeltService.LastBlockedReason))
            {
                AddStep(
                    "TryWeaponSmelt",
                    SmithingSmeltService.LastBlockedReason.IndexOf("no smeltable", StringComparison.OrdinalIgnoreCase) >= 0
                        ? "Blocked"
                        : "Blocked",
                    SmithingSmeltService.LastBlockedReason);
            }

            if (DevToolsConfig.GuildLoopAutoRunForgeHandoff
                && BlacksmithAutomationService.RunAutomationNow(source))
            {
                var after = SmithingAdvisoryPlanner.BuildReserveHealth();
                _activeReport.ForgeHandoff.AfterCharcoal = after.CharcoalHave;
                _activeReport.ForgeHandoff.AfterHardwood = after.HardwoodHave;
                _activeReport.ForgeHandoff.Result = "RunBlacksmithAutomationNow";
                AddStep("ForgeHandoff", "Success", _activeReport.ForgeHandoff.Result);
            }
            else
            {
                _activeReport.ForgeHandoff.Result = BlacksmithAutomationService.LastBlockedReason ?? "skipped";
                AddStep("ForgeHandoff", "Blocked", _activeReport.ForgeHandoff.Result);
            }

            TryContinueMultiCycle(source);
        }

        private static void TryContinueMultiCycle(string source)
        {
            _activeReport.CyclesCompleted++;

            if (_activeReport.CyclesCompleted < _activeReport.MaxCycles)
            {
                _activeReport.CycleIndex++;
                AddStep(
                    "CycleBoundary",
                    "Success",
                    $"cycle {_activeReport.CyclesCompleted} of {_activeReport.MaxCycles} complete — starting next");
                _activeReport.Phase = GuildLoopPhase.MarketScan;
                _activeReport.TradeExecution = null;
                _activeReport.SellExecution = null;
                _activeReport.ForgeHandoff = null;
                _activeReport.CohesionSummary = null;
                _mission = null;
                _originalMission = null;
                _sellTravelMission = null;
                WriteReport();
                InGameNotice.Info($"TBG GUILD LOOP: starting cycle {_activeReport.CycleIndex + 1} of {_activeReport.MaxCycles}.");
                ContinueFromMarketScan(source);
                return;
            }

            Complete("Complete", null);
        }

        private static GuildLoopCapabilities ProbeCapabilities()
        {
            return new GuildLoopCapabilities
            {
                TradeDriver = false,
                WeaponSmelt = false,
                PackAnimalBuy = false,
                HeadlessCraft = false
            };
        }

        private static void Complete(string verdict, string reason)
        {
            if (_activeReport == null)
            {
                return;
            }

            _activeReport.Verdict = verdict;
            _activeReport.BlockedReason = reason;
            _activeReport.NextRecommendedCommand =
                verdict == "Complete" ? RunAutonomousGuildLoopNowCommand : "manual trade or RunAutonomousVisibleTradeRouteNow";
            _activeReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            WriteReport();

            if (verdict == "Complete")
            {
                InGameNotice.Success("TBG GUILD LOOP DONE: bounded cycle complete.");
            }
            else
            {
                InGameNotice.Blocked($"TBG GUILD LOOP {verdict}: {reason}");
            }

            _activeReport = null;
            _mission = null;
            _originalMission = null;
            _sellTravelMission = null;
        }

        private static void WriteTerminal(string source, string verdict, string reason)
        {
            _activeReport = new GuildLoopRunReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Verdict = verdict,
                BlockedReason = reason,
                Capabilities = ProbeCapabilities()
            };
            WriteReport();
            _activeReport = null;
        }

        private static void AddStep(string phase, string result, string detail)
        {
            _activeReport.CycleSteps.Add(new GuildLoopCycleStep
            {
                Phase = phase,
                Result = result,
                Detail = detail
            });
        }

        private static void WriteReport()
        {
            File.WriteAllText(ReportPath, SerializeReport(_activeReport), Encoding.UTF8);
            MirrorEvidence();
        }

        private static string SerializeReport(GuildLoopRunReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"phase\": \"{report.Phase}\",");
            sb.AppendLine($"  \"verdict\": {NullableString(report.Verdict)},");
            sb.AppendLine($"  \"blockedReason\": {NullableString(report.BlockedReason)},");
            sb.AppendLine($"  \"nextRecommendedCommand\": {NullableString(report.NextRecommendedCommand)},");
            sb.AppendLine($"  \"cycleIndex\": {report.CycleIndex},");
            sb.AppendLine($"  \"cyclesCompleted\": {report.CyclesCompleted},");
            sb.AppendLine($"  \"maxCycles\": {report.MaxCycles},");
            sb.AppendLine("  \"capabilities\": {");
            sb.AppendLine($"    \"tradeDriver\": {(report.Capabilities.TradeDriver ? "true" : "false")},");
            sb.AppendLine($"    \"tradeDriverMethod\": {NullableString(report.Capabilities.TradeDriverMethod)},");
            sb.AppendLine($"    \"tradeSell\": {(report.Capabilities.TradeSell ? "true" : "false")},");
            sb.AppendLine($"    \"tradeSellDetail\": {NullableString(report.Capabilities.TradeSellDetail)},");
            sb.AppendLine($"    \"weaponSmelt\": {(report.Capabilities.WeaponSmelt ? "true" : "false")},");
            sb.AppendLine($"    \"weaponSmeltDetail\": {NullableString(report.Capabilities.WeaponSmeltDetail)},");
            sb.AppendLine($"    \"packAnimalBuy\": {(report.Capabilities.PackAnimalBuy ? "true" : "false")},");
            sb.AppendLine($"    \"packAnimalBuyDetail\": {NullableString(report.Capabilities.PackAnimalBuyDetail)},");
            sb.AppendLine($"    \"headlessCraft\": {(report.Capabilities.HeadlessCraft ? "true" : "false")}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"forgeHandoff\": {");
            sb.AppendLine($"    \"beforeCharcoal\": {report.ForgeHandoff?.BeforeCharcoal ?? 0},");
            sb.AppendLine($"    \"afterCharcoal\": {report.ForgeHandoff?.AfterCharcoal ?? 0},");
            sb.AppendLine($"    \"beforeHardwood\": {report.ForgeHandoff?.BeforeHardwood ?? 0},");
            sb.AppendLine($"    \"afterHardwood\": {report.ForgeHandoff?.AfterHardwood ?? 0},");
            sb.AppendLine($"    \"result\": {NullableString(report.ForgeHandoff?.Result)}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"cohesionSummary\": {");
            sb.AppendLine($"    \"recommendedAction\": {NullableString(report.CohesionSummary?.RecommendedAction)},");
            sb.AppendLine($"    \"score\": {(report.CohesionSummary?.Score ?? 0f):0.##},");
            sb.AppendLine($"    \"blockedReason\": {NullableString(report.CohesionSummary?.BlockedReason)}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"tradeExecution\": ");
            AppendTradeExecution(sb, report.TradeExecution, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"sellExecution\": ");
            AppendTradeExecution(sb, report.SellExecution, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"cycleSteps\": [");
            for (var i = 0; i < report.CycleSteps.Count; i++)
            {
                var step = report.CycleSteps[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"phase\": \"{Escape(step.Phase)}\",");
                sb.AppendLine($"      \"result\": \"{Escape(step.Result)}\",");
                sb.AppendLine($"      \"detail\": \"{Escape(step.Detail)}\"");
                sb.Append(i < report.CycleSteps.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void MirrorEvidence()
        {
            try
            {
                var repoRoot = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", ".."));
                var mirrorDir = Path.Combine(repoRoot, "docs", "evidence", "latest");
                if (!Directory.Exists(mirrorDir))
                {
                    return;
                }

                File.Copy(ReportPath, Path.Combine(mirrorDir, ReportFileName), overwrite: true);
            }
            catch
            {
            }
        }

        private static void PauseIfVisible(string label)
        {
            if (!DevToolsConfig.MapTradeVisibleMode || DevToolsConfig.MapTradeDecisionPauseMs <= 0)
            {
                return;
            }

            InGameNotice.Info($"TBG GUILD LOOP: {label}...");
            Thread.Sleep(DevToolsConfig.MapTradeDecisionPauseMs);
        }

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static void AppendTradeExecution(StringBuilder sb, MapTradeExecutionResult execution, string indent)
        {
            if (execution == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"goldBefore\": {execution.GoldBefore},");
            sb.AppendLine($"{indent}  \"goldAfter\": {execution.GoldAfter},");
            sb.AppendLine($"{indent}  \"goldDelta\": {execution.GoldDelta},");
            sb.AppendLine($"{indent}  \"itemId\": {NullableString(execution.ItemId)},");
            sb.AppendLine($"{indent}  \"itemName\": {NullableString(execution.ItemName)},");
            sb.AppendLine($"{indent}  \"quantityBought\": {execution.QuantityBought},");
            sb.AppendLine($"{indent}  \"quantitySold\": {execution.QuantitySold},");
            sb.AppendLine($"{indent}  \"inventoryBefore\": {execution.InventoryBefore},");
            sb.AppendLine($"{indent}  \"inventoryAfter\": {execution.InventoryAfter},");
            sb.AppendLine($"{indent}  \"executionMethod\": {NullableString(execution.ExecutionMethod)}");
            sb.Append($"{indent}}}");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }

    public enum GuildLoopPhase
    {
        Preflight,
        MarketScan,
        SelectMission,
        CohesionCheck,
        TravelToTown,
        TravelToSellTown,
        EnterTown,
        TryVanillaBuy,
        TryVanillaSell,
        TravelOnlyCert,
        ForgeHandoff,
        Complete
    }

    public sealed class GuildLoopRunReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public GuildLoopPhase Phase { get; set; }
        public string Verdict { get; set; }
        public string BlockedReason { get; set; }
        public string NextRecommendedCommand { get; set; }
        public GuildLoopCapabilities Capabilities { get; set; } = new GuildLoopCapabilities();
        public GuildLoopForgeHandoffBlock ForgeHandoff { get; set; }
        public GuildLoopCohesionSummary CohesionSummary { get; set; }
        public MapTradeExecutionResult TradeExecution { get; set; }
        public MapTradeExecutionResult SellExecution { get; set; }
        public int CycleIndex { get; set; }
        public int CyclesCompleted { get; set; }
        public int MaxCycles { get; set; } = 1;
        public List<GuildLoopCycleStep> CycleSteps { get; set; } = new List<GuildLoopCycleStep>();
    }

    public sealed class GuildLoopCycleStep
    {
        public string Phase { get; set; }
        public string Result { get; set; }
        public string Detail { get; set; }
    }

    public sealed class GuildLoopCapabilities
    {
        public bool TradeDriver { get; set; }
        public string TradeDriverMethod { get; set; }
        public bool WeaponSmelt { get; set; }
        public string WeaponSmeltDetail { get; set; }
        public bool PackAnimalBuy { get; set; }
        public string PackAnimalBuyDetail { get; set; }
        public bool TradeSell { get; set; }
        public string TradeSellDetail { get; set; }
        public bool HeadlessCraft { get; set; }
    }

    public sealed class GuildLoopForgeHandoffBlock
    {
        public int BeforeCharcoal { get; set; }
        public int AfterCharcoal { get; set; }
        public int BeforeHardwood { get; set; }
        public int AfterHardwood { get; set; }
        public string Result { get; set; }
    }

    public sealed class GuildLoopCohesionSummary
    {
        public string RecommendedAction { get; set; }
        public float Score { get; set; }
        public string BlockedReason { get; set; }
    }
}
