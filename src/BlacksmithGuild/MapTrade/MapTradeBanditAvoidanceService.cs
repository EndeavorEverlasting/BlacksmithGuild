using System;
using System.Collections.Generic;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeBanditAvoidanceService
    {
        public static bool HasBlockingHostiles(out int hostileCount, out float nearestDistance)
        {
            var snapshot = CaptureSafetySnapshot();
            hostileCount = snapshot.HostileCount;
            nearestDistance = snapshot.NearestHostileDistance;
            return snapshot.IsBlocking;
        }

        public static MapTradeHostileSafetySnapshot CaptureSafetySnapshot()
        {
            var main = MobileParty.MainParty;
            if (main == null)
            {
                return MapTradeHostileSafetySnapshot.Unavailable("main party unavailable");
            }

            var campaignSnapshot = CampaignThreatSnapshotProvider.Capture(
                main,
                DevToolsConfig.MapTradeAvoidHostileRadius);
            if (!campaignSnapshot.ScanSucceeded)
            {
                return MapTradeHostileSafetySnapshot.Unavailable(campaignSnapshot.ScanFailure);
            }

            var threats = new List<HostileThreatVectorSnapshot>();
            var nearestDistance = float.MaxValue;
            foreach (var hostile in campaignSnapshot.Hostiles)
            {
                if (hostile == null)
                {
                    continue;
                }

                threats.Add(new HostileThreatVectorSnapshot
                {
                    PartyId = hostile.PartyId,
                    PositionX = hostile.PositionX,
                    PositionY = hostile.PositionY,
                    Strength = hostile.Strength,
                    ClearanceRadius = 0f
                });
                nearestDistance = Math.Min(nearestDistance, hostile.Distance);
            }

            var escape = HostileEscapeVectorAnalyzer.Analyze(new HostileEscapeVectorRequest
            {
                ProtectedPartyId = main.StringId ?? "main_party",
                ProtectedPositionX = campaignSnapshot.ProtectedPositionX,
                ProtectedPositionY = campaignSnapshot.ProtectedPositionY,
                ProtectedStrength = campaignSnapshot.ProtectedStrength,
                MinimumClearance = DevToolsConfig.MapTradeAbortHostileRadius,
                MaximumInfluenceDistance = DevToolsConfig.MapTradeAvoidHostileRadius,
                SuggestedStepDistance = Math.Max(1f, DevToolsConfig.MapTradeAbortHostileRadius),
                PredictionHorizonSeconds = 0f,
                Hostiles = threats
            });

            return new MapTradeHostileSafetySnapshot
            {
                ScanSucceeded = true,
                EnumerationPasses = campaignSnapshot.EnumerationPasses,
                PartiesEnumerated = campaignSnapshot.PartiesEnumerated,
                HostileCount = threats.Count,
                NearestHostileDistance = nearestDistance,
                IsBlocking = threats.Count > 0
                    && nearestDistance <= DevToolsConfig.MapTradeAbortHostileRadius,
                EscapeRecommendation = escape
            };
        }

        public static string EvaluateRiskLevel()
        {
            var snapshot = CaptureSafetySnapshot();
            if (snapshot.IsBlocking)
            {
                return "High";
            }

            if (snapshot.HostileCount > 0)
            {
                return "Medium";
            }

            return snapshot.ScanSucceeded ? "Low" : "Unknown";
        }
    }

    public sealed class MapTradeHostileSafetySnapshot
    {
        public bool ScanSucceeded { get; set; }
        public string ScanFailure { get; set; }
        public int EnumerationPasses { get; set; }
        public int PartiesEnumerated { get; set; }
        public int HostileCount { get; set; }
        public float NearestHostileDistance { get; set; } = float.MaxValue;
        public bool IsBlocking { get; set; }
        public HostileEscapeVectorResult EscapeRecommendation { get; set; }

        public static MapTradeHostileSafetySnapshot Unavailable(string reason)
        {
            return new MapTradeHostileSafetySnapshot
            {
                ScanSucceeded = false,
                ScanFailure = reason,
                EnumerationPasses = 1,
                NearestHostileDistance = float.MaxValue,
                IsBlocking = true,
                EscapeRecommendation = new HostileEscapeVectorResult
                {
                    NearestHostileDistance = -1f,
                    CurrentMinimumClearanceMargin = -1f,
                    ProjectedMinimumClearanceMargin = -1f,
                    GeometryConfidence = "Unavailable",
                    Urgency = "Unknown",
                    RecommendationOnly = true,
                    MovementMutationApplied = false
                }
            };
        }
    }
}
