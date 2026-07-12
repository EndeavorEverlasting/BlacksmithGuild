using System;
using System.Collections.Generic;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeRouteSafetyAnalyzer
    {
        public const string AnalyzeMapTradeRouteSafetyCommand = "AnalyzeMapTradeRouteSafety";

        public static bool AnalyzeNow(string source = AnalyzeMapTradeRouteSafetyCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG MAP TRADE: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            var report = BuildReport(source);
            MapTradeEvidenceWriter.WriteRouteSafety(report);
            InGameNotice.Info($"TBG MAP TRADE SAFETY: {report.Verdict} | hostiles={report.HostileCount}");
            return true;
        }

        public static MapTradeRouteSafetyReport BuildReport(string source)
        {
            var hostileSnapshot = MapTradeBanditAvoidanceService.CaptureSafetySnapshot();
            HostileEscapeEvidenceWriter.Write(hostileSnapshot, source);
            var hostileCount = hostileSnapshot.HostileCount;
            var nearestHostile = hostileSnapshot.NearestHostileDistance;
            var army = MapTradeArmyPressureAnalyzer.AnalyzeNow();
            var decisions = new List<MapTradeCohesionDecision>();
            CohesionOpportunity cohesion = null;

            if (DevToolsConfig.MapTradeUseTacticalConvergence)
            {
                var objective = CohesionDoctrine.BuildDefaultObjective();
                cohesion = CohesionEngine.BuildPlanForObjective(objective);
                if (cohesion != null)
                {
                    decisions.Add(new MapTradeCohesionDecision
                    {
                        Phase = "AnalyzeRouteSafety",
                        RecommendedAction = cohesion.RecommendedAction.ToString(),
                        Score = cohesion.Score,
                        BlockedReason = cohesion.BlockedReason
                    });
                }
            }

            var verdict = "SafeEnough";
            string blockedReason = null;
            if (!hostileSnapshot.ScanSucceeded)
            {
                verdict = "Blocked";
                blockedReason = hostileSnapshot.ScanFailure ?? "hostile safety snapshot unavailable";
            }
            else if (hostileCount > 0 && nearestHostile <= DevToolsConfig.MapTradeAbortHostileRadius)
            {
                verdict = "HighRisk";
                blockedReason = $"hostile within {nearestHostile:0.#} units";
            }
            else if (army.Window == "Closed")
            {
                verdict = "Blocked";
                blockedReason = "army pressure window closed";
            }
            else if (army.Window == "Likely")
            {
                verdict = "LikelySafeWithCohesion";
            }

            return new MapTradeRouteSafetyReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                Verdict = verdict,
                BlockedReason = blockedReason,
                HostileCount = hostileCount,
                NearestHostileDistance = nearestHostile == float.MaxValue ? -1f : nearestHostile,
                ArmyPressureWindow = army.Window,
                SelectedCohesionOpportunity = cohesion,
                CohesionDecisions = decisions
            };
        }
    }
}
