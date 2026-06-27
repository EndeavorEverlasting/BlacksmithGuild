using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class DeferredActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null && !IsFood(request);
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "activity deferred: targetEngine=" + request.TargetEngine
                + " operation=" + request.Operation
                + " branch=" + request.Branch
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Blocked(
                    request,
                    detail + "; no proven adapter exists for this engine yet",
                    "engine_adapter_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(
                request,
                detail + "; proposal recorded only");
        }

        private static bool IsFood(CampaignActivityRequest request)
        {
            return string.Equals(request.TargetEngine, CampaignActivityEngine.Food.ToString(), StringComparison.OrdinalIgnoreCase)
                || string.Equals(request.Operation, "AcquireFoodBeforeRunwayBreach", StringComparison.OrdinalIgnoreCase);
        }
    }
}
