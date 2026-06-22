using System;
using System.IO;
using System.Text;
using BlacksmithGuild.Cohesion;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeEvidenceWriter
    {
        public const string RouteSafetyFileName = "BlacksmithGuild_MapTradeRouteSafety.json";
        public const string CertFileName = "BlacksmithGuild_MapTradeCert.json";
        public const string ProbeFileName = "BlacksmithGuild_MapTradeProbe.json";
        public const string ForgeHandoffFileName = "BlacksmithGuild_MapTradeForgeHandoff.json";
        public const string ArmyPressureFileName = "BlacksmithGuild_ArmyPressureWindows.json";

        public static void WriteRouteSafety(MapTradeRouteSafetyReport report)
        {
            Write(RouteSafetyFileName, SerializeRouteSafety(report));
        }

        public static void WriteCert(MapTradeCertReport report)
        {
            Write(CertFileName, SerializeCert(report));
        }

        public static void WriteForgeHandoff(MapTradeForgeHandoffReport report)
        {
            Write(ForgeHandoffFileName, SerializeForgeHandoff(report));
        }

        public static void WriteArmyPressure(MapTradeArmyPressureReport report)
        {
            Write(ArmyPressureFileName, SerializeArmyPressure(report));
        }

        private static void Write(string fileName, string json)
        {
            var path = Path.Combine(BasePath.Name, fileName);
            File.WriteAllText(path, json, Encoding.UTF8);
            MirrorEvidence(path, fileName);
        }

        private static string SerializeRouteSafety(MapTradeRouteSafetyReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"readOnly\": {(report.ReadOnly ? "true" : "false")},");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\",");
            sb.AppendLine($"  \"blockedReason\": {NullableString(report.BlockedReason)},");
            sb.AppendLine($"  \"hostileCount\": {report.HostileCount},");
            sb.AppendLine($"  \"nearestHostileDistance\": {report.NearestHostileDistance:0.##},");
            sb.AppendLine($"  \"armyPressureWindow\": \"{Escape(report.ArmyPressureWindow)}\",");
            sb.AppendLine("  \"cohesionSummary\": {");
            var cohesion = report.SelectedCohesionOpportunity;
            sb.AppendLine($"    \"recommendedAction\": {(cohesion == null ? "null" : $"\"{cohesion.RecommendedAction}\"")},");
            sb.AppendLine($"    \"score\": {(cohesion == null ? "null" : cohesion.Score.ToString("0.##"))},");
            sb.AppendLine($"    \"blockedReason\": {(cohesion?.BlockedReason == null ? "null" : $"\"{Escape(cohesion.BlockedReason)}\"")}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"cohesionDecisions\": [");
            for (var i = 0; i < report.CohesionDecisions.Count; i++)
            {
                var d = report.CohesionDecisions[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"phase\": \"{Escape(d.Phase)}\",");
                sb.AppendLine($"      \"recommendedAction\": \"{Escape(d.RecommendedAction)}\",");
                sb.AppendLine($"      \"score\": {d.Score:0.##},");
                sb.AppendLine($"      \"blockedReason\": {NullableString(d.BlockedReason)}");
                sb.Append(i < report.CohesionDecisions.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeCert(MapTradeCertReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"state\": \"{report.State}\",");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\",");
            sb.AppendLine($"  \"blockedReason\": {NullableString(report.BlockedReason)},");
            sb.AppendLine($"  \"tradeDriverAvailable\": {(report.TradeDriverAvailable ? "true" : "false")},");
            sb.AppendLine($"  \"tradeDriverMethod\": {NullableString(report.TradeDriverMethod)},");
            sb.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            sb.AppendLine("  \"tradeExecution\": ");
            AppendTradeExecution(sb, report.TradeExecution, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"sellExecution\": ");
            AppendTradeExecution(sb, report.SellExecution, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"mission\": {");
            var mission = report.Mission;
            sb.AppendLine($"    \"missionType\": \"{(mission?.MissionType.ToString() ?? "None")}\",");
            sb.AppendLine($"    \"itemName\": {NullableString(mission?.ItemName)},");
            sb.AppendLine($"    \"targetSettlementName\": {NullableString(mission?.TargetSettlementName)},");
            sb.AppendLine($"    \"distance\": {(mission?.Distance ?? 0f):0.##}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"cohesionDecisions\": [");
            for (var i = 0; i < report.CohesionDecisions.Count; i++)
            {
                var d = report.CohesionDecisions[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"phase\": \"{Escape(d.Phase)}\",");
                sb.AppendLine($"      \"recommendedAction\": \"{Escape(d.RecommendedAction)}\",");
                sb.AppendLine($"      \"score\": {d.Score:0.##},");
                sb.AppendLine($"      \"blockedReason\": {NullableString(d.BlockedReason)}");
                sb.Append(i < report.CohesionDecisions.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"steps\": [");
            for (var i = 0; i < report.Steps.Count; i++)
            {
                sb.Append($"    \"{Escape(report.Steps[i])}\"");
                sb.AppendLine(i < report.Steps.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static string SerializeForgeHandoff(MapTradeForgeHandoffReport report)
        {
            return "{"
                + $"\"generatedUtc\":\"{Escape(report.GeneratedUtc)}\","
                + $"\"source\":\"{Escape(report.Source)}\","
                + $"\"forgeHandoffRan\":{(report.ForgeHandoffRan ? "true" : "false")},"
                + $"\"forgeHandoffResult\":{NullableString(report.ForgeHandoffResult)},"
                + $"\"blockedReason\":{NullableString(report.BlockedReason)}"
                + "}";
        }

        private static string SerializeArmyPressure(MapTradeArmyPressureReport report)
        {
            return "{"
                + $"\"generatedUtc\":\"{Escape(report.GeneratedUtc)}\","
                + $"\"window\":\"{Escape(report.Window)}\","
                + $"\"hostilePartiesInRadius\":{report.HostilePartiesInRadius},"
                + $"\"friendlyProtectorsInRadius\":{report.FriendlyProtectorsInRadius}"
                + "}";
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

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static void AppendTradeExecution(StringBuilder sb, MapTradeExecutionResult execution, string indent)
        {
            if (execution == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"goldBefore\": {execution.GoldBefore},");
            sb.AppendLine($"{indent}  \"goldAfter\": {execution.GoldAfter},");
            sb.AppendLine($"{indent}  \"goldDelta\": {execution.GoldDelta},");
            sb.AppendLine($"{indent}  \"itemId\": {NullableString(execution.ItemId)},");
            sb.AppendLine($"{indent}  \"itemName\": {NullableString(execution.ItemName)},");
            sb.AppendLine($"{indent}  \"quantityBought\": {execution.QuantityBought},");
            sb.AppendLine($"{indent}  \"quantitySold\": {execution.QuantitySold},");
            sb.AppendLine($"{indent}  \"inventoryBefore\": {execution.InventoryBefore},");
            sb.AppendLine($"{indent}  \"inventoryAfter\": {execution.InventoryAfter},");
            sb.AppendLine($"{indent}  \"executionMethod\": {NullableString(execution.ExecutionMethod)},");
            sb.AppendLine($"{indent}  \"itemClassification\": {NullableString(execution.ItemClassification)}");
            sb.Append($"{indent}}}");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
