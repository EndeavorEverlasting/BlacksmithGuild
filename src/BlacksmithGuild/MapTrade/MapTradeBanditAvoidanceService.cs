using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
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
            foreach (var party in MobileParty.All)
            {
                if (party == null || party == main || party.MapFaction == null)
                {
                    continue;
                }

                if (!main.MapFaction.IsAtWarWith(party.MapFaction))
                {
                    continue;
                }

                var distance = CampaignMapMovementHelper.Distance(main, party);
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
                    && CampaignMapMovementHelper.PartyStrength(party) >= playerStrength)
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
