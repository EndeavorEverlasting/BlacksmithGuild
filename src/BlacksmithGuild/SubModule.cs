using BlacksmithGuild.Behaviors;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
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
            DevToolsConfig.TryLoadMapReadyBisectFromEnvironment();
            PendingReloadWatcher.OnModuleLoad();
            CharacterBuildVariantConfigService.TryLoadAtStartup();
            AgentIterationConfigService.TryLoadAtStartup();
            HotkeyTraceService.LogVersionAtStartup();
            AutoCharacterCreationPatches.TryApply();
            ModuleMismatchAutoConfirmService.TryApply();
            GuildLog.Info("module loaded.", showInGame: false);
        }

        protected override void OnBeforeInitialModuleScreenSetAsRoot()
        {
            base.OnBeforeInitialModuleScreenSetAsRoot();
            AutoCharacterCreationPatches.TryApply();
            ModuleMismatchAutoConfirmService.TryApply();
        }

        protected override void OnApplicationTick(float dt)
        {
            base.OnApplicationTick(dt);

            PendingReloadWatcher.Poll(dt);
            CampaignSetupStateTracker.Poll(dt);

            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            if (IsCampaignActive())
            {
                GameSessionState.Refresh();
                if ((GameSessionState.IsCampaignMapReady || GameSessionState.IsSettlementInteriorReady)
                    && !CampaignSetupStateTracker.IsMapLoadTransitionWindow
                    && (CampaignMapReadyOrchestrator.ImmediateHooksCompleted
                        || CampaignSetupStateTracker.ForwardLaunchCompletedThisProcess))
                {
                    DevHotkeyHandler.Poll();
                }
            }

            _inboxPollAccumulator += dt;
            if (_inboxPollAccumulator < 0.5f)
            {
                return;
            }

            _inboxPollAccumulator = 0f;
            DevCommandFileInbox.Poll();
        }

        private static bool IsCampaignActive()
        {
            try
            {
                return Campaign.Current != null;
            }
            catch
            {
                return false;
            }
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
