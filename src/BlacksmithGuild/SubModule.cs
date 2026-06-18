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

        private float _inboxPollAccumulator;

        protected override void OnSubModuleLoad()
        {
            base.OnSubModuleLoad();
            ForgeStatus.SetModLoaded(true);
            ForgeStatus.SetStep("module_load", "PASS");
            PendingReloadWatcher.OnModuleLoad();
            GuildLog.Info("module loaded.", showInGame: false);
        }

        protected override void OnApplicationTick(float dt)
        {
            base.OnApplicationTick(dt);

            PendingReloadWatcher.Poll(dt);

            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            _inboxPollAccumulator += dt;
            if (_inboxPollAccumulator < 0.5f)
            {
                return;
            }

            _inboxPollAccumulator = 0f;
            DevCommandFileInbox.Poll();
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
