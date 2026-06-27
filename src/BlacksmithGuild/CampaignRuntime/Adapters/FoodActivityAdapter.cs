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
            var gate = FoodProcurementExecutionGate.Evaluate(request, plan);
            var detail = plan.ToDetailString()
                + " " + gate.ToDetailString()
                + " expectedProof=" + request.ExpectedProof;

            if (!request.MutationAuthorized)
            {
                return CampaignActivityDispatcher.Deferred(request, detail + "; proposal recorded only");
            }

            if (!gate.ReadyForVanillaDriver)
            {
                return CampaignActivityDispatcher.Blocked(request, detail, "food_proof_gate_not_satisfied");
            }

            return CampaignActivityDispatcher.Blocked(request, detail + "; vanilla food action driver is not wired yet", "food_vanilla_driver_not_wired");
        }
    }
}
