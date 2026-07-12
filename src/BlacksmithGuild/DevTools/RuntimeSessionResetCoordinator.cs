using BlacksmithGuild.Cohesion;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.HorseMarket;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// One campaign-generation boundary for every long-lived worker. No cache, abort latch,
    /// route key, movement sample, or authority mode may leak into a different save.
    /// </summary>
    public static class RuntimeSessionResetCoordinator
    {
        public static void ResetForNewCampaign()
        {
            RuntimeProofContext.ResetForNewCampaign();
            RuntimeCadenceGate.ResetAll();
            MapTradeAutonomousService.ResetForNewCampaign();
            AutonomousGuildLoopService.ResetForNewCampaign();
            AutoTravelService.ResetForNewCampaign();
            CohesionExecutionDriver.ResetForNewCampaign();
            CohesionEngine.ResetForNewCampaign();
            CampaignThreatSnapshotProvider.ResetForNewCampaign();
            MarketIntelligenceService.ResetForNewCampaign();
            HorseMarketAtlasService.ResetForNewCampaign();
            HerdLedgerService.ResetForNewCampaign();
            EngineToggleAuthority.ResetForNewCampaign();
        }
    }
}
