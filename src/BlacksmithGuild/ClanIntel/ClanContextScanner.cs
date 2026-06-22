using System;
using System.Linq;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.ClanIntel
{
    public static class ClanContextScanner
    {
        public static PlayerClanSnapshot ScanPlayerClan()
        {
            var snapshot = new PlayerClanSnapshot();
            var main = Hero.MainHero;
            var clan = Clan.PlayerClan;
            if (clan == null)
            {
                return snapshot;
            }

            snapshot.Name = clan.Name?.ToString() ?? clan.StringId;
            try { snapshot.Tier = clan.Tier; } catch { }
            try { snapshot.Renown = clan.Renown; } catch { }
            try { snapshot.CompanionLimit = clan.CompanionLimit; } catch { }
            try { snapshot.PartySizeLimit = ReadIntProperty(clan, "PartySizeLimit"); } catch { }
            try { snapshot.WorkshopLimit = ReadIntProperty(clan, "WorkshopLimit"); } catch { }
            try { snapshot.CompanionCount = clan.Companions?.Count; } catch { }

            snapshot.Kingdom = clan.Kingdom?.Name?.ToString();
            snapshot.HasSpouse = main?.Spouse != null;
            snapshot.Posture = ResolvePosture(clan);
            snapshot.NextTierRenownNeeded = ResolveNextTierRenown(clan);
            return snapshot;
        }

        public static KingdomPostureBlock BuildKingdomPosture(PlayerClanSnapshot clan)
        {
            var block = new KingdomPostureBlock();
            if (clan == null)
            {
                block.RecommendedPosture = "Unknown";
                return block;
            }

            if (!string.IsNullOrEmpty(clan.Kingdom))
            {
                block.RecommendedPosture = "RemainVassalOrMercenary";
                block.Reasons.Add($"Already aligned with {clan.Kingdom}");
                return block;
            }

            block.RecommendedPosture = "RemainIndependent";
            if (clan.HasSpouse != true)
            {
                block.Reasons.Add("No spouse secured");
            }

            if (clan.Tier.HasValue && clan.Tier.Value < 2)
            {
                block.Reasons.Add("Clan tier below preferred threshold");
            }

            block.Reasons.Add("Trade/forge loop still fragile without kingdom lock");
            block.Reasons.Add("Develop Aserai noble relations before vassal path");
            return block;
        }

        private static string ResolvePosture(Clan clan)
        {
            if (clan.Kingdom != null)
            {
                try
                {
                    return clan.IsUnderMercenaryService ? "Mercenary" : "Vassal";
                }
                catch
                {
                    return "Vassal";
                }
            }

            return "Independent";
        }

        private static float? ResolveNextTierRenown(Clan clan)
        {
            try
            {
                var model = Campaign.Current?.Models?.ClanTierModel;
                if (model == null || clan == null)
                {
                    return null;
                }

                var nextTier = clan.Tier + 1;
                var method = model.GetType().GetMethod("GetRequiredRenownForTier");
                if (method != null)
                {
                    var value = method.Invoke(model, new object[] { nextTier });
                    if (value is int intValue)
                    {
                        return intValue;
                    }

                    if (value is float floatValue)
                    {
                        return floatValue;
                    }
                }
            }
            catch
            {
            }

            return null;
        }

        private static int? ReadIntProperty(object target, string propertyName)
        {
            try
            {
                var value = target?.GetType().GetProperty(propertyName)?.GetValue(target);
                if (value is int intValue)
                {
                    return intValue;
                }
            }
            catch
            {
            }

            return null;
        }
    }
}
