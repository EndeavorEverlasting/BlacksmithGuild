using BlacksmithGuild.CampaignRuntime;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Treasury;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
        private bool _hasRunGoldTest;
        private bool _loggedGoldTestBlock;
        private string _lastDriverBlockKey;

        internal static void ResetCampaignMapReadyAnnouncement()
        {
            CampaignMapReadyOrchestrator.ResetForNewCampaign();
        }

        public override void RegisterEvents()
        {
            CampaignEvents.DailyTickEvent.AddNonSerializedListener(this, OnDailyTick);
            CampaignEvents.TickEvent.AddNonSerializedListener(this, OnCampaignTick);
        }

        private void OnDailyTick()
        {
            GameReadinessService.RunPreflightWhenReady();
            TreasuryDeltaWatchService.OnDailyTick();

            if (!DevToolsConfig.AutoRunGoldTestOnDailyTick || _hasRunGoldTest)
            {
                return;
            }

            GameSessionState.Refresh();

            if (!GameSessionState.IsCampaignMapReady)
            {
                if (!_loggedGoldTestBlock)
                {
                    _loggedGoldTestBlock = true;
                    DebugLogger.Test(
                        $"DailyTick gold test blocked: campaign map not ready ({GameSessionState.GetCampaignMapBlockDetail()})",
                        showInGame: false
                    );
                }

                return;
            }

            if (GameReadinessService.Verdict == PreflightVerdict.Fail)
            {
                if (!_loggedGoldTestBlock)
                {
                    _loggedGoldTestBlock = true;
                    var reason = GameReadinessService.BlockReason;
                    DebugLogger.Test(
                        $"DailyTick gold test blocked because preflight failed: {reason}",
                        showInGame: false
                    );
                    ForgeStatus.SetTest(EconomyTestScenarios.RichPlayerEconomyTestName, "BLOCKED", reason);
                }

                return;
            }

            _hasRunGoldTest = true;
            DevCommandBus.TryRun(EconomyTestScenarios.RichPlayerEconomyTestName, "daily-tick-auto");
        }

        private void OnCampaignTick(float dt)
        {
            if (!DevToolsConfig.DevToolsEnabled || Campaign.Current == null)
            {
                return;
            }

            var tickCostStartedAt = TickCostProfiler.Start();
            GameSessionState.Refresh();
            TickCostProfiler.Stop("GameSessionState.Refresh", tickCostStartedAt);

            if (!GameSessionState.IsMainHeroReady)
            {
                return;
            }

            if (!GameSessionState.IsCampaignSessionReady)
            {
                return;
            }

            tickCostStartedAt = TickCostProfiler.Start();
            CampaignMapReadyOrchestrator.OnCampaignTick(dt);
            TickCostProfiler.Stop("CampaignMapReadyOrchestrator.OnCampaignTick", tickCostStartedAt);

            if (!CampaignMapReadyOrchestrator.ImmediateHooksCompleted)
            {
                return;
            }

            tickCostStartedAt = TickCostProfiler.Start();
            var autonomousDriversBlocked = LaunchPathInference.AreAutonomousDriversBlocked(
                CampaignMapReadyOrchestrator.ImmediateHooksCompleted,
                CampaignMapReadyOrchestrator.IsPostMapReadyStabilizationWindow);
            TickCostProfiler.Stop("LaunchPathInference.AreAutonomousDriversBlocked", tickCostStartedAt);

            if (autonomousDriversBlocked)
            {
                LogDriverBlockedOnce();
                return;
            }

            RuntimeTrace.Run("CampaignTick", "AutonomousDrivers", () =>
            {
                var segmentStartedAt = TickCostProfiler.Start();
                CampaignRuntimeGovernor.OnCampaignTick();
                TickCostProfiler.Stop("CampaignRuntimeGovernor.OnCampaignTick", segmentStartedAt);

                segmentStartedAt = TickCostProfiler.Start();
                TreasuryDeltaWatchService.ProcessPendingSnapshot();
                TickCostProfiler.Stop("TreasuryDeltaWatchService.ProcessPendingSnapshot", segmentStartedAt);

                segmentStartedAt = TickCostProfiler.Start();
                AutoTravelService.OnCampaignTick();
                TickCostProfiler.Stop("AutoTravelService.OnCampaignTick", segmentStartedAt);

                segmentStartedAt = TickCostProfiler.Start();
                CohesionExecutionDriver.OnCampaignTick();
                TickCostProfiler.Stop("CohesionExecutionDriver.OnCampaignTick", segmentStartedAt);

                segmentStartedAt = TickCostProfiler.Start();
                MapTradeAutonomousService.OnCampaignTick();
                TickCostProfiler.Stop("MapTradeAutonomousService.OnCampaignTick", segmentStartedAt);

                segmentStartedAt = TickCostProfiler.Start();
                AutonomousGuildLoopService.OnCampaignTick();
                TickCostProfiler.Stop("AutonomousGuildLoopService.OnCampaignTick", segmentStartedAt);
            });
        }

        private void LogDriverBlockedOnce()
        {
            var key =
                $"{LaunchPathInference.GetPathLabel()}|{CampaignSetupStateTracker.Phase}|stabilization={CampaignMapReadyOrchestrator.IsPostMapReadyStabilizationWindow}";
            if (string.Equals(_lastDriverBlockKey, key, System.StringComparison.Ordinal))
            {
                return;
            }

            _lastDriverBlockKey = key;
            DebugLogger.Test(
                $"[TBG TRACE] area=CampaignTick op=AutonomousDrivers stage=blocked path={LaunchPathInference.GetPathLabel()} phase={CampaignSetupStateTracker.Phase}",
                showInGame: false);
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
