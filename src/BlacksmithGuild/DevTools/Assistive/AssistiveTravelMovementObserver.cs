using System;
using System.Threading;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelMovementObserver
    {
        public const int MaxObservationMs = 500;
        public const int IntervalMs = 50;

        public static void Observe(Settlement expectedTarget, AssistiveTravelExecutionResult result)
        {
            if (result == null)
            {
                return;
            }

            result.MovementObservationStartedAtUtc = DateTime.UtcNow;
            var attempts = 0;
            var maxAttempts = Math.Max(1, MaxObservationMs / IntervalMs);

            for (var attempt = 1; attempt <= maxAttempts; attempt++)
            {
                attempts = attempt;
                GameSessionState.Refresh();

                var hasRoute = AutoTravelService.HasActiveRoute;
                var routeTarget = AutoTravelService.ActiveRouteDestination;
                var routeTargetId = routeTarget?.StringId;
                var routeMatches = routeTarget != null
                    && expectedTarget != null
                    && string.Equals(routeTargetId, expectedTarget.StringId, StringComparison.OrdinalIgnoreCase);

                result.Steps.Add(new AssistiveTravelStep
                {
                    Name = "MovementObservation",
                    Method = "Poll",
                    Status = hasRoute ? "Observed" : "Pending",
                    Detail = $"attempt={attempt} hasRoute={hasRoute.ToString().ToLowerInvariant()} routeTargetId={routeTargetId ?? "null"} routeMatches={routeMatches.ToString().ToLowerInvariant()}"
                });

                if (hasRoute)
                {
                    result.MovementIntentSet = true;
                    result.RouteTargetSettlementId = routeTargetId;
                    result.RouteTargetSettlement = routeTarget?.Name?.ToString() ?? routeTargetId;
                }

                if (hasRoute && routeMatches)
                {
                    result.ActualExecutionObserved = true;
                    result.MovementObservationPassed = true;
                    break;
                }

                if (attempt < maxAttempts)
                {
                    Thread.Sleep(IntervalMs);
                }
            }

            result.MovementObservationEndedAtUtc = DateTime.UtcNow;
            result.MovementObservationMs = (int)Math.Max(
                0,
                (result.MovementObservationEndedAtUtc.Value - result.MovementObservationStartedAtUtc.Value).TotalMilliseconds);
            result.MovementObservationAttempts = attempts;

            if (result.MovementObservationPassed)
            {
                return;
            }

            result.MovementObservationPassed = false;
            result.MovementObservationFailureReason = !result.MovementIntentSet
                ? AssistiveTravelFallbackReasons.MovementIntentNotObserved
                : AssistiveTravelFallbackReasons.ActualExecutionNotObserved;
        }
    }
}
