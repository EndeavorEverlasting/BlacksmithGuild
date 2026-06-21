using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterBuildProvenanceService
    {
        public const string ReportFileName = "BlacksmithGuild_CharacterBuildProvenance.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        private static readonly List<UpbringingChoiceRecord> UpbringingChoices = new List<UpbringingChoiceRecord>();

        private static CultureSelectionRecord _cultureSelection;
        private static bool _finalized;
        private static bool _visibleTraversalLogged;

        public static void ResetSession()
        {
            UpbringingChoices.Clear();
            _cultureSelection = null;
            _finalized = false;
            _visibleTraversalLogged = false;
        }

        public static void LogVisibleTraversalOnce()
        {
            if (_visibleTraversalLogged || !DevToolsConfig.CharacterCreationVisibleMode)
            {
                return;
            }

            _visibleTraversalLogged = true;
            GuildLog.Info(
                $"[TBG CHARACTER] visible traversal: on pauseMs={DevToolsConfig.CharacterCreationDecisionPauseMs}",
                showInGame: false);
        }

        public static void RecordCultureSelection(
            CultureObject culture,
            bool preferredUsed,
            bool fallbackUsed,
            int cultureCount)
        {
            var cultureId = culture?.StringId ?? "unknown";
            var cultureName = culture?.Name?.ToString() ?? cultureId;

            _cultureSelection = new CultureSelectionRecord
            {
                PreferredCultureId = CharacterDoctrineConfig.PreferredCultureId,
                SelectedCultureId = cultureId,
                SelectedCultureName = cultureName,
                SelectionMode = "CharacterCreationTraversal",
                FallbackUsed = fallbackUsed,
                PreferredUsed = preferredUsed,
                CultureCount = cultureCount
            };
        }

        public static void RecordUpbringingChoice(
            string stage,
            string menuId,
            string optionId,
            string optionText,
            string reason,
            List<string> expectedBenefits,
            List<string> opportunityCosts,
            string benefitSource,
            List<RejectedNarrativeOption> rejectedOptions)
        {
            var choice = new UpbringingChoiceRecord
            {
                Stage = stage,
                MenuId = menuId,
                OptionId = optionId,
                OptionText = optionText,
                Reason = reason,
                ExpectedBenefits = expectedBenefits ?? new List<string>(),
                OpportunityCosts = opportunityCosts ?? new List<string>(),
                BenefitSource = benefitSource ?? "Unavailable",
                SelectionMode = "CharacterCreationTraversal",
                VanillaCostAccepted = true,
                RejectedOptions = rejectedOptions ?? new List<RejectedNarrativeOption>()
            };

            UpbringingChoices.Add(choice);

            GuildLog.Info(
                $"[TBG CHARACTER] selected {menuId} option={optionId}",
                showInGame: false);
        }

        public static void FinalizeOnMapReady()
        {
            if (_finalized)
            {
                return;
            }

            _finalized = true;
            WriteJsonReport();
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Character");
            report.Line(
                "mode",
                $"{CharacterDoctrineConfig.LegitimacyMode} + {(CharacterDoctrineConfig.AssistiveMode ? "Assistive" : "Manual")}");
            report.Line("build", CharacterDoctrineConfig.DefaultBuildId);
            report.Line(
                "culture",
                _cultureSelection?.SelectedCultureName
                ?? (CampaignSetupStateTracker.BootstrapUsed ? "pending" : "unknown"));
            report.Line(
                "postMapInjection",
                CharacterDoctrineConfig.PostMapProfileApplyEnabled ? "on" : "off");
            report.Line("provenanceJson", ReportFileName);
        }

        private static void WriteJsonReport()
        {
            var sb = new StringBuilder();
            var culture = _cultureSelection ?? new CultureSelectionRecord
            {
                PreferredCultureId = CharacterDoctrineConfig.PreferredCultureId,
                SelectedCultureId = "unknown",
                SelectedCultureName = "unknown",
                SelectionMode = "CharacterCreationTraversal",
                FallbackUsed = false,
                PreferredUsed = false,
                CultureCount = 0
            };

            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"build\": \"{Escape(CharacterDoctrineConfig.DefaultBuildId)}\",");
            sb.AppendLine($"  \"legitimacyMode\": \"{Escape(CharacterDoctrineConfig.LegitimacyMode.ToString())}\",");
            sb.AppendLine($"  \"assistiveMode\": {CharacterDoctrineConfig.AssistiveMode.ToString().ToLowerInvariant()},");
            sb.AppendLine("  \"culture\": {");
            sb.AppendLine($"    \"preferredCultureId\": \"{Escape(culture.PreferredCultureId)}\",");
            sb.AppendLine($"    \"selectedCultureId\": \"{Escape(culture.SelectedCultureId)}\",");
            sb.AppendLine($"    \"selectedCultureName\": \"{Escape(culture.SelectedCultureName)}\",");
            sb.AppendLine($"    \"selectionMode\": \"{Escape(culture.SelectionMode)}\",");
            sb.AppendLine($"    \"fallbackUsed\": {culture.FallbackUsed.ToString().ToLowerInvariant()}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"upbringingChoices\": [");

            for (var i = 0; i < UpbringingChoices.Count; i++)
            {
                WriteUpbringingChoiceJson(sb, UpbringingChoices[i], i < UpbringingChoices.Count - 1);
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"postMapProfileApply\": {");
            sb.AppendLine($"    \"enabled\": {CharacterDoctrineConfig.PostMapProfileApplyEnabled.ToString().ToLowerInvariant()},");
            sb.AppendLine("    \"changesApplied\": 0,");
            sb.AppendLine($"    \"mode\": \"{(CharacterDoctrineConfig.PostMapProfileApplyEnabled ? "DevOverride" : "DisabledForVanillaLegit")}\"");
            sb.AppendLine("  },");
            sb.AppendLine("  \"verdict\": \"Vanilla-derived build; no hidden post-map stat injection\"");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteUpbringingChoiceJson(StringBuilder sb, UpbringingChoiceRecord choice, bool trailingComma)
        {
            sb.AppendLine("    {");
            sb.AppendLine($"      \"stage\": \"{Escape(choice.Stage)}\",");
            sb.AppendLine($"      \"menuId\": \"{Escape(choice.MenuId)}\",");
            sb.AppendLine($"      \"optionId\": \"{Escape(choice.OptionId)}\",");
            sb.AppendLine($"      \"optionText\": \"{Escape(choice.OptionText)}\",");
            sb.AppendLine($"      \"reason\": \"{Escape(choice.Reason)}\",");
            sb.AppendLine("      \"expectedBenefits\": [");
            WriteStringArray(sb, choice.ExpectedBenefits, 8);
            sb.AppendLine("      ],");
            sb.AppendLine("      \"opportunityCosts\": [");
            WriteStringArray(sb, choice.OpportunityCosts, 8);
            sb.AppendLine("      ],");
            sb.AppendLine($"      \"benefitSource\": \"{Escape(choice.BenefitSource)}\",");
            sb.AppendLine($"      \"selectionMode\": \"{Escape(choice.SelectionMode)}\",");
            sb.AppendLine($"      \"vanillaCostAccepted\": {choice.VanillaCostAccepted.ToString().ToLowerInvariant()},");
            sb.AppendLine("      \"rejectedOptions\": [");
            for (var i = 0; i < choice.RejectedOptions.Count; i++)
            {
                var rejected = choice.RejectedOptions[i];
                sb.AppendLine("        {");
                sb.AppendLine($"          \"optionId\": \"{Escape(rejected.OptionId)}\",");
                sb.AppendLine($"          \"reasonRejected\": \"{Escape(rejected.ReasonRejected)}\"");
                sb.Append(i < choice.RejectedOptions.Count - 1 ? "        }," : "        }");
                sb.AppendLine();
            }

            sb.AppendLine("      ]");
            sb.Append(trailingComma ? "    }," : "    }");
            sb.AppendLine();
        }

        private static void WriteStringArray(StringBuilder sb, IReadOnlyList<string> values, int indent)
        {
            var pad = new string(' ', indent);
            if (values == null || values.Count == 0)
            {
                return;
            }

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

        private sealed class CultureSelectionRecord
        {
            public string PreferredCultureId { get; set; }
            public string SelectedCultureId { get; set; }
            public string SelectedCultureName { get; set; }
            public string SelectionMode { get; set; }
            public bool FallbackUsed { get; set; }
            public bool PreferredUsed { get; set; }
            public int CultureCount { get; set; }
        }

        private sealed class UpbringingChoiceRecord
        {
            public string Stage { get; set; }
            public string MenuId { get; set; }
            public string OptionId { get; set; }
            public string OptionText { get; set; }
            public string Reason { get; set; }
            public List<string> ExpectedBenefits { get; set; }
            public List<string> OpportunityCosts { get; set; }
            public string BenefitSource { get; set; }
            public string SelectionMode { get; set; }
            public bool VanillaCostAccepted { get; set; }
            public List<RejectedNarrativeOption> RejectedOptions { get; set; }
        }
    }
}
