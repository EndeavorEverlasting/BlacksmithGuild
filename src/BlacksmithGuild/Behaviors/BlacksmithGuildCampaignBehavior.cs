using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
        private static bool _hasAnnouncedCampaignMapReady;
        private bool _hasRunGoldTest;
        private bool _loggedGoldTestBlock;

        public override void RegisterEvents()
        {
            CampaignEvents.DailyTickEvent.AddNonSerializedListener(this, OnDailyTick);
            CampaignEvents.TickEvent.AddNonSerializedListener(this, OnCampaignTick);
        }

        private void OnDailyTick()
        {
            GameReadinessService.RunPreflightWhenReady();

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

            if (!_hasAnnouncedCampaignMapReady && GameSessionState.IsCampaignMapReady)
            {
                _hasAnnouncedCampaignMapReady = true;
                InGameNotice.Ready("campaign map ready. Press F8 for commands.");
                DebugLogger.Test("Campaign map ready; dev hotkeys are now meaningful.", showInGame: false);
            }

            if (GameSessionState.CanPollHotkeys)
            {
                DevHotkeyHandler.Poll();
            }
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
