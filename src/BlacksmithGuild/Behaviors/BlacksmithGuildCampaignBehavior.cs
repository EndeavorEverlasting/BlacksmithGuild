using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Treasury;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
        private static bool _hasAnnouncedCampaignMapReady;
        private bool _hasRunGoldTest;
        private bool _loggedGoldTestBlock;

        internal static void ResetCampaignMapReadyAnnouncement()
        {
            _hasAnnouncedCampaignMapReady = false;
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

            TreasuryDeltaWatchService.ProcessPendingSnapshot();
            AutoTravelService.OnCampaignTick();

            if (!_hasAnnouncedCampaignMapReady && GameSessionState.IsCampaignMapReady)
            {
                _hasAnnouncedCampaignMapReady = true;
                CampaignSetupStateTracker.NotifyCampaignMapReady();
                InGameNotice.Ready("campaign map ready. Press F8 for commands.");
                InGameNotice.Info(ModDisplay.CompactLine("Market", "Press Ctrl+Alt+M for market intel."));
                DebugLogger.Test("Campaign map ready; dev hotkeys are now meaningful.", showInGame: false);
                HotkeyTraceService.OnMapReady();
                TreasuryDeltaWatchService.OnCampaignMapReady();
                AutoCharacterBuildService.OnCampaignMapReady();
                CommandSurfaceService.WriteCommandSurface("MapReady");
            }
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
