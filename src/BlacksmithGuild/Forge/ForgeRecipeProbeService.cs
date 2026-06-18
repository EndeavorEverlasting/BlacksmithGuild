using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.CampaignBehaviors;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class ForgeRecipeProbeService
    {
        public const string ProbeForgeRecipesCommand = "ProbeForgeRecipes";
        public const string ReportFileName = "BlacksmithGuild_RecipeProbe.json";
        private const int MaxMatchedTypes = 50;
        private const int MaxTemplateSample = 20;

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, ReportFileName);

        private static readonly string[] TypeNameTokens =
        {
            "Smith", "Craft", "Forge", "Workshop", "Recipe"
        };

        private static readonly string[] KnownEntryPointTypeNames =
        {
            "TaleWorlds.CampaignSystem.CampaignBehaviors.CraftingCampaignBehavior, TaleWorlds.CampaignSystem",
            "TaleWorlds.Core.CraftingTemplate, TaleWorlds.Core",
            "TaleWorlds.Core.Crafting, TaleWorlds.Core",
            "Helpers.CraftingHelper, TaleWorlds.CampaignSystem",
            "TaleWorlds.CampaignSystem.CraftingSystem.CraftingOrder, TaleWorlds.CampaignSystem"
        };

        private static ForgeRecipeProbeSummary _summary = new ForgeRecipeProbeSummary();
        private static ForgeRecipeProbeReport _cachedReport = new ForgeRecipeProbeReport();
        private static bool _summaryRecorded;

        public static ForgeRecipeProbeSummary Summary => _summary;

        public static ForgeRecipeProbeResult RunProbe()
        {
            var report = new ForgeRecipeProbeReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                ProbeStatus = "Unavailable",
                Detail = "Campaign not ready for recipe probe."
            };

            try
            {
                if (Campaign.Current == null || Hero.MainHero == null)
                {
                    report.Detail = "Campaign not ready for recipe probe.";
                    return BuildResult(report);
                }

                if (!GameSessionState.IsCampaignMapReady)
                {
                    report.Detail = "Campaign map not ready for recipe probe.";
                    return BuildResult(report);
                }

                report.CampaignReady = true;
                ProbeSmithingSkill(report);
                ScanMatchedTypes(report);
                ProbeKnownEntryPoints(report);
                ProbeCraftingTemplates(report);
                ProbeCraftingBehavior(report);

                if (report.Errors.Count > 0)
                {
                    report.ProbeStatus = "Error";
                    report.Detail = $"Probe completed with {report.Errors.Count} error(s).";
                }
                else if (report.TemplateCount > 0 || report.MatchedTypeCount > 0)
                {
                    report.ProbeStatus = "Ok";
                    report.Detail =
                        $"Found {report.TemplateCount} crafting templates and {report.MatchedTypeCount} matching types; real candidate mapping available via SetForgeCandidateSourceReal.";
                }
                else
                {
                    report.ProbeStatus = "Empty";
                    report.Detail = "No crafting templates or matching types discovered.";
                }
            }
            catch (Exception ex)
            {
                report.ProbeStatus = "Error";
                report.Detail = ex.Message;
                report.Errors.Add(ex.ToString());
            }

            return BuildResult(report);
        }

        public static bool RunProbeNow(string source = ProbeForgeRecipesCommand)
        {
            try
            {
                var result = RunProbe();
                PublishProbeResult(result, source, writeStructuredReport: true);

                DebugLogger.Test(
                    $"[TBG FORGE] ProbeForgeRecipes complete status={result.Report.ProbeStatus} templates={result.Report.TemplateCount} types={result.Report.MatchedTypeCount}",
                    showInGame: false);

                return !string.Equals(result.Report.ProbeStatus, "Error", StringComparison.OrdinalIgnoreCase);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] ProbeForgeRecipes failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static void PublishProbeResult(
            ForgeRecipeProbeResult result,
            string source,
            bool writeStructuredReport)
        {
            _cachedReport = result.Report;
            WriteJsonReport(result.Report);
            UpdateSummary(result.Report);
            ForgeStatus.RecordRecipeProbe(_summary);

            if (writeStructuredReport)
            {
                WriteStructuredReport(source, result.Report);
            }
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Recipe Probe");
            if (!_summaryRecorded || !_summary.HasProbe)
            {
                report.Line("status", "no probe cached (run ProbeForgeRecipes)");
                report.Verdict(ReportVerdict.Info, "Run ProbeForgeRecipes to cache API recon results");
                return;
            }

            report.Line("probeStatus", _summary.ProbeStatus);
            report.Line("templates", _summary.TemplateCount.ToString());
            report.Line("matchedTypes", _summary.MatchedTypeCount.ToString());
            if (_summary.CraftingOrderCount.HasValue)
            {
                report.Line("craftingOrders", _summary.CraftingOrderCount.Value.ToString());
            }

            if (_summary.SmithingSkillLevel.HasValue)
            {
                report.Line("smithingSkill", _summary.SmithingSkillLevel.Value.ToString());
            }

            report.Line("json", _summary.ReportPath);
            report.Line("detail", _summary.Detail ?? string.Empty);

            if (string.Equals(_summary.ProbeStatus, "Ok", StringComparison.OrdinalIgnoreCase))
            {
                report.Verdict(ReportVerdict.Pass, "Recipe API probe succeeded (read-only recon)");
            }
            else if (string.Equals(_summary.ProbeStatus, "Empty", StringComparison.OrdinalIgnoreCase))
            {
                report.Verdict(ReportVerdict.Warn, "Probe ran but found no templates");
            }
            else
            {
                report.Verdict(ReportVerdict.Info, "Probe not run or unavailable");
            }
        }

        private static ForgeRecipeProbeResult BuildResult(ForgeRecipeProbeReport report)
        {
            return new ForgeRecipeProbeResult
            {
                Report = report,
                Candidates = Array.Empty<ForgeCandidate>()
            };
        }

        private static void ProbeSmithingSkill(ForgeRecipeProbeReport report)
        {
            try
            {
                report.SmithingSkillLevel = Hero.MainHero.GetSkillValue(DefaultSkills.Crafting);
            }
            catch (Exception ex)
            {
                report.Errors.Add($"smithing skill read failed: {ex.Message}");
            }
        }

        private static void ScanMatchedTypes(ForgeRecipeProbeReport report)
        {
            var matched = new List<string>();

            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                var name = assembly.GetName().Name ?? string.Empty;
                if (!name.StartsWith("TaleWorlds", StringComparison.OrdinalIgnoreCase)
                    && !name.StartsWith("SandBox", StringComparison.OrdinalIgnoreCase)
                    && !name.Equals("SandBox", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                Type[] types;
                try
                {
                    types = assembly.GetTypes();
                }
                catch (ReflectionTypeLoadException ex)
                {
                    types = ex.Types.Where(t => t != null).ToArray();
                }
                catch
                {
                    continue;
                }

                foreach (var type in types)
                {
                    if (type == null)
                    {
                        continue;
                    }

                    var fullName = type.FullName ?? type.Name;
                    if (!TypeNameTokens.Any(token => fullName.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0))
                    {
                        continue;
                    }

                    matched.Add(fullName);
                    if (matched.Count >= MaxMatchedTypes)
                    {
                        break;
                    }
                }

                if (matched.Count >= MaxMatchedTypes)
                {
                    break;
                }
            }

            report.MatchedTypes = matched;
            report.MatchedTypeCount = matched.Count;
        }

        private static void ProbeKnownEntryPoints(ForgeRecipeProbeReport report)
        {
            foreach (var typeName in KnownEntryPointTypeNames)
            {
                try
                {
                    var type = Type.GetType(typeName);
                    report.EntryPoints.Add(new ForgeRecipeProbeEntryPoint
                    {
                        Name = typeName.Split(',')[0],
                        Status = type != null ? "found" : "missing",
                        Detail = type != null ? type.Assembly.GetName().Name : "Type.GetType returned null"
                    });
                }
                catch (Exception ex)
                {
                    report.EntryPoints.Add(new ForgeRecipeProbeEntryPoint
                    {
                        Name = typeName.Split(',')[0],
                        Status = "error",
                        Detail = ex.Message
                    });
                }
            }
        }

        private static void ProbeCraftingTemplates(ForgeRecipeProbeReport report)
        {
            try
            {
                var allProperty = typeof(CraftingTemplate).GetProperty(
                    "All",
                    BindingFlags.Public | BindingFlags.Static);
                if (allProperty == null)
                {
                    report.Errors.Add("CraftingTemplate.All property not found.");
                    return;
                }

                if (!(allProperty.GetValue(null) is IEnumerable<CraftingTemplate> templates))
                {
                    report.Errors.Add("CraftingTemplate.All is null or not enumerable.");
                    return;
                }

                var list = templates.Where(t => t != null).ToList();
                report.TemplateCount = list.Count;

                foreach (var template in list.Take(MaxTemplateSample))
                {
                    report.TemplateSample.Add(new ForgeRecipeProbeTemplateSample
                    {
                        Id = template.StringId ?? template.Id.ToString(),
                        ItemType = template.ItemType.ToString()
                    });
                }
            }
            catch (Exception ex)
            {
                report.Errors.Add($"CraftingTemplate probe failed: {ex.Message}");
            }
        }

        private static void ProbeCraftingBehavior(ForgeRecipeProbeReport report)
        {
            try
            {
                var behavior = Campaign.Current.GetCampaignBehavior<CraftingCampaignBehavior>();
                if (behavior == null)
                {
                    report.EntryPoints.Add(new ForgeRecipeProbeEntryPoint
                    {
                        Name = "CraftingCampaignBehavior.Instance",
                        Status = "missing",
                        Detail = "GetCampaignBehavior returned null"
                    });
                    return;
                }

                report.EntryPoints.Add(new ForgeRecipeProbeEntryPoint
                {
                    Name = "CraftingCampaignBehavior.Instance",
                    Status = "found",
                    Detail = "Campaign behavior resolved"
                });

                var orders = behavior.CraftingOrders;
                report.CraftingOrderCount = orders?.Count ?? 0;
            }
            catch (Exception ex)
            {
                report.Errors.Add($"CraftingCampaignBehavior probe failed: {ex.Message}");
            }
        }

        private static void UpdateSummary(ForgeRecipeProbeReport report)
        {
            _summary = new ForgeRecipeProbeSummary
            {
                HasProbe = true,
                ProbeStatus = report.ProbeStatus,
                Detail = report.Detail,
                MatchedTypeCount = report.MatchedTypeCount,
                TemplateCount = report.TemplateCount,
                CraftingOrderCount = report.CraftingOrderCount,
                SmithingSkillLevel = report.SmithingSkillLevel,
                ReportPath = ReportFileName,
                GeneratedAt = DateTime.Now
            };
            _summaryRecorded = true;
        }

        private static void WriteJsonReport(ForgeRecipeProbeReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, SerializeReport(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] Failed to write recipe probe JSON: {ex.Message}", showInGame: false);
            }
        }

        private static void WriteStructuredReport(string source, ForgeRecipeProbeReport probeReport)
        {
            var report = ReportFormatter.BeginReport("FORGE RECIPE PROBE", source, "forge-recipe-probe");

            report.Section("Probe");
            report.Line("status", probeReport.ProbeStatus);
            report.Line("campaignReady", probeReport.CampaignReady.ToString().ToLowerInvariant());
            report.Line("matchedTypes", probeReport.MatchedTypeCount.ToString());
            report.Line("templates", probeReport.TemplateCount.ToString());
            if (probeReport.CraftingOrderCount.HasValue)
            {
                report.Line("craftingOrders", probeReport.CraftingOrderCount.Value.ToString());
            }

            if (probeReport.SmithingSkillLevel.HasValue)
            {
                report.Line("smithingSkill", probeReport.SmithingSkillLevel.Value.ToString());
            }

            report.Line("detail", probeReport.Detail ?? string.Empty);

            report.Section("Entry Points");
            foreach (var entry in probeReport.EntryPoints.Take(10))
            {
                report.Line(entry.Name, $"{entry.Status} — {entry.Detail}");
            }

            if (probeReport.TemplateSample.Count > 0)
            {
                report.Section("Template Sample");
                var index = 1;
                foreach (var sample in probeReport.TemplateSample.Take(5))
                {
                    report.Line(index.ToString(), $"{sample.Id} ({sample.ItemType})");
                    index++;
                }
            }

            report.Section("Evidence");
            report.Line("json", ReportFileName);

            if (probeReport.Errors.Count > 0)
            {
                report.Verdict(ReportVerdict.Warn, $"{probeReport.Errors.Count} probe error(s) — see JSON");
            }
            else if (string.Equals(probeReport.ProbeStatus, "Ok", StringComparison.OrdinalIgnoreCase))
            {
                report.Verdict(ReportVerdict.Pass, "Read-only recipe API recon succeeded");
            }
            else
            {
                report.Verdict(ReportVerdict.Info, probeReport.Detail ?? "Probe complete");
            }

            report.SummaryLine(
                $"status={probeReport.ProbeStatus} templates={probeReport.TemplateCount} types={probeReport.MatchedTypeCount}");

            report.EndReport(
                emitInGame: string.Equals(source, ProbeForgeRecipesCommand, StringComparison.Ordinal),
                emitToFile: true);
        }

        private static string SerializeReport(ForgeRecipeProbeReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"probeStatus\": \"{Escape(report.ProbeStatus)}\",");
            builder.AppendLine($"  \"detail\": \"{Escape(report.Detail)}\",");
            builder.AppendLine($"  \"campaignReady\": {report.CampaignReady.ToString().ToLowerInvariant()},");
            builder.AppendLine(
                $"  \"smithingSkillLevel\": {(report.SmithingSkillLevel.HasValue ? report.SmithingSkillLevel.Value.ToString() : "null")},");
            builder.AppendLine($"  \"matchedTypeCount\": {report.MatchedTypeCount},");
            builder.AppendLine($"  \"templateCount\": {report.TemplateCount},");
            builder.AppendLine(
                $"  \"craftingOrderCount\": {(report.CraftingOrderCount.HasValue ? report.CraftingOrderCount.Value.ToString() : "null")},");

            builder.AppendLine("  \"matchedTypes\": [");
            AppendStringArray(builder, report.MatchedTypes, trailingComma: true);

            builder.AppendLine("  \"entryPoints\": [");
            for (var i = 0; i < report.EntryPoints.Count; i++)
            {
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                var entry = report.EntryPoints[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"name\": \"{Escape(entry.Name)}\",");
                builder.AppendLine($"      \"status\": \"{Escape(entry.Status)}\",");
                builder.AppendLine($"      \"detail\": \"{Escape(entry.Detail)}\"");
                builder.Append("    }");
            }

            builder.AppendLine();
            builder.AppendLine("  ],");

            builder.AppendLine("  \"templateSample\": [");
            for (var i = 0; i < report.TemplateSample.Count; i++)
            {
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                var sample = report.TemplateSample[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"id\": \"{Escape(sample.Id)}\",");
                builder.AppendLine($"      \"itemType\": \"{Escape(sample.ItemType)}\"");
                builder.Append("    }");
            }

            builder.AppendLine();
            builder.AppendLine("  ],");

            builder.AppendLine("  \"errors\": [");
            AppendStringArray(builder, report.Errors, trailingComma: false);

            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendStringArray(StringBuilder builder, IReadOnlyList<string> values, bool trailingComma)
        {
            for (var i = 0; i < values.Count; i++)
            {
                builder.Append($"    \"{Escape(values[i])}\"");
                if (i < values.Count - 1)
                {
                    builder.AppendLine(",");
                }
                else
                {
                    builder.AppendLine();
                }
            }

            builder.Append("  ]");
            builder.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
