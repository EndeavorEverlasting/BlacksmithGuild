using System;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class TradeActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            return request != null
                && (string.Equals(request.TargetEngine, CampaignActivityEngine.Trade.ToString(), StringComparison.OrdinalIgnoreCase)
                    || string.Equals(request.Operation, "EvaluateOrExecuteTradeRoute", StringComparison.OrdinalIgnoreCase));
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var detail = "trade activity: operation=" + request.Operation
                + " currentTown=" + request.CurrentTown
                + " targetTown=" + request.TargetTown
                + " requiresInventoryDelta=" + request.RequiresInventoryDelta
                + " requiresGoldDelta=" + request.RequiresGoldDelta
                + " expectedProof=" + request.ExpectedProof;

            if (request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Blocked(request, detail + "; trade execution path must be proven before mutation", "trade_execution_not_implemented");
            }

            return CampaignActivityDispatcher.Deferred(request, detail + "; trade proposal recorded only");
        }
    }
}
