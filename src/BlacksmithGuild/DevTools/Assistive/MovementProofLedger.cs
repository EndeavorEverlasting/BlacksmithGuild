using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.Assistive
{
    public enum MovementProofClassification
    {
        Unknown,
        MovementDistanceObserved,
        MovementCheckpointObserved,
        MovementMetricDisagreement,
        MovementObservationIndeterminate,
        MovementCommandAckWithoutDurableEvidence,
        ForegroundInterruptionPreventedObservation,
        MovementNotObservedAfterFairWindow
    }

    public sealed class MovementProofLedger
    {
        public int SchemaVersion { get; set; } = 1;
        public string AttemptId { get; set; }
        public string CommandName { get; set; }
        public string Source { get; set; }
        public bool CommandAckObserved { get; set; }
        public bool ExecuteRequested { get; set; }
        public bool ExecuteAllowed { get; set; }
        public bool TravelApiCallSucceeded { get; set; }
        public string TargetSettlement { get; set; }
        public string TargetSettlementId { get; set; }
        public List<MovementProofSample> Samples { get; set; } = new List<MovementProofSample>();
        public MovementProofDeltas Deltas { get; set; } = new MovementProofDeltas();
        public MovementProofClassification Classification { get; set; } = MovementProofClassification.Unknown;
        public string ClassificationReason { get; set; }
        public bool PartyMovedDistanceReliable { get; set; } = true;
        public double PartyMovedDistance { get; set; }
    }

    public sealed class MovementProofSample
    {
        public string Phase { get; set; }
        public string Reason { get; set; }
        public string TimestampUtc { get; set; }
        public double? PositionX { get; set; }
        public double? PositionY { get; set; }
        public string CurrentSettlement { get; set; }
        public string CurrentSettlementId { get; set; }
        public string NearestSettlement { get; set; }
        public string NearestSettlementId { get; set; }
        public string TargetSettlement { get; set; }
        public string TargetSettlementId { get; set; }
        public double? DistanceFromStart { get; set; }
        public double? DistanceToTarget { get; set; }
        public string MapTimeText { get; set; }
        public bool CampaignClockRunning { get; set; }
        public bool MovementIntentSet { get; set; }
    }

    public sealed class MovementProofDeltas
    {
        public bool PositionChanged { get; set; }
        public bool CurrentSettlementChanged { get; set; }
        public bool NearestSettlementChanged { get; set; }
        public bool TargetChanged { get; set; }
        public bool DistanceToTargetChanged { get; set; }
        public bool MapTimeAdvanced { get; set; }
        public bool PartyMovedDistanceChanged { get; set; }
        public double MaxDistanceFromStart { get; set; }
        public double? StartDistanceToTarget { get; set; }
        public double? LastDistanceToTarget { get; set; }
    }
}