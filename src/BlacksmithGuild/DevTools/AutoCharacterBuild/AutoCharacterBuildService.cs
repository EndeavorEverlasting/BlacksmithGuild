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
        public const string ShowAutoCharacterBuildProfilesCommand = "ShowAutoCharacterBuildProfiles";
        public const string ShowAutoCharacterBuildProfileCommand = "ShowAutoCharacterBuildProfile";
        public const string SetAutoCharacterBuildForgeQuartermasterWarlordCommand =
            "SetAutoCharacterBuildForgeQuartermasterWarlord";
        public const string SetAutoCharacterBuildSmithEconomistCommand = "SetAutoCharacterBuildSmithEconomist";
        public const string SetAutoCharacterBuildKingdomFounderCommand = "SetAutoCharacterBuildKingdomFounder";
        public const string SetAutoCharacterBuildStewardSurgeonEngineerCommand =
            "SetAutoCharacterBuildStewardSurgeonEngineer";
        public const string SetAutoCharacterBuildWarCaptainCommand = "SetAutoCharacterBuildWarCaptain";
        public const string SetAutoCharacterBuildLightTouchVanillaPlusCommand =
            "SetAutoCharacterBuildLightTouchVanillaPlus";
        public const string SetAutoCharacterBuildShadowTraderCommand = "SetAutoCharacterBuildShadowTrader";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_AutoCharacterBuild.json");

        private static AutoCharacterBuildReport _lastReport = new AutoCharacterBuildReport();
        private static AutoCharacterBuildSummary _summary = new AutoCharacterBuildSummary();
        private static bool _hasAnnouncedSelectionNotice;
        private static bool _hasAttemptedBootstrapApply;

        public static AutoCharacterBuildReport LastReport => _lastReport;
        public static AutoCharacterBuildSummary Summary => _summary;

        static AutoCharacterBuildService()
        {
            RefreshStatusSnapshot();
        }

        public static void OnCampaignMapReady()
        {
            RefreshStatusSnapshot();
            CharacterDoctrineService.WriteJsonReport("MapReady");
            CharacterBuildProvenanceService.FinalizeOnMapReady();

            if (!_hasAttemptedBootstrapApply)
            {
                _hasAttemptedBootstrapApply = true;
                if (TryApplyQuickStartBootstrap())
                {
                    return;
                }
            }

            AnnounceSelectionNoticeOnce();
        }

        public static void RefreshStatusSnapshot()
        {
            var selected = AutoCharacterBuildProfileRegistry.GetSelectedProfile();
            _summary = new AutoCharacterBuildSummary
            {
                HasStatus = true,
                HasReport = _lastReport != null && !string.IsNullOrEmpty(_lastReport.ProfileId),
                SelectedProfileId = selected?.Id ?? AutoCharacterBuildProfileRegistry.DefaultProfileId,
                DefaultProfileId = AutoCharacterBuildProfileRegistry.DefaultProfileId,
                AutoApplyNewGame = DevToolsConfig.AutoApplyCharacterBuild,
                ContinueAutoApply = false,
                LastAppliedProfileId = string.IsNullOrEmpty(_lastReport?.ProfileId) ? null : _lastReport.ProfileId,
                LastAppliedTrigger = string.IsNullOrEmpty(_lastReport?.Trigger) ? null : _lastReport.Trigger,
                LastApplied = string.IsNullOrEmpty(_lastReport?.ProfileId) ? null : _lastReport?.Applied,
                AvailableProfilesCsv = AutoCharacterBuildProfileRegistry.GetAvailableProfilesCsv(),
                Profile = _lastReport?.Profile,
                Applied = _lastReport?.Applied ?? false,
                Trigger = _lastReport?.Trigger,
                ReportPath = "BlacksmithGuild_AutoCharacterBuild.json",
                GeneratedAt = ParseReportGeneratedAt(_lastReport)
            };

            ForgeStatus.RecordAutoCharacterBuild(_summary);
        }

        public static bool TryApplyQuickStartBootstrap()
        {
            if (CharacterDoctrineConfig.LegitimacyMode == CharacterLegitimacyMode.VanillaLegit)
            {
                GuildLog.Info("[TBG CHARACTER] postMapProfileApply skipped: VanillaLegit", showInGame: false);
                return false;
            }

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

        public static DevCommandResult ShowProfiles()
        {
            RefreshStatusSnapshot();
            DebugLogger.Test("[TBG CHARACTER] Available auto character build profiles:", showInGame: false);
            foreach (var profile in AutoCharacterBuildProfileRegistry.GetAllProfiles())
            {
                var marker = string.Equals(profile.Id, _summary.SelectedProfileId, StringComparison.OrdinalIgnoreCase)
                    ? " [selected]"
                    : profile.IsDefault ? " [default]" : string.Empty;
                DebugLogger.Test($"  - {profile.Id}{marker}: {profile.Description}", showInGame: false);
            }

            InGameNotice.Info($"TBG CHARACTER: profiles={_summary.AvailableProfilesCsv}");
            return DevCommandResult.Success;
        }

        public static DevCommandResult ShowSelectedProfile()
        {
            RefreshStatusSnapshot();
            var profile = AutoCharacterBuildProfileRegistry.GetSelectedProfile();
            DebugLogger.Test(
                $"[TBG CHARACTER] selected={profile.Id} default={AutoCharacterBuildProfileRegistry.DefaultProfileId} desc={profile.Description}",
                showInGame: false);
            InGameNotice.Info($"TBG CHARACTER: selected profile {profile.Id}.");
            return DevCommandResult.Success;
        }

        public static DevCommandResult SetSelectedProfileById(string profileId)
        {
            if (!AutoCharacterBuildProfileRegistry.SetSelectedProfile(profileId, out var error))
            {
                DebugLogger.Test($"[TBG CHARACTER] set profile failed: {error}", showInGame: false);
                return DevCommandResult.Failed;
            }

            RefreshStatusSnapshot();
            var profile = AutoCharacterBuildProfileRegistry.GetSelectedProfile();
            DebugLogger.Test($"[TBG CHARACTER] selected profile set to {profile.Id}", showInGame: false);
            InGameNotice.Info($"TBG CHARACTER: selected profile {profile.Id}.");
            return DevCommandResult.Success;
        }

        public static bool TryApply(Hero hero, string trigger, bool emitNotice)
        {
            var profile = AutoCharacterBuildProfileRegistry.GetSelectedProfile();
            var report = new AutoCharacterBuildReport
            {
                ProfileId = profile.Id,
                Profile = profile.DisplayName,
                ProfileDescription = profile.Description,
                SelectedProfileAtApply = profile.Id,
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
            RefreshStatusSnapshot();

            report.Section("Auto Character Build");
            report.Line("mode", CharacterDoctrineConfig.LegitimacyMode == CharacterLegitimacyMode.DevOverride
                ? "DevOverride"
                : "VanillaLegit (profile apply disabled)");
            report.Line("selectedProfile", _summary.SelectedProfileId ?? "unknown");
            report.Line("defaultProfile", _summary.DefaultProfileId ?? AutoCharacterBuildProfileRegistry.DefaultProfileId);
            report.Line("autoApplyNewGame", _summary.AutoApplyNewGame ? "on" : "off");
            report.Line("continueAutoApply", _summary.ContinueAutoApply ? "on" : "off");
            report.Line(
                "lastApplied",
                string.IsNullOrEmpty(_summary.LastAppliedProfileId)
                    ? "none"
                    : $"{_summary.LastAppliedProfileId} ({_summary.LastAppliedTrigger})");
            report.Line("availableProfiles", _summary.AvailableProfilesCsv ?? string.Empty);
            report.Line("commandHint", $"{ApplyAutoCharacterBuildCommand} (DevOverride)");

            if (_summary.HasReport)
            {
                report.Line("lastApplyProfile", _summary.Profile ?? "unknown");
                report.Line("lastApplyApplied", (_summary.LastApplied ?? false).ToString().ToLowerInvariant());
                report.Line("json", _summary.ReportPath);
            }

            report.Verdict(
                _summary.HasReport && (_summary.LastApplied ?? false)
                    ? ReportVerdict.Pass
                    : ReportVerdict.Info,
                _summary.HasReport && (_summary.LastApplied ?? false)
                    ? $"{_summary.LastAppliedProfileId} build applied (DevOverride)"
                    : CharacterDoctrineConfig.LegitimacyMode == CharacterLegitimacyMode.VanillaLegit
                        ? "VanillaLegit: no post-map injection; use ApplyAutoCharacterBuild for DevOverride testing"
                        : "Run ApplyAutoCharacterBuild to shape MainHero (DevOverride)");
        }

        private static void AnnounceSelectionNoticeOnce()
        {
            if (_hasAnnouncedSelectionNotice)
            {
                return;
            }

            _hasAnnouncedSelectionNotice = true;
            if (CharacterDoctrineConfig.LegitimacyMode == CharacterLegitimacyMode.VanillaLegit)
            {
                InGameNotice.Info(
                    $"TBG CHARACTER: {CharacterDoctrineConfig.DefaultBuildId} | VanillaLegit + Assistive | postMapInjection off.");
                return;
            }

            var selected = AutoCharacterBuildProfileRegistry.GetSelectedProfile();
            InGameNotice.Info(
                $"TBG CHARACTER: DevOverride profile {selected.DisplayName} selected. Run ApplyAutoCharacterBuild to apply.");
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
            RefreshStatusSnapshot();

            DebugLogger.Test(
                $"[TBG CHARACTER] profile={report.ProfileId} applied={applied} trigger={report.Trigger} changes={report.Changes.Count} warnings={report.Warnings.Count} errors={report.Errors.Count}",
                showInGame: false);

            if (applied && emitNotice)
            {
                InGameNotice.Info(BuildAppliedNotice(report));
            }

            return applied;
        }

        private static string BuildAppliedNotice(AutoCharacterBuildReport report)
        {
            if (string.Equals(report.ProfileId, AutoCharacterBuildProfileRegistry.DefaultProfileId, StringComparison.OrdinalIgnoreCase))
            {
                return "TBG CHARACTER: ForgeQuartermasterWarlord applied — Steward/Crafting/Leadership seeded.";
            }

            return $"TBG CHARACTER: {report.ProfileId} applied — {report.ProfileDescription}";
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
            builder.AppendLine($"  \"profileId\": \"{Escape(report.ProfileId)}\",");
            builder.AppendLine($"  \"profile\": \"{Escape(report.Profile)}\",");
            builder.AppendLine($"  \"profileDescription\": \"{Escape(report.ProfileDescription)}\",");
            builder.AppendLine($"  \"selectedProfileAtApply\": \"{Escape(report.SelectedProfileAtApply)}\",");
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

        private static DateTime? ParseReportGeneratedAt(AutoCharacterBuildReport report)
        {
            if (report == null || string.IsNullOrEmpty(report.ProfileId))
            {
                return null;
            }

            return DateTime.TryParse(report.GeneratedUtc, out var parsed) ? parsed : DateTime.Now;
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
