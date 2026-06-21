using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterBuildVariantService
    {
        public const string BuildCharacterChoiceCatalogNowCommand = "BuildCharacterChoiceCatalogNow";
        public const string GenerateCharacterBuildCandidatesNowCommand = "GenerateCharacterBuildCandidatesNow";
        public const string SelectCharacterBuildBestNowCommand = "SelectCharacterBuildBestNow";
        public const string RunCharacterVisibleReplayNowCommand = "RunCharacterVisibleReplayNow";
        public const string DumpCharacterBuildSnapshotNowCommand = "DumpCharacterBuildSnapshotNow";

        private static readonly string RunsDirectory = Path.Combine(BasePath.Name, "character_runs");
        private static HeroBuildSnapshotCapture _lastSnapshot;
        private static CharacterBuildMutationAuditResult _lastAudit;
        private static bool _runFinalized;

        public static void ResetSession()
        {
            _lastSnapshot = null;
            _lastAudit = null;
            _runFinalized = false;
            CharacterBuildRouteSelector.ResetSession();
            CharacterBuildMutationAudit.ResetSession();
            CharacterCreationChoiceCatalogBuilder.ResetSession();
            CharacterVisibleReplayService.ResetSession();
        }

        public static void OnCampaignMapReady()
        {
            var hero = Hero.MainHero;
            _lastAudit = CharacterBuildMutationAudit.AuditAtMapReady(hero);
            _lastSnapshot = hero == null ? null : HeroBuildSnapshotCapture.CaptureFull(hero);

            if (CharacterBuildVariantConfigService.IsCatalogMode)
            {
                CharacterCreationChoiceCatalogBuilder.FinalizeCatalog();
            }

            if (CharacterBuildVariantConfigService.HasActiveVariantRoute
                || CharacterBuildVariantConfigService.IsReplayMode)
            {
                FinalizeVariantRun(hero);
            }

            if (CharacterBuildVariantConfigService.IsReplayMode)
            {
                CharacterVisibleReplayService.FinalizeOnMapReady();
            }

            CharacterBuildProvenanceService.SetObservedBuild(_lastSnapshot, _lastAudit);
        }

        public static DevCommandResult BuildCatalogNow()
        {
            CharacterCreationChoiceCatalogBuilder.FinalizeCatalog();
            if (!CharacterCreationChoiceCatalogBuilder.IsCatalogComplete())
            {
                InGameNotice.Info("TBG CHARACTER: catalog finalized with extraction gaps — review evidence.");
                return DevCommandResult.Blocked;
            }

            InGameNotice.Info("TBG CHARACTER: choice catalog written.");
            return DevCommandResult.Success;
        }

        public static DevCommandResult GenerateCandidatesNow()
        {
            if (!CharacterBuildCandidateGenerator.TryGenerateDefault(out var error))
            {
                DebugLogger.Test($"[TBG CHARACTER] candidate generation blocked: {error}", showInGame: false);
                InGameNotice.Info($"TBG CHARACTER: matrix blocked — {error}");
                return DevCommandResult.Blocked;
            }

            InGameNotice.Info("TBG CHARACTER: candidate matrix written.");
            return DevCommandResult.Success;
        }

        public static DevCommandResult SelectBestNow()
        {
            if (!CharacterBuildBestSelector.TrySelectBestDefault(out var error))
            {
                DebugLogger.Test($"[TBG CHARACTER] best selection blocked: {error}", showInGame: false);
                InGameNotice.Info($"TBG CHARACTER: best selection blocked — {error}");
                return DevCommandResult.Blocked;
            }

            InGameNotice.Info("TBG CHARACTER: best build selected.");
            return DevCommandResult.Success;
        }

        public static DevCommandResult RunVisibleReplayNow()
        {
            CharacterVisibleReplayService.ArmReplayFromBest();
            InGameNotice.Info("TBG CHARACTER: visible replay armed — restart with replay config.");
            return DevCommandResult.Success;
        }

        public static DevCommandResult DumpSnapshotNow()
        {
            if (!GameSessionState.IsCampaignMapReady || Hero.MainHero == null)
            {
                return DevCommandResult.Blocked;
            }

            _lastSnapshot = HeroBuildSnapshotCapture.CaptureFull(Hero.MainHero);
            WriteSnapshotDiagnostic(_lastSnapshot);
            InGameNotice.Info("TBG CHARACTER: build snapshot dumped.");
            return DevCommandResult.Success;
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Character Build Variant (008C)");
            report.Line("catalogMode", DevToolsConfig.CharacterBuildCatalogMode ? "on" : "off");
            report.Line("variantRoute", CharacterBuildVariantConfigService.HasActiveVariantRoute ? "armed" : "off");
            report.Line("catalogJson", CharacterCreationChoiceCatalogBuilder.CatalogFileName);
            report.Line("matrixJson", CharacterBuildCandidateGenerator.MatrixFileName);
            report.Line("bestJson", CharacterBuildBestSelector.BestFileName);
            report.Line("replayJson", CharacterVisibleReplayService.ReplayFileName);
        }

        private static void FinalizeVariantRun(Hero hero)
        {
            if (_runFinalized)
            {
                return;
            }

            _runFinalized = true;
            var config = CharacterBuildVariantConfigService.ActiveConfig;
            var blocked = CharacterBuildRouteSelector.BlockedReason
                ?? config?.BlockedReason;
            var verdict = string.IsNullOrEmpty(blocked)
                && _lastAudit != null
                && _lastAudit.Clean
                && !CharacterDoctrineConfig.PostMapProfileApplyEnabled
                ? "VanillaLegit"
                : "Failed";

            Directory.CreateDirectory(RunsDirectory);
            var candidateId = config?.CandidateId ?? "unknown";
            var path = Path.Combine(RunsDirectory, $"BlacksmithGuild_CharacterBuildRun_{candidateId}.json");
            WriteRunJson(path, config, hero, blocked, verdict);
        }

        private static void WriteRunJson(
            string path,
            CharacterBuildVariantConfig config,
            Hero hero,
            string blockedReason,
            string verdict)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"candidateId\": \"{Escape(config?.CandidateId)}\",");
            sb.AppendLine($"  \"selectedBuildMode\": \"{Escape(config?.SelectedBuildMode)}\",");
            sb.AppendLine($"  \"score\": {(config?.Score ?? 0d).ToString("0.##")},");
            sb.AppendLine($"  \"verdict\": \"{Escape(verdict)}\",");
            sb.AppendLine($"  \"blockedReason\": \"{Escape(blockedReason)}\",");
            sb.AppendLine($"  \"selectedCulture\": \"{Escape(CharacterDoctrineConfig.PreferredCultureId)}\",");
            sb.AppendLine("  \"route\": [");
            if (config != null)
            {
                for (var i = 0; i < config.Route.Count; i++)
                {
                    var step = config.Route[i];
                    sb.AppendLine("    {");
                    sb.AppendLine($"      \"stage\": \"{Escape(step.Stage)}\",");
                    sb.AppendLine($"      \"menuId\": \"{Escape(step.MenuId)}\",");
                    sb.AppendLine($"      \"optionId\": \"{Escape(step.OptionId)}\",");
                    sb.AppendLine($"      \"optionIndex\": {step.OptionIndex}");
                    sb.Append(i < config.Route.Count - 1 ? "    }," : "    }");
                    sb.AppendLine();
                }
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"selectedOptions\": [");
            CharacterBuildProvenanceService.AppendSelectedOptionsJson(sb, 4);
            sb.AppendLine("  ],");
            WriteSnapshotSection(sb, "resultingAttributes", _lastSnapshot?.Attributes);
            WriteSnapshotSection(sb, "resultingSkills", _lastSnapshot?.Skills);
            WriteSnapshotSection(sb, "resultingFocusPoints", _lastSnapshot?.Focus);
            sb.AppendLine("  \"postMapProfileApply\": {");
            sb.AppendLine($"    \"enabled\": {CharacterDoctrineConfig.PostMapProfileApplyEnabled.ToString().ToLowerInvariant()},");
            sb.AppendLine("    \"changesApplied\": 0");
            sb.AppendLine("  },");
            if (_lastAudit != null)
            {
                CharacterBuildMutationAudit.AppendMutationAuditJson(sb, _lastAudit, 2);
                sb.AppendLine(",");
            }
            else
            {
                sb.AppendLine("  \"mutationAudit\": { \"postMapProfileApply\": false },");
            }

            sb.AppendLine($"  \"effectSource\": \"RuntimeCatalog\"");
            sb.AppendLine("}");
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
            GuildLog.Info($"[TBG CHARACTER] variant run written {Path.GetFileName(path)} verdict={verdict}", showInGame: false);
        }

        private static void WriteSnapshotSection(
            StringBuilder sb,
            string propertyName,
            Dictionary<string, int> values)
        {
            sb.AppendLine($"  \"{propertyName}\": {{");
            if (values != null)
            {
                var index = 0;
                foreach (var entry in values)
                {
                    sb.Append($"    \"{Escape(entry.Key)}\": {entry.Value}");
                    sb.AppendLine(index < values.Count - 1 ? "," : string.Empty);
                    index++;
                }
            }

            sb.AppendLine("  },");
        }

        private static void WriteSnapshotDiagnostic(HeroBuildSnapshotCapture snapshot)
        {
            var path = Path.Combine(BasePath.Name, "BlacksmithGuild_CharacterBuildSnapshot.json");
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            WriteSnapshotSection(sb, "attributes", snapshot?.Attributes);
            WriteSnapshotSection(sb, "skills", snapshot?.Skills);
            WriteSnapshotSection(sb, "focus", snapshot?.Focus);
            sb.AppendLine($"  \"gold\": {snapshot?.Gold ?? 0},");
            sb.AppendLine($"  \"renown\": {snapshot?.Renown ?? 0},");
            sb.AppendLine($"  \"equipmentSummary\": \"{Escape(snapshot?.EquipmentSummary)}\"");
            sb.AppendLine("}");
            File.WriteAllText(path, sb.ToString(), Encoding.UTF8);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
