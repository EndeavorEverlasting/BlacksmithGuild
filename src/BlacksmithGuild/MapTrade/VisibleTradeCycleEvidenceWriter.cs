using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    /// <summary>
    /// One terminal, correlated handoff for the unattended save -> route -> visible trade workflow.
    /// It is derived only from the live route report and observed Bannerlord deltas.
    /// </summary>
    public static class VisibleTradeCycleEvidenceWriter
    {
        public const string FileName = "BlacksmithGuild_VisibleTradeCycle.json";

        public static void WriteTerminal(MapTradeCertReport report)
        {
            if (report == null || string.IsNullOrWhiteSpace(report.RunId))
            {
                return;
            }

            var execution = report.TradeExecution;
            var surface = report.TradeSurface;
            var inventoryDelta = execution == null ? 0 : execution.InventoryAfter - execution.InventoryBefore;
            var realTradeDelta = execution != null
                && !execution.FakeGameplayDelta
                && execution.GoldDelta < 0
                && inventoryDelta > 0;
            var passed = report.State == MapTradeRouteState.Complete
                && report.RouteStarted
                && report.MovementObserved
                && report.PartyMovedDistance > 0f
                && report.ArrivalObserved
                && realTradeDelta
                && surface != null
                && surface.Visible
                && string.Equals(surface.Surface, GameplaySurfaceKinds.Trading, StringComparison.Ordinal);

            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine("  \"schemaVersion\": \"TbgVisibleTradeRuntimeEvidence.v1\",");
            sb.AppendLine("  \"generatedAtUtc\": \"" + DateTime.UtcNow.ToString("o") + "\",");
            sb.AppendLine("  \"runId\": " + NullableString(report.RunId) + ",");
            sb.AppendLine("  \"headSha\": " + NullableString(report.HeadSha) + ",");
            sb.AppendLine("  \"runtimeSessionId\": " + NullableString(report.RuntimeSessionId) + ",");
            sb.AppendLine("  \"source\": " + NullableString(report.Source) + ",");
            sb.AppendLine("  \"loadedAssemblySha256\": " + NullableString(RuntimeProofContext.LoadedAssemblySha256) + ",");
            sb.AppendLine("  \"terminal\": true,");
            sb.AppendLine("  \"state\": \"" + report.State + "\",");
            sb.AppendLine("  \"pass\": " + Boolean(passed) + ",");
            sb.AppendLine("  \"verdict\": " + NullableString(report.Verdict) + ",");
            sb.AppendLine("  \"blockedReason\": " + NullableString(report.BlockedReason) + ",");
            sb.AppendLine("  \"route\": {");
            sb.AppendLine("    \"started\": " + Boolean(report.RouteStarted) + ",");
            sb.AppendLine("    \"movementObserved\": " + Boolean(report.MovementObserved) + ",");
            sb.AppendLine("    \"partyMovedDistance\": " + report.PartyMovedDistance.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture) + ",");
            sb.AppendLine("    \"arrivalObserved\": " + Boolean(report.ArrivalObserved) + ",");
            sb.AppendLine("    \"targetSettlement\": " + NullableString(report.DestinationSettlement ?? report.Mission?.TargetSettlementName) + ",");
            sb.AppendLine("    \"arrivedSettlement\": " + NullableString(report.ArrivedSettlement));
            sb.AppendLine("  },");
            sb.AppendLine("  \"tradeExecution\": {");
            sb.AppendLine("    \"fakeGameplayDelta\": " + Boolean(execution?.FakeGameplayDelta ?? true) + ",");
            sb.AppendLine("    \"mutationApplied\": " + Boolean(report.MutationApplied) + ",");
            sb.AppendLine("    \"goldBefore\": " + (execution?.GoldBefore ?? 0) + ",");
            sb.AppendLine("    \"goldAfter\": " + (execution?.GoldAfter ?? 0) + ",");
            sb.AppendLine("    \"goldDelta\": " + (execution?.GoldDelta ?? 0) + ",");
            sb.AppendLine("    \"inventoryBefore\": " + (execution?.InventoryBefore ?? 0) + ",");
            sb.AppendLine("    \"inventoryAfter\": " + (execution?.InventoryAfter ?? 0) + ",");
            sb.AppendLine("    \"inventoryDelta\": " + inventoryDelta + ",");
            sb.AppendLine("    \"itemId\": " + NullableString(execution?.ItemId) + ",");
            sb.AppendLine("    \"quantityBought\": " + (execution?.QuantityBought ?? 0));
            sb.AppendLine("  },");
            sb.AppendLine("  \"tradeSurface\": {");
            sb.AppendLine("    \"surface\": " + NullableString(surface?.Surface) + ",");
            sb.AppendLine("    \"visible\": " + Boolean(surface?.Visible ?? false) + ",");
            sb.AppendLine("    \"openedAtUtc\": " + NullableString(surface?.OpenedAtUtc) + ",");
            sb.AppendLine("    \"settlement\": " + NullableString(surface?.Settlement) + ",");
            sb.AppendLine("    \"method\": " + NullableString(surface?.Method) + ",");
            sb.AppendLine("    \"activeState\": " + NullableString(surface?.ActiveState));
            sb.AppendLine("  }");
            sb.AppendLine("}");

            RuntimeProofContext.WriteAllTextAtomic(Path.Combine(BasePath.Name, FileName), sb.ToString());
        }

        private static string Boolean(bool value) => value ? "true" : "false";
        private static string NullableString(string value) => value == null ? "null" : "\"" + Escape(value) + "\"";
        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
