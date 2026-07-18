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
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; travel action step is pending implementation", "travel_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Travel(request, "Prepare travel only after destination, visible map surface, and stop-condition evidence are present."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; travel proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Travel(request, "Use the travel narrative to compare destination context and missing surface evidence."));
            return deferred;
        }
    }
}
