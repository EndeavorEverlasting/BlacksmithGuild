using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class SmithingActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.Smithing.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "PrepareOrExecuteSafeSmithing", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "smithing activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " requiresVisibleSurface=" + request.RequiresVisibleSurface
                + " requiresInventoryDelta=" + request.RequiresInventoryDelta
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; smithing action step must route through the known safe service", "smithing_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Smithing(request, "Prepare smithing work only through the known safe service and require material/stamina evidence."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; smithing proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Smithing(request, "Use the smithing narrative to identify missing stamina, material, or smithy surface evidence."));
            return deferred;
        }
    }
}
