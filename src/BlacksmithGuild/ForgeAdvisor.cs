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
                .OrderByDescending(candidate => candidate.FinalScore)
                .ThenByDescending(candidate => candidate.EstimatedNetProfit)
                .ToList();
        }

        private ForgeCandidate ScoreCandidate(
            ForgeCandidate candidate,
            ForgeDoctrine doctrine)
        {
            var netProfit = ComputeNetProfit(candidate);
            var doctrineScore = ComputeDoctrineScore(candidate, doctrine, netProfit);
            var finalScore = netProfit + doctrineScore;

            candidate.EstimatedNetProfit = netProfit;
            candidate.DoctrineScore = doctrineScore;
            candidate.FinalScore = finalScore;
            candidate.Score = finalScore;

            candidate.Reason =
                $"net={netProfit}, doctrine={doctrineScore}, reservePolicy={DescribeReservePolicy()}, doctrineMode={doctrine}.";

            return candidate;
        }

        private int ComputeNetProfit(ForgeCandidate candidate)
        {
            return candidate.EstimatedValue
                - candidate.EstimatedMaterialCost
                - candidate.RareMaterialPenalty;
        }

        private int ComputeDoctrineScore(
            ForgeCandidate candidate,
            ForgeDoctrine doctrine,
            int netProfit)
        {
            switch (doctrine)
            {
                case ForgeDoctrine.CashCrisis:
                    return candidate.EstimatedValue / 10;

                case ForgeDoctrine.RareMetalConservation:
                    return _reservePolicy.PreserveRareMaterials
                        ? -candidate.RareMaterialPenalty
                        : 0;

                case ForgeDoctrine.ProfitForge:
                    return netProfit > 0 ? 0 : -500;

                case ForgeDoctrine.UnlockGrinder:
                    return candidate.WeaponClass.Contains("Two-Handed") ? 250 : 0;

                case ForgeDoctrine.WarArsenal:
                    return candidate.WeaponClass.Contains("Polearm") ? 300 : 0;

                case ForgeDoctrine.MaterialAlchemist:
                    return candidate.RareMaterialPenalty > 0 ? -candidate.RareMaterialPenalty / 2 : 100;

                case ForgeDoctrine.CommissionHunter:
                    return candidate.EstimatedValue >= 10000 ? 150 : 0;

                default:
                    return 0;
            }
        }

        private string DescribeReservePolicy()
        {
            return _reservePolicy.PreserveRareMaterials ? "preserve-rare" : "spend-rare";
        }
    }
}
