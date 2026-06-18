using BlacksmithGuild.Behaviors;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.MountAndBlade;

namespace BlacksmithGuild
{
    public sealed class SubModule : MBSubModuleBase
    {
        private const string ForgeLitMessage =
            "[The Blacksmith Guild] Mod loaded. The forge is lit.";

        protected override void OnSubModuleLoad()
        {
            base.OnSubModuleLoad();
            GuildLog.Info("module loaded.");
        }

        protected override void OnGameStart(Game game, IGameStarter gameStarterObject)
        {
            base.OnGameStart(game, gameStarterObject);

            if (game.GameType is Campaign)
            {
                var campaignStarter = (CampaignGameStarter)gameStarterObject;
                campaignStarter.AddBehavior(new BlacksmithGuildCampaignBehavior());

                GameDataPreflight.RunOnce();

                GuildLog.Display(ForgeLitMessage);
                ForgeAdvisorSmokeTest.Run();
            }
        }
    }
}
