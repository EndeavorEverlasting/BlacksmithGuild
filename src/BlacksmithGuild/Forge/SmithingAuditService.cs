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
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class SmithingAuditService
    {
        public const string ProbeSmithingAuditCommand = "ProbeSmithingAudit";
        public const string ProbeSmithingRefineApiCommand = "ProbeSmithingRefineApi";
        public const string ReportFileName = "BlacksmithGuild_SmithingAudit.json";
        public const string RefineProbeReportFileName = "BlacksmithGuild_SmithingRefineProbe.json";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, ReportFileName);

        private static readonly string RefineProbeReportPath =
            Path.Combine(BasePath.Name, RefineProbeReportFileName);

        private static readonly string[] StaminaMemberTokens =
        {
            "Stamina", "Smith", "Craft", "Forge", "Energy", "Fatigue"
        };

        public static bool RunAuditNow(string source = ProbeSmithingAuditCommand)
        {
            try
            {
                var report = BuildReport();
                WriteJsonReport(report);

                DebugLogger.Test(
                    $"[TBG SMITHING] ProbeSmithingAudit status={report.AuditStatus} heroes={report.HeroCount} staminaHints={report.StaminaMemberHints.Count}",
                    showInGame: false);

                InGameNotice.Info(
                    ModDisplay.CompactLine(
                        "Smithing Audit",
                        $"{report.AuditStatus} heroes={report.HeroCount} hints={report.StaminaMemberHints.Count}"));
                InGameNotice.Info(ModDisplay.CompactLine("Smithing Audit", $"json={ReportFileName}"));

                return !string.Equals(report.AuditStatus, "Error", StringComparison.OrdinalIgnoreCase);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG SMITHING] ProbeSmithingAudit failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool RunRefineApiProbeNow(string source = ProbeSmithingRefineApiCommand)
        {
            try
            {
                if (Campaign.Current == null || !GameSessionState.IsCampaignMapReady)
                {
                    DebugLogger.Test("[TBG SMITHING] ProbeSmithingRefineApi blocked: campaign map not ready.", showInGame: false);
                    return false;
                }

                var mapped = SmithingRefineApi.RunRefineApiProbe(out var detail);
                var canRefine = SmithingStaminaReader.CanInvokeRefineCharcoal(Hero.MainHero, out var refineDetail);
                WriteRefineProbeJson(mapped, detail, canRefine, refineDetail);

                DebugLogger.Test(
                    $"[TBG SMITHING] ProbeSmithingRefineApi mapped={mapped} canRefine={canRefine} detail={detail}",
                    showInGame: false);

                InGameNotice.Info(
                    ModDisplay.CompactLine(
                        "Smithing Refine Probe",
                        mapped
                            ? $"DoRefinement mapped; canRefine={canRefine}"
                            : $"blocked: {detail}"));
                InGameNotice.Info(ModDisplay.CompactLine("Smithing Refine Probe", $"json={RefineProbeReportFileName}"));

                return mapped;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG SMITHING] ProbeSmithingRefineApi failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static void WriteRefineProbeJson(
            bool mapped,
            string detail,
            bool canRefine,
            string refineDetail)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"doRefinementMapped\": {mapped.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"canRefineCharcoal\": {canRefine.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"detail\": \"{Escape(detail ?? string.Empty)}\",");
            sb.AppendLine($"  \"refineDetail\": \"{Escape(refineDetail ?? string.Empty)}\",");
            sb.AppendLine("  \"methodHints\": [");

            var hints = SmithingRefineApi.LastProbeHints;
            for (var i = 0; i < hints.Count; i++)
            {
                sb.Append($"    \"{Escape(hints[i])}\"");
                sb.AppendLine(i < hints.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");

            File.WriteAllText(RefineProbeReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static SmithingAuditReport BuildReport()
        {
            var report = new SmithingAuditReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                AuditStatus = "Unavailable",
                Detail = "Campaign not ready."
            };

            if (Campaign.Current == null || Hero.MainHero == null)
            {
                return report;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                report.Detail = "Campaign map not ready for smithing audit.";
                return report;
            }

            report.CampaignReady = true;

            try
            {
                AuditPartyHeroes(report);
                AuditMainHeroMembers(report, Hero.MainHero);
                AuditCraftingBehavior(report);
                ScanStaminaRelatedTypes(report);

                report.AuditStatus = report.Errors.Count > 0 ? "Partial" : "Ok";
                report.Detail =
                    $"Audited {report.HeroCount} party hero(es); {report.StaminaMemberHints.Count} stamina-related member hint(s).";
            }
            catch (Exception ex)
            {
                report.AuditStatus = "Error";
                report.Detail = ex.Message;
                report.Errors.Add(ex.ToString());
            }

            return report;
        }

        private static void AuditPartyHeroes(SmithingAuditReport report)
        {
            var party = MobileParty.MainParty;
            if (party?.MemberRoster == null)
            {
                report.Errors.Add("MainParty.MemberRoster unavailable.");
                return;
            }

            foreach (var element in party.MemberRoster.GetTroopRoster())
            {
                var hero = element.Character?.HeroObject;
                if (hero == null)
                {
                    continue;
                }

                var entry = new SmithingHeroAuditEntry
                {
                    Name = hero.Name?.ToString() ?? "(unnamed)",
                    IsMainHero = hero == Hero.MainHero,
                    CraftingSkill = SafeSkill(hero, DefaultSkills.Crafting),
                    Gold = hero.Gold
                };

                report.Heroes.Add(entry);
            }

            report.HeroCount = report.Heroes.Count;
        }

        private static int SafeSkill(Hero hero, SkillObject skill)
        {
            try
            {
                return hero.GetSkillValue(skill);
            }
            catch
            {
                return -1;
            }
        }

        private static void AuditMainHeroMembers(SmithingAuditReport report, Hero hero)
        {
            if (hero == null)
            {
                return;
            }

            foreach (var member in hero.GetType().GetMembers(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var name = member.Name ?? string.Empty;
                if (!StaminaMemberTokens.Any(token => name.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0))
                {
                    continue;
                }

                report.StaminaMemberHints.Add($"Hero.{name} ({member.MemberType})");
            }
        }

        private static void AuditCraftingBehavior(SmithingAuditReport report)
        {
            try
            {
                var behavior = Campaign.Current.GetCampaignBehavior<CraftingCampaignBehavior>();
                if (behavior == null)
                {
                    report.Errors.Add("CraftingCampaignBehavior not found on campaign.");
                    return;
                }

                report.CraftingBehaviorType = behavior.GetType().FullName;

                foreach (var member in behavior.GetType().GetMembers(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
                {
                    var name = member.Name ?? string.Empty;
                    if (!StaminaMemberTokens.Any(token => name.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0)
                        && name.IndexOf("Refin", StringComparison.OrdinalIgnoreCase) < 0
                        && name.IndexOf("Smelt", StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        continue;
                    }

                    report.StaminaMemberHints.Add($"CraftingCampaignBehavior.{name} ({member.MemberType})");
                }
            }
            catch (Exception ex)
            {
                report.Errors.Add($"CraftingCampaignBehavior audit failed: {ex.Message}");
            }
        }

        private static void ScanStaminaRelatedTypes(SmithingAuditReport report)
        {
            const int maxTypes = 30;
            var count = 0;

            foreach (var assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                var assemblyName = assembly.GetName().Name ?? string.Empty;
                if (!assemblyName.StartsWith("TaleWorlds", StringComparison.OrdinalIgnoreCase)
                    && !assemblyName.StartsWith("SandBox", StringComparison.OrdinalIgnoreCase))
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
                    if (type == null || count >= maxTypes)
                    {
                        break;
                    }

                    var typeName = type.Name ?? string.Empty;
                    if (!StaminaMemberTokens.Any(token => typeName.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0))
                    {
                        continue;
                    }

                    report.StaminaRelatedTypes.Add(type.FullName);
                    count++;
                }
            }
        }

        private static void WriteJsonReport(SmithingAuditReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"auditStatus\": \"{Escape(report.AuditStatus)}\",");
            sb.AppendLine($"  \"detail\": \"{Escape(report.Detail)}\",");
            sb.AppendLine($"  \"campaignReady\": {report.CampaignReady.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"heroCount\": {report.HeroCount},");
            sb.AppendLine($"  \"craftingBehaviorType\": \"{Escape(report.CraftingBehaviorType ?? string.Empty)}\",");
            sb.AppendLine("  \"heroes\": [");

            for (var i = 0; i < report.Heroes.Count; i++)
            {
                var h = report.Heroes[i];
                var comma = i < report.Heroes.Count - 1 ? "," : string.Empty;
                sb.AppendLine(
                    $"    {{ \"name\": \"{Escape(h.Name)}\", \"isMainHero\": {h.IsMainHero.ToString().ToLowerInvariant()}, \"craftingSkill\": {h.CraftingSkill}, \"gold\": {h.Gold} }}{comma}");
            }

            sb.AppendLine("  ],");
            WriteStringArray(sb, "staminaMemberHints", report.StaminaMemberHints);
            sb.AppendLine(",");
            WriteStringArray(sb, "staminaRelatedTypes", report.StaminaRelatedTypes);
            sb.AppendLine(",");
            WriteStringArray(sb, "errors", report.Errors, trailingComma: false);
            sb.AppendLine();
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteStringArray(StringBuilder sb, string key, List<string> values, bool trailingComma = true)
        {
            sb.Append($"  \"{key}\": [");
            for (var i = 0; i < values.Count; i++)
            {
                if (i > 0)
                {
                    sb.Append(", ");
                }

                sb.Append($"\"{Escape(values[i])}\"");
            }

            sb.Append("]");
            if (trailingComma)
            {
                sb.AppendLine(",");
            }
            else
            {
                sb.AppendLine();
            }
        }

        private static string Escape(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            return value.Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private sealed class SmithingAuditReport
        {
            public string GeneratedUtc { get; set; }
            public string AuditStatus { get; set; }
            public string Detail { get; set; }
            public bool CampaignReady { get; set; }
            public int HeroCount { get; set; }
            public string CraftingBehaviorType { get; set; }
            public List<SmithingHeroAuditEntry> Heroes { get; } = new List<SmithingHeroAuditEntry>();
            public List<string> StaminaMemberHints { get; } = new List<string>();
            public List<string> StaminaRelatedTypes { get; } = new List<string>();
            public List<string> Errors { get; } = new List<string>();
        }

        private sealed class SmithingHeroAuditEntry
        {
            public string Name { get; set; }
            public bool IsMainHero { get; set; }
            public int CraftingSkill { get; set; }
            public int Gold { get; set; }
        }
    }
}
