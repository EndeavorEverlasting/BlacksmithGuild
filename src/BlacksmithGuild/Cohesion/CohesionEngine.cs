using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionEngine
    {
        public const string AnalyzeCohesionOpportunitiesCommand = "AnalyzeCohesionOpportunities";
        public const string ShowCohesionPlanCommand = "ShowCohesionPlan";

        private static CohesionOpportunitiesReport _lastReport;

        public static CohesionOpportunitiesReport LastReport => _lastReport;

        public static bool AnalyzeNow(string source = AnalyzeCohesionOpportunitiesCommand, CohesionObjective objectiveOverride = null)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG COHESION: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            try
            {
                var report = BuildReport(source, objectiveOverride);
                _lastReport = report;
                CohesionJsonWriter.WriteOpportunities(report);
                InGameNotice.Info($"TBG COHESION: scanning friendly movement near route | {report.Opportunities.Count} opportunities.");
                if (report.SelectedOpportunity != null)
                {
                    InGameNotice.Info(
                        $"TBG COHESION PLAN: {report.SelectedOpportunity.RecommendedAction} | score {report.SelectedOpportunity.Score:0.#}.");
                }
                else if (!string.IsNullOrEmpty(report.Verdict))
                {
                    InGameNotice.Blocked($"TBG COHESION BLOCKED: {report.Verdict}");
                }

                DebugLogger.Test($"[TBG COHESION] analyze complete: {report.Verdict}", showInGame: false);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG COHESION] analyze failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool ShowPlan()
        {
            if (_lastReport == null)
            {
                return AnalyzeNow(ShowCohesionPlanCommand);
            }

            CohesionJsonWriter.WriteOpportunities(_lastReport);
            InGameNotice.Info($"TBG COHESION PLAN: {_lastReport.Verdict}");
            return true;
        }

        public static CohesionOpportunity BuildPlanForObjective(CohesionObjective objective)
        {
            var report = BuildReport("CohesionEngine.BuildPlanForObjective", objective);
            return report.SelectedOpportunity;
        }

        public static CohesionOpportunitiesReport BuildReport(string source, CohesionObjective objectiveOverride = null)
        {
            var main = MobileParty.MainParty;
            var objective = objectiveOverride ?? CohesionDoctrine.BuildDefaultObjective();
            var snapshots = CohesionPartyScanner.Scan(DevToolsConfig.CohesionScanRadius, main);
            var primary = snapshots.FirstOrDefault(s => s.RelationToPlayer == CohesionRelationToPlayer.Player);
            var helpers = CohesionPartyScanner.FilterHelpers(snapshots);
            var hostiles = CohesionPartyScanner.FilterHostiles(snapshots);
            var settlement = CohesionRoutePlanner.ResolveSettlement(objective);
            var opportunities = new List<CohesionOpportunity>();

            if (helpers.Count == 0 && hostiles.Count == 0)
            {
                opportunities.Add(BuildStandaloneOpportunity(objective, primary, hostiles, settlement));
            }
            else
            {
                foreach (var helper in helpers.Take(8))
                {
                    opportunities.Add(BuildHelperOpportunity(objective, primary, helper, helpers, hostiles, settlement, main));
                }
            }

            var selected = CohesionScoringService.SelectBest(opportunities);
            var verdict = selected?.BlockedReason
                ?? (selected == null ? "No cohesion opportunities found" : $"Selected {selected.RecommendedAction} score={selected.Score:0.#}");

            return new CohesionOpportunitiesReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = CohesionDoctrine.GetLabel(),
                CurrentObjective = objective,
                PartySnapshots = snapshots,
                Opportunities = opportunities,
                SelectedOpportunity = selected,
                Verdict = verdict
            };
        }

        public static CohesionObjective BuildObjectiveFromDoctrine(CohesionDoctrineKind doctrine)
        {
            var objective = new CohesionObjective
            {
                ObjectiveId = Guid.NewGuid().ToString("N").Substring(0, 8),
                MaxDurationHours = DevToolsConfig.MapTradeMaxTravelDurationHours,
                MaxDistance = DevToolsConfig.MapTradeMaxRouteDistance,
                AllowCombatContact = false,
                PreferAvoidingCombat = true
            };

            switch (doctrine)
            {
                case CohesionDoctrineKind.Relief:
                    objective.ObjectiveType = CohesionObjectiveType.Relief;
                    objective.DesiredOutcome = "Reach threatened friendly unit with combined strength";
                    break;
                case CohesionDoctrineKind.Escort:
                    objective.ObjectiveType = CohesionObjectiveType.Escort;
                    objective.DesiredOutcome = "Escort along route using friendly cover";
                    break;
                case CohesionDoctrineKind.BanditSuppression:
                    objective.ObjectiveType = CohesionObjectiveType.BanditSuppression;
                    objective.DesiredOutcome = "Advance while friendly force pressures bandits";
                    break;
                case CohesionDoctrineKind.Rally:
                    objective.ObjectiveType = CohesionObjectiveType.Rally;
                    objective.DesiredOutcome = "Rally at safe settlement before proceeding";
                    break;
                case CohesionDoctrineKind.SafeTraversal:
                    objective.ObjectiveType = CohesionObjectiveType.SafeTraversal;
                    objective.DesiredOutcome = "Cross dangerous map safely";
                    break;
                default:
                    objective.ObjectiveType = CohesionObjectiveType.TradeForge;
                    objective.DesiredOutcome = "Safer forge/trade route using friendly coalescence";
                    objective.RequiredItemIds = new List<string> { "hardwood", "charcoal", "iron", "iron_ore" };
                    break;
            }

            var nearestTown = CohesionPartyScanner.FindNearestSafeTown(MobileParty.MainParty);
            if (nearestTown != null)
            {
                objective.TargetSettlementId = nearestTown.StringId;
                objective.TargetSettlementName = nearestTown.Name?.ToString();
            }

            return objective;
        }

        private static CohesionOpportunity BuildStandaloneOpportunity(
            CohesionObjective objective,
            CohesionPartySnapshot primary,
            List<CohesionPartySnapshot> hostiles,
            Settlement settlement)
        {
            var eta = BuildEta(primary, null, hostiles, settlement);
            var power = BuildPower(primary, null, hostiles);
            var convergence = CohesionRoutePlanner.PlanConvergence(MobileParty.MainParty, null, settlement);
            return CohesionScoringService.ScoreOpportunity(objective, primary, new List<CohesionPartySnapshot>(), hostiles, convergence, eta, power);
        }

        private static CohesionOpportunity BuildHelperOpportunity(
            CohesionObjective objective,
            CohesionPartySnapshot primary,
            CohesionPartySnapshot helper,
            List<CohesionPartySnapshot> helpers,
            List<CohesionPartySnapshot> hostiles,
            Settlement settlement,
            MobileParty main)
        {
            var helperList = new List<CohesionPartySnapshot> { helper };
            var eta = BuildEta(primary, helper, hostiles, settlement);
            var power = BuildPower(primary, helper, hostiles);
            var convergence = CohesionRoutePlanner.PlanConvergence(main, helper, settlement);
            return CohesionScoringService.ScoreOpportunity(objective, primary, helperList, hostiles, convergence, eta, power);
        }

        private static CohesionEtaBlock BuildEta(
            CohesionPartySnapshot primary,
            CohesionPartySnapshot helper,
            List<CohesionPartySnapshot> hostiles,
            Settlement settlement)
        {
            var main = MobileParty.MainParty;
            var playerSpeed = primary?.Speed ?? main?.Speed ?? 1f;
            var playerToObjective = settlement == null
                ? 0f
                : CampaignMapMovementHelper.Distance(main, settlement);
            var playerEta = CampaignMapMovementHelper.EstimateEtaHours(playerToObjective, playerSpeed);

            float? helperEta = null;
            if (helper != null && settlement != null)
            {
                var helperDistance = new Vec2(helper.PositionX, helper.PositionY).Distance(settlement.GetPosition2D);
                helperEta = CampaignMapMovementHelper.EstimateEtaHours(helperDistance, Math.Max(helper.Speed, 0.5f));
            }

            float? hostileEta = null;
            var nearestHostile = hostiles?.OrderBy(h => h.DistanceToPlayer).FirstOrDefault();
            if (nearestHostile != null)
            {
                hostileEta = CampaignMapMovementHelper.EstimateEtaHours(
                    nearestHostile.DistanceToPlayer,
                    Math.Max(nearestHostile.Speed, 0.5f));
            }

            var convergenceEta = helperEta.HasValue ? Math.Max(playerEta, helperEta.Value) : playerEta;
            float? escapeMargin = hostileEta.HasValue ? hostileEta.Value - convergenceEta : null;

            return new CohesionEtaBlock
            {
                PlayerEtaHours = playerEta,
                HelperEtaHours = helperEta,
                HostileEtaHours = hostileEta,
                ConvergenceEtaHours = convergenceEta,
                EscapeMarginHours = escapeMargin
            };
        }

        private static CohesionPowerBlock BuildPower(
            CohesionPartySnapshot primary,
            CohesionPartySnapshot helper,
            List<CohesionPartySnapshot> hostiles)
        {
            var playerStrength = primary?.Strength;
            var helperStrength = helper?.Strength;
            var combined = (playerStrength ?? 0) + (helperStrength ?? 0);
            var hostileStrength = CohesionPartyScanner.ClusterStrength(hostiles);
            float? ratio = hostileStrength > 0 ? combined / (float)hostileStrength : combined > 0 ? 2f : null;

            return new CohesionPowerBlock
            {
                PlayerStrength = playerStrength,
                HelperStrength = helperStrength,
                CombinedFriendlyStrength = combined,
                HostileClusterStrength = hostileStrength,
                StrengthRatio = ratio,
                Confidence = ratio.HasValue ? "Medium" : "Unknown"
            };
        }
    }
}
