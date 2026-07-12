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

            if (request.MutationAuthorized)
            {
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; market action step is pending implementation", "market_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(request, "Prepare a read-only market scan and keep later market steps pending until scan output is available."));
                return blocked;
            }

            if (!MarketIntelligenceService.EnsureFreshScan("governor_activity:" + request.ActivityId))
            {
                var blocked = CampaignActivityDispatcher.Blocked(
                    request,
                    detail + "; read-only market scan or its evidence persistence failed",
                    "market_scan_failed");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(request, "The Governor requested a fresh read-only scan, but current machine evidence was not persisted."));
                return blocked;
            }

            var completed = CampaignActivityDispatcher.CompletedReadOnly(
                request,
                detail + "; fresh read-only market evidence is available");
            completed.NarrativeDetails.Add(CampaignActivityEngineNarratives.Market(request, "The market worker refreshed or reused a valid bounded cache and handed current evidence back to the Governor."));
            return completed;
        }
    }
}
