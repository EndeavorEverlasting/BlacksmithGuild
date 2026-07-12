using System;
using System.Collections.Generic;

namespace BlacksmithGuild.Cohesion
{
    /// <summary>
    /// A game-agnostic threat sample. Runtime adapters own enumeration and classification;
    /// this model deliberately has no game-runtime dependency and cannot move a party.
    /// </summary>
    public sealed class HostileThreatVectorSnapshot
    {
        public string PartyId { get; set; }
        public float PositionX { get; set; }
        public float PositionY { get; set; }
        public float VelocityX { get; set; }
        public float VelocityY { get; set; }
        public int Strength { get; set; }
        public float ClearanceRadius { get; set; }
    }

    public sealed class HostileEscapeVectorRequest
    {
        public HostileEscapeVectorRequest()
        {
            Hostiles = new List<HostileThreatVectorSnapshot>();
        }

        public string ProtectedPartyId { get; set; }
        public float ProtectedPositionX { get; set; }
        public float ProtectedPositionY { get; set; }
        public int ProtectedStrength { get; set; }
        public float MinimumClearance { get; set; }
        public float MaximumInfluenceDistance { get; set; }
        public float SuggestedStepDistance { get; set; }
        public float PredictionHorizonSeconds { get; set; }
        public IList<HostileThreatVectorSnapshot> Hostiles { get; set; }
    }

    public sealed class HostileEscapeVectorResult
    {
        public string ProtectedPartyId { get; set; }
        public int SnapshotCount { get; set; }
        public int ThreatsConsidered { get; set; }
        public int PairEvaluations { get; set; }
        public float NearestHostileDistance { get; set; }
        public float CurrentMinimumClearanceMargin { get; set; }
        public float EscapeHeadingX { get; set; }
        public float EscapeHeadingY { get; set; }
        public float SuggestedPositionX { get; set; }
        public float SuggestedPositionY { get; set; }
        public float ProjectedMinimumClearanceMargin { get; set; }
        public float WeightedRepulsionMagnitude { get; set; }
        public float VectorCancellationRatio { get; set; }
        public bool FallbackDirectionUsed { get; set; }
        public bool ThreatsSurroundProtectedParty { get; set; }
        public bool ImprovesMinimumClearance { get; set; }
        public bool ClearanceSatisfied { get; set; }
        public string GeometryConfidence { get; set; }
        public string Urgency { get; set; }
        public bool RecommendationOnly { get; set; }
        public bool MovementMutationApplied { get; set; }
    }

    /// <summary>
    /// Computes a strength- and proximity-weighted direction away from every hostile in one
    /// supplied snapshot. It never enumerates campaign state and never issues movement.
    /// Runtime cost is O(n): one accumulation pass plus one clearance projection pass.
    /// </summary>
    public static class HostileEscapeVectorAnalyzer
    {
        public const string Algorithm = "strength_proximity_weighted_repulsion";
        private const float Epsilon = 0.0001f;
        private const float SurroundingCancellationThreshold = 0.08f;

