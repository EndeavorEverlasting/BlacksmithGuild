using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.Assistive
{
    public sealed class AssistiveTravelStep
    {
        public string Name { get; set; }
        public string Method { get; set; }
        public string Status { get; set; }
        public string Detail { get; set; }
    }

    public sealed class AssistiveTravelExecutionResult
    {
        public bool CommandAccepted { get; set; }
        public bool ExecuteRequested { get; set; }
        public bool ExecuteAllowed { get; set; }
        public string TravelCommandMode { get; set; } = "advisory_only";
        public string FallbackReason { get; set; }
        public string CurrentSettlement { get; set; }
        public string TargetSettlement { get; set; }
        public bool LeaveTownAttempted { get; set; }
        public bool LeaveTownSucceeded { get; set; }
        public bool MapTravelAttempted { get; set; }
        public bool MovementIntentSet { get; set; }
        public bool ActualExecutionObserved { get; set; }
        public bool FakeGameplayDelta { get; set; }
        public List<AssistiveTravelStep> Steps { get; set; } = new List<AssistiveTravelStep>();
    }
}
