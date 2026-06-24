namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelFallbackReasons
    {
        public const string ExecuteNotRequested = "execute_not_requested";
        public const string InvalidTarget = "invalid_target";
        public const string TargetIsCurrentSettlement = "target_is_current_settlement";
        public const string MissionActive = "mission_active";
        public const string LeaveTownFailed = "leave_town_failed";
        public const string LeaveTownIncomplete = "leave_town_incomplete";
        public const string MapSurfaceNotReached = "map_surface_not_reached";
        public const string TravelApiUnavailable = "travel_api_unavailable";
        public const string TravelApiCallFailed = "travel_api_call_failed";
        public const string MovementIntentNotObserved = "movement_intent_not_observed";
        public const string ActualExecutionNotObserved = "actual_execution_not_observed";

        public static string SurfaceNotExecuteEligible(string surface) =>
            $"surface_not_execute_eligible:{surface ?? "unknown"}";

        public static string NormalizeTravelApiDetail(string detail, bool callAttempted)
        {
            if (string.IsNullOrWhiteSpace(detail))
            {
                return callAttempted ? TravelApiCallFailed : TravelApiUnavailable;
            }

            if (detail == TravelApiUnavailable
                || detail == TravelApiCallFailed
                || detail.StartsWith("surface_not_execute_eligible:")
                || detail.StartsWith("nearby war-hostile"))
            {
                return detail;
            }

            if (detail.IndexOf("unavailable", System.StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return TravelApiUnavailable;
            }

            return callAttempted ? TravelApiCallFailed : TravelApiUnavailable;
        }
    }
}