        public static HostileEscapeVectorResult Analyze(HostileEscapeVectorRequest request)
        {
            if (request == null)
            {
                throw new ArgumentNullException("request");
            }

            var result = new HostileEscapeVectorResult
            {
                ProtectedPartyId = request.ProtectedPartyId,
                SnapshotCount = request.Hostiles == null ? 0 : request.Hostiles.Count,
                NearestHostileDistance = -1f,
                CurrentMinimumClearanceMargin = -1f,
                ProjectedMinimumClearanceMargin = -1f,
                SuggestedPositionX = request.ProtectedPositionX,
                SuggestedPositionY = request.ProtectedPositionY,
                GeometryConfidence = "Clear",
                Urgency = "Clear",
                RecommendationOnly = true,
                MovementMutationApplied = false
            };

            if (request.Hostiles == null || request.Hostiles.Count == 0)
            {
                result.ClearanceSatisfied = true;
                return result;
            }

            var maximumInfluence = PositiveOrDefault(request.MaximumInfluenceDistance, 10f);
            var minimumClearance = Math.Max(0f, request.MinimumClearance);
            var suggestedStep = PositiveOrDefault(request.SuggestedStepDistance, 1f);
            var horizon = Math.Max(0f, Math.Min(request.PredictionHorizonSeconds, 3600f));
            var protectedStrength = Math.Max(1, request.ProtectedStrength);
            var considered = new List<PredictedThreat>(request.Hostiles.Count);

            var repulsionX = 0f;
            var repulsionY = 0f;
            var totalWeight = 0f;
            var strongestWeight = -1f;
            var strongestAwayX = 0f;
            var strongestAwayY = 0f;
            var nearest = float.MaxValue;
            var currentMargin = float.MaxValue;

            foreach (var hostile in request.Hostiles)
            {
                if (hostile == null)
                {
                    continue;
                }

                var predictedX = hostile.PositionX + (hostile.VelocityX * horizon);
                var predictedY = hostile.PositionY + (hostile.VelocityY * horizon);
                var awayX = request.ProtectedPositionX - predictedX;
                var awayY = request.ProtectedPositionY - predictedY;
                var distance = Length(awayX, awayY);
                if (distance > maximumInfluence)
                {
                    continue;
                }

                if (distance <= Epsilon)
                {
                    StableUnitDirection(hostile.PartyId, out awayX, out awayY);
                }
                else
                {
                    awayX /= distance;
                    awayY /= distance;
                }

                var threatClearance = Math.Max(0f, hostile.ClearanceRadius);
                var requiredClearance = minimumClearance + threatClearance;
                var margin = distance - requiredClearance;
                var proximity = Math.Max(0f, (maximumInfluence - distance) / maximumInfluence);
                var clearanceDeficit = Math.Max(0f, -margin) / Math.Max(0.25f, requiredClearance);
                var strengthRatio = Math.Max(1, hostile.Strength) / (float)protectedStrength;
                var weight = strengthRatio
                    * (0.05f + (proximity * proximity) + (clearanceDeficit * clearanceDeficit))
                    / Math.Max(0.25f, distance);

                repulsionX += awayX * weight;
                repulsionY += awayY * weight;
                totalWeight += weight;
                if (weight > strongestWeight)
                {
                    strongestWeight = weight;
                    strongestAwayX = awayX;
                    strongestAwayY = awayY;
                }

                nearest = Math.Min(nearest, distance);
                currentMargin = Math.Min(currentMargin, margin);
                considered.Add(new PredictedThreat
                {
                    PositionX = predictedX,
                    PositionY = predictedY,
                    RequiredClearance = requiredClearance
                });
            }

            result.ThreatsConsidered = considered.Count;
            result.PairEvaluations = considered.Count;
            if (considered.Count == 0)
            {
                result.ClearanceSatisfied = true;
                return result;
            }

            var repulsionMagnitude = Length(repulsionX, repulsionY);
            var netRepulsionMagnitude = repulsionMagnitude;
            var cancellationRatio = totalWeight <= Epsilon ? 0f : repulsionMagnitude / totalWeight;
            var surrounding = considered.Count > 1 && cancellationRatio < SurroundingCancellationThreshold;
            var fallback = repulsionMagnitude <= Epsilon || surrounding;
            if (fallback)
            {
                repulsionX = strongestAwayX;
                repulsionY = strongestAwayY;
                repulsionMagnitude = Length(repulsionX, repulsionY);
            }

            if (repulsionMagnitude > Epsilon)
            {
                repulsionX /= repulsionMagnitude;
                repulsionY /= repulsionMagnitude;
            }

            var suggestedX = request.ProtectedPositionX + (repulsionX * suggestedStep);
            var suggestedY = request.ProtectedPositionY + (repulsionY * suggestedStep);
            var projectedMargin = float.MaxValue;
            foreach (var hostile in considered)
            {
                var projectedDistance = Length(
                    suggestedX - hostile.PositionX,
                    suggestedY - hostile.PositionY);
                projectedMargin = Math.Min(
                    projectedMargin,
                    projectedDistance - hostile.RequiredClearance);
                result.PairEvaluations++;
            }

            result.NearestHostileDistance = nearest;
            result.CurrentMinimumClearanceMargin = currentMargin;
            result.EscapeHeadingX = repulsionX;
            result.EscapeHeadingY = repulsionY;
            result.SuggestedPositionX = suggestedX;
            result.SuggestedPositionY = suggestedY;
            result.ProjectedMinimumClearanceMargin = projectedMargin;
            result.WeightedRepulsionMagnitude = netRepulsionMagnitude;
            result.VectorCancellationRatio = cancellationRatio;
            result.FallbackDirectionUsed = fallback;
            result.ThreatsSurroundProtectedParty = surrounding;
            result.ImprovesMinimumClearance = projectedMargin > currentMargin + Epsilon;
            result.ClearanceSatisfied = projectedMargin >= 0f;
            result.GeometryConfidence = surrounding ? "Low" : considered.Count == 1 ? "High" : "Medium";
            result.Urgency = currentMargin < 0f
                ? "Emergency"
                : nearest <= minimumClearance * 2f ? "Avoid" : "Monitor";
            return result;
        }

        private static float PositiveOrDefault(float value, float fallback)
        {
            return value > Epsilon && !float.IsNaN(value) && !float.IsInfinity(value)
                ? value
                : fallback;
        }

        private static float Length(float x, float y)
        {
            return (float)Math.Sqrt((x * x) + (y * y));
        }

        private static void StableUnitDirection(string partyId, out float x, out float y)
        {
            unchecked
            {
                uint hash = 2166136261;
                foreach (var character in partyId ?? "unknown")
                {
                    hash = (hash ^ character) * 16777619;
                }

                switch (hash % 8)
                {
                    case 0: x = 1f; y = 0f; return;
                    case 1: x = 0.70710677f; y = 0.70710677f; return;
                    case 2: x = 0f; y = 1f; return;
                    case 3: x = -0.70710677f; y = 0.70710677f; return;
                    case 4: x = -1f; y = 0f; return;
                    case 5: x = -0.70710677f; y = -0.70710677f; return;
                    case 6: x = 0f; y = -1f; return;
                    default: x = 0.70710677f; y = -0.70710677f; return;
                }
            }
        }

        private sealed class PredictedThreat
        {
            public float PositionX { get; set; }
            public float PositionY { get; set; }
            public float RequiredClearance { get; set; }
        }
    }
}
