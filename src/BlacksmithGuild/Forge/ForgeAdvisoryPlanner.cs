using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class ForgeAdvisoryPlanner
    {
        private const int MaxActionPlanSteps = 5;
        private const int MaxMaterialGaps = 6;

        public static SourceHonestyInfo BuildSourceHonesty(
            ForgeCandidateSourceKind requestedKind,
            ForgeRecommendationReport report)
        {
            var isStub = string.Equals(report.Source, StubForgeCandidateSource.SourceName, StringComparison.OrdinalIgnoreCase)
                || report.FallbackUsed;
            var verdict = report.FallbackUsed
                ? ReportVerdict.Warn
                : isStub
                    ? ReportVerdict.Info
                    : ReportVerdict.Pass;
            var message = report.FallbackUsed
                ? "real source unavailable — fell back to stub oracle"
                : isStub
                    ? "illustrative stub oracle — use SetForgeCandidateSourceStub to force stub on map rank"
                    : "candidate source resolved";

            return new SourceHonestyInfo
            {
                Requested = requestedKind.ToString(),
                Resolved = report.Source,
                FallbackUsed = report.FallbackUsed,
                Detail = report.ResolutionDetail,
                Verdict = verdict,
                VerdictMessage = message
            };
        }

        public static List<CraftCandidateRow> BuildCraftNextRows(IReadOnlyList<ForgeCandidate> ranked, int maxRows = 3)
        {
            return ranked
                .Take(maxRows)
                .Select(candidate => new CraftCandidateRow
                {
                    Name = candidate.DesignName,
                    FinalScore = candidate.FinalScore,
                    NetProfit = candidate.EstimatedNetProfit,
                    IsStub = string.Equals(candidate.Source, StubForgeCandidateSource.SourceName, StringComparison.OrdinalIgnoreCase)
                })
                .ToList();
        }

        public static List<MaterialGapRow> BuildMaterialGaps(ForgeCandidate topCandidate)
        {
            var gaps = new List<MaterialGapRow>();
            if (topCandidate == null)
            {
                return gaps;
            }

            if (topCandidate.MaterialNeeds != null && topCandidate.MaterialNeeds.Count > 0)
            {
                foreach (var need in topCandidate.MaterialNeeds.Take(MaxMaterialGaps))
                {
                    var have = CountPartyItem(need.ItemId, need.ItemName);
                    var gap = new MaterialGapRow
                    {
                        ItemId = need.ItemId,
                        ItemName = need.ItemName,
                        Need = need.Quantity,
                        Have = have
                    };

                    if (need.Quantity > have
                        && MarketIntelligenceService.TryFindBuyAtNearest(
                            need.ItemId,
                            need.ItemName,
                            out var town,
                            out var buyPrice,
                            out var stock))
                    {
                        gap.BuyTown = town;
                        gap.BuyPrice = buyPrice;
                        gap.Stock = stock;
                    }
                    else if (need.Quantity > have)
                    {
                        var nearest = MarketIntelligenceService.HasCachedScan
                            ? MarketIntelligenceService.GetAdvisorySnapshot().NearestTown
                            : "nearest town";
                        gap.BuyHint = AdvisoryReportText.FormatBuyMaterialHintStep(nearest, need.ItemName);
                    }

                    gaps.Add(gap);
                }

                return gaps;
            }

            if (string.Equals(topCandidate.Source, StubForgeCandidateSource.SourceName, StringComparison.OrdinalIgnoreCase))
            {
                gaps.Add(new MaterialGapRow
                {
                    ItemName = "Materials",
                    BuyHint = AdvisoryReportText.FormatStubMaterialSummary(topCandidate.EstimatedMaterialCost)
                });
            }

            return gaps;
        }

        public static List<ActionPlanStep> BuildActionPlan(
            ForgeCandidate topCandidate,
            IReadOnlyList<MaterialGapRow> materialGaps,
            bool isStub,
            IReadOnlyList<ActionPlanStep> prepSteps = null)
        {
            var steps = new List<ActionPlanStep>();
            var stepNum = 1;

            if (topCandidate == null)
            {
                steps.Add(new ActionPlanStep
                {
                    Step = 1,
                    Text = "No forge candidate available — run RankForgeCandidates again."
                });
                return steps;
            }

            if (prepSteps != null)
            {
                foreach (var prep in prepSteps)
                {
                    if (stepNum > MaxActionPlanSteps)
                    {
                        break;
                    }

                    steps.Add(new ActionPlanStep
                    {
                        Step = stepNum++,
                        Text = prep.Text
                    });
                }
            }

            foreach (var gap in materialGaps.Where(g => g.Need > g.Have || !string.IsNullOrEmpty(g.BuyHint)))
            {
                if (stepNum > MaxActionPlanSteps)
                {
                    break;
                }

                if (!string.IsNullOrEmpty(gap.BuyHint))
                {
                    if (prepSteps != null
                        && prepSteps.Any(p => string.Equals(p.Text, gap.BuyHint, StringComparison.Ordinal)))
                    {
                        continue;
                    }

                    steps.Add(new ActionPlanStep
                    {
                        Step = stepNum++,
                        Text = gap.BuyHint
                    });
                    continue;
                }

                if (gap.Need > gap.Have
                    && !string.IsNullOrEmpty(gap.BuyTown)
                    && gap.BuyPrice.HasValue)
                {
                    steps.Add(new ActionPlanStep
                    {
                        Step = stepNum++,
                        Text = AdvisoryReportText.FormatBuyMaterialStep(
                            gap.BuyTown,
                            gap.ItemName,
                            gap.BuyPrice.Value,
                            gap.Stock ?? 0,
                            gap.Need,
                            gap.Have)
                    });
                }
            }

            var stubLabel = isStub ? "[stub]" : string.Empty;
            steps.Add(new ActionPlanStep
            {
                Step = stepNum++,
                Text = AdvisoryReportText.FormatCraftStep(
                    topCandidate.DesignName,
                    topCandidate.EstimatedNetProfit,
                    stubLabel)
            });

            if (stepNum <= MaxActionPlanSteps)
            {
                steps.Add(new ActionPlanStep
                {
                    Step = stepNum,
                    Text = AdvisoryReportText.FormatSellCraftedHint(
                        topCandidate.DesignName,
                        topCandidate.EstimatedValue)
                });
            }

            return steps.Take(MaxActionPlanSteps).ToList();
        }

        private static int CountPartyItem(string itemId, string itemName)
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return 0;
            }

            var total = 0;
            for (var i = 0; i < party.ItemRoster.Count; i++)
            {
                var element = party.ItemRoster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null)
                {
                    continue;
                }

                if (MatchesItem(item.StringId, item.Name?.ToString(), itemId, itemName))
                {
                    total += element.Amount;
                }
            }

            return total;
        }

        private static bool MatchesItem(string leftId, string leftName, string rightId, string rightName)
        {
            if (!string.IsNullOrEmpty(leftId)
                && !string.IsNullOrEmpty(rightId)
                && string.Equals(leftId, rightId, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName)
                && !string.IsNullOrEmpty(rightName)
                && string.Equals(leftName, rightName, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            if (!string.IsNullOrEmpty(leftName) && !string.IsNullOrEmpty(rightName))
            {
                return leftName.IndexOf(rightName, StringComparison.OrdinalIgnoreCase) >= 0
                    || rightName.IndexOf(leftName, StringComparison.OrdinalIgnoreCase) >= 0;
            }

            return false;
        }
    }
}
