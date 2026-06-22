using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.ClanIntel
{
    public static class FactionPowerPostureScanner
    {
        public static FactionPowerPostureBlock Scan()
        {
            var block = new FactionPowerPostureBlock();
            var main = MobileParty.MainParty;
            var hero = Hero.MainHero;
            var clan = Clan.PlayerClan;

            if (main == null || hero == null)
            {
                block.PowerVerdict = "Unknown";
                block.Warnings.Add("Main party unavailable");
                return block;
            }

            block.AllegianceMode = clan != null ? ResolveAllegiance(clan) : "Unknown";
            block.KingdomName = clan?.Kingdom?.Name?.ToString();
            block.MapFactionName = hero.MapFaction?.Name?.ToString();
            block.IsAtWar = ResolveAtWar(hero.MapFaction);
            block.PlayerPartyStrength = CampaignMapMovementHelper.PartyStrength(main);
            block.PlayerTroopCount = main.Party?.NumberOfRegularMembers;

            var radius = DevToolsConfig.CohesionScanRadius;
            var snapshots = CohesionPartyScanner.Scan(radius, main);
            var hostiles = snapshots
                .Where(snapshot => snapshot.RelationToPlayer == CohesionRelationToPlayer.Hostile && snapshot.PartyId != main.StringId)
                .ToList();
            var friendlies = snapshots
                .Where(snapshot =>
                    (snapshot.RelationToPlayer == CohesionRelationToPlayer.Friendly
                     || snapshot.RelationToPlayer == CohesionRelationToPlayer.Clan)
                    && snapshot.RelationToPlayer != CohesionRelationToPlayer.Player)
                .ToList();

            block.HostileCountInRadius = hostiles.Count;
            block.FriendlyProtectorStrengthInRadius = friendlies.Sum(snapshot => snapshot.Strength);

            if (hostiles.Count > 0)
            {
                var nearest = hostiles.OrderBy(snapshot => snapshot.DistanceToPlayer).First();
                block.NearestHostileStrength = nearest.Strength;
                block.NearestHostileDistance = nearest.DistanceToPlayer;
                if (nearest.Strength > 0 && block.PlayerPartyStrength.HasValue)
                {
                    block.StrengthRatioVsNearestHostile =
                        block.PlayerPartyStrength.Value / (float)nearest.Strength;
                }
            }

            block.PowerVerdict = ResolveVerdict(block.StrengthRatioVsNearestHostile, hostiles.Count);
            block.Warnings = BuildWarnings(block);
            return block;
        }

        private static string ResolveAllegiance(Clan clan)
        {
            if (clan.Kingdom == null)
            {
                return "Independent";
            }

            try
            {
                return clan.IsUnderMercenaryService ? "Mercenary" : "Vassal";
            }
            catch
            {
                return "Vassal";
            }
        }

        private static bool ResolveAtWar(IFaction mapFaction)
        {
            if (mapFaction == null)
            {
                return false;
            }

            try
            {
                foreach (var kingdom in Kingdom.All)
                {
                    if (kingdom == null || kingdom == mapFaction)
                    {
                        continue;
                    }

                    if (FactionManager.IsAtWarAgainstFaction(mapFaction, kingdom))
                    {
                        return true;
                    }
                }
            }
            catch
            {
            }

            return false;
        }

        private static string ResolveVerdict(float? ratio, int hostileCount)
        {
            if (hostileCount <= 0 || !ratio.HasValue)
            {
                return hostileCount > 0 ? "Even" : "Dominant";
            }

            if (ratio.Value >= 1.05f)
            {
                return "Dominant";
            }

            if (ratio.Value >= 0.85f)
            {
                return "Even";
            }

            if (ratio.Value >= 0.50f)
            {
                return "Outmatched";
            }

            return "SeverelyOutmatched";
        }

        private static List<string> BuildWarnings(FactionPowerPostureBlock block)
        {
            var warnings = new List<string>();
            if (string.Equals(block.AllegianceMode, "Independent", StringComparison.OrdinalIgnoreCase)
                && (block.PowerVerdict == "Outmatched" || block.PowerVerdict == "SeverelyOutmatched"))
            {
                warnings.Add("Solo clan outmatched near hostiles — trade route risk elevated");
            }

            if (block.IsAtWar)
            {
                warnings.Add("Player map faction is at war");
            }

            if (block.HostileCountInRadius > 2)
            {
                warnings.Add($"Multiple hostiles in scan radius ({block.HostileCountInRadius})");
            }

            return warnings;
        }
    }
}
