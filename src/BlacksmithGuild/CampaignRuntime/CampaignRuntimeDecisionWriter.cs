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
            AppendString(sb, "foodForecastStatus", decision.FoodForecastStatus, comma: true);
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
            AppendString(sb, "failureClass", decision.FailureClass, comma: true);
            AppendActivityRequest(sb, "proposedActivity", decision.ProposedActivity, comma: true);
            AppendActivityResult(sb, "latestActivityResult", decision.LatestActivityResult, comma: false);
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void AppendActivityRequest(StringBuilder sb, string name, CampaignActivityRequest activity, bool comma)
        {
            sb.Append("  \"").Append(Escape(name)).Append("\": ");
            if (activity == null)
            {
                sb.Append("null");
                if (comma)
                {
                    sb.Append(",");
                }
                sb.AppendLine();
                return;
            }

            sb.AppendLine("{");
            AppendString(sb, "activityId", activity.ActivityId, comma: true, indent: "    ");
            AppendString(sb, "cycleId", activity.CycleId, comma: true, indent: "    ");
            AppendString(sb, "createdUtc", activity.CreatedUtc, comma: true, indent: "    ");
            AppendString(sb, "sourceEngine", activity.SourceEngine, comma: true, indent: "    ");
            AppendString(sb, "targetEngine", activity.TargetEngine, comma: true, indent: "    ");
            AppendString(sb, "mode", activity.Mode, comma: true, indent: "    ");
            AppendString(sb, "status", activity.Status, comma: true, indent: "    ");
            AppendString(sb, "branch", activity.Branch, comma: true, indent: "    ");
            AppendString(sb, "operation", activity.Operation, comma: true, indent: "    ");
            AppendString(sb, "reason", activity.Reason, comma: true, indent: "    ");
            AppendString(sb, "currentTown", activity.CurrentTown, comma: true, indent: "    ");
            AppendString(sb, "targetTown", activity.TargetTown, comma: true, indent: "    ");
            AppendString(sb, "targetItemId", activity.TargetItemId, comma: true, indent: "    ");
            AppendString(sb, "targetItemName", activity.TargetItemName, comma: true, indent: "    ");
            sb.AppendLine($"    \"priorityRank\": {activity.PriorityRank},");
            sb.AppendLine($"    \"mutationAuthorized\": {JsonBool(activity.MutationAuthorized)},");
            sb.AppendLine($"    \"requiresFreshMarketScan\": {JsonBool(activity.RequiresFreshMarketScan)},");
            sb.AppendLine($"    \"requiresVisibleSurface\": {JsonBool(activity.RequiresVisibleSurface)},");
            sb.AppendLine($"    \"requiresInventoryDelta\": {JsonBool(activity.RequiresInventoryDelta)},");
            sb.AppendLine($"    \"requiresGoldDelta\": {JsonBool(activity.RequiresGoldDelta)},");
            AppendString(sb, "expectedProof", activity.ExpectedProof, comma: true, indent: "    ");
            AppendString(sb, "blockedReason", activity.BlockedReason, comma: false, indent: "    ");
            sb.Append(comma ? "  }," : "  }");
            sb.AppendLine();
        }

        private static void AppendActivityResult(StringBuilder sb, string name, CampaignActivityResult result, bool comma)
        {
            sb.Append("  \"").Append(Escape(name)).Append("\": ");
            if (result == null)
            {
                sb.Append("null");
                if (comma)
                {
                    sb.Append(",");
                }
                sb.AppendLine();
                return;
            }

            sb.AppendLine("{");
            AppendString(sb, "activityId", result.ActivityId, comma: true, indent: "    ");
            AppendString(sb, "completedUtc", result.CompletedUtc, comma: true, indent: "    ");
            AppendString(sb, "sourceEngine", result.SourceEngine, comma: true, indent: "    ");
            AppendString(sb, "status", result.Status, comma: true, indent: "    ");
            AppendString(sb, "detail", result.Detail, comma: true, indent: "    ");
            sb.AppendLine($"    \"mutationApplied\": {JsonBool(result.MutationApplied)},");
            sb.AppendLine($"    \"inventoryDeltaObserved\": {JsonBool(result.InventoryDeltaObserved)},");
            sb.AppendLine($"    \"goldDeltaObserved\": {JsonBool(result.GoldDeltaObserved)},");
            AppendString(sb, "failureClass", result.FailureClass, comma: false, indent: "    ");
            sb.Append(comma ? "  }," : "  }");
            sb.AppendLine();
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
