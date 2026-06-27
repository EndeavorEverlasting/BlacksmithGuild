using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class CompanionActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.Companion.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "EvaluateTavernRecruitment", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "companion activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " requiresVisibleSurface=" + request.RequiresVisibleSurface
                + " requiresGoldDelta=" + request.RequiresGoldDelta
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Blocked(request, detail + "; companion action path must be proven before mutation", "companion_execution_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; companion proposal recorded only");
        }
    }
}
