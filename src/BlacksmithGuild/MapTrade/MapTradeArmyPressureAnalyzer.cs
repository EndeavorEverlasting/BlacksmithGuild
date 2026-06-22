using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeArmyPressureAnalyzer
    {
        public static MapTradeArmyPressureReport AnalyzeNow()
        {
            var main = MobileParty.MainParty;
            var snapshots = CohesionPartyScanner.Scan(DevToolsConfig.MapTradeArmyPressureScanRadius, main);
            var hostiles = CohesionPartyScanner.FilterHostiles(snapshots);
            var helpers = CohesionPartyScanner.FilterHelpers(snapshots);

            var window = "Unknown";
            if (hostiles.Count == 0)
            {
                window = "Open";
            }
            else if (helpers.Count > 0 && helpers.Any(h => h.Strength >= (main?.Party?.NumberOfAllMembers ?? 0) * DevToolsConfig.MapTradeMinimumProtectorStrengthRatio))
            {
                window = DevToolsConfig.MapTradeAllowLikelyArmyWindows ? "Likely" : "Closed";
            }
            else if (hostiles.Any(h => h.DistanceToPlayer <= DevToolsConfig.MapTradeAbortHostileRadius))
            {
                window = "Closed";
            }
            else if (hostiles.Any(h => h.DistanceToPlayer <= DevToolsConfig.MapTradeAvoidHostileRadius))
            {
                window = DevToolsConfig.MapTradeAllowLikelyArmyWindows ? "Likely" : "Closed";
            }
            else
            {
                window = "Open";
            }

            return new MapTradeArmyPressureReport
            {
                GeneratedUtc = System.DateTime.UtcNow.ToString("o"),
                Window = window,
                HostilePartiesInRadius = hostiles.Count,
                FriendlyProtectorsInRadius = helpers.Count
            };
        }
    }
}
