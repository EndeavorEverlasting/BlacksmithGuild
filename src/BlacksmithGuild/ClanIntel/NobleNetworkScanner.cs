using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.ClanIntel
{
    public static class NobleNetworkScanner
    {
        public static List<NobleTarget> Scan()
        {
            var results = new List<NobleTarget>();
            var main = Hero.MainHero;
            if (main == null)
            {
                return results;
            }

            var objective = CohesionDoctrine.BuildDefaultObjective();
            var corridorSettlement = Settlement.All.FirstOrDefault(s =>
                s != null
                && !string.IsNullOrEmpty(objective.TargetSettlementId)
                && string.Equals(s.StringId, objective.TargetSettlementId, StringComparison.OrdinalIgnoreCase));

            foreach (var hero in Hero.AllAliveHeroes ?? Enumerable.Empty<Hero>())
            {
                if (hero == null || hero == main || hero.IsDead)
                {
                    continue;
                }

                if (!IsStrategicHero(hero))
                {
                    continue;
                }

                var settlement = ResolveHeroSettlement(hero);
                var distance = settlement != null
                    ? CampaignMapMovementHelper.Distance(MobileParty.MainParty, settlement)
                    : float.MaxValue;
                if (distance > ClanIntelDoctrine.MaxScanDistance)
                {
                    continue;
                }

                results.Add(new NobleTarget
                {
                    HeroId = hero.StringId,
                    TargetNoble = hero.Name?.ToString() ?? hero.StringId,
                    Clan = hero.Clan?.Name?.ToString(),
                    Faction = hero.MapFaction?.Name?.ToString(),
                    Relation = SafeRelation(main, hero),
                    Distance = distance == float.MaxValue ? (float?)null : distance,
                    RouteSafety = settlement != null
                        ? ClanRouteSafetyHelper.EvaluateRouteSafety(distance)
                        : "Unknown"
                });
            }

            return NobleNetworkScorer.ScoreAll(results, main, corridorSettlement);
        }

        private static bool IsStrategicHero(Hero hero)
        {
            if (hero.IsFactionLeader || hero.IsLord || hero.IsNotable)
            {
                return true;
            }

            if (hero.GovernorOf != null)
            {
                return true;
            }

            return hero.Clan?.Leader == hero;
        }

        private static Settlement ResolveHeroSettlement(Hero hero)
        {
            return ResolveHeroSettlementPublic(hero);
        }

        public static Settlement ResolveHeroSettlementPublic(Hero hero)
        {
            if (hero.CurrentSettlement != null)
            {
                return hero.CurrentSettlement;
            }

            if (hero.PartyBelongedTo?.CurrentSettlement != null)
            {
                return hero.PartyBelongedTo.CurrentSettlement;
            }

            if (hero.StayingInSettlement != null)
            {
                return hero.StayingInSettlement;
            }

            return hero.HomeSettlement;
        }

        private static int? SafeRelation(Hero main, Hero other)
        {
            try
            {
                return main.GetRelation(other);
            }
            catch
            {
                return null;
            }
        }
    }

    public static class NobleNetworkScorer
    {
        public static List<NobleTarget> ScoreAll(List<NobleTarget> targets, Hero main, Settlement corridorSettlement)
        {
            foreach (var target in targets)
            {
                var score = 10f;
                var reasons = new List<string>();

                if (CultureMatches(target))
                {
                    score += 20f * ClanIntelDoctrine.CultureFitWeight;
                    reasons.Add("Culture-aligned (Aserai path)");
                }

                if (target.Relation.HasValue && target.Relation.Value < 10)
                {
                    score += (10 - target.Relation.Value) * ClanIntelDoctrine.RelationDeficitWeight;
                    reasons.Add("Relation deficit with upside");
                }

                if (target.RouteSafety == "Safe")
                {
                    score += 8f;
                    reasons.Add("Safe route access");
                }
                else if (target.RouteSafety == "Unsafe")
                {
                    score -= 25f;
                    reasons.Add("Unsafe travel corridor");
                }

                if (corridorSettlement != null && target.Distance.HasValue && target.Distance.Value < 40f)
                {
                    score += 12f;
                    reasons.Add("Near trade/forge corridor");
                }

                if (string.Equals(target.Faction, main.MapFaction?.Name?.ToString(), StringComparison.OrdinalIgnoreCase))
                {
                    score += 5f;
                }

                target.Reasons = reasons;
                target.Score = score;
                target.StrategicValue = score >= 35f ? "High" : score >= 20f ? "Medium" : "Low";
                target.RecommendedAction = score >= 25f ? "SeekQuestOrAudience" : "Monitor";
            }

            return targets.OrderByDescending(t => t.Score).ToList();
        }

        private static bool CultureMatches(NobleTarget target)
        {
            return target.Faction?.IndexOf("Aserai", StringComparison.OrdinalIgnoreCase) >= 0
                || target.Clan?.IndexOf("Banu", StringComparison.OrdinalIgnoreCase) >= 0;
        }
    }
}
