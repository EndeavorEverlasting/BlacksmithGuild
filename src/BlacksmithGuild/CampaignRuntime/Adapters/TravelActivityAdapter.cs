using System;
using BlacksmithGuild.MapTrade;

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
                if (MapTradeAutonomousService.TryStartGovernorTravelActivity(request, out var startDetail))
                {
                    var started = CampaignActivityDispatcher.Started(
                        request,
                        detail + "; " + startDetail);
                    started.NarrativeDetails.Add(CampaignActivityEngineNarratives.Travel(
                        request,
                        "Visible MapTrade movement started; terminal arrival or blocked evidence will reconcile this governor activity."));
                    return started;
                }

                var blocked = CampaignActivityDispatcher.Blocked(
                    request,
                    detail + "; " + (startDetail ?? MapTradeAutonomousService.LastFailReason ?? "MapTrade travel did not start"),
                    "map_trade_travel_start_blocked");
                blocked.NarrativeDetails.Add(CampaignActivityEngineNarratives.Travel(
                    request,
                    "Travel remained blocked and no movement-complete claim was emitted."));
                return blocked;
            }

            var deferred = CampaignActivityDispatcher.Deferred(request, detail + "; travel proposal recorded only");
            deferred.NarrativeDetails.Add(CampaignActivityEngineNarratives.Travel(request, "Use the travel narrative to compare destination context and missing surface evidence."));
            return deferred;
        }
    }
}
