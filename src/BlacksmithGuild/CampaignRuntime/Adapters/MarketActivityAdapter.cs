using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class MarketActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.Market.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "RefreshMarketScan", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "market activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " requiresFreshMarketScan=" + request.RequiresFreshMarketScan
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; market action step is pending implementation", "market_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(request, "Prepare a read-only market scan and keep later market steps pending until scan output is available."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; market scan proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(request, "Use the market narrative to decide whether a read-only scan should be scheduled."));
            return deferred;
        }
    }
}
