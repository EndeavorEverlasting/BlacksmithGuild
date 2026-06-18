using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
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

            if (!GameReadinessService.IsMainHeroReady)
            {
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
