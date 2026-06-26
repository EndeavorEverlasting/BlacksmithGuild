using System;

namespace BlacksmithGuild.DevTools.Automation
{
    // Section-boundary record. Boundaries wrap each major runner/mod section with a start/terminal
    // lifecycle so the offline economic-loop certifier can prove every started section closed and
    // attach the gameplay-delta evidence files that justify a completed status. Proof still requires
    // the domain JSON deltas referenced in EvidenceFilesJson; the boundary itself is only a wrapper.
    public sealed class BoundaryEvent
    {
        public const int SchemaVersion = 1;
        public const string FileName = "BlacksmithGuild_BoundaryEvents.jsonl";

        public const string StatusStarted = "started";
        public const string StatusCompleted = "completed";
        public const string StatusFailed = "failed";
        public const string StatusBlocked = "blocked";
        public const string StatusSkipped = "skipped";

        public string BoundaryId { get; set; } = Guid.NewGuid().ToString();
        public string SessionId { get; set; }
        public string SectionName { get; set; }
        public string BranchName { get; set; }
        public int? CycleId { get; set; }
        public string Status { get; set; } = StatusStarted;
        public DateTime StartedAtUtc { get; set; } = DateTime.UtcNow;
        public DateTime? EndedAtUtc { get; set; }
        public string FailureClass { get; set; }
        public string Reason { get; set; }
        public string Source { get; set; } = "mod";

        // Compact JSON array of evidence file names / event ids, e.g. ["BlacksmithGuild_TradeIterations.jsonl"].
        public string EvidenceFilesJson { get; set; }
        public string EventIdsJson { get; set; }
    }
}
