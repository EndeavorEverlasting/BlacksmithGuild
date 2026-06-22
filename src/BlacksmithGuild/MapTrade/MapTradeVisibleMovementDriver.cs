using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeVisibleMovementDriver
    {
        public static bool TryStartTravel(MapTradeMission mission, out string detail)
        {
            detail = null;
            if (mission?.TargetSettlement == null)
            {
                detail = "no target settlement";
                return false;
            }

            return CampaignMapMovementHelper.TryMoveToSettlement(
                MobileParty.MainParty,
                mission.TargetSettlement,
                out detail);
        }

        public static bool HasArrived(MapTradeMission mission)
        {
            if (mission?.TargetSettlement == null)
            {
                return false;
            }

            return CampaignMapMovementHelper.HasArrived(MobileParty.MainParty, mission.TargetSettlement);
        }

        public static bool TryDuckToNearestSafeTown(out string detail)
        {
            detail = null;
            var town = Cohesion.CohesionPartyScanner.FindNearestSafeTown(MobileParty.MainParty);
            if (town == null)
            {
                detail = "no safe town";
                return false;
            }

            return CampaignMapMovementHelper.TryMoveToSettlement(MobileParty.MainParty, town, out detail);
        }

        public static bool ShouldHoldForHostiles()
        {
            return MapTradeBanditAvoidanceService.HasBlockingHostiles(out _, out _);
        }

        public static void Hold()
        {
            CampaignMapMovementHelper.TryHold(MobileParty.MainParty);
        }
    }
}
