using System;
using System.Linq;
using System.Reflection;
using System.Text;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeVanillaTradeDriver
    {
        public static string LastProbeMethod { get; private set; }
        public static bool LastProbeAvailable { get; private set; }
        public static string LastProbeDetail { get; private set; }

        public static bool ProbeTradeApi(out string detail)
        {
            detail = null;
            LastProbeMethod = null;
            LastProbeAvailable = false;
            LastProbeDetail = null;

            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                detail = GameSessionState.GetCampaignMapBlockDetail();
                LastProbeDetail = detail;
                return false;
            }

            var settlement = MobileParty.MainParty?.CurrentSettlement;
            if (settlement == null)
            {
                detail = "party not at settlement — travel required before trade probe";
                LastProbeDetail = detail;
                return false;
            }

            if (TryProbeSettlementEntry(out detail))
            {
                LastProbeMethod = "PlayerEncounter.EnterSettlement";
            }

            if (TryProbeTradeActions(out var tradeMethod, out var tradeDetail))
            {
                LastProbeMethod = tradeMethod;
                LastProbeAvailable = true;
                LastProbeDetail = tradeDetail ?? "trade action reflection probe succeeded";
                detail = LastProbeDetail;
                return true;
            }

            detail = tradeDetail ?? detail ?? "VisibleTradeDriverUnavailable";
            LastProbeDetail = detail;
            return false;
        }

        public static bool TryExecuteBuy(MapTradeMission mission, out string detail)
        {
            detail = null;
            if (mission == null)
            {
                detail = "no mission";
                return false;
            }

            if (DevToolsConfig.MapTradeAllowDirectInventoryMutation || DevToolsConfig.MapTradeAllowDirectGoldMutation)
            {
                detail = "direct mutation forbidden by config";
                return false;
            }

            if (!ProbeTradeApi(out detail))
            {
                return false;
            }

            detail = $"trade driver probed ({LastProbeMethod}) but buy execution not yet proven — VisibleTradeDriverUnavailable";
            LastProbeDetail = detail;
            return false;
        }

        public static bool ProbePackAnimalBuyApi(out string detail)
        {
            detail = "pack-animal buy API not proven";
            return false;
        }

        public static bool ProbeSmithingSmeltApi(out string detail)
        {
            detail = "weapon smelt API not proven";
            var hero = Hero.MainHero;
            if (hero == null)
            {
                detail = "MainHero unavailable for smelt probe";
                return false;
            }

            var smithingType = hero.GetType().Assembly.GetType("TaleWorlds.CampaignSystem.CampaignBehaviors.SmithingBehavior");
            if (smithingType != null)
            {
                detail = "SmithingBehavior type found but headless smelt path not proven";
            }

            return false;
        }

        private static bool TryProbeSettlementEntry(out string detail)
        {
            detail = null;
            try
            {
                if (PlayerEncounter.Current != null)
                {
                    return true;
                }

                PlayerEncounter.EnterSettlement();
                return PlayerEncounter.Current != null;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                return false;
            }
        }

        private static bool TryProbeTradeActions(out string methodName, out string detail)
        {
            methodName = null;
            detail = null;
            var candidates = new[]
            {
                "TaleWorlds.CampaignSystem.Actions.SellItemsAction",
                "TaleWorlds.CampaignSystem.Actions.ChangeRelationAction"
            };

            foreach (var typeName in candidates)
            {
                var type = typeof(Campaign).Assembly.GetType(typeName)
                    ?? AppDomain.CurrentDomain.GetAssemblies()
                        .SelectMany(a =>
                        {
                            try { return a.GetTypes(); }
                            catch { return Array.Empty<Type>(); }
                        })
                        .FirstOrDefault(t => t.FullName == typeName);

                if (type == null)
                {
                    continue;
                }

                foreach (var method in type.GetMethods(BindingFlags.Public | BindingFlags.Static))
                {
                    if (method.Name.Contains("Apply") || method.Name.Contains("Sell") || method.Name.Contains("Buy"))
                    {
                        methodName = $"{type.Name}.{method.Name}";
                        detail = "reflection candidate located; live buy/sell not executed in probe";
                        return true;
                    }
                }
            }

            detail = "no vanilla trade action candidates found";
            return false;
        }
    }
}
