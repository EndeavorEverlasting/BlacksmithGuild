using System;
using BlacksmithGuild.CampaignRuntime;

namespace BlacksmithGuild.Food
{
    public sealed class FoodProcurementExecutionGateResult
    {
        public bool ProofRulesSatisfied { get; set; }
        public bool ReadyForVanillaDriver { get; set; }
        public string Status { get; set; }
        public string Reason { get; set; }

        public string ToDetailString()
        {
            return "food execution gate: status=" + Status
                + " proofRulesSatisfied=" + ProofRulesSatisfied
                + " readyForVanillaDriver=" + ReadyForVanillaDriver
                + " reason=" + Reason;
        }
    }

    public static class FoodProcurementExecutionGate
    {
        public static FoodProcurementExecutionGateResult Evaluate(CampaignActivityRequest request, FoodProcurementPlan plan)
        {
            if (request == null)
            {
                return Blocked("missing activity request");
            }

            if (plan == null)
            {
                return Blocked("missing food procurement plan");
            }

            if (!request.MutationAuthorized)
            {
                return Deferred("mutation is not authorized; proposal only");
            }

            if (!plan.ProcurementNeeded)
            {
                return Deferred("food procurement is not required by the current plan");
            }

            if (!request.RequiresFreshMarketScan)
            {
                return Blocked("fresh market scan proof is required before food procurement can execute");
            }

            if (!request.RequiresVisibleSurface)
            {
                return Blocked("visible surface proof is required before food procurement can execute");
            }

            if (!request.RequiresInventoryDelta)
            {
                return Blocked("inventory delta proof is required before food procurement can execute");
            }

            if (!request.RequiresGoldDelta)
            {
                return Blocked("gold delta proof is required before food procurement can execute");
            }

            if (string.IsNullOrWhiteSpace(request.ExpectedProof))
            {
                return Blocked("expected proof description is missing");
            }

            return new FoodProcurementExecutionGateResult
            {
                ProofRulesSatisfied = true,
                ReadyForVanillaDriver = true,
                Status = "ready_for_vanilla_driver",
                Reason = "food procurement proof rules are satisfied; route only through a proven vanilla action driver"
            };
        }

        private static FoodProcurementExecutionGateResult Deferred(string reason)
        {
            return new FoodProcurementExecutionGateResult
            {
                ProofRulesSatisfied = false,
                ReadyForVanillaDriver = false,
                Status = "deferred",
                Reason = reason
            };
        }

        private static FoodProcurementExecutionGateResult Blocked(string reason)
        {
            return new FoodProcurementExecutionGateResult
            {
                ProofRulesSatisfied = false,
                ReadyForVanillaDriver = false,
                Status = "blocked",
                Reason = reason
            };
        }
    }
}
