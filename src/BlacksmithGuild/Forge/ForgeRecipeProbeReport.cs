using System;
using System.Collections.Generic;

namespace BlacksmithGuild.Forge
{
    public sealed class ForgeRecipeProbeSummary
    {
        public bool HasProbe { get; set; }
        public string ProbeStatus { get; set; }
        public string Detail { get; set; }
        public int MatchedTypeCount { get; set; }
        public int TemplateCount { get; set; }
        public int? CraftingOrderCount { get; set; }
        public int? SmithingSkillLevel { get; set; }
        public string ReportPath { get; set; } = "BlacksmithGuild_RecipeProbe.json";
        public DateTime? GeneratedAt { get; set; }
    }

    public sealed class ForgeRecipeProbeEntryPoint
    {
        public string Name { get; set; }
        public string Status { get; set; }
        public string Detail { get; set; }
    }

    public sealed class ForgeRecipeProbeTemplateSample
    {
        public string Id { get; set; }
        public string ItemType { get; set; }
    }

    public sealed class ForgeRecipeProbeReport
    {
        public string GeneratedUtc { get; set; }
        public string ProbeStatus { get; set; }
        public string Detail { get; set; }
        public bool CampaignReady { get; set; }
        public int? SmithingSkillLevel { get; set; }
        public int MatchedTypeCount { get; set; }
        public List<string> MatchedTypes { get; set; } = new List<string>();
        public List<ForgeRecipeProbeEntryPoint> EntryPoints { get; set; } = new List<ForgeRecipeProbeEntryPoint>();
        public int TemplateCount { get; set; }
        public List<ForgeRecipeProbeTemplateSample> TemplateSample { get; set; } = new List<ForgeRecipeProbeTemplateSample>();
        public int? CraftingOrderCount { get; set; }
        public List<string> Errors { get; set; } = new List<string>();
    }

    public sealed class ForgeRecipeProbeResult
    {
        public ForgeRecipeProbeReport Report { get; set; } = new ForgeRecipeProbeReport();
        public IReadOnlyList<ForgeCandidate> Candidates { get; set; } = Array.Empty<ForgeCandidate>();
    }
}
