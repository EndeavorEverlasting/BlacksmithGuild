using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.InputSystem;

namespace BlacksmithGuild.Behaviors
{
    public sealed class BlacksmithGuildCampaignBehavior : CampaignBehaviorBase
    {
        private bool _hasRunGoldTest;

        public override void RegisterEvents()
        {
            CampaignEvents.DailyTickEvent.AddNonSerializedListener(this, OnDailyTick);
            CampaignEvents.TickEvent.AddNonSerializedListener(this, OnCampaignTick);
        }

        private void OnDailyTick()
        {
            if (!DevToolsConfig.AutoRunGoldTestOnDailyTick || _hasRunGoldTest || Hero.MainHero == null)
            {
                return;
            }

            _hasRunGoldTest = true;
            TestScenarioRunner.Run(EconomyTestScenarios.RichPlayerEconomyTestName);
        }

        private void OnCampaignTick(float dt)
        {
            if (!DevToolsConfig.DevToolsEnabled || Campaign.Current == null)
            {
                return;
            }

            if (!IsCtrlAltDown())
            {
                return;
            }

            if (Input.IsKeyPressed(InputKey.D))
            {
                DevCommandRunner.Run(DevCommandRegistry.AdvanceOneDayCommand);
            }
            else if (Input.IsKeyPressed(InputKey.F))
            {
                DevCommandRunner.Run(DevCommandRegistry.ToggleFastForwardCommand);
            }
            else if (Input.IsKeyPressed(InputKey.L))
            {
                DevCommandRunner.Run(DevCommandRegistry.ListScenariosCommand);
            }
        }

        private static bool IsCtrlAltDown()
        {
            bool ctrl =
                Input.IsKeyDown(InputKey.LeftControl) || Input.IsKeyDown(InputKey.RightControl);
            bool alt = Input.IsKeyDown(InputKey.LeftAlt) || Input.IsKeyDown(InputKey.RightAlt);
            return ctrl && alt;
        }

        public override void SyncData(IDataStore dataStore)
        {
        }
    }
}
