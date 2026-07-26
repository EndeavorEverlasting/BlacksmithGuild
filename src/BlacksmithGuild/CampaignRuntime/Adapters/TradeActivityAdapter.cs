using System;
using BlacksmithGuild.MapTrade;

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
                if (MapTradeAutonomousService.TryStartGovernorTradeActivity(request, out var startDetail))
                {
                    var started = CampaignActivityDispatcher.Started(
                        request,
                        detail + "; " + startDetail);
                    started.NarrativeDetails.Add(CampaignActivityEngineNarratives.Trade(
                        request,
                        "MapTrade route started; only a proven vanilla inventory/gold delta can reconcile this activity as completed."));
                    return started;
                }

                var blocked = CampaignActivityDispatcher.Blocked(
                    request,
                    detail + "; " + (startDetail ?? MapTradeAutonomousService.LastFailReason ?? "MapTrade trade route did not start"),
                    "map_trade_trade_start_blocked");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Trade(
                    request,
                    "Trade remained blocked and no inventory or gold mutation was claimed."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; trade proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Trade(request, "Use the trade narrative to compare route context and identify missing evidence."));
            return deferred;
        }
    }
}
