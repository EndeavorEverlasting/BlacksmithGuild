using System;
using System.Collections.Generic;
using System.Linq;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.ClanIntel
{
    public static class MarriageCandidateScanner
    {
        private const string CourtshipNotCertified = "Courtship dialogue path not yet certified";

        public static List<MarriageCandidateEntry> Scan()
        {
            var results = new List<MarriageCandidateEntry>();
            var main = Hero.MainHero;
            if (main == null || main.Spouse != null)
            {
                return results;
            }

            var marriageModel = Campaign.Current?.Models?.MarriageModel;
            foreach (var hero in Hero.AllAliveHeroes ?? Enumerable.Empty<Hero>())
            {
                if (hero == null || hero == main || hero.IsDead || hero.Spouse != null)
                {
                    continue;
                }

                if (!IsMarriageCandidate(hero, main, marriageModel))
                {
                    continue;
                }

                var settlement = NobleNetworkScanner.ResolveHeroSettlementPublic(hero);
                var distance = settlement != null
                    ? DevTools.CampaignMapMovementHelper.Distance(MobileParty.MainParty, settlement)
                    : float.MaxValue;
                if (distance > ClanIntelDoctrine.MaxScanDistance)
                {
                    continue;
                }

                results.Add(new MarriageCandidateEntry
                {
                    HeroId = hero.StringId,
                    Candidate = hero.Name?.ToString() ?? hero.StringId,
                    Culture = hero.Culture?.Name?.ToString(),
                    Clan = hero.Clan?.Name?.ToString(),
                    Distance = distance == float.MaxValue ? (float?)null : distance,
                    RouteSafety = settlement != null
                        ? ClanRouteSafetyHelper.EvaluateRouteSafety(distance)
                        : "Unknown",
                    CourtshipAvailable = null,
                    Warnings = new List<string> { CourtshipNotCertified }
                });
            }

            return MarriageCandidateScorer.ScoreAll(results, main);
        }

        private static bool IsMarriageCandidate(Hero candidate, Hero main, object marriageModel)
        {
            if (candidate.IsLord || candidate.IsNotable)
            {
                try
                {
                    if (marriageModel != null)
                    {
                        var method = marriageModel.GetType().GetMethod("IsCoupleSuitableForMarriage")
                            ?? marriageModel.GetType().GetMethod("CanHeroesMarry");
                        if (method != null)
                        {
                            var suitable = method.Invoke(marriageModel, new object[] { main, candidate });
                            if (suitable is bool boolResult)
                            {
                                return boolResult;
                            }
                        }
                    }
                }
                catch
                {
                }

                if (main.IsFemale != candidate.IsFemale)
                {
                    return true;
                }
            }

            return false;
        }
    }

    public static class MarriageCandidateScorer
    {
        public static List<MarriageCandidateEntry> ScoreAll(List<MarriageCandidateEntry> candidates, Hero main)
        {
            foreach (var candidate in candidates)
            {
                var score = 10f;
                if (string.Equals(candidate.Culture, "Aserai", StringComparison.OrdinalIgnoreCase)
                    || candidate.Culture?.IndexOf("Aserai", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    score += 25f;
                }

                if (candidate.RouteSafety == "Safe")
                {
                    score += 15f;
                }
                else if (candidate.RouteSafety == "Unsafe")
                {
                    score -= 30f;
                }

                if (candidate.Distance.HasValue)
                {
                    score -= candidate.Distance.Value * ClanIntelDoctrine.DistancePenaltyPerUnit;
                }

                candidate.Score = score;
                candidate.PoliticalValue = score >= 30f ? "High" : score >= 15f ? "Medium" : "Low";
                candidate.SkillsValue = "Unknown";
                candidate.RecommendedAction = score >= 25f ? "TravelAndOpenConversation" : "Monitor";
                candidate.Category = ResolveCategory(candidate, score);
            }

            return candidates.OrderByDescending(c => c.Score).ToList();
        }

        private static string ResolveCategory(MarriageCandidateEntry candidate, float score)
        {
            if (candidate.RouteSafety == "Unsafe")
            {
                return "Unsafe Route";
            }

            if (candidate.RouteSafety == "LogisticallyBad")
            {
                return "Logistically Bad";
            }

            if (score >= 35f)
            {
                return "Prime Candidate";
            }

            if (score >= 20f)
            {
                return "Good Candidate";
            }

            if (candidate.PoliticalValue == "High")
            {
                return "Politically Useful";
            }

            return "Unknown Eligibility";
        }
    }
}
