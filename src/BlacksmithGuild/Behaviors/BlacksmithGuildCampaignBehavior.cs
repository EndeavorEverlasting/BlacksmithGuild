using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.QuickStart;
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

            GameSessionState.Refresh();

            if (!GameSessionState.IsMainHeroReady)
            {
                return;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                return;
            }

            CampaignMapReadyOrchestrator.OnCampaignTick(dt);

            if (!CampaignMapReadyOrchestrator.ImmediateHooksCompleted)
            {
                return;
            }

            if (CampaignMapReadyOrchestrator.IsPostMapReadyStabilizationWindow
                || CampaignSetupStateTracker.IsMapLoadTransitionWindow)
            {
                return;
            }

            TreasuryDeltaWatchService.ProcessPendingSnapshot();
            AutoTravelService.OnCampaignTick();
            CohesionExecutionDriver.OnCampaignTick();
            MapTradeAutonomousService.OnCampaignTick();
            AutonomousGuildLoopService.OnCampaignTick();
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
