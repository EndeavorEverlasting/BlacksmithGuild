using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.ClanIntel
{
    public static class ClanRouteSafetyHelper
    {
        public static string EvaluateRouteSafety(float distance)
        {
            var main = MobileParty.MainParty;
            if (main == null)
            {
                return "Unknown";
            }

            var snapshots = CohesionPartyScanner.Scan(DevToolsConfig.MapTradeAbortHostileRadius * 3f, main);
            var hostiles = CohesionPartyScanner.FilterHostiles(snapshots);
            var nearest = hostiles.OrderBy(h => h.DistanceToPlayer).FirstOrDefault();
            if (nearest != null && nearest.DistanceToPlayer <= DevToolsConfig.MapTradeAbortHostileRadius)
            {
                return "Unsafe";
            }

            if (nearest != null && nearest.DistanceToPlayer <= DevToolsConfig.MapTradeAvoidHostileRadius)
            {
                return "Medium";
            }

            if (distance > ClanIntelDoctrine.MaxScanDistance * 0.75f)
            {
                return "LogisticallyBad";
            }

            return "Safe";
        }

        public static float? DistanceToHero(Settlement settlement)
        {
            var main = MobileParty.MainParty;
            if (main == null || settlement == null)
            {
                return null;
            }

            return CampaignMapMovementHelper.Distance(main, settlement);
        }
    }
}
