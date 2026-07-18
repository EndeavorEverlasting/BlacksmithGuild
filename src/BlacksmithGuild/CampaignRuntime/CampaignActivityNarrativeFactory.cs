using System.Collections.Generic;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignActivityNarrativeFactory
    {
        public static CampaignActivityNarrativeDetail Create(
            CampaignActivityRequest request,
            string narrative,
            string knownState,
            string neededProof,
            string nextAction,
            IEnumerable<string> signals = null,
            IEnumerable<string> constraints = null,
            IEnumerable<string> blockers = null)
        {
            var detail = new CampaignActivityNarrativeDetail
            {
                Engine = request?.TargetEngine,
                Operation = request?.Operation,
                Narrative = narrative,
                KnownState = knownState,
                NeededProof = neededProof,
                NextAction = nextAction
            };

            AddRange(detail.Signals, signals);
            AddRange(detail.Constraints, constraints);
            AddRange(detail.Blockers, blockers);
            return detail;
        }

        public static void AttachDefault(CampaignActivityResult result, CampaignActivityRequest request, string detail, string failureClass)
        {
            if (result == null || request == null || result.NarrativeDetails.Count > 0)
            {
                return;
            }

            var signals = new List<string>
            {
                "branch=" + request.Branch,
                "currentTown=" + (request.CurrentTown ?? "unknown"),
                "targetTown=" + (request.TargetTown ?? "none"),
                "targetItemId=" + (request.TargetItemId ?? "none"),
                "mutationAuthorized=" + request.MutationAuthorized
            };

            var constraints = new List<string>
            {
                "requiresFreshMarketScan=" + request.RequiresFreshMarketScan,
                "requiresVisibleSurface=" + request.RequiresVisibleSurface,
                "requiresInventoryDelta=" + request.RequiresInventoryDelta,
                "requiresGoldDelta=" + request.RequiresGoldDelta
            };

            var blockers = new List<string>();
            if (!string.IsNullOrWhiteSpace(failureClass))
            {
                blockers.Add("failureClass=" + failureClass);
            }

            if (!request.MutationAuthorized)
            {
                blockers.Add("proposal-only request; no mutation authorized");
            }

            result.NarrativeDetails.Add(Create(
                request,
                "Activity result captured for downstream engine analysis.",
                detail,
                string.IsNullOrWhiteSpace(request.ExpectedProof) ? "no explicit proof supplied" : request.ExpectedProof,
                request.MutationAuthorized ? "Resolve blockers before bounded execution." : "Analyze proposal and select the next safe engine step.",
                signals,
                constraints,
                blockers));
        }

        private static void AddRange(List<string> target, IEnumerable<string> values)
        {
            if (target == null || values == null)
            {
                return;
            }

            foreach (var value in values)
            {
                if (!string.IsNullOrWhiteSpace(value))
                {
                    target.Add(value);
                }
            }
        }
    }
}
