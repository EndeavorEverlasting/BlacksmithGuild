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
                var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; trade action step is pending implementation", "trade_action_pending");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Trade(request, "Use route and market evidence to prepare a future trade step without changing inventory or gold."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; trade proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Trade(request, "Use the trade narrative to compare route context and identify missing evidence."));
            return deferred;
        }
    }
}
