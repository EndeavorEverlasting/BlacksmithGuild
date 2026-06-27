using System.Collections.Generic;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignActivityEngineNarratives
    {
        public static CampaignActivityNarrativeDetail Market(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Market engine evaluated whether a read-only market refresh is needed before any market-dependent step.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetItemId=" + (request.TargetItemId ?? "none"),
                "fresh market scan evidence, visible market surface when required, and structured stock or price output",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "market scan action path remains inactive"));
        }

        public static CampaignActivityNarrativeDetail Trade(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Trade engine evaluated route or transaction context for downstream analysis.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetTown=" + (request.TargetTown ?? "unknown") + "; targetItemId=" + (request.TargetItemId ?? "none"),
                "market evidence, inventory delta evidence, gold delta evidence, and route value evidence",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "trade action path remains inactive"));
        }

        public static CampaignActivityNarrativeDetail Smithing(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Smithing engine evaluated whether safe smithing or refine work should be prepared through the known smithing service.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetItemId=" + (request.TargetItemId ?? "none"),
                "visible smithy surface, stamina and material evidence, inventory delta evidence, and safe service routing",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "smithing action path remains inactive outside the known safe service"));
        }

        public static CampaignActivityNarrativeDetail Travel(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Map travel engine evaluated movement toward the best known opportunity.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetTown=" + (request.TargetTown ?? "unknown"),
                "visible campaign map surface, destination confirmation, path intent evidence, and stop-condition evidence",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "travel action path remains inactive"));
        }

        public static CampaignActivityNarrativeDetail HorseMarket(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Horse-market engine evaluated pack-animal acquisition context for capacity pressure.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetTown=" + (request.TargetTown ?? "unknown") + "; targetItemId=" + (request.TargetItemId ?? "any_pack_animal"),
                "fresh market evidence, pack animal candidate evidence, inventory delta evidence, and gold delta evidence",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "horse-market action path remains inactive"));
        }

        public static CampaignActivityNarrativeDetail Companion(CampaignActivityRequest request, string nextAction)
        {
            return CampaignActivityNarrativeFactory.Create(
                request,
                "Companion engine evaluated tavern recruitment context for downstream analysis.",
                "currentTown=" + (request.CurrentTown ?? "unknown") + "; targetTown=" + (request.TargetTown ?? "unknown"),
                "visible tavern surface, candidate identity evidence, cost evidence, roster delta evidence, and gold delta evidence",
                nextAction,
                BaseSignals(request),
                BaseConstraints(request),
                BuildBlockers(request, "companion action path remains inactive"));
        }

        private static List<string> BaseSignals(CampaignActivityRequest request)
        {
            return new List<string>
            {
                "branch=" + (request.Branch ?? "unknown"),
                "operation=" + (request.Operation ?? "unknown"),
                "currentTown=" + (request.CurrentTown ?? "unknown"),
                "targetTown=" + (request.TargetTown ?? "none"),
                "targetItemId=" + (request.TargetItemId ?? "none"),
                "targetItemName=" + (request.TargetItemName ?? "none"),
                "priorityRank=" + request.PriorityRank
            };
        }

        private static List<string> BaseConstraints(CampaignActivityRequest request)
        {
            return new List<string>
            {
                "changeRequested=" + request.MutationAuthorized,
                "requiresFreshMarketScan=" + request.RequiresFreshMarketScan,
                "requiresVisibleSurface=" + request.RequiresVisibleSurface,
                "requiresInventoryDelta=" + request.RequiresInventoryDelta,
                "requiresGoldDelta=" + request.RequiresGoldDelta,
                "expectedProof=" + (request.ExpectedProof ?? "none")
            };
        }

        private static List<string> BuildBlockers(CampaignActivityRequest request, string engineBlocker)
        {
            var blockers = new List<string>();
            if (!request.MutationAuthorized)
            {
                blockers.Add("proposal-only request; state-changing action not requested");
            }

            blockers.Add(engineBlocker);

            if (string.IsNullOrWhiteSpace(request.ExpectedProof))
            {
                blockers.Add("expected evidence is missing or incomplete");
            }

            return blockers;
        }
    }
}
