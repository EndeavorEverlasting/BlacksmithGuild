using System;
using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeBanditAvoidanceService
    {
        public static bool HasBlockingHostiles(out int hostileCount, out float nearestDistance)
        {
            hostileCount = 0;
            nearestDistance = float.MaxValue;
            var main = MobileParty.MainParty;
            if (main == null)
            {
                return false;
            }

            var playerStrength = CampaignMapMovementHelper.PartyStrength(main);
            var scanRadius = Math.Max(
                DevToolsConfig.MapTradeAvoidHostileRadius,
                DevToolsConfig.MapTradeAbortHostileRadius);
            var snapshots = CohesionPartyScanner.Scan(scanRadius, main);
            foreach (var party in snapshots.Where(snapshot =>
                         snapshot.RelationToPlayer == CohesionRelationToPlayer.Hostile))
            {
                var distance = party.DistanceToPlayer;
                if (distance > DevToolsConfig.MapTradeAvoidHostileRadius)
                {
                    continue;
                }

                hostileCount++;
                if (distance < nearestDistance)
                {
                    nearestDistance = distance;
                }

                if (distance <= DevToolsConfig.MapTradeAbortHostileRadius
                    && party.Strength >= playerStrength)
                {
                    return true;
                }
            }

            return hostileCount > 0 && nearestDistance <= DevToolsConfig.MapTradeAbortHostileRadius;
        }

        public static string EvaluateRiskLevel()
        {
            if (HasBlockingHostiles(out _, out var nearest))
            {
                return "High";
            }

            var snapshots = CohesionPartyScanner.Scan(DevToolsConfig.CohesionScanRadius, MobileParty.MainParty);
            var hostiles = CohesionPartyScanner.FilterHostiles(snapshots);
            if (hostiles.Any(h => h.DistanceToPlayer <= DevToolsConfig.MapTradeAvoidHostileRadius))
            {
                return "Medium";
            }

            return "Low";
        }
    }
}
