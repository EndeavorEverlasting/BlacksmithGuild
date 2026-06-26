using System;
using System.Text;

namespace BlacksmithGuild.DevTools
{
    public static class RecursiveCampaignBranchState
    {
        // Schema v2 (additive): adds horse_acquisition + inventory_management branches and enriches
        // every gate object with evidenceSource / updatedAtUtc / boundaryName / failureClass.
        // v1 consumers that read only state/reason continue to work unchanged.
        public const int SchemaVersion = 2;

        public static string BuildJsonBlock(GameplaySurfaceSnapshot snapshot)
        {
            snapshot = snapshot ?? new GameplaySurfaceSnapshot();
            var next = SelectNextBranch(snapshot);
            var reason = ExplainNextBranch(snapshot, next);
            var updatedAt = snapshot.UpdatedAtUtc.ToString("o");
            var settlementLike = IsSettlementLike(snapshot);

            var sb = new StringBuilder();
            sb.AppendLine("  \"recursiveBranchState\": {");
            sb.AppendLine($"    \"schemaVersion\": {SchemaVersion},");
            sb.AppendLine($"    \"updatedAtUtc\": \"{updatedAt}\",");
            sb.AppendLine($"    \"currentTown\": {JsonString(snapshot.SettlementName)},");
            sb.AppendLine($"    \"currentSettlementId\": {JsonString(snapshot.SettlementId)},");
            sb.AppendLine($"    \"gameplaySurface\": {JsonString(snapshot.GameplaySurface)},");
            sb.AppendLine("    \"terminal\": false,");
            sb.AppendLine("    \"nextActionRequired\": true,");
            sb.AppendLine($"    \"nextPlannedBranch\": {JsonString(next)},");
            sb.AppendLine($"    \"nextActionReason\": {JsonString(reason)},");
            sb.AppendLine("    \"branches\": {");
            AppendBranch(sb, "travel", snapshot.SafeToExecuteTravel ? "available" : "blocked",
                snapshot.SafeToExecuteTravel ? "surface_allows_travel" : snapshot.BlockReason ?? "travel_surface_blocked",
                "status", "map_traversal", updatedAt, comma: true);
            AppendBranch(sb, "trade", snapshot.SafeToExecuteTrade ? "unknown" : "blocked",
                snapshot.SafeToExecuteTrade ? "market_profitability_not_evaluated" : "trade_surface_not_open",
                "map_trade", "execute_trade_iteration", updatedAt, comma: true);
            AppendBranch(sb, "horse_acquisition", settlementLike ? "unknown" : "blocked",
                settlementLike ? "horse_market_affordability_not_evaluated" : "not_at_settlement_surface",
                settlementLike ? "horse_market" : "none", "horse_acquisition", updatedAt, comma: true);
            AppendBranch(sb, "inventory_management", snapshot.IsCampaignLoaded ? "unknown" : "blocked",
                snapshot.IsCampaignLoaded ? "inventory_pressure_not_evaluated" : "campaign_not_loaded",
                snapshot.IsCampaignLoaded ? "status" : "none", "inventory_management", updatedAt, comma: true);
            AppendBranch(sb, "smith_refine", snapshot.SafeToExecuteSmithing ? "unknown" : "blocked",
                snapshot.SafeToExecuteSmithing ? "smithing_stamina_materials_not_evaluated" : "smithing_surface_not_open",
                "smithing", "smithing_or_prep", updatedAt, comma: true);
            AppendBranch(sb, "rest_wait", snapshot.SafeToWait ? "available" : "blocked",
                snapshot.SafeToWait ? "safe_wait_surface" : "wait_not_safe_on_surface",
                "status", "rest_wait", updatedAt, comma: true);
            AppendBranch(sb, "tavern_scan", settlementLike ? "unknown" : "blocked",
                settlementLike ? "tavern_candidates_not_scanned" : "not_at_settlement_surface",
                "status", "observe_runtime_state", updatedAt, comma: true);
            AppendBranch(sb, "companion_roster", snapshot.IsCampaignLoaded ? "unknown" : "blocked",
                snapshot.IsCampaignLoaded ? "companion_roster_not_scanned" : "campaign_not_loaded",
                "status", "observe_runtime_state", updatedAt, comma: true);
            AppendBranch(sb, "avoid_threat", "unknown", "threat_state_unknown_until_posture_scan_consumed",
                "threat_scan", "evaluate_threat_state", updatedAt, comma: true);
            AppendBranch(sb, "observe_only", "available", "always_safe_fallback",
                "none", "observe_only", updatedAt, comma: false);
            sb.AppendLine("    }");
            sb.AppendLine("  },");
            return sb.ToString();
        }

