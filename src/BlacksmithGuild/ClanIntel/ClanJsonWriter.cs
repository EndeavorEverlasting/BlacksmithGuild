using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.ClanIntel
{
    public static class ClanJsonWriter
    {
        public const string ClanContextFileName = "BlacksmithGuild_ClanContext.json";
        public const string NobleNetworkFileName = "BlacksmithGuild_NobleNetwork.json";
        public const string MarriageCandidatesFileName = "BlacksmithGuild_MarriageCandidates.json";
        public const string CourtshipPlanFileName = "BlacksmithGuild_CourtshipPlan.json";
        public const string ClanRolesFileName = "BlacksmithGuild_ClanRoles.json";
        public const string CourtshipProbeFileName = "BlacksmithGuild_CourtshipProbe.json";

        public static void WriteClanContext(ClanContextReport report) => Write(ClanContextFileName, SerializeClanContext(report));
        public static void WriteNobleNetwork(NobleNetworkReport report) => Write(NobleNetworkFileName, SerializeNobleNetwork(report));
        public static void WriteMarriageCandidates(MarriageCandidatesReport report) => Write(MarriageCandidatesFileName, SerializeMarriageCandidates(report));
        public static void WriteCourtshipPlan(CourtshipPlanReport report) => Write(CourtshipPlanFileName, SerializeCourtshipPlan(report));
        public static void WriteClanRoles(ClanRolesReport report) => Write(ClanRolesFileName, SerializeClanRoles(report));
        public static void WriteCourtshipProbe(CourtshipProbeReport report) => Write(CourtshipProbeFileName, SerializeCourtshipProbe(report));

        private static void Write(string fileName, string json)
        {
            var path = Path.Combine(BasePath.Name, fileName);
            File.WriteAllText(path, json, Encoding.UTF8);
            MirrorEvidence(path, fileName);
        }

        private static string SerializeClanContext(ClanContextReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            AppendPlayerClan(sb, report.PlayerClan);
            AppendSocialPriorities(sb, report.SocialPriorities);
            AppendRecommendedActions(sb, report.RecommendedActions);
            sb.AppendLine("  \"blockedActions\": [");
            AppendStringList(sb, report.BlockedActions, "  ");
            sb.AppendLine("  ],");
            sb.AppendLine("  \"kingdomPosture\": {");
            sb.AppendLine($"    \"recommendedPosture\": {NullableString(report.KingdomPosture?.RecommendedPosture)},");
            sb.AppendLine("    \"reasons\": [");
            AppendStringList(sb, report.KingdomPosture?.Reasons ?? new List<string>(), "    ");
            sb.AppendLine("    ]");
            sb.AppendLine("  }");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeNobleNetwork(NobleNetworkReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            sb.AppendLine("  \"targets\": [");
            for (var i = 0; i < report.Targets.Count; i++)
            {
                AppendNobleTarget(sb, report.Targets[i], "    ");
                sb.AppendLine(i < report.Targets.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"topTarget\": ");
            AppendNobleTarget(sb, report.TopTarget, "  ", true);
            sb.AppendLine();
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeMarriageCandidates(MarriageCandidatesReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            sb.AppendLine("  \"candidates\": [");
            for (var i = 0; i < report.Candidates.Count; i++)
            {
                AppendMarriageCandidate(sb, report.Candidates[i], "    ");
                sb.AppendLine(i < report.Candidates.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"topCandidate\": ");
            AppendMarriageCandidate(sb, report.TopCandidate, "  ", true);
            sb.AppendLine();
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeCourtshipPlan(CourtshipPlanReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            sb.AppendLine("  \"topCandidate\": ");
            AppendMarriageCandidate(sb, report.TopCandidate, "  ", true);
            sb.AppendLine(",");
            sb.AppendLine("  \"travelPlan\": {");
            sb.AppendLine($"    \"targetSettlement\": {NullableString(report.TravelPlan?.TargetSettlement)},");
            sb.AppendLine($"    \"targetHero\": {NullableString(report.TravelPlan?.TargetHero)},");
            sb.AppendLine($"    \"distance\": {NullableFloat(report.TravelPlan?.Distance)},");
            sb.AppendLine($"    \"routeSafety\": {NullableString(report.TravelPlan?.RouteSafety)},");
            sb.AppendLine($"    \"recommendedAction\": {NullableString(report.TravelPlan?.RecommendedAction)}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"nobleContext\": ");
            AppendNobleTarget(sb, report.NobleContext, "  ", true);
            sb.AppendLine(",");
            sb.AppendLine("  \"nextSteps\": [");
            AppendStringList(sb, report.NextSteps, "    ");
            sb.AppendLine("  ],");
            sb.AppendLine("  \"certificationGaps\": [");
            AppendStringList(sb, report.CertificationGaps, "    ");
            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeClanRoles(ClanRolesReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            sb.AppendLine("  \"roles\": {");
            var first = true;
            foreach (var pair in report.Roles)
            {
                if (!first) sb.AppendLine(",");
                first = false;
                sb.AppendLine($"    \"{Escape(pair.Key)}\": {{");
                sb.AppendLine($"      \"assigned\": {NullableString(pair.Value.Assigned)},");
                sb.AppendLine($"      \"fitScore\": {NullableInt(pair.Value.FitScore)},");
                sb.AppendLine($"      \"missingBetterCandidate\": {(pair.Value.MissingBetterCandidate ? "true" : "false")},");
                sb.AppendLine("      \"assignedHeroes\": [");
                AppendStringList(sb, pair.Value.AssignedHeroes, "        ");
                sb.AppendLine("      ],");
                sb.AppendLine($"      \"recommendedRecruitment\": {NullableString(pair.Value.RecommendedRecruitment)},");
                sb.AppendLine($"      \"staminaAvailable\": {NullableInt(pair.Value.StaminaAvailable)}");
                sb.Append("    }");
            }

            sb.AppendLine();
            sb.AppendLine("  },");
            sb.AppendLine("  \"recruitmentGaps\": [");
            AppendStringList(sb, report.RecruitmentGaps, "    ");
            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeCourtshipProbe(CourtshipProbeReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendEnvelope(sb, report);
            sb.AppendLine("  \"hints\": [");
            for (var i = 0; i < report.Hints.Count; i++)
            {
                var hint = report.Hints[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"name\": \"{Escape(hint.Name)}\",");
                sb.AppendLine($"      \"available\": {(hint.Available ? "true" : "false")}");
                sb.Append(i < report.Hints.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void AppendEnvelope(StringBuilder sb, ClanIntelEnvelope report)
        {
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"readOnly\": {(report.ReadOnly ? "true" : "false")},");
            sb.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            sb.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\",");
            sb.AppendLine($"  \"blockedReason\": {NullableString(report.BlockedReason)},");
        }

        private static void AppendPlayerClan(StringBuilder sb, PlayerClanSnapshot clan)
        {
            sb.AppendLine("  \"playerClan\": {");
            sb.AppendLine($"    \"name\": {NullableString(clan?.Name)},");
            sb.AppendLine($"    \"tier\": {NullableInt(clan?.Tier)},");
            sb.AppendLine($"    \"renown\": {NullableFloat(clan?.Renown)},");
            sb.AppendLine($"    \"nextTierRenownNeeded\": {NullableFloat(clan?.NextTierRenownNeeded)},");
            sb.AppendLine($"    \"companionCount\": {NullableInt(clan?.CompanionCount)},");
            sb.AppendLine($"    \"companionLimit\": {NullableInt(clan?.CompanionLimit)},");
            sb.AppendLine($"    \"partySizeLimit\": {NullableInt(clan?.PartySizeLimit)},");
            sb.AppendLine($"    \"workshopLimit\": {NullableInt(clan?.WorkshopLimit)},");
            sb.AppendLine($"    \"kingdom\": {NullableString(clan?.Kingdom)},");
            sb.AppendLine($"    \"posture\": {NullableString(clan?.Posture)},");
            sb.AppendLine($"    \"hasSpouse\": {NullableBool(clan?.HasSpouse)}");
            sb.AppendLine("  },");
        }

        private static void AppendSocialPriorities(StringBuilder sb, List<SocialPriority> priorities)
        {
            sb.AppendLine("  \"socialPriorities\": [");
            for (var i = 0; i < priorities.Count; i++)
            {
                var p = priorities[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"type\": \"{Escape(p.Type)}\",");
                sb.AppendLine($"      \"priority\": \"{Escape(p.Priority)}\",");
                sb.AppendLine($"      \"reason\": \"{Escape(p.Reason)}\"");
                sb.Append(i < priorities.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
        }

        private static void AppendRecommendedActions(StringBuilder sb, List<RecommendedAction> actions)
        {
            sb.AppendLine("  \"recommendedActions\": [");
            for (var i = 0; i < actions.Count; i++)
            {
                var a = actions[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"command\": \"{Escape(a.Command)}\",");
                sb.AppendLine($"      \"reason\": \"{Escape(a.Reason)}\"");
                sb.Append(i < actions.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
        }

        private static void AppendNobleTarget(StringBuilder sb, NobleTarget target, string indent, bool allowNull = false)
        {
            if (target == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"targetNoble\": {NullableString(target.TargetNoble)},");
            sb.AppendLine($"{indent}  \"heroId\": {NullableString(target.HeroId)},");
            sb.AppendLine($"{indent}  \"clan\": {NullableString(target.Clan)},");
            sb.AppendLine($"{indent}  \"faction\": {NullableString(target.Faction)},");
            sb.AppendLine($"{indent}  \"relation\": {NullableInt(target.Relation)},");
            sb.AppendLine($"{indent}  \"strategicValue\": {NullableString(target.StrategicValue)},");
            sb.AppendLine($"{indent}  \"reasons\": [");
            AppendStringList(sb, target.Reasons, indent + "    ");
            sb.AppendLine($"{indent}  ],");
            sb.AppendLine($"{indent}  \"recommendedAction\": {NullableString(target.RecommendedAction)},");
            sb.AppendLine($"{indent}  \"distance\": {NullableFloat(target.Distance)},");
            sb.AppendLine($"{indent}  \"routeSafety\": {NullableString(target.RouteSafety)},");
            sb.AppendLine($"{indent}  \"score\": {target.Score:0.##}");
            sb.Append($"{indent}}}");
        }

        private static void AppendMarriageCandidate(StringBuilder sb, MarriageCandidateEntry c, string indent, bool allowNull = false)
        {
            if (c == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"candidate\": {NullableString(c.Candidate)},");
            sb.AppendLine($"{indent}  \"heroId\": {NullableString(c.HeroId)},");
            sb.AppendLine($"{indent}  \"category\": {NullableString(c.Category)},");
            sb.AppendLine($"{indent}  \"culture\": {NullableString(c.Culture)},");
            sb.AppendLine($"{indent}  \"clan\": {NullableString(c.Clan)},");
            sb.AppendLine($"{indent}  \"distance\": {NullableFloat(c.Distance)},");
            sb.AppendLine($"{indent}  \"routeSafety\": {NullableString(c.RouteSafety)},");
            sb.AppendLine($"{indent}  \"politicalValue\": {NullableString(c.PoliticalValue)},");
            sb.AppendLine($"{indent}  \"skillsValue\": {NullableString(c.SkillsValue)},");
            sb.AppendLine($"{indent}  \"courtshipAvailable\": {NullableBool(c.CourtshipAvailable)},");
            sb.AppendLine($"{indent}  \"recommendedAction\": {NullableString(c.RecommendedAction)},");
            sb.AppendLine($"{indent}  \"warnings\": [");
            AppendStringList(sb, c.Warnings, indent + "    ");
            sb.AppendLine($"{indent}  ],");
            sb.AppendLine($"{indent}  \"score\": {c.Score:0.##}");
            sb.Append($"{indent}}}");
        }

        private static void AppendStringList(StringBuilder sb, List<string> values, string indent)
        {
            values = values ?? new List<string>();
            for (var i = 0; i < values.Count; i++)
            {
                sb.Append($"{indent}\"{Escape(values[i])}\"");
                sb.AppendLine(i < values.Count - 1 ? "," : string.Empty);
            }
        }

        private static void MirrorEvidence(string sourcePath, string fileName)
        {
            try
            {
                var repoRoot = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", ".."));
                var mirrorDir = Path.Combine(repoRoot, "docs", "evidence", "latest");
                if (!Directory.Exists(mirrorDir))
                {
                    return;
                }

                File.Copy(sourcePath, Path.Combine(mirrorDir, fileName), overwrite: true);
            }
            catch
            {
            }
        }

        private static string NullableString(string value) => value == null ? "null" : $"\"{Escape(value)}\"";
        private static string NullableInt(int? value) => value.HasValue ? value.Value.ToString() : "null";
        private static string NullableFloat(float? value) => value.HasValue ? value.Value.ToString("0.##") : "null";
        private static string NullableBool(bool? value) => !value.HasValue ? "null" : value.Value ? "true" : "false";
        private static string Escape(string value) => (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
