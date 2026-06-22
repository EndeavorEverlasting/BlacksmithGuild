using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.CampaignSystem.Settlements.Locations;
using TaleWorlds.Core;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroScanner
    {
        private static readonly string[] SkillNames =
        {
            "Smithing", "Trade", "Steward", "Medicine", "Scouting", "Riding", "Athletics",
            "Leadership", "Charm", "OneHanded", "TwoHanded", "Polearm", "Bow", "Crossbow", "Throwing"
        };

        public static TavernHeroSettlementSnapshot BuildSettlementSnapshot()
        {
            var snapshot = new TavernHeroSettlementSnapshot
            {
                PlayerInSettlement = GameSessionState.IsSettlementInteriorReady,
                PlayerInTavern = GameSessionState.IsTavernLocationReady,
                ActiveMenuId = GameSessionState.ActiveMenuId,
                CurrentLocationId = GameSessionState.CurrentLocationId
            };

            var settlement = GameSessionState.ResolveCurrentSettlement();
            if (settlement == null)
            {
                snapshot.BlockedReason = "party not at a settlement";
                return snapshot;
            }

            snapshot.Name = settlement.Name?.ToString() ?? settlement.StringId;
            snapshot.StringId = settlement.StringId;
            snapshot.Type = ResolveSettlementType(settlement);
            snapshot.HasTavern = settlement.LocationComplex?.GetLocationWithId("tavern") != null;

            if (!snapshot.PlayerInSettlement)
            {
                snapshot.BlockedReason = $"outside settlement {snapshot.Name} — enter town first";
            }
            else if (snapshot.HasTavern == false)
            {
                snapshot.BlockedReason = "settlement has no tavern location";
            }
            else if (!snapshot.PlayerInTavern)
            {
                snapshot.BlockedReason = "not in tavern location yet";
            }

            return snapshot;
        }

        public static TavernHeroPlayerSnapshot BuildPlayerSnapshot(Hero hero)
        {
            var gold = 0;
            try
            {
                gold = hero?.Gold ?? 0;
            }
            catch
            {
            }

            var reserve = DevToolsConfig.TavernHeroSafeGoldReserve;
            return new TavernHeroPlayerSnapshot
            {
                Gold = gold,
                SafeGoldReserve = reserve,
                SpendableGold = Math.Max(0, gold - reserve)
            };
        }

        public static TavernHeroCompanionStateSnapshot BuildCompanionSnapshot(MobileParty party)
        {
            var snapshot = new TavernHeroCompanionStateSnapshot();
            try
            {
                var clan = Clan.PlayerClan;
                if (clan != null)
                {
                    snapshot.CurrentCompanionCount = clan.Companions?.Count ?? 0;
                    snapshot.CompanionLimit = clan.CompanionLimit;
                    snapshot.LimitAvailable = true;
                    if (snapshot.CurrentCompanionCount.HasValue && snapshot.CompanionLimit.HasValue)
                    {
                        snapshot.RemainingSlots = Math.Max(0, snapshot.CompanionLimit.Value - snapshot.CurrentCompanionCount.Value);
                    }
                }
            }
            catch
            {
            }

            if (party?.MemberRoster != null)
            {
                foreach (var element in party.MemberRoster.GetTroopRoster())
                {
                    var hero = element.Character?.HeroObject;
                    if (hero == null)
                    {
                        continue;
                    }

                    var label = hero.Name?.ToString() ?? hero.StringId;
                    snapshot.PartyHeroes.Add(label);
                    if ((TryGetSkill(hero, "Smithing") ?? 0) >= 40 || (TryGetSkill(hero, "Trade") ?? 0) >= 40)
                    {
                        snapshot.SmithingCrewCandidates.Add(label);
                    }
                }
            }

            return snapshot;
        }

        public static List<TavernHeroCandidate> ScanCandidates(Settlement settlement)
        {
            var results = new List<TavernHeroCandidate>();
            if (settlement == null)
            {
                return results;
            }

            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            AddHeroes(results, seen, settlement.HeroesWithoutParty, "HeroesWithoutParty");
            AddLocationHeroes(results, seen, settlement, "tavern");
            AddLocationHeroes(results, seen, settlement, "tavern_backroom");

            return results
                .OrderByDescending(c => c.Score)
                .ThenBy(c => c.Name)
                .ToList();
        }

        private static void AddLocationHeroes(
            List<TavernHeroCandidate> results,
            HashSet<string> seen,
            Settlement settlement,
            string locationId)
        {
            try
            {
                var complex = settlement.LocationComplex;
                if (complex == null)
                {
                    return;
                }

                foreach (var character in complex.GetListOfCharactersInLocation(locationId))
                {
                    var hero = character?.Character?.HeroObject;
                    if (hero == null)
                    {
                        continue;
                    }

                    AddCandidate(results, seen, hero, $"Location:{locationId}");
                }
            }
            catch
            {
            }
        }

        private static void AddHeroes(
            List<TavernHeroCandidate> results,
            HashSet<string> seen,
            IEnumerable<Hero> heroes,
            string source)
        {
            if (heroes == null)
            {
                return;
            }

            foreach (var hero in heroes)
            {
                AddCandidate(results, seen, hero, source);
            }
        }

        private static void AddCandidate(
            List<TavernHeroCandidate> results,
            HashSet<string> seen,
            Hero hero,
            string source)
        {
            if (hero == null || !seen.Add(hero.StringId))
            {
                return;
            }

            if (!hero.IsWanderer)
            {
                return;
            }

            if (hero.IsPlayerCompanion)
            {
                return;
            }

            var candidate = BuildCandidate(hero, source);
            if (candidate != null)
            {
                results.Add(candidate);
            }
        }

        private static TavernHeroCandidate BuildCandidate(Hero hero, string source)
        {
            var candidate = new TavernHeroCandidate
            {
                HeroId = hero.StringId,
                Name = hero.Name?.ToString() ?? hero.StringId,
                Occupation = hero.Occupation.ToString(),
                Culture = hero.Culture?.Name?.ToString() ?? hero.Culture?.StringId,
                Clan = hero.Clan?.Name?.ToString() ?? hero.Clan?.StringId,
                IsWanderer = hero.IsWanderer,
                IsCompanion = hero.IsPlayerCompanion,
                IsAlive = hero.IsAlive,
                IsPrisoner = hero.IsPrisoner,
                CurrentSettlement = hero.CurrentSettlement?.Name?.ToString() ?? hero.StayingInSettlement?.Name?.ToString()
            };

            foreach (var skillName in SkillNames)
            {
                candidate.Skills[skillName] = TryGetSkill(hero, skillName);
            }

            candidate.RecruitmentCost = TryGetRecruitmentCost(hero);
            candidate.RecruitmentAvailable = EvaluateRecruitmentAvailable(hero, candidate);
            if (candidate.RecruitmentCost == null)
            {
                candidate.Warnings.Add("recruitment cost unavailable");
            }

            candidate.Warnings.Add($"source={source}");
            return candidate;
        }

        private static bool? EvaluateRecruitmentAvailable(Hero hero, TavernHeroCandidate candidate)
        {
            if (hero.IsPrisoner)
            {
                candidate.RiskFlags.Add("prisoner");
                return false;
            }

            if (!hero.IsAlive)
            {
                candidate.RiskFlags.Add("dead");
                return false;
            }

            if (hero.IsPlayerCompanion)
            {
                candidate.RiskFlags.Add("already_companion");
                return false;
            }

            if (!hero.IsWanderer)
            {
                candidate.RiskFlags.Add("not_wanderer");
                return false;
            }

            return true;
        }

        public static int? TryGetRecruitmentCost(Hero hero)
        {
            try
            {
                return Campaign.Current?.Models?.CompanionHiringPriceCalculationModel?.GetCompanionHiringPrice(hero);
            }
            catch
            {
                return null;
            }
        }

        public static int? TryGetSkill(Hero hero, string skillName)
        {
            try
            {
                var skill = ResolveSkill(skillName);
                if (skill == null)
                {
                    return null;
                }

                return hero.GetSkillValue(skill);
            }
            catch
            {
                return null;
            }
        }

        private static SkillObject ResolveSkill(string skillName)
        {
            switch (skillName)
            {
                case "Smithing":
                    return DefaultSkills.Crafting;
                case "OneHanded":
                    return DefaultSkills.OneHanded;
                case "TwoHanded":
                    return DefaultSkills.TwoHanded;
                case "Polearm":
                    return DefaultSkills.Polearm;
                case "Bow":
                    return DefaultSkills.Bow;
                case "Crossbow":
                    return DefaultSkills.Crossbow;
                case "Throwing":
                    return DefaultSkills.Throwing;
                case "Riding":
                    return DefaultSkills.Riding;
                case "Athletics":
                    return DefaultSkills.Athletics;
                case "Leadership":
                    return DefaultSkills.Leadership;
                case "Charm":
                    return DefaultSkills.Charm;
                case "Trade":
                    return DefaultSkills.Trade;
                case "Steward":
                    return DefaultSkills.Steward;
                case "Medicine":
                    return DefaultSkills.Medicine;
                case "Scouting":
                    return DefaultSkills.Scouting;
                default:
                    return null;
            }
        }

        private static string ResolveSettlementType(Settlement settlement)
        {
            if (settlement.IsTown)
            {
                return "Town";
            }

            if (settlement.IsCastle)
            {
                return "Castle";
            }

            if (settlement.IsVillage)
            {
                return "Village";
            }

            return "Other";
        }
    }
}
