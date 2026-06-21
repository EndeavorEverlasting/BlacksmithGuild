using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class CharacterBuildMutationAuditResult
    {
        public bool PostMapProfileApply { get; set; }
        public List<string> HiddenSkillChanges { get; } = new List<string>();
        public List<string> HiddenFocusChanges { get; } = new List<string>();
        public List<string> HiddenAttributeChanges { get; } = new List<string>();
        public bool Clean => !PostMapProfileApply
            && HiddenSkillChanges.Count == 0
            && HiddenFocusChanges.Count == 0
            && HiddenAttributeChanges.Count == 0;
    }

    public static class CharacterBuildMutationAudit
    {
        private static HeroBuildSnapshotCapture _preMapBaseline;
        private static bool _phase1Checked;

        public static void ResetSession()
        {
            _preMapBaseline = null;
            _phase1Checked = false;
        }

        public static void CapturePreMapBaseline(Hero hero)
        {
            if (hero == null)
            {
                return;
            }

            _preMapBaseline = HeroBuildSnapshotCapture.CaptureFull(hero);
        }

        public static CharacterBuildMutationAuditResult AuditAtMapReady(Hero hero)
        {
            var result = new CharacterBuildMutationAuditResult();
            result.PostMapProfileApply = CharacterDoctrineConfig.PostMapProfileApplyEnabled
                || AutoCharacterBuildService.Summary.LastApplied == true;

            if (!_phase1Checked)
            {
                _phase1Checked = true;
                if (Phase1ContainsForbiddenMutation())
                {
                    result.PostMapProfileApply = true;
                }
            }

            if (hero == null || _preMapBaseline == null)
            {
                return result;
            }

            var current = HeroBuildSnapshotCapture.CaptureFull(hero);
            CompareDictionaries(_preMapBaseline.Skills, current.Skills, "skill", result.HiddenSkillChanges);
            CompareDictionaries(_preMapBaseline.Focus, current.Focus, "focus", result.HiddenFocusChanges);
            CompareDictionaries(_preMapBaseline.Attributes, current.Attributes, "attribute", result.HiddenAttributeChanges);
            return result;
        }

        public static void AppendMutationAuditJson(StringBuilder sb, CharacterBuildMutationAuditResult audit, int indent)
        {
            var pad = new string(' ', indent);
            sb.AppendLine($"{pad}\"mutationAudit\": {{");
            sb.AppendLine($"{pad}  \"postMapProfileApply\": {audit.PostMapProfileApply.ToString().ToLowerInvariant()},");
            sb.AppendLine($"{pad}  \"hiddenSkillChanges\": [");
            WriteStringArray(sb, audit.HiddenSkillChanges, indent + 4);
            sb.AppendLine($"{pad}  ],");
            sb.AppendLine($"{pad}  \"hiddenFocusChanges\": [");
            WriteStringArray(sb, audit.HiddenFocusChanges, indent + 4);
            sb.AppendLine($"{pad}  ],");
            sb.AppendLine($"{pad}  \"hiddenAttributeChanges\": [");
            WriteStringArray(sb, audit.HiddenAttributeChanges, indent + 4);
            sb.AppendLine($"{pad}  ]");
            sb.Append($"{pad}}}");
        }

        private static bool Phase1ContainsForbiddenMutation()
        {
            try
            {
                var phase1Path = Path.Combine(BasePath.Name, "BlacksmithGuild_Phase1.log");
                if (!File.Exists(phase1Path))
                {
                    return false;
                }

                var tail = File.ReadAllText(phase1Path);
                return tail.IndexOf(
                    "ForgeQuartermasterWarlord applied=True trigger=quickstart-bootstrap",
                    StringComparison.OrdinalIgnoreCase) >= 0;
            }
            catch
            {
                return false;
            }
        }

        private static void CompareDictionaries(
            Dictionary<string, int> before,
            Dictionary<string, int> after,
            string category,
            List<string> changes)
        {
            foreach (var entry in after)
            {
                before.TryGetValue(entry.Key, out var beforeValue);
                if (beforeValue != entry.Value)
                {
                    changes.Add($"{category}.{entry.Key}: {beforeValue} -> {entry.Value}");
                }
            }
        }

        private static void WriteStringArray(StringBuilder sb, IReadOnlyList<string> values, int indent)
        {
            var pad = new string(' ', indent);
            for (var i = 0; i < values.Count; i++)
            {
                sb.Append(pad);
                sb.Append($"\"{Escape(values[i])}\"");
                sb.AppendLine(i < values.Count - 1 ? "," : string.Empty);
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"");
        }
    }
}
