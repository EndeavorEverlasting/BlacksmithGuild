using System;
using System.Collections.Generic;
using System.Reflection;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    internal static class CharacterBuildRouteSelector
    {
        private static int _routeStepIndex;
        private static string _blockedReason;
        private static bool _blockedLogged;

        public static string BlockedReason => _blockedReason;

        public static void ResetSession()
        {
            _routeStepIndex = 0;
            _blockedReason = null;
            _blockedLogged = false;
        }

        public static NarrativeOptionDecision SelectRouteOption(
            IReadOnlyList<object> availableOptions,
            string menuId,
            object manager)
        {
            var config = CharacterBuildVariantConfigService.ActiveConfig;
            if (config == null || config.Route.Count == 0)
            {
                return null;
            }

            if (!string.IsNullOrEmpty(_blockedReason))
            {
                return BuildBlockedDecision(_blockedReason);
            }

            if (_routeStepIndex >= config.Route.Count)
            {
                return AseraiTradeSmithDecisionMap.SelectOption(availableOptions, menuId, manager);
            }

            var step = config.Route[_routeStepIndex];
            if (!string.IsNullOrWhiteSpace(step.MenuId)
                && !string.Equals(step.MenuId, menuId, StringComparison.OrdinalIgnoreCase))
            {
                return null;
            }

            object selected = null;
            var selectedId = "unknown";
            var selectedText = string.Empty;

            for (var index = 0; index < availableOptions.Count; index++)
            {
                var option = availableOptions[index];
                if (option == null || !IsOptionAvailable(option, manager))
                {
                    continue;
                }

                var optionId = DescribeOption(option);
                if (!string.IsNullOrWhiteSpace(step.OptionId)
                    && string.Equals(step.OptionId, optionId, StringComparison.OrdinalIgnoreCase))
                {
                    selected = option;
                    selectedId = optionId;
                    selectedText = AseraiTradeSmithDecisionMap.ExtractOptionText(option);
                    break;
                }

                if (selected == null
                    && step.OptionIndex >= 0
                    && index == step.OptionIndex)
                {
                    selected = option;
                    selectedId = optionId;
                    selectedText = AseraiTradeSmithDecisionMap.ExtractOptionText(option);
                }
            }

            if (selected == null)
            {
                _blockedReason =
                    $"configured option unavailable menu={menuId} optionId={step.OptionId} optionIndex={step.OptionIndex}";
                return BuildBlockedDecision(_blockedReason);
            }

            _routeStepIndex++;
            return new NarrativeOptionDecision
            {
                SelectedOption = selected,
                OptionId = selectedId,
                OptionText = selectedText,
                Reason = $"variant route step {_routeStepIndex}/{config.Route.Count} candidate={config.CandidateId}",
                BenefitSource = "RuntimeCatalog"
            };
        }

        private static NarrativeOptionDecision BuildBlockedDecision(string reason)
        {
            if (!_blockedLogged)
            {
                _blockedLogged = true;
                GuildLog.Info($"[TBG CHARACTER] variant route blocked: {reason}", showInGame: false);
            }

            return new NarrativeOptionDecision
            {
                Reason = reason,
                BenefitSource = "RuntimeCatalog"
            };
        }

        private static bool IsOptionAvailable(object option, object manager)
        {
            try
            {
                var onCondition = option.GetType().GetMethod(
                    "OnCondition",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (onCondition == null)
                {
                    return true;
                }

                var parameters = onCondition.GetParameters();
                if (parameters.Length == 1 && parameters[0].ParameterType.IsInstanceOfType(manager))
                {
                    return onCondition.Invoke(option, new[] { manager }) as bool? != false;
                }

                return onCondition.Invoke(option, null) as bool? != false;
            }
            catch
            {
                return false;
            }
        }

        private static string DescribeOption(object option)
        {
            if (option == null)
            {
                return "null";
            }

            var stringId = ReadMemberString(option, "StringId");
            if (!string.IsNullOrWhiteSpace(stringId))
            {
                return stringId;
            }

            var id = ReadMemberString(option, "Id");
            return !string.IsNullOrWhiteSpace(id) ? id : option.GetType().Name;
        }

        private static string ReadMemberString(object target, string memberName)
        {
            try
            {
                var field = target.GetType().GetField(
                    memberName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var fieldValue = field?.GetValue(target);
                if (fieldValue != null)
                {
                    return fieldValue.ToString();
                }

                var property = target.GetType().GetProperty(
                    memberName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                return property?.GetValue(target)?.ToString();
            }
            catch
            {
                return null;
            }
        }
    }
}
