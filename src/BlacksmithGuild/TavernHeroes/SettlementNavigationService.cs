using System;
using System.Collections.Generic;
using System.Reflection;
using System.Threading;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.GameMenus;
using TaleWorlds.CampaignSystem.GameState;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.CampaignSystem.Settlements.Locations;
using TaleWorlds.Localization;

namespace BlacksmithGuild.TavernHeroes
{
    public static class SettlementNavigationService
    {
        public const string NavigateToSettlementTavernNowCommand = "NavigateToSettlementTavernNow";

        public static bool TryNavigateToTavernNow(out string detail, List<TavernHeroRecruitmentActionStep> actions)
        {
            detail = null;
            actions = actions ?? new List<TavernHeroRecruitmentActionStep>();
            GameSessionState.Refresh();

            if (!GameSessionState.IsMainHeroReady)
            {
                detail = "MainHero not ready";
                return false;
            }

            if (GameSessionState.IsTavernLocationReady)
            {
                actions.Add(Step("AlreadyInTavern", "StateCheck", "Success", "player already in tavern"));
                return true;
            }

            if (GameSessionState.IsCampaignMapReady)
            {
                var settlement = MobileParty.MainParty?.CurrentSettlement ?? GameSessionState.ResolveCurrentSettlement();
                if (settlement == null)
                {
                    detail = "party not at a settlement — travel to a town first";
                    actions.Add(Step("ResolveSettlement", "StateCheck", "Blocked", detail));
                    return false;
                }

                if (!TryEnterSettlement(actions, out detail))
                {
                    return false;
                }

                PauseIfVisible("entering settlement");

                var settleDeadline = DateTime.UtcNow.AddSeconds(5);
                while (!GameSessionState.IsSettlementInteriorReady && DateTime.UtcNow < settleDeadline)
                {
                    GameSessionState.Refresh();
                    if (!GameSessionState.IsSettlementInteriorReady)
                    {
                        Thread.Sleep(250);
                    }
                }
            }

            if (!GameSessionState.IsSettlementInteriorReady)
            {
                detail = GameSessionState.GetCommandReadyBlockDetail();
                actions.Add(Step("SettlementInterior", "StateCheck", "Blocked", detail));
                return false;
            }

            if (TryEnterTavern(actions, out detail))
            {
                PauseIfVisible("opening tavern");
                GameSessionState.Refresh();
                if (GameSessionState.IsTavernLocationReady)
                {
                    return true;
                }

                detail = detail ?? "tavern navigation completed but tavern state not confirmed";
            }

            return GameSessionState.IsTavernLocationReady;
        }

        private static bool TryEnterSettlement(List<TavernHeroRecruitmentActionStep> actions, out string detail)
        {
            detail = null;
            try
            {
                if (PlayerEncounter.InsideSettlement)
                {
                    actions.Add(Step("EnterSettlement", "VanillaTraversal", "Success", "already inside settlement"));
                    return true;
                }

                PlayerEncounter.EnterSettlement();
                actions.Add(Step("EnterSettlement", "VanillaTraversal", "Success", "PlayerEncounter.EnterSettlement()"));
                return true;
            }
            catch (Exception ex)
            {
                detail = $"EnterSettlement failed: {ex.Message}";
                actions.Add(Step("EnterSettlement", "VanillaTraversal", "Failed", detail));
                return false;
            }
        }

        private static bool TryEnterTavern(List<TavernHeroRecruitmentActionStep> actions, out string detail)
        {
            detail = null;
            var settlement = GameSessionState.ResolveCurrentSettlement();
            if (settlement?.LocationComplex?.GetLocationWithId("tavern") == null)
            {
                detail = "settlement has no tavern location";
                actions.Add(Step("OpenTavern", "VanillaTraversal", "Blocked", detail));
                return false;
            }

            if (TryRunMenuOption(actions, "tavern", out detail))
            {
                return true;
            }

            if (TryActivateMenu(actions, "tavern", out detail))
            {
                return true;
            }

            if (TryChangeLocation(actions, settlement, "tavern", out detail))
            {
                return true;
            }

            actions.Add(Step("OpenTavern", "VanillaTraversal", "Blocked", detail ?? "no tavern menu option found"));
            return false;
        }

