using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
        private bool _hasRunGoldTest;

        public override void RegisterEvents()
        {
            CampaignEvents.DailyTickEvent.AddNonSerializedListener(this, OnDailyTick);
        }

        private void OnDailyTick()
        {
            if (_hasRunGoldTest || Hero.MainHero == null)
            {
                return;
            }

            _hasRunGoldTest = true;
            TestScenarioRunner.Run(EconomyTestScenarios.RichPlayerEconomyTestName);
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
