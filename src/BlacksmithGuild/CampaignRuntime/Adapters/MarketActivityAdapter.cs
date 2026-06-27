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
                return CampaignActivityDispatcher.Blocked(request, detail + "; market execution path not proven by this adapter yet", "market_execution_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; market scan proposal recorded only");
        }
    }
}
