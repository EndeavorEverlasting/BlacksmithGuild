using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    internal static class CharacterCreationRewardTextParser
    {
        private static readonly Regex RewardPattern = new Regex(
            @"([+-])\s*(\d+)\s+([A-Za-z][A-Za-z ]*)",
            RegexOptions.Compiled);

        private static readonly Dictionary<string, string> SkillAliases =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "smithing", "Smithing" },
                { "crafting", "Smithing" },
                { "trade", "Trade" },
                { "riding", "Riding" },
                { "polearm", "Polearm" },
                { "steward", "Steward" },
                { "leadership", "Leadership" },
                { "charm", "Charm" },
                { "tactics", "Tactics" },
                { "roguery", "Roguery" },
                { "medicine", "Medicine" },
                { "bow", "Bow" },
                { "athletics", "Athletics" },
                { "scouting", "Scouting" },
                { "engineering", "Engineering" },
                { "endurance", "Endurance" },
                { "social", "Social" },
                { "intelligence", "Intelligence" },
                { "vigor", "Vigor" },
                { "control", "Control" },
                { "cunning", "Cunning" }
            };

        public static RewardParseResult Parse(string optionText, string positiveEffectText, string negativeEffectText)
        {
            var result = new RewardParseResult();
            var corpus = string.Join(
                " | ",
                new[] { optionText, positiveEffectText, negativeEffectText });

            if (string.IsNullOrWhiteSpace(corpus))
            {
                result.ExtractionErrors.Add("empty reward text corpus");
                return result;
            }

            result.RawRewardText = corpus.Trim();
            var matches = RewardPattern.Matches(corpus);
            if (matches.Count == 0)
            {
                result.ExtractionErrors.Add("no +N Skill/Attribute tokens matched");
                return result;
            }

            foreach (Match match in matches)
            {
                if (!match.Success)
                {
                    continue;
                }

                var sign = match.Groups[1].Value == "-" ? -1 : 1;
                if (!int.TryParse(match.Groups[2].Value, out var amount))
                {
                    result.ExtractionErrors.Add($"unparseable amount: {match.Groups[2].Value}");
                    continue;
                }

                var rawName = match.Groups[3].Value.Trim();
                if (!SkillAliases.TryGetValue(rawName, out var canonical))
                {
                    canonical = char.ToUpper(rawName[0]) + rawName.Substring(1).Trim();
                }

                if (result.ParsedRewards.ContainsKey(canonical))
                {
                    result.ParsedRewards[canonical] += sign * amount;
                }
                else
                {
                    result.ParsedRewards[canonical] = sign * amount;
                }
            }

            result.ExtractionMethod = result.ExtractionErrors.Count == 0 ? "TextParse" : "TextParse";
            return result;
        }
    }

    internal sealed class RewardParseResult
    {
        public Dictionary<string, int> ParsedRewards { get; } = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        public string RawRewardText { get; set; }
        public string ExtractionMethod { get; set; } = "TextParse";
        public List<string> ExtractionErrors { get; } = new List<string>();
    }
}
