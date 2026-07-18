using System;
using System.IO;

namespace BlacksmithGuild.DevTools.SessionIntent
{
    /// <summary>
    /// Machine-readable session intent model. Written by the harness before launch and read by the mod at runtime.
    /// Answers: who is driving (human/automation/agent/CI), what sprint is active, and how the priority engine should behave.
    /// </summary>
    public class SessionIntentModel
    {
        public const string FileName = "BlacksmithGuild_SessionIntent.json";

        public string Schema { get; set; }
        public string GeneratedUtc { get; set; }
        public string DrivenBy { get; set; }
        public string LaunchIntent { get; set; }
        public string SessionId { get; set; }
        public string Sprint { get; set; }
        public string AgentRole { get; set; }
        public string AgentLabel { get; set; }
        public string PriorityEngineMode { get; set; }
        public bool AutoLoopEnabled { get; set; }
        public string CertProfile { get; set; }
        public string CertSegment { get; set; }
        public string Branch { get; set; }
        public string CommitSha { get; set; }
        public string Comment { get; set; }

        public bool IsAutomation => DrivenBy == "automation_script" || DrivenBy == "ai_agent" || DrivenBy == "ci_cd";
        public bool IsHuman => DrivenBy == "human_player";
        public bool IsCiCd => DrivenBy == "ci_cd";
        public bool IsAgent => DrivenBy == "ai_agent";
    }
}
