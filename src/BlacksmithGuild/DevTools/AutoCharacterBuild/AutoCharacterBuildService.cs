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
    public static class AutoCharacterBuildService
    {
        public const string ApplyAutoCharacterBuildCommand = "ApplyAutoCharacterBuild";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_AutoCharacterBuild.json");

        private static AutoCharacterBuildReport _lastReport = new AutoCharacterBuildReport();
        private static AutoCharacterBuildSummary _summary = new AutoCharacterBuildSummary();

        public static AutoCharacterBuildReport LastReport => _lastReport;
        public static AutoCharacterBuildSummary Summary => _summary;

        public static bool TryApplyQuickStartBootstrap()
        {
            if (!DevToolsConfig.AutoApplyCharacterBuild)
            {
                return false;
            }

            if (!CampaignSetupStateTracker.BootstrapUsed || CampaignSetupStateTracker.DevSaveLoadUsed)
            {
                return false;
            }

            return TryApply(Hero.MainHero, "quickstart-bootstrap", emitNotice: true);
        }

        public static DevCommandResult TryApplyFromCommand()
        {
            if (!TryApply(Hero.MainHero, "command", emitNotice: true))
            {
                return DevCommandResult.Failed;
            }

            return DevCommandResult.Success;
        }

        public static bool TryApply(Hero hero, string trigger, bool emitNotice)
        {
            var profile = AutoCharacterBuildProfile.CreateDefault();
            var report = new AutoCharacterBuildReport
            {
                Profile = profile.Name,
                Trigger = trigger,
                MainHeroReady = hero != null,
                CampaignReady = Campaign.Current != null && GameSessionState.IsCampaignMapReady,
                NormalSaveProtected = !string.Equals(trigger, "quickstart-bootstrap", StringComparison.Ordinal)
            };

            if (hero == null)
            {
                report.Errors.Add("MainHero is null.");
                return Finalize(report, applied: false, emitNotice);
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                report.Errors.Add("Campaign map not ready.");
                return Finalize(report, applied: false, emitNotice);
            }

            var before = CharacterBuildSnapshot.Capture(hero, profile);
            before.CopyAttributesTo(report.BeforeAttributes);
            before.CopyFocusTo(report.BeforeFocus);
            before.CopySkillsTo(report.BeforeSkills);

            ApplyAttributes(hero, profile, report);
            ApplyFocus(hero, profile, report);
            ApplySkillFloors(hero, profile, report);

            var after = CharacterBuildSnapshot.Capture(hero, profile);
            after.CopyAttributesTo(report.AfterAttributes);
            after.CopyFocusTo(report.AfterFocus);
            after.CopySkillsTo(report.AfterSkills);

            RecordChanges(report);
            var applied = report.Errors.Count == 0 || report.Changes.Count > 0;
            return Finalize(report, applied, emitNotice);
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Auto Character Build");
            if (!_summary.HasReport)
            {
                report.Line("status", "no build report cached (run ApplyAutoCharacterBuild)");
                report.Verdict(ReportVerdict.Info, "Run ApplyAutoCharacterBuild to shape MainHero");
                return;
            }

            report.Line("profile", _summary.Profile ?? "unknown");
            report.Line("applied", _summary.Applied.ToString().ToLowerInvariant());
            report.Line("trigger", _summary.Trigger ?? "unknown");
            report.Line("json", _summary.ReportPath);
            report.Verdict(
                _summary.Applied ? ReportVerdict.Pass : ReportVerdict.Warn,
                _summary.Applied
                    ? "ForgeQuartermasterWarlord build applied"
                    : "Build incomplete — inspect JSON report");
        }

        private static void ApplyAttributes(Hero hero, AutoCharacterBuildProfile profile, AutoCharacterBuildReport report)
        {
            foreach (var entry in profile.AttributeTargets)
            {
                var attribute = entry.Key;
                var target = entry.Value;
                var before = ReadAttribute(hero, attribute);

                if (!HeroProgressionDevTools.EnsureAttribute(hero, attribute, target))
                {
                    report.Errors.Add(
                        $"attribute {attribute.StringId}: failed to reach target {target} (before={before})");
                    continue;
                }

                var after = ReadAttribute(hero, attribute);
                if (after < target)
                {
                    report.Warnings.Add(
                        $"attribute {attribute.StringId}: below target {target} after apply (after={after})");
                }
            }
        }

        private static void ApplyFocus(Hero hero, AutoCharacterBuildProfile profile, AutoCharacterBuildReport report)
        {
            foreach (var entry in profile.FocusTargets)
            {
                var skill = entry.Key;
                var target = entry.Value;
                var before = ReadFocus(hero, skill);

                if (!HeroProgressionDevTools.EnsureFocus(hero, skill, target))
                {
                    report.Errors.Add($"focus {skill.StringId}: failed to reach target {target} (before={before})");
                    continue;
                }

                var after = ReadFocus(hero, skill);
                if (after < target)
                {
                    report.Warnings.Add($"focus {skill.StringId}: below target {target} after apply (after={after})");
                }
            }
        }

        private static void ApplySkillFloors(Hero hero, AutoCharacterBuildProfile profile, AutoCharacterBuildReport report)
        {
            foreach (var entry in profile.SkillFloorTargets)
            {
                var skill = entry.Key;
                var target = entry.Value;
                var before = ReadSkill(hero, skill);

                if (!HeroProgressionDevTools.EnsureSkillFloor(hero, skill, target))
                {
                    report.Errors.Add($"skill {skill.StringId}: failed to reach floor {target} (before={before})");
                    continue;
                }

                var after = ReadSkill(hero, skill);
                if (after < target)
                {
                    report.Warnings.Add($"skill {skill.StringId}: below floor {target} after apply (after={after})");
                }
            }
        }

        private static void RecordChanges(AutoCharacterBuildReport report)
        {
            AppendDictionaryChanges(report, "attribute", report.BeforeAttributes, report.AfterAttributes);
            AppendDictionaryChanges(report, "focus", report.BeforeFocus, report.AfterFocus);
            AppendDictionaryChanges(report, "skill", report.BeforeSkills, report.AfterSkills);
        }

        private static void AppendDictionaryChanges(
            AutoCharacterBuildReport report,
            string category,
            Dictionary<string, int> before,
            Dictionary<string, int> after)
        {
            foreach (var entry in after)
            {
                before.TryGetValue(entry.Key, out var beforeValue);
                if (beforeValue != entry.Value)
                {
                    report.Changes.Add($"{category}.{entry.Key}: {beforeValue} -> {entry.Value}");
                }
            }
        }

        private static bool Finalize(AutoCharacterBuildReport report, bool applied, bool emitNotice)
        {
            report.Applied = applied;
            _lastReport = report;
            WriteJsonReport(report);
            UpdateSummary(report);

            DebugLogger.Test(
                $"[TBG CHARACTER] profile={report.Profile} applied={applied} trigger={report.Trigger} changes={report.Changes.Count} warnings={report.Warnings.Count} errors={report.Errors.Count}",
                showInGame: false);

            if (applied && emitNotice)
            {
                InGameNotice.Info(
                    "TBG CHARACTER: ForgeQuartermasterWarlord applied — Steward/Crafting/Leadership seeded.");
            }

            return applied;
        }

        private static void UpdateSummary(AutoCharacterBuildReport report)
        {
            _summary = new AutoCharacterBuildSummary
            {
                HasReport = true,
                Profile = report.Profile,
                Applied = report.Applied,
                Trigger = report.Trigger,
                GeneratedAt = DateTime.Now
            };
            ForgeStatus.RecordAutoCharacterBuild(_summary);
        }

        private static void WriteJsonReport(AutoCharacterBuildReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, SerializeReport(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG CHARACTER] Failed to write build JSON: {ex.Message}", showInGame: false);
            }
        }

        private static string SerializeReport(AutoCharacterBuildReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"profile\": \"{Escape(report.Profile)}\",");
            builder.AppendLine($"  \"applied\": {report.Applied.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"trigger\": \"{Escape(report.Trigger)}\",");
            builder.AppendLine($"  \"mainHeroReady\": {report.MainHeroReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"campaignReady\": {report.CampaignReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"normalSaveProtected\": {report.NormalSaveProtected.ToString().ToLowerInvariant()},");
            AppendSnapshotSection(builder, "before", report.BeforeAttributes, report.BeforeFocus, report.BeforeSkills, trailingComma: true);
            AppendSnapshotSection(builder, "after", report.AfterAttributes, report.AfterFocus, report.AfterSkills, trailingComma: true);
            AppendStringArray(builder, "changes", report.Changes, trailingComma: true);
            AppendStringArray(builder, "warnings", report.Warnings, trailingComma: true);
            AppendStringArray(builder, "errors", report.Errors, trailingComma: false);
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendSnapshotSection(
            StringBuilder builder,
            string sectionName,
            Dictionary<string, int> attributes,
            Dictionary<string, int> focus,
            Dictionary<string, int> skills,
            bool trailingComma)
        {
            builder.AppendLine($"  \"{sectionName}\": {{");
            AppendIntDictionary(builder, "attributes", attributes, indent: 4, trailingComma: true);
            AppendIntDictionary(builder, "focus", focus, indent: 4, trailingComma: true);
            AppendIntDictionary(builder, "skills", skills, indent: 4, trailingComma: false);
            builder.Append("  }");
            builder.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static void AppendIntDictionary(
            StringBuilder builder,
            string propertyName,
            Dictionary<string, int> values,
            int indent,
            bool trailingComma)
        {
            var prefix = new string(' ', indent);
            builder.AppendLine($"{prefix}\"{propertyName}\": {{");

            var first = true;
            foreach (var entry in values)
            {
                if (!first)
                {
                    builder.AppendLine(",");
                }

                first = false;
                builder.Append($"{prefix}  \"{Escape(entry.Key)}\": {entry.Value}");
            }

            if (!first)
            {
                builder.AppendLine();
            }

            builder.Append($"{prefix}}}");
            builder.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static void AppendStringArray(
            StringBuilder builder,
            string propertyName,
            List<string> values,
            bool trailingComma)
        {
            builder.Append($"  \"{propertyName}\": [");
            for (var index = 0; index < values.Count; index++)
            {
                if (index > 0)
                {
                    builder.Append(", ");
                }

                builder.Append($"\"{Escape(values[index])}\"");
            }

            builder.AppendLine("]" + (trailingComma ? "," : string.Empty));
        }

        private static int ReadAttribute(Hero hero, CharacterAttribute attribute)
        {
            try
            {
                return hero.GetAttributeValue(attribute);
            }
            catch
            {
                return 0;
            }
        }

        private static int ReadFocus(Hero hero, SkillObject skill)
        {
            try
            {
                return hero.HeroDeveloper.GetFocus(skill);
            }
            catch
            {
                return 0;
            }
        }

        private static int ReadSkill(Hero hero, SkillObject skill)
        {
            try
            {
                return hero.GetSkillValue(skill);
            }
            catch
            {
                return 0;
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
