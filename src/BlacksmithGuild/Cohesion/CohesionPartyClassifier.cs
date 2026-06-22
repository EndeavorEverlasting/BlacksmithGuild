using System;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionPartyClassifier
    {
        public static CohesionRelationToPlayer ClassifyRelation(MobileParty party, MobileParty main)
        {
            if (party == null || main == null)
            {
                return CohesionRelationToPlayer.Unknown;
            }

            if (party == main)
            {
                return CohesionRelationToPlayer.Player;
            }

            if (party.IsMainParty)
            {
                return CohesionRelationToPlayer.Player;
            }

            if (party.ActualClan != null && main.ActualClan != null
                && party.ActualClan == main.ActualClan)
            {
                return CohesionRelationToPlayer.Clan;
            }

            if (party.MapFaction != null && main.MapFaction != null)
            {
                if (party.MapFaction.IsAtWarWith(main.MapFaction))
                {
                    return CohesionRelationToPlayer.Hostile;
                }

                if (party.MapFaction == main.MapFaction)
                {
                    return CohesionRelationToPlayer.Friendly;
                }
            }

            if (IsBanditParty(party))
            {
                return CohesionRelationToPlayer.Hostile;
            }

            if (IsLargeNeutralParty(party))
            {
                return CohesionRelationToPlayer.NeutralProtector;
            }

            return CohesionRelationToPlayer.Unknown;
        }

        public static CohesionPartyType ClassifyType(MobileParty party)
        {
            if (party == null)
            {
                return CohesionPartyType.Unknown;
            }

            if (party.IsMainParty)
            {
                return CohesionPartyType.PlayerParty;
            }

            if (party.IsBandit)
            {
                return CohesionPartyType.BanditParty;
            }

            if (party.IsCaravan)
            {
                return CohesionPartyType.Caravan;
            }

            if (party.IsVillager)
            {
                return CohesionPartyType.VillagerParty;
            }

            if (party.Army != null)
            {
                return party.MapFaction != null && party.MapFaction.IsAtWarWith(Hero.MainHero?.MapFaction)
                    ? CohesionPartyType.HostileArmy
                    : CohesionPartyType.Army;
            }

            if (party.LeaderHero != null)
            {
                if (party.ActualClan != null && Hero.MainHero?.Clan != null
                    && party.ActualClan == Hero.MainHero.Clan)
                {
                    return CohesionPartyType.ClanParty;
                }

                return CohesionPartyType.LordParty;
            }

            return CohesionPartyType.Unknown;
        }

        private static bool IsBanditParty(MobileParty party)
        {
            try
            {
                return party.IsBandit;
            }
            catch
            {
                return party.StringId != null
                    && party.StringId.IndexOf("bandit", StringComparison.OrdinalIgnoreCase) >= 0;
            }
        }

        private static bool IsLargeNeutralParty(MobileParty party)
        {
            var strength = party.Party?.NumberOfAllMembers ?? 0;
            var relation = ClassifyRelation(party, MobileParty.MainParty);
            return strength >= 80
                && relation != CohesionRelationToPlayer.Hostile
                && relation != CohesionRelationToPlayer.Player;
        }
    }
}
