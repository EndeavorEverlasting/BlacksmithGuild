using System;
using System.Text;

namespace BlacksmithGuild.DevTools
{
    public static class RecursiveCampaignBranchState
    {
        public const int SchemaVersion = 1;

        public static string BuildJsonBlock(GameplaySurfaceSnapshot snapshot)
        {
            snapshot = snapshot ?? new GameplaySurfaceSnapshot();
            var next = SelectNextBranch(snapshot);
            var reason = ExplainNextBranch(snapshot, next);

            var sb = new StringBuilder();
            sb.AppendLine("  \"recursiveBranchState\": {");
            sb.AppendLine($"    \"schemaVersion\": {SchemaVersion},");
            sb.AppendLine($"    \"updatedAtUtc\": \"{snapshot.UpdatedAtUtc:o}\",");
            sb.AppendLine($"    \"currentTown\": {JsonString(snapshot.SettlementName)},");
            sb.AppendLine($"    \"currentSettlementId\": {JsonString(snapshot.SettlementId)},");
            sb.AppendLine($"    \"gameplaySurface\": {JsonString(snapshot.GameplaySurface)},");
            sb.AppendLine("    \"terminal\": false,");
            sb.AppendLine("    \"nextActionRequired\": true,");
            sb.AppendLine($"    \"nextPlannedBranch\": {JsonString(next)},");
            sb.AppendLine($"    \"nextActionReason\": {JsonString(reason)},");
            sb.AppendLine("    \"branches\": {");
            AppendBranch(sb, "travel", snapshot.SafeToExecuteTravel ? "available" : "blocked",
                snapshot.SafeToExecuteTravel ? "surface_allows_travel" : snapshot.BlockReason ?? "travel_surface_blocked", comma: true);
            AppendBranch(sb, "trade", snapshot.SafeToExecuteTrade ? "unknown" : "blocked",
                snapshot.SafeToExecuteTrade ? "market_profitability_not_evaluated" : "trade_surface_not_open", comma: true);
            AppendBranch(sb, "smith_refine", snapshot.SafeToExecuteSmithing ? "unknown" : "blocked",
                snapshot.SafeToExecuteSmithing ? "smithing_stamina_materials_not_evaluated" : "smithing_surface_not_open", comma: true);
            AppendBranch(sb, "rest_wait", snapshot.SafeToWait ? "available" : "blocked",
                snapshot.SafeToWait ? "safe_wait_surface" : "wait_not_safe_on_surface", comma: true);
            AppendBranch(sb, "tavern_scan", IsSettlementLike(snapshot) ? "unknown" : "blocked",
                IsSettlementLike(snapshot) ? "tavern_candidates_not_scanned" : "not_at_settlement_surface", comma: true);
            AppendBranch(sb, "companion_roster", snapshot.IsCampaignLoaded ? "unknown" : "blocked",
                snapshot.IsCampaignLoaded ? "companion_roster_not_scanned" : "campaign_not_loaded", comma: true);
            AppendBranch(sb, "avoid_threat", "unknown", "threat_state_unknown_until_posture_scan_consumed", comma: true);
            AppendBranch(sb, "observe_only", "available", "always_safe_fallback", comma: false);
            sb.AppendLine("    }");
            sb.AppendLine("  },");
            return sb.ToString();
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

        private static void AppendBranch(StringBuilder sb, string name, string state, string reason, bool comma)
        {
            sb.AppendLine($"      \"{Escape(name)}\": {{ \"state\": \"{Escape(state)}\", \"reason\": \"{Escape(reason)}\" }}{(comma ? "," : string.Empty)}");
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
