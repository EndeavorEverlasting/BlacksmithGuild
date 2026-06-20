using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Market;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingAdvisoryPlanner
    {
        public static SmithingReserveHealth BuildReserveHealth()
        {
            var charcoalHave = SmithingPartyInventory.CountCharcoal();
            var hardwoodHave = SmithingPartyInventory.CountHardwood();

            return new SmithingReserveHealth
            {
                CharcoalHave = charcoalHave,
                CharcoalFloor = SmithingReservePolicy.CharcoalFloor,
                HardwoodHave = hardwoodHave,
                HardwoodFloor = SmithingReservePolicy.HardwoodFloor,
                CharcoalStatus = SmithingReservePolicy.DescribeReserveStatus(
                    charcoalHave,
                    SmithingReservePolicy.CharcoalFloor),
                HardwoodStatus = SmithingReservePolicy.DescribeReserveStatus(
                    hardwoodHave,
                    SmithingReservePolicy.HardwoodFloor)
            };
        }

        public static SmithingAdvisoryReport BuildAdvisoryReport(
            string source,
            ForgeCandidate topCandidate,
            IReadOnlyList<MaterialGapRow> materialGaps)
        {
            var workers = SmithingWorkerSelector.GetPartyWorkers();
            var reserve = BuildReserveHealth();
            var crew = BuildSmithingCrew(workers, topCandidate, materialGaps, reserve);
            var recommendations = BuildRecommendations(crew, reserve, topCandidate);

            return new SmithingAdvisoryReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Status = "Ok",
                Detail = $"workers={workers.Count} crew={crew.Count}",
                ReserveHealth = reserve,
                Workers = workers,
                Crew = crew,
                Recommendations = recommendations
            };
        }

        public static List<SmithingCrewRow> BuildSmithingCrew(
            IReadOnlyList<SmithingWorkerProfile> workers,
            ForgeCandidate topCandidate,
            IReadOnlyList<MaterialGapRow> materialGaps,
            SmithingReserveHealth reserve)
        {
            var crew = new List<SmithingCrewRow>();
            var rank = 1;
            var grunt = SmithingWorkerSelector.SelectGruntWorker(workers);
            var crafter = SmithingWorkerSelector.SelectCraftWorker(workers, topCandidate);

            var charcoalNeed = GetCharcoalNeed(materialGaps, reserve);
            if (charcoalNeed > 0 && reserve.HardwoodHave >= charcoalNeed && grunt != null)
            {
                crew.Add(new SmithingCrewRow
                {
                    Rank = rank++,
                    HeroName = grunt.Name,
                    Action = "RefineCharcoal",
                    Target = $"hardwood→charcoal x{charcoalNeed}",
                    Reason = "low-skill grunt work; preserve main smith stamina",
                    StaminaLabel = FormatStaminaLabel(grunt)
                });
            }
            else if (charcoalNeed > 0 && grunt != null)
            {
                crew.Add(new SmithingCrewRow
                {
                    Rank = rank++,
                    HeroName = grunt.Name,
                    Action = "BuyMaterials",
                    Target = "charcoal or hardwood",
                    Reason = reserve.HardwoodHave < charcoalNeed
                        ? "hardwood shortage — buy fuel or smeltables at nearest town"
                        : "charcoal shortage — buy @ nearest or refine hardwood",
                    StaminaLabel = FormatStaminaLabel(grunt)
                });
            }

            if (topCandidate != null && crafter != null)
            {
                crew.Add(new SmithingCrewRow
                {
                    Rank = rank,
                    HeroName = crafter.Name,
                    Action = "CraftRanked",
                    Target = topCandidate.DesignName,
                    Reason = crafter.IsMainHero
                        ? "highest craft skill for top real rank"
                        : "best available smith for ranked craft",
                    StaminaLabel = FormatStaminaLabel(crafter)
                });
            }

            return crew;
        }

        public static List<SmithingRecommendation> BuildRecommendations(
            IReadOnlyList<SmithingCrewRow> crew,
            SmithingReserveHealth reserve,
            ForgeCandidate topCandidate)
        {
            return crew
                .Select(row => new SmithingRecommendation
                {
                    Priority = row.Rank,
                    HeroName = row.HeroName,
                    Action = row.Action,
                    Target = row.Target,
                    Reason = row.Reason,
                    ReserveImpact = DescribeReserveImpact(row.Action, reserve, topCandidate)
                })
                .ToList();
        }

        public static List<ActionPlanStep> BuildPrepActionSteps(
            IReadOnlyList<SmithingCrewRow> crew,
            IReadOnlyList<MaterialGapRow> materialGaps,
            SmithingReserveHealth reserve)
        {
            var steps = new List<ActionPlanStep>();
            var charcoalNeed = GetCharcoalNeed(materialGaps, reserve);

            var refineRow = crew?.FirstOrDefault(row =>
                string.Equals(row.Action, "RefineCharcoal", StringComparison.Ordinal));
            if (refineRow != null && charcoalNeed > 0)
            {
                steps.Add(new ActionPlanStep
                {
                    Step = 0,
                    Text = AdvisoryReportText.FormatRefineCharcoalStep(
                        refineRow.HeroName,
                        charcoalNeed,
                        reserve.HardwoodHave,
                        refineRow.StaminaLabel)
                });
            }

            return steps;
        }

        public static void EnrichMaterialGaps(
            IList<MaterialGapRow> gaps,
            SmithingReserveHealth reserve,
            SmithingWorkerProfile gruntWorker)
        {
            if (gaps == null)
            {
                return;
            }

            EnsureCharcoalReserveGap(gaps, reserve);

            for (var i = 0; i < gaps.Count; i++)
            {
                var gap = gaps[i];
                if (!SmithingReservePolicy.IsCharcoalItem(gap.ItemId, gap.ItemName))
                {
                    continue;
                }

                if (gap.Need <= gap.Have && reserve.CharcoalHave >= SmithingReservePolicy.CharcoalFloor)
                {
                    continue;
                }

                var deficit = Math.Max(gap.Need - gap.Have, SmithingReservePolicy.CharcoalFloor - reserve.CharcoalHave);
                if (deficit <= 0)
                {
                    continue;
                }

                if (reserve.HardwoodHave >= deficit && gruntWorker != null)
                {
                    gap.BuyHint = AdvisoryReportText.FormatRefineCharcoalGap(
                        gruntWorker.Name,
                        deficit,
                        reserve.HardwoodHave);
                    gap.BuyTown = null;
                    gap.BuyPrice = null;
                    continue;
                }

                if (string.IsNullOrEmpty(gap.BuyTown)
                    && MarketIntelligenceService.TryFindBuyAtNearest(
                        gap.ItemId,
                        gap.ItemName,
                        out var town,
                        out var buyPrice,
                        out var stock))
                {
                    gap.BuyTown = town;
                    gap.BuyPrice = buyPrice;
                    gap.Stock = stock;
                }
                else if (MarketIntelligenceService.TryFindBuyAtNearest(
                             null,
                             "hardwood",
                             out var hardwoodTown,
                             out var hardwoodPrice,
                             out var hardwoodStock))
                {
                    gap.BuyHint = AdvisoryReportText.FormatBuyHardwoodForCharcoalStep(
                        hardwoodTown,
                        hardwoodPrice,
                        hardwoodStock,
                        deficit);
                }
            }
        }

        private static int GetCharcoalNeed(IReadOnlyList<MaterialGapRow> materialGaps, SmithingReserveHealth reserve)
        {
            var recipeNeed = 0;
            if (materialGaps != null)
            {
                foreach (var gap in materialGaps)
                {
                    if (!SmithingReservePolicy.IsCharcoalItem(gap.ItemId, gap.ItemName))
                    {
                        continue;
                    }

                    if (gap.Need > gap.Have)
                    {
                        recipeNeed = Math.Max(recipeNeed, gap.Need - gap.Have);
                    }
                }
            }

            var floorNeed = Math.Max(0, SmithingReservePolicy.CharcoalFloor - reserve.CharcoalHave);
            return Math.Max(recipeNeed, floorNeed);
        }

        private static string DescribeReserveImpact(
            string action,
            SmithingReserveHealth reserve,
            ForgeCandidate topCandidate)
        {
            if (string.Equals(action, "RefineCharcoal", StringComparison.Ordinal))
            {
                return reserve.CharcoalStatus == "low" ? "stabilizes charcoal reserve" : "safe";
            }

            if (string.Equals(action, "CraftRanked", StringComparison.Ordinal))
            {
                return topCandidate == null ? "blocked" : "uses craft materials";
            }

            return reserve.CharcoalStatus == "low" ? "risky" : "safe";
        }

        private static string FormatStaminaLabel(SmithingWorkerProfile worker)
        {
            if (worker == null)
            {
                return "stamina ?";
            }

            return worker.StaminaKnown
                ? $"stamina {worker.Stamina}/{worker.MaxStamina}"
                : "stamina ?";
        }

        private static void EnsureCharcoalReserveGap(IList<MaterialGapRow> gaps, SmithingReserveHealth reserve)
        {
            if (reserve.CharcoalHave >= SmithingReservePolicy.CharcoalFloor)
            {
                return;
            }

            foreach (var gap in gaps)
            {
                if (SmithingReservePolicy.IsCharcoalItem(gap.ItemId, gap.ItemName))
                {
                    return;
                }
            }

            gaps.Insert(
                0,
                new MaterialGapRow
                {
                    ItemName = "Charcoal",
                    Need = SmithingReservePolicy.CharcoalFloor,
                    Have = reserve.CharcoalHave
                });
        }
    }
}
