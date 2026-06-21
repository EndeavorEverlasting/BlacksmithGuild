using System;
using System.Collections.Generic;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class CharacterBuildCandidate
    {
        public string CandidateId { get; set; }
        public string Profile { get; set; }
        public double Score { get; set; }
        public string Confidence { get; set; } = "High";
        public List<CharacterBuildRouteStep> Route { get; } = new List<CharacterBuildRouteStep>();
        public Dictionary<string, int> ProjectedSkills { get; } = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, int> ProjectedAttributes { get; } = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        public List<string> Reasons { get; } = new List<string>();
    }

    public static class CharacterBuildCandidateScorer
    {
        private static readonly Dictionary<string, int> ScreenshotSkillTargets =
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                { "Trade", 20 }, { "Smithing", 0 }, { "Riding", 10 }, { "Polearm", 10 },
                { "Steward", 10 }, { "Leadership", 10 }, { "Charm", 10 }, { "Tactics", 10 },
                { "Roguery", 10 }, { "Medicine", 10 }
            };

        private static readonly Dictionary<string, int> BalancedSkillTargets =
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                { "Smithing", 5 }, { "Trade", 5 }, { "Riding", 4 }, { "Polearm", 4 },
                { "Steward", 4 }, { "Leadership", 4 }, { "Charm", 3 }, { "Tactics", 3 },
                { "Roguery", 3 }, { "Medicine", 3 }
            };

        private static readonly Dictionary<string, int> SmithingMaxSkillTargets =
            new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase)
            {
                { "Smithing", 10 }, { "Trade", 5 }, { "Riding", 4 }, { "Steward", 4 }
            };

        private static readonly Dictionary<string, double> AttributeWeights =
            new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase)
            {
                { "Endurance", 5 }, { "Social", 5 }, { "Intelligence", 3 },
                { "Vigor", 1 }, { "Control", 0.5 }, { "Cunning", 0.5 }
            };

        public static double ScoreCandidate(
            CharacterBuildCandidate candidate,
            string profile,
            bool lowConfidence)
        {
            var skillTargets = GetSkillTargets(profile);
            var score = 0d;

            foreach (var target in skillTargets)
            {
                candidate.ProjectedSkills.TryGetValue(target.Key, out var actual);
                var delta = Math.Abs(actual - target.Value);
                score += Math.Max(0, 20 - delta);
            }

            foreach (var weight in AttributeWeights)
            {
                candidate.ProjectedAttributes.TryGetValue(weight.Key, out var actual);
                score += actual * weight.Value;
            }

            candidate.ProjectedSkills.TryGetValue("Smithing", out var smithing);
            candidate.ProjectedSkills.TryGetValue("Trade", out var trade);
            candidate.ProjectedAttributes.TryGetValue("Endurance", out var endurance);
            candidate.ProjectedAttributes.TryGetValue("Social", out var social);

            if (smithing <= 0)
            {
                score -= 50;
                candidate.Reasons.Add("penalty: Smithing remains 0");
            }

            if (trade <= 0)
            {
                score -= 35;
                candidate.Reasons.Add("penalty: Trade remains 0");
            }

            if (endurance < 3)
            {
                score -= 20;
                candidate.Reasons.Add("penalty: Endurance below 3");
            }

            if (social < 3)
            {
                score -= 20;
                candidate.Reasons.Add("penalty: Social below 3");
            }

            if (lowConfidence)
            {
                score -= 25;
                candidate.Confidence = "Low";
                candidate.Reasons.Add("penalty: unparseable route without runtime validation");
            }

            candidate.Score = score;
            candidate.Profile = profile;
            return score;
        }

        public static Dictionary<string, int> GetSkillTargets(string profile)
        {
            if (string.Equals(profile, "ScreenshotReplayNearest", StringComparison.OrdinalIgnoreCase))
            {
                return ScreenshotSkillTargets;
            }

            if (string.Equals(profile, "AseraiSmithingMax", StringComparison.OrdinalIgnoreCase))
            {
                return SmithingMaxSkillTargets;
            }

            return BalancedSkillTargets;
        }
    }
}
