using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterDoctrineService
    {
        public const string ShowCharacterDoctrineCommand = "ShowCharacterDoctrine";
        public const string ReportFileName = "BlacksmithGuild_CharacterDoctrine.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static bool ShowDoctrineNow(string source = ShowCharacterDoctrineCommand)
        {
            WriteJsonReport(source);

            InGameNotice.Info(
                ModDisplay.CompactLine(
                    "Character Doctrine",
                    $"{CharacterDoctrineConfig.DefaultBuildId} | {CharacterDoctrineConfig.LegitimacyMode}"));

            return true;
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Character Doctrine");
            report.Line("defaultBuild", CharacterDoctrineConfig.DefaultBuildId);
            report.Line("legitimacyMode", CharacterDoctrineConfig.LegitimacyMode.ToString());
            report.Line("assistiveMode", CharacterDoctrineConfig.AssistiveMode ? "on" : "off");
            report.Line("preferredCultureId", CharacterDoctrineConfig.PreferredCultureId);
            report.Line("postMapInjection", CharacterDoctrineConfig.PostMapProfileApplyEnabled ? "on" : "off");
            report.Line("commandHint", ShowCharacterDoctrineCommand);
            report.Line("json", ReportFileName);
        }

        public static void WriteJsonReport(string source = "bootstrap")
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"defaultBuild\": \"{Escape(CharacterDoctrineConfig.DefaultBuildId)}\",");
            sb.AppendLine($"  \"legitimacyMode\": \"{Escape(CharacterDoctrineConfig.LegitimacyMode.ToString())}\",");
            sb.AppendLine($"  \"assistiveMode\": {CharacterDoctrineConfig.AssistiveMode.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"preferredCultureId\": \"{Escape(CharacterDoctrineConfig.PreferredCultureId)}\",");
            sb.AppendLine("  \"fallbackCultureIds\": [");
            WriteStringList(sb, CharacterDoctrineConfig.FallbackCultureIds, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"primaryAxis\": [");
            WriteStringList(sb, CharacterDoctrineConfig.PrimaryAxis, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"secondaryAxis\": [");
            WriteStringList(sb, CharacterDoctrineConfig.SecondaryAxis, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"combatSupport\": [");
            WriteStringList(sb, CharacterDoctrineConfig.CombatSupport, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"economicDoctrine\": [");
            WriteStringList(sb, CharacterDoctrineConfig.EconomicDoctrine, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"communityLegitimacy\": {");
            sb.AppendLine("    \"noHiddenStatInjection\": true,");
            sb.AppendLine("    \"noFreeResources\": true,");
            sb.AppendLine("    \"accessibilityRationale\": \"reduces repetitive input while preserving vanilla costs\"");
            sb.AppendLine("  }");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteStringList(StringBuilder sb, System.Collections.Generic.IReadOnlyList<string> values, int indent)
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
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            return value
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
        }
    }
}
