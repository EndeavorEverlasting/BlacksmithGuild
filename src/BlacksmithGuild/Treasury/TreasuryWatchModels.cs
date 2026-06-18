using System.Collections.Generic;

namespace BlacksmithGuild.Treasury
{
    public enum TreasurySeverity
    {
        Observed,
        Suspicious,
        Critical
    }

    public sealed class TreasurySnapshot
    {
        public string ActorId { get; set; }
        public string ActorName { get; set; }
        public string ActorType { get; set; }
        public int Gold { get; set; }
        public int Day { get; set; }
        public string WarStateAgainstPlayer { get; set; }
    }

    public sealed class TreasuryDelta
    {
        public string ActorId { get; set; }
        public string ActorName { get; set; }
        public string ActorType { get; set; }
        public int PreviousGold { get; set; }
        public int CurrentGold { get; set; }
        public int Delta { get; set; }
        public int PreviousDay { get; set; }
        public int CurrentDay { get; set; }
        public string Classification { get; set; }
        public int SuspicionScore { get; set; }
        public string Explanation { get; set; }
    }

    public sealed class TreasuryWatchSummary
    {
        public bool Enabled { get; set; }
        public int LastSnapshotDay { get; set; }
        public int ActorsTracked { get; set; }
        public int SnapshotCount { get; set; }
        public int SnapshotGeneration { get; set; }
        public int DeltaCount { get; set; }
        public int ObservedCount { get; set; }
        public int SuspiciousCount { get; set; }
        public int CriticalCount { get; set; }
        public int MaxAbsDelta { get; set; }
        public string MaxSeverity { get; set; }
        public string LastCriticalActor { get; set; }
        public int LastCriticalDelta { get; set; }
        public string ReportPath { get; set; }
    }

    public sealed class TreasuryWatchReport
    {
        public string GeneratedUtc { get; set; }
        public int CampaignDay { get; set; }
        public bool WatchEnabled { get; set; }
        public int LastSnapshotDay { get; set; }
        public int ActorsTracked { get; set; }
        public int SnapshotCount { get; set; }
        public int SnapshotGeneration { get; set; }
        public List<TreasurySnapshot> LatestSnapshots { get; set; } = new List<TreasurySnapshot>();
        public List<TreasuryDelta> RecentDeltas { get; set; } = new List<TreasuryDelta>();
        public TreasuryWatchSummary Summary { get; set; } = new TreasuryWatchSummary();
        public List<string> Warnings { get; set; } = new List<string>();
    }
}
