using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionJsonWriter
    {
        public const string OpportunitiesFileName = "BlacksmithGuild_CohesionOpportunities.json";
        public const string MoveFileName = "BlacksmithGuild_CohesionMove.json";

        public static void WriteOpportunities(CohesionOpportunitiesReport report)
        {
            var path = Path.Combine(BasePath.Name, OpportunitiesFileName);
            File.WriteAllText(path, SerializeOpportunities(report), Encoding.UTF8);
            MirrorEvidence(path, OpportunitiesFileName);
        }

        public static void WriteMove(CohesionMoveReport report)
        {
            var path = Path.Combine(BasePath.Name, MoveFileName);
            File.WriteAllText(path, SerializeMove(report), Encoding.UTF8);
            MirrorEvidence(path, MoveFileName);
        }

        public static string SerializeOpportunities(CohesionOpportunitiesReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"readOnly\": {(report.ReadOnly ? "true" : "false")},");
            sb.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            sb.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");
            sb.AppendLine("  \"currentObjective\": " + SerializeObjective(report.CurrentObjective) + ",");
            sb.AppendLine("  \"partySnapshots\": [");
            AppendSnapshots(sb, report.PartySnapshots);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"opportunities\": [");
            AppendOpportunities(sb, report.Opportunities);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"selectedOpportunity\": "
                + (report.SelectedOpportunity == null ? "null" : SerializeOpportunity(report.SelectedOpportunity, indent: 2)) + ",");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\"");
            sb.AppendLine("}");
            return sb.ToString();
        }

        public static string SerializeMove(CohesionMoveReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"legitimacyMode\": \"{Escape(report.LegitimacyMode)}\",");
            sb.AppendLine("  \"visibleMode\": {");
            sb.AppendLine($"    \"enabled\": {(report.VisibleModeEnabled ? "true" : "false")},");
            sb.AppendLine($"    \"decisionPauseMs\": {report.DecisionPauseMs}");
            sb.AppendLine("  },");
            sb.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            sb.AppendLine("  \"mutationTypes\": [\"PartyPosition\", \"CampaignTime\"],");
            sb.AppendLine($"  \"selectedOpportunityId\": {(report.SelectedOpportunityId == null ? "null" : $"\"{Escape(report.SelectedOpportunityId)}\"")},");
            sb.AppendLine($"  \"state\": \"{report.State}\",");
            sb.AppendLine("  \"objective\": " + SerializeObjective(report.Objective) + ",");
            sb.AppendLine("  \"before\": {},");
            sb.AppendLine("  \"steps\": [");
            for (var i = 0; i < report.Steps.Count; i++)
            {
                var step = report.Steps[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"state\": \"{Escape(step.State)}\",");
                sb.AppendLine($"      \"action\": \"{Escape(step.Action)}\",");
                sb.AppendLine($"      \"mode\": \"{Escape(step.Mode)}\",");
                sb.AppendLine($"      \"result\": \"{Escape(step.Result)}\",");
                sb.AppendLine("      \"notes\": []");
                sb.Append(i < report.Steps.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"cohesionWindowsUsed\": [],");
            sb.AppendLine("  \"helperMovement\": {");
            sb.AppendLine($"    \"commanded\": {(report.HelperMovementCommanded ? "true" : "false")},");
            sb.AppendLine($"    \"method\": {(report.HelperMovementMethod == null ? "null" : $"\"{Escape(report.HelperMovementMethod)}\"")},");
            sb.AppendLine($"    \"reason\": \"{Escape(report.HelperMovementReason)}\"");
            sb.AppendLine("  },");
            sb.AppendLine("  \"after\": { \"objectiveResumed\": " + (report.ObjectiveResumed ? "true" : "false") + " },");
            sb.AppendLine("  \"vanillaProof\": {");
            sb.AppendLine($"    \"teleportUsed\": {(report.TeleportUsed ? "true" : "false")},");
            sb.AppendLine($"    \"rawPositionSet\": {(report.RawPositionSet ? "true" : "false")},");
            sb.AppendLine("    \"forcedPartyMergeUsed\": false,");
            sb.AppendLine("    \"forcedBattleResultUsed\": false,");
            sb.AppendLine("    \"directGoldMutationUsed\": false,");
            sb.AppendLine("    \"directInventoryMutationUsed\": false");
            sb.AppendLine("  },");
            sb.AppendLine($"  \"blockedReason\": {(report.BlockedReason == null ? "null" : $"\"{Escape(report.BlockedReason)}\"")},");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\"");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void AppendSnapshots(StringBuilder sb, List<CohesionPartySnapshot> snapshots)
        {
            for (var i = 0; i < snapshots.Count; i++)
            {
                var s = snapshots[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"partyId\": \"{Escape(s.PartyId)}\",");
                sb.AppendLine($"      \"name\": \"{Escape(s.Name)}\",");
                sb.AppendLine($"      \"relationToPlayer\": \"{s.RelationToPlayer}\",");
                sb.AppendLine($"      \"partyType\": \"{s.PartyType}\",");
                sb.AppendLine($"      \"inferredIntent\": \"{s.InferredIntent}\",");
                sb.AppendLine($"      \"confidence\": \"{s.Confidence}\",");
                sb.AppendLine($"      \"strength\": {s.Strength},");
                sb.AppendLine($"      \"distanceToPlayer\": {s.DistanceToPlayer:0.##},");
                sb.AppendLine($"      \"controllableByPlayer\": {(s.ControllableByPlayer ? "true" : "false")}");
                sb.Append(i < snapshots.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }
        }

        private static void AppendOpportunities(StringBuilder sb, List<CohesionOpportunity> opportunities)
        {
            for (var i = 0; i < opportunities.Count; i++)
            {
                sb.Append(SerializeOpportunity(opportunities[i], indent: 4));
                sb.AppendLine(i < opportunities.Count - 1 ? "," : string.Empty);
            }
        }

        private static string SerializeOpportunity(CohesionOpportunity o, int indent)
        {
            var pad = new string(' ', indent);
            var sb = new StringBuilder();
            sb.AppendLine(pad + "{");
            sb.AppendLine($"{pad}  \"opportunityId\": \"{Escape(o.OpportunityId)}\",");
            sb.AppendLine($"{pad}  \"objectiveType\": \"{o.ObjectiveType}\",");
            sb.AppendLine($"{pad}  \"recommendedAction\": \"{o.RecommendedAction}\",");
            sb.AppendLine($"{pad}  \"score\": {o.Score:0.##},");
            sb.AppendLine($"{pad}  \"confidence\": \"{o.Confidence}\",");
            sb.AppendLine($"{pad}  \"blockedReason\": {(o.BlockedReason == null ? "null" : $"\"{Escape(o.BlockedReason)}\"")},");
            sb.AppendLine($"{pad}  \"eta\": {{");
            sb.AppendLine($"{pad}    \"playerEtaHours\": {NullableFloat(o.Eta?.PlayerEtaHours)},");
            sb.AppendLine($"{pad}    \"helperEtaHours\": {NullableFloat(o.Eta?.HelperEtaHours)},");
            sb.AppendLine($"{pad}    \"hostileEtaHours\": {NullableFloat(o.Eta?.HostileEtaHours)},");
            sb.AppendLine($"{pad}    \"convergenceEtaHours\": {NullableFloat(o.Eta?.ConvergenceEtaHours)},");
            sb.AppendLine($"{pad}    \"escapeMarginHours\": {NullableFloat(o.Eta?.EscapeMarginHours)}");
            sb.AppendLine($"{pad}  }},");
            sb.AppendLine($"{pad}  \"power\": {{");
            sb.AppendLine($"{pad}    \"playerStrength\": {NullableInt(o.Power?.PlayerStrength)},");
            sb.AppendLine($"{pad}    \"helperStrength\": {NullableInt(o.Power?.HelperStrength)},");
            sb.AppendLine($"{pad}    \"combinedFriendlyStrength\": {NullableInt(o.Power?.CombinedFriendlyStrength)},");
            sb.AppendLine($"{pad}    \"hostileClusterStrength\": {NullableInt(o.Power?.HostileClusterStrength)},");
            sb.AppendLine($"{pad}    \"strengthRatio\": {NullableFloat(o.Power?.StrengthRatio)},");
            sb.AppendLine($"{pad}    \"confidence\": \"{Escape(o.Power?.Confidence)}\"");
            sb.AppendLine($"{pad}  }},");
            sb.AppendLine($"{pad}  \"risk\": {{");
            sb.AppendLine($"{pad}    \"interceptRisk\": \"{Escape(o.Risk?.InterceptRisk)}\",");
            sb.AppendLine($"{pad}    \"combatContactLikely\": {(o.Risk?.CombatContactLikely == true ? "true" : "false")},");
            sb.AppendLine($"{pad}    \"nearestSafeSettlement\": null,");
            sb.AppendLine($"{pad}    \"fallbackEtaHours\": {NullableFloat(o.Risk?.FallbackEtaHours)}");
            sb.AppendLine($"{pad}  }},");
            sb.AppendLine($"{pad}  \"reasons\": [{string.Join(", ", (o.Reasons ?? new List<string>()).ConvertAll(r => $"\"{Escape(r)}\""))}],");
            sb.AppendLine($"{pad}  \"risks\": [{string.Join(", ", (o.Risks ?? new List<string>()).ConvertAll(r => $"\"{Escape(r)}\""))}]");
            sb.Append(pad + "}");
            return sb.ToString();
        }

        private static string SerializeObjective(CohesionObjective objective)
        {
            if (objective == null)
            {
                return "null";
            }

            return "{"
                + $"\"objectiveId\": \"{Escape(objective.ObjectiveId)}\","
                + $"\"objectiveType\": \"{objective.ObjectiveType}\","
                + $"\"targetSettlementId\": {(objective.TargetSettlementId == null ? "null" : $"\"{Escape(objective.TargetSettlementId)}\"")},"
                + $"\"targetSettlementName\": {(objective.TargetSettlementName == null ? "null" : $"\"{Escape(objective.TargetSettlementName)}\"")}"
                + "}";
        }

        private static string NullableFloat(float? value) => value.HasValue ? value.Value.ToString("0.##") : "null";
        private static string NullableInt(int? value) => value.HasValue ? value.Value.ToString() : "null";

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

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
