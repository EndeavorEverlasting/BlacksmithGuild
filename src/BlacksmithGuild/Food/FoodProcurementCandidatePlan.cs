using System;
using System.Collections.Generic;

namespace BlacksmithGuild.Food
{
    public sealed class FoodProcurementCandidate
    {
        public string CandidateKind { get; set; }
        public string TargetItemId { get; set; }
        public string TargetItemName { get; set; }
        public int DesiredQuantity { get; set; }
        public string Reason { get; set; }

        public string ToDetailString()
        {
            return CandidateKind
                + ":" + (TargetItemId ?? "any_food")
                + " qty=" + DesiredQuantity
                + " reason=" + Reason;
        }
    }

    public sealed class FoodProcurementCandidatePlan
    {
        public bool CandidatePlanningNeeded { get; set; }
        public string Status { get; set; }
        public string Reason { get; set; }
        public List<FoodProcurementCandidate> Candidates { get; } = new List<FoodProcurementCandidate>();

        public string ToDetailString()
        {
            var parts = new List<string>();
            for (var i = 0; i < Candidates.Count; i++)
            {
                parts.Add(Candidates[i].ToDetailString());
            }

            return "food candidates: status=" + Status
                + " needed=" + CandidatePlanningNeeded
                + " count=" + Candidates.Count
                + " reason=" + Reason
                + (parts.Count > 0 ? " candidates=[" + string.Join("; ", parts.ToArray()) + "]" : string.Empty);
        }
    }

    public static class FoodProcurementCandidatePlanner
    {
        private const string AnyFoodId = "any_food";
        private const string AnyFoodName = "Any food item";
        private const string DiverseFoodId = "diverse_food";
        private const string DiverseFoodName = "Food type not already represented";

        public static FoodProcurementCandidatePlan Plan(FoodProcurementPlan plan)
        {
            var result = new FoodProcurementCandidatePlan();
            if (plan == null)
            {
                result.Status = "blocked";
                result.Reason = "missing food procurement plan";
                return result;
            }

            result.CandidatePlanningNeeded = plan.ProcurementNeeded;
            result.Status = plan.ProcurementNeeded ? "planned" : "not_needed";
            result.Reason = plan.Reason;

            if (!plan.ProcurementNeeded)
            {
                return result;
            }

            if (plan.UniqueFoodTypeShortfall > 0)
            {
                result.Candidates.Add(new FoodProcurementCandidate
                {
                    CandidateKind = "diversity",
                    TargetItemId = DiverseFoodId,
                    TargetItemName = DiverseFoodName,
                    DesiredQuantity = Math.Max(1, plan.UniqueFoodTypeShortfall),
                    Reason = "restore protected food diversity floor"
                });
            }

            if (plan.FoodShortfall > 0)
            {
                result.Candidates.Add(new FoodProcurementCandidate
                {
                    CandidateKind = "quantity",
                    TargetItemId = AnyFoodId,
                    TargetItemName = AnyFoodName,
                    DesiredQuantity = plan.FoodShortfall,
                    Reason = "restore target food buffer"
                });
            }

            if (result.Candidates.Count == 0)
            {
                result.Candidates.Add(new FoodProcurementCandidate
                {
                    CandidateKind = "forecast",
                    TargetItemId = AnyFoodId,
                    TargetItemName = AnyFoodName,
                    DesiredQuantity = Math.Max(1, plan.TargetFoodItems - plan.CurrentFoodItems),
                    Reason = "forecast runway requires market scan before action"
                });
            }

            return result;
        }
    }
}
