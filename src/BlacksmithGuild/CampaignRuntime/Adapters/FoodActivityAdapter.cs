using System;
using BlacksmithGuild.Food;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.CampaignRuntime.Adapters
{
    public sealed class FoodActivityAdapter : ICampaignActivityAdapter
    {
        public bool CanHandle(CampaignActivityRequest request)
        {
            if (request == null)
            {
                return false;
            }

            return string.Equals(request.TargetEngine, CampaignActivityEngine.Food.ToString(), StringComparison.OrdinalIgnoreCase)
                || string.Equals(request.Operation, "AcquireFoodBeforeRunwayBreach", StringComparison.OrdinalIgnoreCase);
        }

        public CampaignActivityResult TryHandle(CampaignActivityRequest request)
        {
            var food = FoodInventoryAnalyzer.Analyze(MobileParty.MainParty);
            var plan = FoodProcurementPlanner.Plan(food);
            var detail = plan.ToDetailString() + " expectedProof=" + request.ExpectedProof;

            if (!request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Deferred(request, detail + "; proposal recorded only");
            }

            return CampaignActivityDispatcher.Blocked(request, detail + "; procurement action path is not implemented yet", "food_action_path_not_implemented");
        }
    }
}
