using System;
using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class AutoCharacterBuildReport
    {
        public string Profile { get; set; }
        public bool Applied { get; set; }
        public string Trigger { get; set; }
        public bool MainHeroReady { get; set; }
        public bool CampaignReady { get; set; }
        public bool NormalSaveProtected { get; set; }
        public string GeneratedUtc { get; set; } = DateTime.UtcNow.ToString("o");
        public Dictionary<string, int> BeforeAttributes { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, int> BeforeFocus { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, int> BeforeSkills { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, int> AfterAttributes { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, int> AfterFocus { get; set; } = new Dictionary<string, int>();
        public Dictionary<string, int> AfterSkills { get; set; } = new Dictionary<string, int>();
        public List<string> Changes { get; set; } = new List<string>();
        public List<string> Warnings { get; set; } = new List<string>();
        public List<string> Errors { get; set; } = new List<string>();
    }

    public sealed class AutoCharacterBuildSummary
    {
        public bool HasReport { get; set; }
        public string Profile { get; set; }
        public bool Applied { get; set; }
        public string Trigger { get; set; }
        public string ReportPath { get; set; } = "BlacksmithGuild_AutoCharacterBuild.json";
        public DateTime? GeneratedAt { get; set; }
    }
}
