namespace BlacksmithGuild.DevTools.Assistive
{
    public sealed class AssistiveTravelCertSummary
    {
        public bool ExecuteRequested { get; set; }
        public bool ExecuteAllowed { get; set; }
        public string TravelCommandMode { get; set; }
        public bool PassCandidate { get; set; }
        public string BlockingReason { get; set; }
        public string RouteOwner { get; set; }
        public string NextRouteOnFail { get; set; }

        public static AssistiveTravelCertSummary Build(AssistiveTravelExecutionResult result)
        {
            if (result == null)
            {
                return null;
            }

            var durableMovementProof = result.PartyMovedDistance > 0
                || result.MovementCheckpointObserved
                || result.MovementMetricDisagreement
                || result.MovementProofClassification == MovementProofClassification.MovementDistanceObserved.ToString()
                || result.MovementProofClassification == MovementProofClassification.MovementCheckpointObserved.ToString()
                || result.MovementProofClassification == MovementProofClassification.MovementMetricDisagreement.ToString();

            var passCandidate = result.ExecuteRequested
                && result.ExecuteAllowed
                && result.TravelCommandMode == "execute"
                && result.TravelApiCallSucceeded
                && result.MovementIntentSet
                && result.ActualExecutionObserved
                && durableMovementProof
                && !result.FakeGameplayDelta;

            var summary = new AssistiveTravelCertSummary
            {
                ExecuteRequested = result.ExecuteRequested,
                ExecuteAllowed = result.ExecuteAllowed,
                TravelCommandMode = result.TravelCommandMode ?? "advisory_only",
                PassCandidate = passCandidate,
                BlockingReason = passCandidate ? null : result.FallbackReason,
                RouteOwner = passCandidate ? "AgentA" : null,
                NextRouteOnFail = null
            };

            if (passCandidate || !result.ExecuteRequested)
            {
                return summary;
            }

            summary.NextRouteOnFail = IsAgentBRuntimeBlock(result.FallbackReason)
                ? "AgentB"
                : "AgentA";
            return summary;
        }

        private static bool IsAgentBRuntimeBlock(string fallbackReason)
        {
            if (string.IsNullOrWhiteSpace(fallbackReason))
            {
                return false;
            }

            return fallbackReason == "movement_intent_not_observed"
                || fallbackReason == "actual_execution_not_observed"
                || fallbackReason == "leave_town_failed"
                || fallbackReason == "leave_town_incomplete"
                || fallbackReason == "map_surface_not_reached"
                || fallbackReason == "travel_api_call_failed"
                || fallbackReason.StartsWith("surface_not_execute_eligible:");
        }
    }
}
