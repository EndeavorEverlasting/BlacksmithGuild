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

            if (request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Blocked(request, detail + "; horse-market action path is not proven by this adapter yet", "horse_market_action_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; horse-market proposal recorded only");
        }
    }
}
