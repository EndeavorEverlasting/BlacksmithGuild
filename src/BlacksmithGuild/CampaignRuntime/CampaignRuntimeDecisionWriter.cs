using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignRuntimeDecisionWriter
    {
        public const string ReportFileName = "BlacksmithGuild_CampaignGovernorDecision.json";

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);

        public static void Write(CampaignRuntimeDecision decision)
        {
            if (decision == null)
            {
                return;
            }

            File.WriteAllText(ReportPath, Serialize(decision), Encoding.UTF8);
        }

        public static string Serialize(CampaignRuntimeDecision decision)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            AppendString(sb, "cycleId", decision.CycleId, comma: true);
            AppendString(sb, "generatedUtc", decision.GeneratedUtc, comma: true);
            AppendString(sb, "source", decision.Source, comma: true);
            AppendString(sb, "surface", decision.Surface, comma: true);
            AppendString(sb, "gameHealth", decision.GameHealth, comma: true);
            AppendString(sb, "selectedBranch", decision.SelectedBranch, comma: true);
            AppendString(sb, "selectedReason", decision.SelectedReason, comma: true);
            sb.AppendLine($"  \"priorityRank\": {decision.PriorityRank},");
            sb.AppendLine("  \"blockedBranches\": [");
            for (var i = 0; i < decision.BlockedBranches.Count; i++)
            {
                var blocked = decision.BlockedBranches[i];
                sb.AppendLine("    {");
                AppendString(sb, "branch", blocked.Branch, comma: true, indent: "      ");
                AppendString(sb, "reason", blocked.Reason, comma: true, indent: "      ");
                sb.AppendLine($"      \"priorityRank\": {blocked.PriorityRank}");
                sb.Append(i < decision.BlockedBranches.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }
            sb.AppendLine("  ],");
            AppendString(sb, "currentTown", decision.CurrentTown, comma: true);
            AppendString(sb, "destinationCandidate", decision.DestinationCandidate, comma: true);
            AppendString(sb, "foodStatus", decision.FoodStatus, comma: true);
            AppendString(sb, "foodDiversityStatus", decision.FoodDiversityStatus, comma: true);
            AppendString(sb, "capacityStatus", decision.CapacityStatus, comma: true);
            AppendString(sb, "horseStatus", decision.HorseStatus, comma: true);
            AppendString(sb, "staminaStatus", decision.StaminaStatus, comma: true);
            AppendString(sb, "materialStatus", decision.MaterialStatus, comma: true);
            AppendString(sb, "tradeStatus", decision.TradeStatus, comma: true);
            AppendString(sb, "smithingStatus", decision.SmithingStatus, comma: true);
            AppendString(sb, "companionStatus", decision.CompanionStatus, comma: true);
            AppendString(sb, "diplomacyStatus", decision.DiplomacyStatus, comma: true);
            AppendString(sb, "threatStatus", decision.ThreatStatus, comma: true);
            sb.AppendLine($"  \"reportInsufficient\": {JsonBool(decision.ReportInsufficient)},");
            sb.AppendLine($"  \"mapScanRequired\": {JsonBool(decision.MapScanRequired)},");
            AppendString(sb, "confidence", decision.Confidence, comma: true);
            sb.AppendLine($"  \"allowed\": {JsonBool(decision.Allowed)},");
            AppendString(sb, "failureClass", decision.FailureClass, comma: false);
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void AppendString(StringBuilder sb, string name, string value, bool comma, string indent = "  ")
        {
            sb.Append(indent)
                .Append("\"")
                .Append(Escape(name))
                .Append("\": ");

            if (value == null)
            {
                sb.Append("null");
            }
            else
            {
                sb.Append("\"")
                    .Append(Escape(value))
                    .Append("\"");
            }

            if (comma)
            {
                sb.Append(",");
            }

            sb.AppendLine();
        }

        private static string JsonBool(bool value) => value ? "true" : "false";

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
    }
}
