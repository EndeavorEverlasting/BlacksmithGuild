using System;
using System.Collections.Generic;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.Forge
{
    public sealed class ForgeRecommendationSummary
    {
        public bool HasRankings { get; set; }
        public string Source { get; set; }
        public string SourceKind { get; set; }
        public string SourceStatus { get; set; }
        public bool FallbackUsed { get; set; }
        public string ResolutionDetail { get; set; }
        public string Doctrine { get; set; }
        public string EconomicsMode { get; set; }
        public int TemplateCount { get; set; }
        public int MappedCount { get; set; }
        public string TopCandidateId { get; set; }
        public string TopCandidateName { get; set; }
        public float TopFinalScore { get; set; }
        public int RankedCount { get; set; }
        public int CandidateCount { get; set; }
        public string ReportPath { get; set; } = "BlacksmithGuild_ForgeRecommendations.json";
        public DateTime? GeneratedAt { get; set; }
    }

    public sealed class ForgeRecommendationReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string SourceKind { get; set; }
        public string SourceStatus { get; set; }
        public bool FallbackUsed { get; set; }
        public string ResolutionDetail { get; set; }
        public int CandidateCount { get; set; }
        public string Doctrine { get; set; }
        public string EconomicsMode { get; set; }
        public int TemplateCount { get; set; }
        public int MappedCount { get; set; }
        public ForgeCandidate TopCandidate { get; set; }
        public List<ForgeCandidate> Ranked { get; set; } = new List<ForgeCandidate>();
        public SourceHonestyInfo SourceHonesty { get; set; }
        public List<ActionPlanStep> ActionPlan { get; set; } = new List<ActionPlanStep>();
        public List<MaterialGapRow> MaterialGaps { get; set; } = new List<MaterialGapRow>();
        public List<SmithingCrewRow> SmithingCrew { get; set; } = new List<SmithingCrewRow>();
    }
}
