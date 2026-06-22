using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionScoringService
    {
        public static CohesionOpportunity ScoreOpportunity(
            CohesionObjective objective,
            CohesionPartySnapshot primary,
            List<CohesionPartySnapshot> helpers,
            List<CohesionPartySnapshot> hostiles,
            CohesionConvergencePoint convergence,
            CohesionEtaBlock eta,
            CohesionPowerBlock power)
        {
            var opportunity = new CohesionOpportunity
            {
                OpportunityId = Guid.NewGuid().ToString("N").Substring(0, 12),
                ObjectiveType = objective?.ObjectiveType ?? CohesionObjectiveType.SafeTraversal,
                PrimaryParty = primary,
                HelperParties = helpers ?? new List<CohesionPartySnapshot>(),
                HostileParties = hostiles ?? new List<CohesionPartySnapshot>(),
                ProtectorParties = helpers?
                    .Where(h => h.InferredIntent == CohesionIntent.ShadowableProtector)
                    .ToList() ?? new List<CohesionPartySnapshot>(),
                ConvergencePoint = convergence,
                Eta = eta,
                Power = power
            };

            var objectiveValue = ObjectiveValue(objective);
            var strengthScore = StrengthRatioScore(power);
            var etaScore = EtaAlignmentScore(eta);
            var protectorScore = ProtectorPressureScore(opportunity.ProtectorParties, hostiles);
            var safetyScore = SafetySettlementScore(eta);
            var forgeScore = objective?.ObjectiveType == CohesionObjectiveType.TradeForge ? 1.2f : 1f;
            var interceptPenalty = InterceptPenalty(eta, hostiles);
            var isolationPenalty = helpers == null || helpers.Count == 0 ? 0.35f : 0f;
            var uncertaintyPenalty = UncertaintyPenalty(helpers, hostiles);
            var delayPenalty = DelayPenalty(eta);
            var overextensionPenalty = OverextensionPenalty(primary, objective);

            opportunity.Score = objectiveValue
                * strengthScore
                * etaScore
                * protectorScore
                * safetyScore
                * forgeScore
                - interceptPenalty
                - isolationPenalty
                - uncertaintyPenalty
                - delayPenalty
                - overextensionPenalty;

            opportunity.Confidence = ResolveConfidence(helpers, hostiles, power);
            opportunity.RecommendedAction = RecommendAction(opportunity, power, eta, hostiles);
            opportunity.Risk = BuildRisk(hostiles, eta, opportunity.RecommendedAction);
            opportunity.Reasons = BuildReasons(opportunity, power, eta);
            opportunity.Risks = BuildRisks(hostiles, power, eta);
            opportunity.BlockedReason = ResolveBlockedReason(opportunity);
            return opportunity;
        }

        public static CohesionOpportunity SelectBest(IEnumerable<CohesionOpportunity> opportunities)
        {
            return opportunities?
                .Where(o => o.BlockedReason == null)
                .OrderByDescending(o => o.Score)
                .FirstOrDefault()
                ?? opportunities?.OrderByDescending(o => o.Score).FirstOrDefault();
        }

        private static float ObjectiveValue(CohesionObjective objective)
        {
            if (objective == null)
            {
                return 0.5f;
            }

            switch (objective.ObjectiveType)
            {
                case CohesionObjectiveType.TradeForge:
                case CohesionObjectiveType.ForgeHubMove:
                    return 1.4f;
                case CohesionObjectiveType.Relief:
                    return 1.3f;
                case CohesionObjectiveType.Escort:
                    return 1.1f;
                case CohesionObjectiveType.BanditSuppression:
                    return 1.0f;
                case CohesionObjectiveType.Rally:
                    return 0.9f;
                default:
                    return 0.7f;
            }
        }

        private static float StrengthRatioScore(CohesionPowerBlock power)
        {
            if (power?.StrengthRatio == null)
            {
                return 0.5f;
            }

            var ratio = power.StrengthRatio.Value;
            if (ratio >= DevToolsConfig.CohesionMinimumEngageRatio)
            {
                return 1.2f;
            }

            if (ratio >= DevToolsConfig.CohesionMinimumSurvivalRatio)
            {
                return 1.0f;
            }

            if (ratio >= DevToolsConfig.CohesionMinimumShadowRatio)
            {
                return 0.75f;
            }

            return 0.35f;
        }

        private static float EtaAlignmentScore(CohesionEtaBlock eta)
        {
            if (eta?.EscapeMarginHours == null || eta.HostileEtaHours == null || eta.ConvergenceEtaHours == null)
            {
                return 0.5f;
            }

            var margin = eta.EscapeMarginHours.Value;
            if (margin >= DevToolsConfig.CohesionMinEscapeMarginHours)
            {
                return 1.1f;
            }

            return margin > 0 ? 0.8f : 0.3f;
        }

        private static float ProtectorPressureScore(
            List<CohesionPartySnapshot> protectors,
            List<CohesionPartySnapshot> hostiles)
        {
            if (protectors == null || protectors.Count == 0)
            {
                return hostiles == null || hostiles.Count == 0 ? 1f : 0.6f;
            }

            return 1.15f;
        }

        private static float SafetySettlementScore(CohesionEtaBlock eta)
        {
            return eta?.EscapeMarginHours != null && eta.EscapeMarginHours <= DevToolsConfig.CohesionMaxWindowHours
                ? 1.05f
                : 0.85f;
        }

        private static float InterceptPenalty(CohesionEtaBlock eta, List<CohesionPartySnapshot> hostiles)
        {
            if (hostiles == null || hostiles.Count == 0)
            {
                return 0f;
            }

            if (eta?.EscapeMarginHours == null)
            {
                return 0.5f;
            }

            return eta.EscapeMarginHours <= 0 ? 0.8f : 0.1f;
        }

        private static float UncertaintyPenalty(
            List<CohesionPartySnapshot> helpers,
            List<CohesionPartySnapshot> hostiles)
        {
            var penalty = 0f;
            foreach (var party in helpers ?? Enumerable.Empty<CohesionPartySnapshot>())
            {
                if (party.Confidence == CohesionConfidence.Unknown || party.Confidence == CohesionConfidence.Low)
                {
                    penalty += 0.05f;
                }
            }

            foreach (var party in hostiles ?? Enumerable.Empty<CohesionPartySnapshot>())
            {
                if (party.Confidence == CohesionConfidence.Unknown)
                {
                    penalty += 0.1f;
                }
            }

            return penalty;
        }

        private static float DelayPenalty(CohesionEtaBlock eta)
        {
            if (eta?.ConvergenceEtaHours == null)
            {
                return 0.1f;
            }

            return eta.ConvergenceEtaHours > DevToolsConfig.CohesionMaxWindowHours ? 0.25f : 0f;
        }

        private static float OverextensionPenalty(CohesionPartySnapshot primary, CohesionObjective objective)
        {
            if (primary == null || objective == null)
            {
                return 0f;
            }

            return primary.DistanceToPlayer > objective.MaxDistance ? 0.4f : 0f;
        }

        private static CohesionConfidence ResolveConfidence(
            List<CohesionPartySnapshot> helpers,
            List<CohesionPartySnapshot> hostiles,
            CohesionPowerBlock power)
        {
            if (power?.StrengthRatio == null)
            {
                return CohesionConfidence.Unknown;
            }

            var lowCount = 0;
            foreach (var party in helpers ?? Enumerable.Empty<CohesionPartySnapshot>())
            {
                if (party.Confidence == CohesionConfidence.Low || party.Confidence == CohesionConfidence.Unknown)
                {
                    lowCount++;
                }
            }

            foreach (var party in hostiles ?? Enumerable.Empty<CohesionPartySnapshot>())
            {
                if (party.Confidence == CohesionConfidence.Unknown)
                {
                    lowCount++;
                }
            }

            if (lowCount >= 3)
            {
                return CohesionConfidence.Low;
            }

            if (lowCount >= 1)
            {
                return CohesionConfidence.Medium;
            }

            return CohesionConfidence.High;
        }

        private static CohesionRecommendedAction RecommendAction(
            CohesionOpportunity opportunity,
            CohesionPowerBlock power,
            CohesionEtaBlock eta,
            List<CohesionPartySnapshot> hostiles)
        {
            if (hostiles != null && hostiles.Any(h => h.DistanceToPlayer <= DevToolsConfig.MapTradeAbortHostileRadius))
            {
                return power?.StrengthRatio >= DevToolsConfig.CohesionMinimumSurvivalRatio
                    ? CohesionRecommendedAction.DuckIntoSettlement
                    : CohesionRecommendedAction.AbortCohesion;
            }

            if (opportunity.HelperParties == null || opportunity.HelperParties.Count == 0)
            {
                return hostiles != null && hostiles.Count > 0
                    ? CohesionRecommendedAction.BlockedNoHelper
                    : CohesionRecommendedAction.ContinueTradeRoute;
            }

            if (power?.StrengthRatio == null)
            {
                return CohesionRecommendedAction.BlockedUnknownRisk;
            }

            if (power.StrengthRatio < DevToolsConfig.CohesionMinimumShadowRatio)
            {
                return CohesionRecommendedAction.BlockedInsufficientStrength;
            }

            if (opportunity.ProtectorParties.Count > 0
                && power.StrengthRatio >= DevToolsConfig.CohesionMinimumShadowRatio)
            {
                return eta?.EscapeMarginHours >= DevToolsConfig.CohesionMinEscapeMarginHours
                    ? CohesionRecommendedAction.ShadowProtector
                    : CohesionRecommendedAction.WaitForCohesionWindow;
            }

            if (power.StrengthRatio >= DevToolsConfig.CohesionMinimumEngageRatio)
            {
                return CohesionRecommendedAction.MoveTowardHelper;
            }

            if (power.StrengthRatio >= DevToolsConfig.CohesionMinimumSurvivalRatio)
            {
                return CohesionRecommendedAction.WaitForCohesionWindow;
            }

            return CohesionRecommendedAction.RerouteAroundThreat;
        }

        private static CohesionRiskBlock BuildRisk(
            List<CohesionPartySnapshot> hostiles,
            CohesionEtaBlock eta,
            CohesionRecommendedAction action)
        {
            var nearestHostile = hostiles?.OrderBy(h => h.DistanceToPlayer).FirstOrDefault();
            var intercept = "Unknown";
            if (eta?.EscapeMarginHours != null)
            {
                intercept = eta.EscapeMarginHours <= 0 ? "High" :
                    eta.EscapeMarginHours < DevToolsConfig.CohesionMinEscapeMarginHours ? "Medium" : "Low";
            }

            return new CohesionRiskBlock
            {
                InterceptRisk = intercept,
                CombatContactLikely = nearestHostile != null
                    && nearestHostile.DistanceToPlayer <= DevToolsConfig.MapTradeAvoidHostileRadius,
                NearestSafeSettlement = null,
                FallbackEtaHours = eta?.PlayerEtaHours
            };
        }

        private static List<string> BuildReasons(
            CohesionOpportunity opportunity,
            CohesionPowerBlock power,
            CohesionEtaBlock eta)
        {
            var reasons = new List<string>();
            if (opportunity.ProtectorParties.Count > 0)
            {
                reasons.Add("Friendly protector movement may open a safer corridor");
            }

            if (power?.StrengthRatio != null)
            {
                reasons.Add($"Combined strength ratio {power.StrengthRatio:0.00}");
            }

            if (eta?.EscapeMarginHours != null)
            {
                reasons.Add($"Escape margin {eta.EscapeMarginHours:0.00}h");
            }

            return reasons;
        }

        private static List<string> BuildRisks(
            List<CohesionPartySnapshot> hostiles,
            CohesionPowerBlock power,
            CohesionEtaBlock eta)
        {
            var risks = new List<string>();
            if (hostiles != null && hostiles.Count > 0)
            {
                risks.Add($"{hostiles.Count} hostile party(ies) in scan radius");
            }

            if (power?.StrengthRatio != null && power.StrengthRatio < DevToolsConfig.CohesionMinimumSurvivalRatio)
            {
                risks.Add("Combined strength below survival threshold");
            }

            if (eta?.EscapeMarginHours != null && eta.EscapeMarginHours <= 0)
            {
                risks.Add("Hostile may reach player before cohesion completes");
            }

            return risks;
        }

        private static string ResolveBlockedReason(CohesionOpportunity opportunity)
        {
            switch (opportunity.RecommendedAction)
            {
                case CohesionRecommendedAction.BlockedNoHelper:
                    return "No helper or protector within scan radius";
                case CohesionRecommendedAction.BlockedInsufficientStrength:
                    return "Combined friendly strength too low";
                case CohesionRecommendedAction.BlockedUnknownRisk:
                    return "Risk could not be estimated with sufficient confidence";
                case CohesionRecommendedAction.BlockedWouldTriggerCombat:
                    return "Action would likely trigger combat contact";
                default:
                    return null;
            }
        }
    }
}
