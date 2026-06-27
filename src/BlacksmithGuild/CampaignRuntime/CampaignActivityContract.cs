using System;
using System.Collections.Generic;

namespace BlacksmithGuild.CampaignRuntime
{
    public enum CampaignActivityMode
    {
        Observe,
        Propose,
        Dictate,
        Execute
    }

    public enum CampaignActivityStatus
    {
        NotStarted,
        Proposed,
        Dictated,
        Started,
        Blocked,
        Completed,
        Failed,
        Deferred
    }

    public enum CampaignActivityEngine
    {
        Governor,
        Food,
        Market,
        MapTravel,
        Trade,
        Smithing,
        HorseMarket,
        Companion,
        Cohesion,
        Diplomacy,
        ObserveOnly
    }

    public sealed class CampaignActivityNarrativeDetail
    {
        public string Engine { get; set; }
        public string Operation { get; set; }
        public string Narrative { get; set; }
        public string KnownState { get; set; }
        public string NeededProof { get; set; }
        public string NextAction { get; set; }
        public List<string> Signals { get; set; } = new List<string>();
        public List<string> Constraints { get; set; } = new List<string>();
        public List<string> Blockers { get; set; } = new List<string>();

        public string ToDetailString()
        {
            return "narrative engine=" + Engine
                + " operation=" + Operation
                + " knownState=" + KnownState
                + " neededProof=" + NeededProof
                + " nextAction=" + NextAction;
        }
    }

    public sealed class CampaignActivityRequest
    {
        public string ActivityId { get; set; }
        public string CycleId { get; set; }
        public string CreatedUtc { get; set; }
        public string SourceEngine { get; set; }
        public string TargetEngine { get; set; }
        public string Mode { get; set; }
        public string Status { get; set; }
        public string Branch { get; set; }
        public string Operation { get; set; }
        public string Reason { get; set; }
        public string CurrentTown { get; set; }
        public string TargetTown { get; set; }
        public string TargetItemId { get; set; }
        public string TargetItemName { get; set; }
        public int PriorityRank { get; set; }
        public bool MutationAuthorized { get; set; }
        public bool RequiresFreshMarketScan { get; set; }
        public bool RequiresVisibleSurface { get; set; }
        public bool RequiresInventoryDelta { get; set; }
        public bool RequiresGoldDelta { get; set; }
        public string ExpectedProof { get; set; }
        public string BlockedReason { get; set; }
        public List<string> Inputs { get; set; } = new List<string>();
        public List<string> ExpectedOutputs { get; set; } = new List<string>();
        public List<CampaignActivityHandoff> HandoffTrail { get; set; } = new List<CampaignActivityHandoff>();
    }

    public sealed class CampaignActivityResult
    {
        public string ActivityId { get; set; }
        public string CompletedUtc { get; set; }
        public string SourceEngine { get; set; }
        public string Status { get; set; }
        public string Detail { get; set; }
        public bool MutationApplied { get; set; }
        public bool InventoryDeltaObserved { get; set; }
        public bool GoldDeltaObserved { get; set; }
        public string FailureClass { get; set; }
        public List<CampaignActivityNarrativeDetail> NarrativeDetails { get; set; } = new List<CampaignActivityNarrativeDetail>();
        public List<CampaignActivityHandoff> HandoffTrail { get; set; } = new List<CampaignActivityHandoff>();
    }

    public static class CampaignActivityFactory
    {
        public static CampaignActivityRequest Create(
            string cycleId,
            string branch,
            CampaignActivityEngine targetEngine,
            string operation,
            string reason,
            int priorityRank,
            bool mutationAuthorized,
            string currentTown = null,
            string targetTown = null)
        {
            var request = new CampaignActivityRequest
            {
                ActivityId = Guid.NewGuid().ToString("N"),
                CycleId = cycleId,
                CreatedUtc = DateTime.UtcNow.ToString("o"),
                SourceEngine = CampaignActivityEngine.Governor.ToString(),
                TargetEngine = targetEngine.ToString(),
                Mode = mutationAuthorized ? CampaignActivityMode.Dictate.ToString() : CampaignActivityMode.Propose.ToString(),
                Status = mutationAuthorized ? CampaignActivityStatus.Dictated.ToString() : CampaignActivityStatus.Proposed.ToString(),
                Branch = branch,
                Operation = operation,
                Reason = reason,
                PriorityRank = priorityRank,
                MutationAuthorized = mutationAuthorized,
                CurrentTown = currentTown,
                TargetTown = targetTown
            };

            CampaignActivityHandoffRecorder.RecordRequest(
                request,
                CampaignActivityEngine.Governor.ToString(),
                targetEngine.ToString(),
                "governor_selection",
                request.Status,
                mutationAuthorized ? "Governor dictated bounded activity to target engine." : "Governor proposed activity to target engine.");

            return request;
        }

        public static CampaignActivityRequest ObserveOnly(string cycleId, string branch, string reason, int priorityRank)
        {
            var request = new CampaignActivityRequest
            {
                ActivityId = Guid.NewGuid().ToString("N"),
                CycleId = cycleId,
                CreatedUtc = DateTime.UtcNow.ToString("o"),
                SourceEngine = CampaignActivityEngine.Governor.ToString(),
                TargetEngine = CampaignActivityEngine.ObserveOnly.ToString(),
                Mode = CampaignActivityMode.Observe.ToString(),
                Status = CampaignActivityStatus.Deferred.ToString(),
                Branch = branch,
                Operation = "ObserveOnly",
                Reason = reason,
                PriorityRank = priorityRank,
                MutationAuthorized = false
            };

            CampaignActivityHandoffRecorder.RecordRequest(
                request,
                CampaignActivityEngine.Governor.ToString(),
                CampaignActivityEngine.ObserveOnly.ToString(),
                "governor_observation",
                request.Status,
                "Governor observed state and did not authorize engine execution.");

            return request;
        }
    }
}
