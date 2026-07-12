using System;
using System.Reflection;
using BlacksmithGuild.DevTools;
using Helpers;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.GameMenus;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Core;

namespace BlacksmithGuild.MapTrade
{
    public static class SettlementNavigationHelper
    {
        private static readonly string[] MarketMenuHints =
        {
            "market", "trade", "town_market", "settlement_market"
        };

        public static bool TryEnsureSettlementInterior(out string detail)
        {
            detail = null;
            GameSessionState.Refresh();

            if (GameSessionState.IsSettlementInteriorReady)
            {
                return true;
            }

            if (!GameSessionState.IsCampaignMapReady && !GameSessionState.IsSettlementInteriorReady)
            {
                detail = GameSessionState.GetCommandReadyBlockDetail();
                return false;
            }

            try
            {
                if (PlayerEncounter.InsideSettlement)
                {
                    return true;
                }

                var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
                if (settlement == null)
                {
                    detail = "party not at a settlement";
                    return false;
                }

                PlayerEncounter.EnterSettlement();
                GameSessionState.Refresh();
                return GameSessionState.IsSettlementInteriorReady || PlayerEncounter.InsideSettlement;
            }
            catch (Exception ex)
            {
                detail = $"EnterSettlement failed: {ex.Message}";
                return false;
            }
        }

        public static bool TryOpenMarketMenu(out string detail)
        {
            detail = null;
            if (!TryEnsureSettlementInterior(out detail))
            {
                return false;
            }

            foreach (var hint in MarketMenuHints)
            {
                if (TryRunMenuOption(hint, out detail))
                {
                    return true;
                }

                if (TryActivateMenu(hint, out detail))
                {
                    return true;
                }
            }

            detail = detail ?? "no market/trade menu option found";
            return false;
        }

        public static bool TryOpenVisibleTradeScreen(
            out MapTradeTradeSurfaceEvidence evidence,
            out string detail)
        {
            evidence = null;
            detail = null;
            if (!TryEnsureSettlementInterior(out detail))
            {
                return false;
            }

            var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
            if (settlement == null || settlement.Town == null)
            {
                detail = "visible trade screen requires a town settlement";
                return false;
            }

            try
            {
                InventoryScreenHelper.ActivateTradeWithCurrentSettlement();
                var activeState = GameStateManager.Current?.ActiveState?.GetType().Name;
                var visible = !string.IsNullOrWhiteSpace(activeState)
                    && activeState.IndexOf("Inventory", StringComparison.OrdinalIgnoreCase) >= 0;
                evidence = new MapTradeTradeSurfaceEvidence
                {
                    Surface = visible ? GameplaySurfaceKinds.Trading : GameplaySurfaceKinds.Unknown,
                    Visible = visible,
                    OpenedAtUtc = DateTime.UtcNow.ToString("o"),
                    Settlement = settlement.Name?.ToString() ?? settlement.StringId,
                    Method = "InventoryScreenHelper.ActivateTradeWithCurrentSettlement",
                    ActiveState = activeState
                };
                detail = visible
                    ? "vanilla settlement trade inventory is active"
                    : "trade activation returned without an InventoryState";
                return visible;
            }
            catch (Exception ex)
            {
                detail = "visible trade activation failed: " + ex.Message;
                return false;
            }
        }

        private static bool TryRunMenuOption(string hint, out string detail)
        {
            detail = null;
            try
            {
                var campaign = Campaign.Current;
                if (campaign == null)
                {
                    return false;
                }

                var method = campaign.GetType().GetMethod(
                    "RunConsequencesOfMenuOption",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (method == null)
                {
                    return false;
                }

                foreach (var optionId in BuildMenuOptionCandidates(hint))
                {
                    try
                    {
                        method.Invoke(campaign, new object[] { optionId });
                        GameSessionState.Refresh();
                        if (GameSessionState.ActiveMenuId?.IndexOf(hint, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            return true;
                        }
                    }
                    catch
                    {
                    }
                }
            }
            catch (Exception ex)
            {
                detail = ex.Message;
            }

            return false;
        }

        private static bool TryActivateMenu(string hint, out string detail)
        {
            detail = null;
            try
            {
                foreach (var menuId in BuildMenuOptionCandidates(hint))
                {
                    try
                    {
                        GameMenu.ActivateGameMenu(menuId);
                        GameSessionState.Refresh();
                        return true;
                    }
                    catch
                    {
                    }
                }
            }
            catch (Exception ex)
            {
                detail = ex.Message;
            }

            return false;
        }

        private static string[] BuildMenuOptionCandidates(string hint)
        {
            return new[]
            {
                hint,
                $"town_{hint}",
                $"{hint}_menu",
                "town"
            };
        }
    }
}
