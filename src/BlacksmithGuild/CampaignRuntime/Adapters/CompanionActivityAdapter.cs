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
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; companion action step is pending implementation", "companion_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Companion(request, "Prepare tavern recruitment evaluation only after candidate, cost, and roster evidence are present."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; companion proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Companion(request, "Use the companion narrative to identify missing candidate, cost, or roster evidence."));
            return deferred;
        }
    }
}
