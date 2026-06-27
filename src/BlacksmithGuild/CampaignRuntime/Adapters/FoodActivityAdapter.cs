using System;
using System.Collections.Generic;
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
            var candidates = FoodProcurementCandidatePlanner.Plan(plan);
            var marketStock = FoodMarketStockScanner.ScanCurrentSettlement(MobileParty.MainParty);
            var marketMatches = FoodMarketCandidateMatcher.Match(candidates, marketStock);
            var gate = FoodProcurementExecutionGate.Evaluate(request, plan);
            var detail = plan.ToDetailString()
                + " " + candidates.ToDetailString()
                + " " + marketStock.ToDetailString()
                + " " + marketMatches.ToDetailString()
                + " " + gate.ToDetailString()
                + " expectedProof=" + request.ExpectedProof;

            if (!request.MutationAuthorized)
            {
                var result = CampaignActivityDispatcher.Deferred(request, detail + "; proposal recorded only");
                AddFoodNarrative(result, request, plan, candidates, marketStock, marketMatches, gate, "Analyze food proposal and decide whether a proven market action path should be prepared.");
                return result;
            }

            if (!gate.ReadyForVanillaDriver)
            {
                var result = CampaignActivityDispatcher.Blocked(request, detail, "food_proof_gate_not_satisfied");
                AddFoodNarrative(result, request, plan, candidates, marketStock, marketMatches, gate, "Satisfy proof gate before any food purchase driver is allowed.");
                return result;
            }

            var blocked = CampaignActivityDispatcher.Blocked(request, detail + "; vanilla food driver is not wired yet", "food_vanilla_driver_not_wired");
            AddFoodNarrative(blocked, request, plan, candidates, marketStock, marketMatches, gate, "Wire and prove the vanilla food driver before execution.");
            return blocked;
        }

        private static void AddFoodNarrative(
            CampaignActivityResult result,
            CampaignActivityRequest request,
            FoodProcurementPlan plan,
            FoodProcurementCandidatePlan candidates,
            FoodMarketStockSnapshot marketStock,
            FoodMarketCandidateMatchPlan marketMatches,
            FoodProcurementExecutionGateResult gate,
            string nextAction)
        {
            if (result == null)
            {
                return;
            }

            result.NarrativeDetails.Add(CampaignActivityNarrativeFactory.Create(
                request,
                "Food engine evaluated runway, procurement candidates, read-only market stock, and execution proof readiness.",
                plan.ToDetailString() + " " + candidates.ToDetailString() + " " + marketStock.ToDetailString() + " " + marketMatches.ToDetailString(),
                gate.ToDetailString(),
                nextAction,
                new List<string>
                {
                    "currentFoodItems=" + plan.CurrentFoodItems,
                    "targetFoodItems=" + plan.TargetFoodItems,
                    "foodShortfall=" + plan.FoodShortfall,
                    "uniqueFoodTypeShortfall=" + plan.UniqueFoodTypeShortfall,
                    "marketStockStatus=" + marketStock.Status,
                    "marketMatchStatus=" + marketMatches.Status
                },
                new List<string>
                {
                    "mutationAuthorized=" + request.MutationAuthorized,
                    "requiresFreshMarketScan=" + request.RequiresFreshMarketScan,
                    "requiresVisibleSurface=" + request.RequiresVisibleSurface,
                    "requiresInventoryDelta=" + request.RequiresInventoryDelta,
                    "requiresGoldDelta=" + request.RequiresGoldDelta
                },
                BuildFoodBlockers(request, gate, marketStock, marketMatches)));
        }

        private static List<string> BuildFoodBlockers(
            CampaignActivityRequest request,
            FoodProcurementExecutionGateResult gate,
            FoodMarketStockSnapshot marketStock,
            FoodMarketCandidateMatchPlan marketMatches)
        {
            var blockers = new List<string>();
            if (!request.MutationAuthorized)
            {
                blockers.Add("proposal-only request; no food purchase authorized");
            }

            if (!gate.ReadyForVanillaDriver)
            {
                blockers.Add("proof gate not ready: " + gate.Status);
            }

            if (!string.Equals(marketStock.Status, "scanned", StringComparison.OrdinalIgnoreCase))
            {
                blockers.Add("market stock not fully scanned: " + marketStock.Status);
            }

            if (string.Equals(marketMatches.Status, "unknown", StringComparison.OrdinalIgnoreCase))
            {
                blockers.Add("candidate match unknown: " + marketMatches.Reason);
            }

            return blockers;
        }
    }
}