        // Stable change-detection signature: excludes timestamps so identical branch truth across
        // repeated status flushes does not spam recursiveBranchState.changed runtime events.
        public static string BuildSignature(GameplaySurfaceSnapshot snapshot)
        {
            snapshot = snapshot ?? new GameplaySurfaceSnapshot();
            var settlementLike = IsSettlementLike(snapshot);
            return string.Join("|", new[]
            {
                "next=" + SelectNextBranch(snapshot),
                "surface=" + (snapshot.GameplaySurface ?? "null"),
                "travel=" + (snapshot.SafeToExecuteTravel ? "1" : "0"),
                "trade=" + (snapshot.SafeToExecuteTrade ? "1" : "0"),
                "smith=" + (snapshot.SafeToExecuteSmithing ? "1" : "0"),
                "wait=" + (snapshot.SafeToWait ? "1" : "0"),
                "settlement=" + (settlementLike ? "1" : "0"),
                "campaign=" + (snapshot.IsCampaignLoaded ? "1" : "0")
            });
        }

        private static string SelectNextBranch(GameplaySurfaceSnapshot snapshot)
        {
            if (snapshot.SafeToExecuteTravel)
            {
                return "travel";
            }

            if (snapshot.SafeToExecuteTrade || snapshot.SafeToExecuteSmithing)
            {
                return "observe_only";
            }

            if (snapshot.SafeToWait)
            {
                return "rest_wait";
            }

            return "observe_only";
        }

        private static string ExplainNextBranch(GameplaySurfaceSnapshot snapshot, string branch)
        {
            switch (branch)
            {
                case "travel":
                    return "surface_allows_travel_recompute_destination_from_fresh_state";
                case "rest_wait":
                    return "productive_branch_blocked_wait_is_safe";
                default:
                    return snapshot.BlockReason ?? "branch_truth_requires_fresh_observation";
            }
        }

        private static bool IsSettlementLike(GameplaySurfaceSnapshot snapshot)
        {
            return snapshot.GameplaySurface == GameplaySurfaceKinds.SettlementMenu
                || snapshot.GameplaySurface == GameplaySurfaceKinds.SettlementCity
                || snapshot.GameplaySurface == GameplaySurfaceKinds.SettlementInterior
                || Contains(snapshot.LocationId, "tavern")
                || Contains(snapshot.MenuId, "town", "village", "tavern");
        }

        private static void AppendBranch(
            StringBuilder sb,
            string name,
            string state,
            string reason,
            string evidenceSource,
            string boundaryName,
            string updatedAtUtc,
            bool comma)
        {
            sb.Append("      \"").Append(Escape(name)).Append("\": { ");
            sb.Append("\"state\": \"").Append(Escape(state)).Append("\", ");
            sb.Append("\"reason\": \"").Append(Escape(reason)).Append("\", ");
            sb.Append("\"evidenceSource\": \"").Append(Escape(evidenceSource)).Append("\", ");
            sb.Append("\"updatedAtUtc\": \"").Append(Escape(updatedAtUtc)).Append("\", ");
            sb.Append("\"boundaryName\": \"").Append(Escape(boundaryName)).Append("\", ");
            sb.Append("\"failureClass\": null }");
            sb.AppendLine(comma ? "," : string.Empty);
        }

        private static bool Contains(string value, params string[] needles)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            foreach (var needle in needles)
            {
                if (value.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }

            return false;
        }

        private static string JsonString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
    }
}
