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
            ForgeStatus.SetModLoaded(true);
            ForgeStatus.SetStep("module_load", "PASS");
            GuildLog.Info("module loaded.", showInGame: false);
        }

        protected override void OnGameStart(Game game, IGameStarter gameStarterObject)
        {
            base.OnGameStart(game, gameStarterObject);

            if (game.GameType is Campaign)
            {
                try
                {
                    var campaignStarter = (CampaignGameStarter)gameStarterObject;
                    campaignStarter.AddBehavior(new BlacksmithGuildCampaignBehavior());

                    GuildLog.Display(ForgeLitMessage);
                    ForgeStatus.SetTest("forge_lit", "PASS");
                    ForgeAdvisorSmokeTest.Run();
                }
                catch (System.Exception ex)
                {
                    ForgeStatus.RecordError($"Campaign start failed: {ex.Message}");
                    GuildLog.Info($"[TBG ERROR] Campaign start failed: {ex.Message}", showInGame: false);
                }
            }
        }
    }
}
