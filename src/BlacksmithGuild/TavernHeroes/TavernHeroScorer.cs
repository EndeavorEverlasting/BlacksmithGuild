using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroScorer
    {
        public static List<TavernHeroRecommendation> BuildRecommendations(
            List<TavernHeroCandidate> candidates,
            TavernHeroPlayerSnapshot player,
            TavernHeroCompanionStateSnapshot companionState,
            TavernHeroSettlementSnapshot settlement)
        {
            var recommendations = new List<TavernHeroRecommendation>();
            foreach (var candidate in candidates)
            {
                var score = ScoreCandidate(candidate, player, companionState, settlement, out var reasons, out var label);
                candidate.Score = score;
                recommendations.Add(new TavernHeroRecommendation
                {
                    HeroId = candidate.HeroId,
                    Name = candidate.Name,
                    Score = score,
                    Reasons = reasons,
                    RecruitmentCost = candidate.RecruitmentCost,
                    Label = label
                });
            }

            return recommendations.OrderByDescending(r => r.Score).ThenBy(r => r.Name).ToList();
        }

        private static float ScoreCandidate(
            TavernHeroCandidate candidate,
            TavernHeroPlayerSnapshot player,
            TavernHeroCompanionStateSnapshot companionState,
            TavernHeroSettlementSnapshot settlement,
            out List<string> reasons,
            out string label)
        {
            reasons = new List<string>();
            var score = 0f;
            label = TavernHeroDoctrine.GetDoctrineLabel();

            if (candidate.RecruitmentAvailable == false)
            {
                score -= 1000f;
                reasons.Add("recruitment unavailable");
            }

            if (settlement?.PlayerInTavern == false)
            {
                score -= 500f;
                reasons.Add("not in tavern location");
            }

            if (companionState?.RemainingSlots == 0)
            {
                score -= 1000f;
                reasons.Add("companion limit full");
            }

            if (candidate.RecruitmentCost.HasValue
                && player != null
                && candidate.RecruitmentCost.Value > player.SpendableGold)
            {
                score -= 1000f;
                reasons.Add("cannot afford after reserve");
            }

            if (!candidate.RecruitmentCost.HasValue)
            {
                score -= 75f;
                reasons.Add("recruitment cost unknown");
            }

            if (candidate.Skills.Values.All(v => v == null))
            {
                score -= 25f;
                reasons.Add("skills unavailable");
            }

            score += ScoreDoctrineSkills(candidate, reasons);
            score += ScoreCostEfficiency(candidate, player, reasons);

            if (string.Equals(candidate.Culture, "Aserai", StringComparison.OrdinalIgnoreCase))
            {
                score += 1f;
                reasons.Add("Aserai culture synergy");
            }

            if (candidate.RiskFlags.Count == 0)
            {
                score += 5f;
                reasons.Add("low recruitment risk");
            }

            return score;
        }

        private static float ScoreDoctrineSkills(TavernHeroCandidate candidate, List<string> reasons)
        {
            switch (TavernHeroDoctrine.ActiveDoctrine)
            {
                case TavernHeroDoctrineKind.ScoutQuartermaster:
                    return AddWeighted(candidate, reasons, "Scouting", 2f)
                           + AddWeighted(candidate, reasons, "Riding", 2f)
                           + AddWeighted(candidate, reasons, "Steward", 4f)
                           + AddWeighted(candidate, reasons, "Trade", 3f);
                case TavernHeroDoctrineKind.CombatEscort:
                    return AddWeighted(candidate, reasons, "Polearm", 1f)
                           + AddWeighted(candidate, reasons, "Bow", 1f)
                           + AddWeighted(candidate, reasons, "OneHanded", 1f)
                           + AddWeighted(candidate, reasons, "Leadership", 1f);
                default:
                    return AddWeighted(candidate, reasons, "Smithing", 5f)
                           + AddWeighted(candidate, reasons, "Steward", 4f)
                           + AddWeighted(candidate, reasons, "Trade", 3f)
                           + AddWeighted(candidate, reasons, "Medicine", 3f);
            }
        }

        private static float AddWeighted(
            TavernHeroCandidate candidate,
            List<string> reasons,
            string skill,
            float weight)
        {
            if (!candidate.Skills.TryGetValue(skill, out var value) || !value.HasValue)
            {
                return 0f;
            }

            var contribution = value.Value / 20f * weight;
            if (contribution > 0f)
            {
                reasons.Add($"{skill} {value.Value}");
            }

            return contribution;
        }

        private static float ScoreCostEfficiency(
            TavernHeroCandidate candidate,
            TavernHeroPlayerSnapshot player,
            List<string> reasons)
        {
            if (!candidate.RecruitmentCost.HasValue || candidate.RecruitmentCost.Value <= 0)
            {
                return 0f;
            }

            var smithing = candidate.Skills.TryGetValue("Smithing", out var smith) ? smith ?? 0 : 0;
            var steward = candidate.Skills.TryGetValue("Steward", out var st) ? st ?? 0 : 0;
            var utility = smithing + steward;
            if (utility <= 0)
            {
                return 0f;
            }

            var efficiency = utility / (candidate.RecruitmentCost.Value / 100f) * 3f;
            reasons.Add($"cost efficiency {efficiency:0.#}");
            return efficiency;
        }
    }
}
