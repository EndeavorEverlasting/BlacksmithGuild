using System;
using BlacksmithGuild.Market;

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

            if (MarketIntelligenceService.RunScanNow("governor:" + request.ActivityId))
            {
                var completed = CampaignActivityDispatcher.CompletedReadOnly(
                    request,
                    detail + "; read-only market scan completed");
                completed.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(
                    request,
                    "Fresh read-only market evidence is available for the next governor priority cycle."));
                return completed;
            }

            var blocked = CampaignActivityDispatcher.Blocked(
                request,
                detail + "; read-only market scan failed",
                "market_scan_failed");
            blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(
                request,
                "Market evidence was not refreshed; later trade mutation remains blocked."));
            return blocked;
        }
    }
}
