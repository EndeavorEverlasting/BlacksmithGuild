using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class TravelActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.MapTravel.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "TravelToBestKnownOpportunity", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "travel activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " targetTown=" + request.TargetTown
                + " requiresVisibleSurface=" + request.RequiresVisibleSurface
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Blocked(request, detail + "; travel execution must route through proven visible travel driver", "travel_execution_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; travel proposal recorded only");
        }
    }
}
