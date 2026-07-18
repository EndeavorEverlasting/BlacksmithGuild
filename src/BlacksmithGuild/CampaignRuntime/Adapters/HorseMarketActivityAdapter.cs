using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class HorseMarketActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.HorseMarket.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "AcquirePackAnimalForCapacity", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "horse-market activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " targetTown=" + request.TargetTown
                + " requiresFreshMarketScan=" + request.RequiresFreshMarketScan
                + " requiresInventoryDelta=" + request.RequiresInventoryDelta
                + " requiresGoldDelta=" + request.RequiresGoldDelta
                + " expectedProof=" + request.ExpectedProof;

            if (string.Equals(request.Operation, "RefreshHorseAtlas", StringComparison.OrdinalIgnoreCase))
            {
                var refresh = CampaignActivityDispatcher.Deferred(request, detail + "; nextAction=ScanHorseAtlas; localVerificationRequiredBeforeBuySell=true");
                refresh.NarrativeDetails.Add(CampaignActivityEngineNarratives.HorseMarket(request, "ScanHorseAtlas before any horse buy/sell."));
                return refresh;
            }

            if (string.Equals(request.Operation, "AnalyzeHerdLedger", StringComparison.OrdinalIgnoreCase))
            {
                var analyze = CampaignActivityDispatcher.Deferred(request, detail + "; nextAction=AnalyzeHerdLedger; mutationBlockedUntilLedgerFresh=true");
                analyze.NarrativeDetails.Add(CampaignActivityEngineNarratives.HorseMarket(request, "AnalyzeHerdLedger before any horse buy/sell."));
                return analyze;
            }

            if (request.MutationAuthorized)
            {
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; horse-market action step is pending implementation", "horse_market_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.HorseMarket(request, "Prepare pack-animal evaluation only after market evidence, cost evidence, and capacity need are present."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; horse-market proposal recorded only; nextAction=" + (request.BlockedReason ?? "LocalVerifyHorseMarketBeforeBuySell"));
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.HorseMarket(request, "Local verification required before buy/sell; use the horse-market narrative to identify missing pack-animal and market evidence."));
            return deferred;
        }
    }
}
