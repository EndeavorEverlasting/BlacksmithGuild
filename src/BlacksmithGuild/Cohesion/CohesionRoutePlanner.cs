using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionRoutePlanner
    {
        public static CohesionConvergencePoint PlanConvergence(
            MobileParty main,
            CohesionPartySnapshot helper,
            Settlement objectiveSettlement)
        {
            if (main == null)
            {
                return null;
            }

            var mainPos = main.GetPosition2D;
            if (helper != null)
            {
                var helperPos = new Vec2(helper.PositionX, helper.PositionY);
                var midpoint = (mainPos + helperPos) * 0.5f;
                if (objectiveSettlement != null)
                {
                    var objectivePos = objectiveSettlement.GetPosition2D;
                    midpoint = (midpoint + objectivePos) * 0.5f;
                }

                return new CohesionConvergencePoint
                {
                    X = midpoint.x,
                    Y = midpoint.y,
                    Label = helper.Name ?? helper.PartyId,
                    SettlementId = objectiveSettlement?.StringId
                };
            }

            if (objectiveSettlement != null)
            {
                var pos = objectiveSettlement.GetPosition2D;
                return new CohesionConvergencePoint
                {
                    X = pos.x,
                    Y = pos.y,
                    Label = objectiveSettlement.Name?.ToString(),
                    SettlementId = objectiveSettlement.StringId
                };
            }

            return new CohesionConvergencePoint
            {
                X = mainPos.x,
                Y = mainPos.y,
                Label = "player-position"
            };
        }

        public static Settlement ResolveSettlement(CohesionObjective objective)
        {
            if (objective == null || string.IsNullOrEmpty(objective.TargetSettlementId))
            {
                return null;
            }

            return Settlement.All.FirstOrDefault(s =>
                string.Equals(s.StringId, objective.TargetSettlementId, StringComparison.OrdinalIgnoreCase));
        }

        public static Settlement FindRallySettlement(MobileParty main, IEnumerable<CohesionPartySnapshot> helpers)
        {
            var safeTown = CohesionPartyScanner.FindNearestSafeTown(main, DevToolsConfig.CohesionMaxRallyDistance);
            if (safeTown != null)
            {
                return safeTown;
            }

            var helper = helpers?.OrderBy(h => h.DistanceToPlayer).FirstOrDefault();
            if (helper == null)
            {
                return null;
            }

            return Settlement.All
                .Where(s => s.IsTown)
                .OrderBy(s => new Vec2(helper.PositionX, helper.PositionY).Distance(s.GetPosition2D))
                .FirstOrDefault();
        }

        public static float DistanceToPoint(MobileParty party, CohesionConvergencePoint point)
        {
            if (party == null || point == null)
            {
                return float.MaxValue;
            }

            return party.GetPosition2D.Distance(new Vec2(point.X, point.Y));
        }
    }
}
