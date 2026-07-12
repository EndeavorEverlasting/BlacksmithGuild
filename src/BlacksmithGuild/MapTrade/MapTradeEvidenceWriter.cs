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
        public const string RouteCertFileName = "BlacksmithGuild_MapTradeRouteCert.json";
        public const string ProbeFileName = "BlacksmithGuild_MapTradeProbe.json";
        public const string ForgeHandoffFileName = "BlacksmithGuild_MapTradeForgeHandoff.json";
        public const string ArmyPressureFileName = "BlacksmithGuild_ArmyPressureWindows.json";

        public static void WriteRouteSafety(MapTradeRouteSafetyReport report)
        {
            Write(RouteSafetyFileName, SerializeRouteSafety(report));
        }

        public static void WriteCert(MapTradeCertReport report)
        {
            var json = SerializeCert(report);
            Write(CertFileName, json);
            Write(RouteCertFileName, json);
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
            DevTools.RuntimeProofContext.WriteAllTextAtomic(path, json);
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
            sb.AppendLine($"  \"runId\": {NullableString(report.RunId)},");
            sb.AppendLine($"  \"headSha\": {NullableString(report.HeadSha)},");
            sb.AppendLine($"  \"runtimeSessionId\": {NullableString(report.RuntimeSessionId)},");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            sb.AppendLine($"  \"startedAtUtc\": {NullableString(report.StartedAtUtc)},");
            sb.AppendLine($"  \"destinationSettlement\": {NullableString(report.DestinationSettlement)},");
            sb.AppendLine($"  \"targetSettlementId\": {NullableString(report.TargetSettlementId)},");
            sb.AppendLine($"  \"startPosition\": {NullableString(report.StartPosition)},");
            sb.AppendLine($"  \"latestPosition\": {NullableString(report.LatestPosition)},");
            sb.AppendLine($"  \"initialTimePaused\": {(report.InitialTimePaused ? "true" : "false")},");
            sb.AppendLine($"  \"attemptedUnpause\": {(report.AttemptedUnpause ? "true" : "false")},");
            sb.AppendLine($"  \"travelCommandIssued\": {(report.TravelCommandIssued ? "true" : "false")},");
            sb.AppendLine($"  \"routeStarted\": {(report.RouteStarted ? "true" : "false")},");
            sb.AppendLine($"  \"autoStartTickReturnObserved\": {(report.AutoStartTickReturnObserved ? "true" : "false")},");
            sb.AppendLine($"  \"sameTickHoldObserved\": {(report.SameTickHoldObserved ? "true" : "false")},");
            sb.AppendLine($"  \"movementObserved\": {(report.MovementObserved ? "true" : "false")},");
            sb.AppendLine($"  \"partyMovedDistance\": {report.PartyMovedDistance:0.###},");
            sb.AppendLine($"  \"arrivalObserved\": {(report.ArrivalObserved ? "true" : "false")},");
            sb.AppendLine($"  \"arrivedSettlement\": {NullableString(report.ArrivedSettlement)},");
            sb.AppendLine($"  \"runtimeProofClaim\": {NullableString(report.RuntimeProofClaim)},");
            sb.AppendLine($"  \"state\": \"{report.State}\",");
            sb.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\",");
            sb.AppendLine($"  \"blockedReason\": {NullableString(report.BlockedReason)},");
            sb.AppendLine($"  \"tradeDriverAvailable\": {(report.TradeDriverAvailable ? "true" : "false")},");
            sb.AppendLine($"  \"tradeDriverMethod\": {NullableString(report.TradeDriverMethod)},");
            sb.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            sb.AppendLine("  \"routeClockEvidence\": ");
            AppendRouteClockEvidence(sb, report.RouteClockEvidence, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"tradeExecution\": ");
            AppendTradeExecution(sb, report.TradeExecution, "  ");
            sb.AppendLine(",");
            sb.AppendLine("  \"tradeSurface\": ");
            AppendTradeSurface(sb, report.TradeSurface, "  ");
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

        private static void AppendRouteClockEvidence(StringBuilder sb, MapTradeRouteClockEvidence evidence, string indent)
        {
            if (evidence == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"commandAck\": {NullableString(evidence.CommandAck)},");
            sb.AppendLine($"{indent}  \"routeTarget\": {NullableString(evidence.RouteTarget)},");
            sb.AppendLine($"{indent}  \"routeIntent\": {NullableString(evidence.RouteIntent)},");
            sb.AppendLine($"{indent}  \"routeOwner\": {NullableString(evidence.RouteOwner)},");
            sb.AppendLine($"{indent}  \"clockStateBefore\": {NullableString(evidence.ClockStateBefore)},");
            sb.AppendLine($"{indent}  \"clockResumeAttempted\": {(evidence.ClockResumeAttempted ? "true" : "false")},");
            sb.AppendLine($"{indent}  \"clockResumeResult\": {NullableString(evidence.ClockResumeResult)},");
            sb.AppendLine($"{indent}  \"authorityMode\": {NullableString(evidence.AuthorityMode)},");
            sb.AppendLine($"{indent}  \"movementObservation\": {NullableString(evidence.MovementObservation)},");
            sb.AppendLine($"{indent}  \"arrivalBlockedIndeterminate\": {NullableString(evidence.ArrivalBlockedIndeterminate)},");
            sb.AppendLine($"{indent}  \"nextOwner\": {NullableString(evidence.NextOwner)},");
            sb.AppendLine($"{indent}  \"runtimeProofClaim\": {(evidence.RuntimeProofClaim ? "true" : "false")}");
            sb.Append($"{indent}}}");
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
            sb.AppendLine($"{indent}  \"inventoryBefore\": {execution.InventoryBefore},");
            sb.AppendLine($"{indent}  \"inventoryAfter\": {execution.InventoryAfter},");
            sb.AppendLine($"{indent}  \"inventoryDelta\": {execution.InventoryAfter - execution.InventoryBefore},");
            sb.AppendLine($"{indent}  \"fakeGameplayDelta\": {(execution.FakeGameplayDelta ? "true" : "false")},");
            sb.AppendLine($"{indent}  \"executionMethod\": {NullableString(execution.ExecutionMethod)},");
            sb.AppendLine($"{indent}  \"itemClassification\": {NullableString(execution.ItemClassification)}");
            sb.Append($"{indent}}}");
        }

        private static void AppendTradeSurface(StringBuilder sb, MapTradeTradeSurfaceEvidence surface, string indent)
        {
            if (surface == null)
            {
                sb.Append($"{indent}null");
                return;
            }

            sb.AppendLine($"{indent}{{");
            sb.AppendLine($"{indent}  \"surface\": {NullableString(surface.Surface)},");
            sb.AppendLine($"{indent}  \"visible\": {(surface.Visible ? "true" : "false")},");
            sb.AppendLine($"{indent}  \"openedAtUtc\": {NullableString(surface.OpenedAtUtc)},");
            sb.AppendLine($"{indent}  \"settlement\": {NullableString(surface.Settlement)},");
            sb.AppendLine($"{indent}  \"method\": {NullableString(surface.Method)},");
            sb.AppendLine($"{indent}  \"activeState\": {NullableString(surface.ActiveState)}");
            sb.Append($"{indent}}}");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
