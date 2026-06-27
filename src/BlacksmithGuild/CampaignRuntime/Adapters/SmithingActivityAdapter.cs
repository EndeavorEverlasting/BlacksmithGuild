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
                return CampaignActivityDispatcher.Blocked(request, detail + "; smithing execution must route through proven safe-action service", "smithing_execution_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; smithing proposal recorded only");
        }
    }
}
