using System;
using System.Collections.Generic;
using System.Reflection;
using System.Text;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    internal sealed class NarrativeOptionDecision
    {
        public object SelectedOption { get; set; }
        public string OptionId { get; set; }
        public string OptionText { get; set; }
        public string Reason { get; set; }
        public List<string> ExpectedBenefits { get; } = new List<string>();
        public List<string> OpportunityCosts { get; } = new List<string>();
        public string BenefitSource { get; set; } = "Unavailable";
        public List<RejectedNarrativeOption> RejectedOptions { get; } = new List<RejectedNarrativeOption>();
    }

    public sealed class RejectedNarrativeOption
    {
        public string OptionId { get; set; }
        public string ReasonRejected { get; set; }
    }

    internal static class AseraiTradeSmithDecisionMap
    {
        private static readonly Dictionary<string, int> PositiveTagWeights =
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                { "trade", 12 },
                { "merchant", 11 },
                { "caravan", 10 },
                { "smith", 14 },
                { "craft", 13 },
                { "forge", 13 },
                { "artisan", 10 },
                { "steward", 9 },
                { "leadership", 7 },
                { "riding", 8 },
                { "horse", 8 },
                { "herder", 8 },
                { "charm", 6 },
                { "bow", 5 },
                { "polearm", 5 },
                { "engineer", 6 },
                { "workshop", 8 }
            };

        private static readonly Dictionary<string, int> NegativeTagWeights =
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                { "warrior", -8 },
                { "soldier", -7 },
                { "mercenary", -6 },
                { "bandit", -10 },
                { "brute", -6 },
                { "infantry", -4 }
            };

        public static NarrativeOptionDecision SelectOption(
            IReadOnlyList<object> availableOptions,
            string menuId,
            object manager)
        {
            var decision = new NarrativeOptionDecision();
            if (availableOptions == null || availableOptions.Count == 0)
            {
                return decision;
            }

            object bestOption = null;
            var bestScore = int.MinValue;
            var bestId = "unknown";
            var bestText = string.Empty;

            foreach (var option in availableOptions)
            {
                if (option == null || !IsOptionAvailable(option, manager))
                {
                    continue;
                }

                var optionId = DescribeOption(option);
                var optionText = ExtractOptionText(option);
                var score = ScoreOption(optionId, optionText, menuId, out var matchedTags, out var negativeTags);

                if (score > bestScore)
                {
                    if (bestOption != null)
                    {
                        decision.RejectedOptions.Add(new RejectedNarrativeOption
                        {
                            OptionId = bestId,
                            ReasonRejected = BuildRejectionReason(bestScore, score, bestId, optionId)
                        });
                    }

                    bestScore = score;
                    bestOption = option;
                    bestId = optionId;
                    bestText = optionText;
                }
                else
                {
                    decision.RejectedOptions.Add(new RejectedNarrativeOption
                    {
                        OptionId = optionId,
                        ReasonRejected = BuildRejectionReason(score, bestScore, optionId, bestId)
                    });
                }

                if (matchedTags.Count > 0 && string.IsNullOrEmpty(decision.BenefitSource))
                {
                    decision.BenefitSource = "MenuText";
                }
            }

            if (bestOption == null)
            {
                bestOption = availableOptions[0];
                bestId = DescribeOption(bestOption);
                bestText = ExtractOptionText(bestOption);
                decision.Reason = "fallback first available option";
            }
            else
            {
                decision.Reason = "doctrine-weighted Aserai Trade-Smith path";
                if (!string.IsNullOrWhiteSpace(bestText))
                {
                    decision.ExpectedBenefits.Add($"menu text suggests: {Truncate(bestText, 120)}");
                    decision.BenefitSource = "MenuText";
                }
            }

            decision.SelectedOption = bestOption;
            decision.OptionId = bestId;
            decision.OptionText = bestText;
            decision.OpportunityCosts.Add("vanilla upbringing tradeoff accepted via menu selection");

            return decision;
        }

        public static string InferStage(string menuId)
        {
            if (string.IsNullOrWhiteSpace(menuId))
            {
                return "unknown";
            }

            if (menuId.IndexOf("parent", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "parent";
            }

            if (menuId.IndexOf("childhood", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "childhood";
            }

            if (menuId.IndexOf("education", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "education";
            }

            if (menuId.IndexOf("youth", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "youth";
            }

            if (menuId.IndexOf("adulthood", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "adulthood";
            }

            if (menuId.IndexOf("age", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return "age";
            }

            return menuId;
        }

        private static int ScoreOption(
            string optionId,
            string optionText,
            string menuId,
            out List<string> matchedTags,
            out List<string> negativeTags)
        {
            matchedTags = new List<string>();
            negativeTags = new List<string>();
            var corpus = $"{menuId} {optionId} {optionText}".ToLowerInvariant();
            var score = 0;

            foreach (var entry in PositiveTagWeights)
            {
                if (corpus.IndexOf(entry.Key, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                score += entry.Value;
                matchedTags.Add(entry.Key);
            }

            foreach (var entry in NegativeTagWeights)
            {
                if (corpus.IndexOf(entry.Key, StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                score += entry.Value;
                negativeTags.Add(entry.Key);
            }

            return score;
        }

        private static string BuildRejectionReason(int score, int winnerScore, string optionId, string winnerId)
        {
            if (score < winnerScore)
            {
                return $"lower doctrine score than {winnerId} for trade-smith identity";
            }

            return "tie-breaker kept earlier candidate";
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

        public static string ExtractOptionText(object option)
        {
            if (option == null)
            {
                return string.Empty;
            }

            var parts = new List<string>();
            foreach (var memberName in new[] { "Text", "PositiveEffectText", "NegativeEffectText", "Description" })
            {
                var value = ReadMemberString(option, memberName);
                if (!string.IsNullOrWhiteSpace(value))
                {
                    parts.Add(value.Trim());
                }
            }

            return string.Join(" | ", parts);
        }

        private static string ReadMemberString(object target, string memberName)
        {
            if (target == null)
            {
                return null;
            }

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
                var propertyValue = property?.GetValue(target);
                return propertyValue?.ToString();
            }
            catch
            {
                return null;
            }
        }

        private static string Truncate(string value, int maxLength)
        {
            if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
            {
                return value;
            }

            return value.Substring(0, maxLength) + "...";
        }
    }
}
