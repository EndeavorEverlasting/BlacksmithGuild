using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Conversation;
using TaleWorlds.CampaignSystem.Encounters;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Localization;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroVisibleRecruitmentDriver
    {
        public static bool TryRecruitVisible(
            Hero hero,
            List<TavernHeroRecruitmentActionStep> actions,
            out string detail)
        {
            detail = null;
            actions = actions ?? new List<TavernHeroRecruitmentActionStep>();

            if (hero == null)
            {
                detail = "hero was null";
                return false;
            }

            if (DevToolsConfig.TavernHeroAllowDirectInjection)
            {
                detail = "direct injection disabled by default policy";
                actions.Add(Step("DirectInjection", "Policy", "Blocked", detail));
                return false;
            }

            if (!TryOpenConversation(hero, actions, out detail))
            {
                return false;
            }

            PauseIfVisible($"talking to {hero.Name}");

            if (!TrySelectRecruitmentOptions(actions, out detail))
            {
                return false;
            }

            GameSessionState.Refresh();
            if (hero.IsPlayerCompanion)
            {
                actions.Add(Step("ConfirmRecruitment", "VanillaDialogueOption", "Success", "hero joined party"));
                return true;
            }

            detail = detail ?? "conversation finished but hero did not join party";
            actions.Add(Step("ConfirmRecruitment", "VanillaDialogueOption", "Blocked", detail));
            return false;
        }

        private static bool TryOpenConversation(
            Hero hero,
            List<TavernHeroRecruitmentActionStep> actions,
            out string detail)
        {
            detail = null;
            try
            {
                var manager = Campaign.Current?.ConversationManager;
                if (manager == null)
                {
                    detail = "ConversationManager unavailable";
                    actions.Add(Step("OpenConversation", "VanillaTraversal", "Blocked", detail));
                    return false;
                }

                try
                {
                    PlayerEncounter.StartCombatMissionWithDialogueInTownCenter(hero.CharacterObject);
                    actions.Add(Step("OpenConversation", "VanillaTraversal", "Success", "StartCombatMissionWithDialogueInTownCenter"));
                    return true;
                }
                catch (Exception ex)
                {
                    detail = ex.Message;
                }

                var heroData = new ConversationCharacterData(hero.CharacterObject, hero.PartyBelongedTo?.Party);
                var playerData = new ConversationCharacterData(Hero.MainHero.CharacterObject, MobileParty.MainParty?.Party);
                manager.OpenMapConversation(heroData, playerData);
                actions.Add(Step("OpenConversation", "VanillaTraversal", "Success", "OpenMapConversation"));
                return true;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                actions.Add(Step("OpenConversation", "VanillaTraversal", "Failed", detail));
                return false;
            }
        }

        private static bool TrySelectRecruitmentOptions(
            List<TavernHeroRecruitmentActionStep> actions,
            out string detail)
        {
            detail = null;
            var manager = Campaign.Current?.ConversationManager;
            if (manager == null)
            {
                detail = "ConversationManager unavailable after open";
                return false;
            }

            for (var pass = 0; pass < 8; pass++)
            {
                if (!manager.IsConversationInProgress && pass > 0)
                {
                    break;
                }

                var options = manager.CurOptions;
                if (options == null || options.Count == 0)
                {
                    manager.ContinueConversation();
                    PauseIfVisible("continuing conversation");
                    continue;
                }

                if (!TryPickDialogueOption(options, out var selected))
                {
                    detail = "no clickable recruitment dialogue option";
                    actions.Add(Step("SelectRecruitmentOption", "VanillaDialogueOption", "Blocked", detail));
                    return false;
                }

                try
                {
                    if (!string.IsNullOrEmpty(selected.Id))
                    {
                        manager.DoOption(selected.Id);
                    }
                    else
                    {
                        manager.DoOption(options.IndexOf(selected));
                    }

                    actions.Add(
                        Step(
                            "SelectRecruitmentOption",
                            "VanillaDialogueOption",
                            "Success",
                            selected.Id ?? selected.Text?.ToString()));
                    PauseIfVisible("confirming recruitment");
                }
                catch (Exception ex)
                {
                    detail = ex.Message;
                    actions.Add(Step("SelectRecruitmentOption", "VanillaDialogueOption", "Failed", detail));
                    return false;
                }

                if (options.Any(o => IsPaymentOption(o)))
                {
                    manager.DoOptionContinue();
                }
            }

            return true;
        }

        private static bool TryPickDialogueOption(
            IReadOnlyList<ConversationSentenceOption> options,
            out ConversationSentenceOption selected)
        {
            selected = default;
            for (var i = 0; i < options.Count; i++)
            {
                if (IsRecruitmentOption(options[i]))
                {
                    selected = options[i];
                    return true;
                }
            }

            for (var i = 0; i < options.Count; i++)
            {
                if (options[i].IsClickable)
                {
                    selected = options[i];
                    return true;
                }
            }

            return false;
        }

        private static bool IsRecruitmentOption(ConversationSentenceOption option)
        {
            var id = option.Id ?? string.Empty;
            var text = option.Text?.ToString() ?? string.Empty;
            return id.IndexOf("companion_hire", StringComparison.OrdinalIgnoreCase) >= 0
                   || id.IndexOf("hire", StringComparison.OrdinalIgnoreCase) >= 0
                   || text.IndexOf("join", StringComparison.OrdinalIgnoreCase) >= 0
                   || text.IndexOf("hire", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static bool IsPaymentOption(ConversationSentenceOption option)
        {
            var id = option.Id ?? string.Empty;
            return id.IndexOf("gold", StringComparison.OrdinalIgnoreCase) >= 0
                   || id.IndexOf("companion_hire_gold", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static void PauseIfVisible(string label)
        {
            if (!DevToolsConfig.TavernHeroVisibleMode || DevToolsConfig.TavernHeroDecisionPauseMs <= 0)
            {
                return;
            }

            InGameNotice.Info($"TBG TAVERN RECRUIT: {label}...");
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