        private static bool TryRunMenuOption(List<TavernHeroRecruitmentActionStep> actions, string optionId, out string detail)
        {
            detail = null;
            try
            {
                var context = Campaign.Current?.CurrentMenuContext;
                var manager = Campaign.Current?.GameMenuManager;
                if (context == null || manager == null)
                {
                    detail = "menu context unavailable";
                    return false;
                }

                var count = manager.GetVirtualMenuOptionAmount(context);
                for (var i = 0; i < count; i++)
                {
                    if (!manager.GetVirtualMenuOptionConditionsHold(context, i))
                    {
                        continue;
                    }

                    var optionIdString = manager.GetMenuOptionIdString(context, i);
                    if (string.IsNullOrEmpty(optionIdString)
                        || optionIdString.IndexOf(optionId, StringComparison.OrdinalIgnoreCase) < 0)
                    {
                        continue;
                    }

                    manager.RunConsequencesOfMenuOption(context, i);
                    actions.Add(Step("OpenTavern", "VanillaMenuOption", "Success", optionIdString));
                    return true;
                }

                detail = $"menu option '{optionId}' not found among {count} options";
                return false;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                actions.Add(Step("OpenTavern", "VanillaMenuOption", "Failed", detail));
                return false;
            }
        }

        private static bool TryActivateMenu(List<TavernHeroRecruitmentActionStep> actions, string menuId, out string detail)
        {
            detail = null;
            foreach (var candidate in new[] { menuId, "town_tavern", "tavern_menu" })
            {
                try
                {
                    GameMenu.ActivateGameMenu(candidate);
                    actions.Add(Step("OpenTavern", "VanillaMenuActivate", "Success", candidate));
                    return true;
                }
                catch
                {
                }
            }

            detail = "ActivateGameMenu tavern failed";
            return false;
        }

        private static bool TryChangeLocation(
            List<TavernHeroRecruitmentActionStep> actions,
            Settlement settlement,
            string locationId,
            out string detail)
        {
            detail = null;
            try
            {
                var complex = settlement.LocationComplex;
                var tavern = complex?.GetLocationWithId(locationId);
                var hero = Hero.MainHero;
                if (complex == null || tavern == null || hero == null)
                {
                    detail = "location complex or hero unavailable";
                    return false;
                }

                var heroCharacter = complex.GetLocationCharacterOfHero(hero);
                if (heroCharacter == null)
                {
                    detail = "player location character unavailable for ChangeLocation";
                    return false;
                }

                Location fromLocation = complex.GetLocationOfCharacter(heroCharacter);

                if (fromLocation == null)
                {
                    fromLocation = complex.GetLocationWithId("center")
                                       ?? complex.GetLocationWithId("lordshall")
                                       ?? complex.GetLocationWithId("alley");
                }

                if (fromLocation == null)
                {
                    detail = "could not resolve current settlement location";
                    return false;
                }

                complex.ChangeLocation(heroCharacter, fromLocation, tavern);
                actions.Add(Step("OpenTavern", "LocationComplex", "Success", locationId));
                return true;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                actions.Add(Step("OpenTavern", "LocationComplex", "Failed", detail));
                return false;
            }
        }

        private static void PauseIfVisible(string label)
        {
            if (!DevToolsConfig.TavernHeroVisibleMode || DevToolsConfig.TavernHeroDecisionPauseMs <= 0)
            {
                return;
            }

            InGameNotice.Info($"TBG TAVERN: {label}...");
            Thread.Sleep(DevToolsConfig.TavernHeroDecisionPauseMs);
        }

        private static TavernHeroRecruitmentActionStep Step(string step, string mode, string result, string detail)
        {
            return new TavernHeroRecruitmentActionStep
            {
                Step = step,
                Mode = mode,
                Result = result,
                Detail = detail
            };
        }
    }
}
