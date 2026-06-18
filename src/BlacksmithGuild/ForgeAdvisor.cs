using System.Collections.Generic;
using System.Linq;

namespace BlacksmithGuild
{
    public sealed class ForgeAdvisor
    {
        private readonly MaterialReservePolicy _reservePolicy;

        public ForgeAdvisor(MaterialReservePolicy reservePolicy)
        {
            _reservePolicy = reservePolicy;
        }

        public IReadOnlyList<ForgeCandidate> RankCandidates(
            IEnumerable<ForgeCandidate> candidates,
            ForgeDoctrine doctrine)
        {
            return candidates
                .Select(candidate => ScoreCandidate(candidate, doctrine))
                .OrderByDescending(candidate => candidate.Score)
                .ToList();
        }

        private ForgeCandidate ScoreCandidate(
            ForgeCandidate candidate,
            ForgeDoctrine doctrine)
        {
            int doctrineBonus = GetDoctrineBonus(candidate, doctrine);

            candidate.EstimatedNetProfit =
                candidate.EstimatedValue
                - candidate.EstimatedMaterialCost
                - candidate.RareMaterialPenalty
                + doctrineBonus;

            candidate.Score = candidate.EstimatedNetProfit;

            candidate.Reason =
                $"Value {candidate.EstimatedValue}, " +
                $"material cost {candidate.EstimatedMaterialCost}, " +
                $"rare penalty {candidate.RareMaterialPenalty}, " +
                $"doctrine {doctrine}.";

            return candidate;
        }

        private int GetDoctrineBonus(ForgeCandidate candidate, ForgeDoctrine doctrine)
        {
            switch (doctrine)
            {
                case ForgeDoctrine.CashCrisis:
                    return candidate.EstimatedValue / 10;

                case ForgeDoctrine.RareMetalConservation:
                    return -candidate.RareMaterialPenalty;

                case ForgeDoctrine.ProfitForge:
                    return 0;

                case ForgeDoctrine.UnlockGrinder:
                    return 0;

                case ForgeDoctrine.WarArsenal:
                    return 0;

                case ForgeDoctrine.MaterialAlchemist:
                    return 0;

                case ForgeDoctrine.CommissionHunter:
                    return 0;

                default:
                    return 0;
            }
        }
    }
}
