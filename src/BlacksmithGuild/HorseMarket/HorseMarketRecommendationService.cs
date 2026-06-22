using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.HorseMarket
{
    public static class HorseMarketRecommendationService
    {
        public const string AnalyzeHorseMarketCommand = "AnalyzeHorseMarket";
        public const string ShowHorseMarketIntelCommand = "ShowHorseMarketIntel";
        public const string RankHorseMarketActionsCommand = "RankHorseMarketActions";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_HorseMarketIntel.json");

        private static HorseMarketReport _lastReport;

        public static bool HasCachedReport => _lastReport != null;

        public static bool RunAnalyzeNow(string source = AnalyzeHorseMarketCommand)
        {
            if (Campaign.Current == null || Hero.MainHero == null || MobileParty.MainParty == null)
            {
                DebugLogger.Test("[TBG HORSE] analyze blocked: campaign not ready.", showInGame: false);
                return false;
            }

            GameSessionState.Refresh();

            if (!GameSessionState.IsCampaignMapReady && !GameSessionState.IsSettlementInteriorReady)
            {
                var detail = GameSessionState.GetCommandReadyBlockDetail();
                DebugLogger.Test($"[TBG HORSE] analyze blocked: {detail}", showInGame: false);
                InGameNotice.Blocked($"{ModDisplay.Name} — Horse market: {detail}.");
                return false;
            }

            try
            {
                var party = MobileParty.MainParty;
                var context = HorseMarketAnalyzer.BuildContext(party, Hero.MainHero);
                var report = BuildReport(source, context);
                _lastReport = report;
                WriteJsonReport(report);

                var fromInterior = GameSessionState.IsSettlementInteriorReady && !GameSessionState.IsCampaignMapReady;
                WriteStructuredReport(source, report, suppressInGameFeed: fromInterior);

                if (fromInterior)
                {
                    var top = report.TopRecommendation?.ItemName ?? report.Verdict ?? "scan complete";
                    InGameNotice.Info(
                        $"TBG HORSE: {report.Settlement?.Name} — {top}. JSON saved. Exit to map → ShowHorseMarketIntel for full feed.");
                }

                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG HORSE] analyze failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool ShowLastIntel()
        {
            if (_lastReport == null)
            {
                return RunAnalyzeNow(ShowHorseMarketIntelCommand);
            }

            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                var detail = GameSessionState.GetCampaignMapBlockDetail();
                InGameNotice.Blocked(
                    $"{ModDisplay.Name} — Horse market: exit to campaign map for feed replay ({detail}). JSON cached at BlacksmithGuild_HorseMarketIntel.json.");
                return false;
            }

            WriteStructuredReport(ShowHorseMarketIntelCommand, _lastReport);
            return true;
        }

        private static HorseMarketReport BuildReport(string source, HorseMarketAnalysisContext context)
        {
            var recommendations = BuildRecommendations(context);
            var top = recommendations.OrderByDescending(r => r.Score).FirstOrDefault();

            if (top != null && top.CapacityDeltaEstimate > 0f)
            {
                context.Capacity.ProjectedBufferAfterRecommendedBuys = ProjectBufferAfterBuy(
                    context.Capacity,
                    top.CapacityDeltaEstimate);
            }

            var verdict = BuildVerdict(context, recommendations, top);
            var blockedReason = ResolveBlockedReason(context, recommendations);

            return new HorseMarketReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                SessionPhase = context.SessionPhase,
                SettlementResolveMethod = context.SettlementResolveMethod,
                ReadOnly = true,
                MutationApplied = false,
                Settlement = context.Settlement,
                Player = context.Player,
                Capacity = context.Capacity,
                Herd = context.Herd,
                UpgradeDemandAvailable = context.UpgradeDemandAvailable,
                PlayerAnimals = context.PlayerAnimals,
                MarketAnimals = context.MarketAnimals,
                Recommendations = recommendations,
                TopRecommendation = top,
                BlockedReason = blockedReason,
                Verdict = verdict
            };
        }

        private static List<HorseMarketActionCandidate> BuildRecommendations(HorseMarketAnalysisContext context)
        {
            var recommendations = new List<HorseMarketActionCandidate>();

            if (!context.Settlement.MarketAvailable)
            {
                recommendations.Add(BlockedAction(
                    HorseMarketActionType.BlockedNoMarket,
                    context.Settlement.BlockedReason ?? "no market available"));
                return recommendations;
            }

            if (context.MarketAnimals.Count == 0)
            {
                recommendations.Add(BlockedAction(
                    HorseMarketActionType.BlockedNoMarket,
                    "no horse/animal roster in current settlement market"));
            }

            var underBuffer = context.Capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent;
            if (underBuffer)
            {
                recommendations.AddRange(BuildCapacityBuyRecommendations(context));
            }

            recommendations.AddRange(BuildHoldRecommendations(context));
            recommendations.AddRange(BuildProfitRecommendations(context, underBuffer));
            recommendations.AddRange(BuildSellRecommendations(context));

            if (context.Player.SpendableGold <= 0 && underBuffer)
            {
                recommendations.Add(BlockedAction(
                    HorseMarketActionType.BlockedInsufficientGold,
                    $"spendable gold {context.Player.SpendableGold} below reserve"));
            }

            return recommendations
                .OrderByDescending(r => r.Score)
                .ThenBy(r => r.ActionType.ToString())
                .ToList();
        }

        private static IEnumerable<HorseMarketActionCandidate> BuildCapacityBuyRecommendations(
            HorseMarketAnalysisContext context)
        {
            var results = new List<HorseMarketActionCandidate>();
            var remainingDeficit = context.Capacity.CapacityDeficit;
            var spendable = context.Player.SpendableGold;
            var projectedFree = context.Capacity.CurrentFreeCapacity;

            var packCandidates = context.MarketAnimals
                .Where(a => a.Classification == HorseAnimalClassification.PackAnimal && a.AskPrice.HasValue)
                .OrderBy(a => a.AskPrice.Value)
                .ToList();

            foreach (var animal in packCandidates)
            {
                if (remainingDeficit <= 0f || spendable <= 0)
                {
                    break;
                }

                var unitPrice = animal.AskPrice.Value;
                var maxAffordable = spendable / Math.Max(1, unitPrice);
                var maxUseful = (int)Math.Ceiling(remainingDeficit / Math.Max(1f, animal.CapacityUtilityScore));
                var quantity = Math.Min(Math.Min(animal.Count, maxAffordable), Math.Max(1, maxUseful));
                if (quantity <= 0)
                {
                    continue;
                }

                var totalCost = unitPrice * quantity;
                var capacityDelta = (float)(animal.CapacityUtilityScore * quantity);
                var projectedBuffer = ProjectBufferAfterBuy(context.Capacity, capacityDelta);

                var candidate = new HorseMarketActionCandidate
                {
                    ActionType = HorseMarketActionType.BuyCapacity,
                    ItemStringId = animal.StringId,
                    ItemName = animal.Name,
                    Classification = animal.Classification,
                    Quantity = quantity,
                    UnitPrice = unitPrice,
                    TotalCost = totalCost,
                    CapacityDeltaEstimate = capacityDelta,
                    ProjectedBufferPercent = projectedBuffer,
                    Confidence = animal.ClassificationConfidence == ClassificationConfidence.Low
                        ? RecommendationConfidence.Low
                        : RecommendationConfidence.Medium,
                    Reasons =
                    {
                        $"capacity buffer {context.Capacity.CurrentBufferPercent:0}% below target {HorseMarketDoctrine.TargetBufferPercent:0}%",
                        "prioritize cheap pack animals"
                    }
                };

                candidate.Score = ScoreCandidate(candidate, context);
                results.Add(candidate);

                spendable -= totalCost;
                remainingDeficit = Math.Max(0f, remainingDeficit - capacityDelta);
                projectedFree += capacityDelta;
            }

            if (underBufferNoPack(context, packCandidates))
            {
                results.Add(BlockedAction(
                    HorseMarketActionType.BlockedWouldBreakCapacityBuffer,
                    "market has no affordable pack animals to restore 25% buffer"));
            }

            return results;
        }

        private static IEnumerable<HorseMarketActionCandidate> BuildHoldRecommendations(
            HorseMarketAnalysisContext context)
        {
            foreach (var animal in context.PlayerAnimals)
            {
                if (animal.Classification == HorseAnimalClassification.WarMount
                    || animal.Classification == HorseAnimalClassification.NobleMount)
                {
                    yield return new HorseMarketActionCandidate
                    {
                        ActionType = HorseMarketActionType.HoldUpgradeReserve,
                        ItemStringId = animal.StringId,
                        ItemName = animal.Name,
                        Classification = animal.Classification,
                        Quantity = animal.Count,
                        Confidence = RecommendationConfidence.Medium,
                        Reasons =
                        {
                            "preserve for cavalry upgrades",
                            context.UpgradeDemandAvailable
                                ? "upgrade demand observed"
                                : "upgradeDemandAvailable=false — hold war/noble mounts conservatively"
                        },
                        Score = 50 + animal.UpgradeUtilityScore
                    };
                }
                else if (animal.Classification == HorseAnimalClassification.PackAnimal
                         && context.Capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent)
                {
                    yield return new HorseMarketActionCandidate
                    {
                        ActionType = HorseMarketActionType.HoldCapacityReserve,
                        ItemStringId = animal.StringId,
                        ItemName = animal.Name,
                        Classification = animal.Classification,
                        Quantity = animal.Count,
                        Confidence = RecommendationConfidence.High,
                        Reasons = { "pack animals needed while under capacity buffer target" },
                        Score = 40 + animal.CapacityUtilityScore
                    };
                }
            }
        }

        private static IEnumerable<HorseMarketActionCandidate> BuildProfitRecommendations(
            HorseMarketAnalysisContext context,
            bool underBuffer)
        {
            if (underBuffer)
            {
                yield break;
            }

            foreach (var animal in context.MarketAnimals)
            {
                if (!animal.AskPrice.HasValue)
                {
                    yield return new HorseMarketActionCandidate
                    {
                        ActionType = HorseMarketActionType.WatchPrice,
                        ItemStringId = animal.StringId,
                        ItemName = animal.Name,
                        Classification = animal.Classification,
                        Quantity = 1,
                        Confidence = RecommendationConfidence.Low,
                        Reasons = { "price unknown — need market history" },
                        Score = 5
                    };
                    continue;
                }

                if (animal.ProfitScore <= 0)
                {
                    continue;
                }

                var unitPrice = animal.AskPrice.Value;
                if (unitPrice > context.Player.SpendableGold)
                {
                    continue;
                }

                var candidate = new HorseMarketActionCandidate
                {
                    ActionType = HorseMarketActionType.BuyProfit,
                    ItemStringId = animal.StringId,
                    ItemName = animal.Name,
                    Classification = animal.Classification,
                    Quantity = 1,
                    UnitPrice = unitPrice,
                    TotalCost = unitPrice,
                    ExpectedProfit = (int)Math.Round(animal.ProfitScore),
                    ProjectedBufferPercent = context.Capacity.CurrentBufferPercent,
                    Confidence = RecommendationConfidence.Medium,
                    Reasons = { "price below base value threshold with capacity buffer satisfied" },
                    Score = ScoreCandidate(new HorseMarketActionCandidate
                    {
                        ActionType = HorseMarketActionType.BuyProfit,
                        Classification = animal.Classification,
                        ExpectedProfit = (int)Math.Round(animal.ProfitScore),
                        TotalCost = unitPrice,
                        ProjectedBufferPercent = context.Capacity.CurrentBufferPercent
                    }, context) + animal.ProfitScore
                };

                yield return candidate;
            }
        }

        private static IEnumerable<HorseMarketActionCandidate> BuildSellRecommendations(
            HorseMarketAnalysisContext context)
        {
            var herdPressure = context.Herd.HerdPenaltyObserved == true;
            foreach (var animal in context.PlayerAnimals)
            {
                if (animal.Classification == HorseAnimalClassification.WarMount
                    || animal.Classification == HorseAnimalClassification.NobleMount)
                {
                    continue;
                }

                if (context.Capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent
                    && animal.Classification == HorseAnimalClassification.PackAnimal)
                {
                    continue;
                }

                var excess = herdPressure
                             || animal.Classification == HorseAnimalClassification.Livestock
                             || animal.Classification == HorseAnimalClassification.RidingMount;

                if (!excess)
                {
                    continue;
                }

                yield return new HorseMarketActionCandidate
                {
                    ActionType = HorseMarketActionType.SellExcess,
                    ItemStringId = animal.StringId,
                    ItemName = animal.Name,
                    Classification = animal.Classification,
                    Quantity = animal.Count,
                    UnitPrice = animal.Value,
                    Confidence = herdPressure ? RecommendationConfidence.Medium : RecommendationConfidence.Low,
                    Reasons =
                    {
                        herdPressure ? "herd pressure observed" : "inventory excess with buffer satisfied",
                        "advisory only — verify offered price in trade UI"
                    },
                    Score = herdPressure ? 25 : 10
                };
            }
        }

        private static HorseMarketActionCandidate BlockedAction(HorseMarketActionType actionType, string reason)
        {
            return new HorseMarketActionCandidate
            {
                ActionType = actionType,
                ItemName = actionType.ToString(),
                Confidence = RecommendationConfidence.High,
                Reasons = { reason },
                Score = HorseMarketDoctrine.HardPenaltyBreaksBuffer
            };
        }

        private static double ScoreCandidate(HorseMarketActionCandidate candidate, HorseMarketAnalysisContext context)
        {
            var score = 0.0;

            if (candidate.ActionType == HorseMarketActionType.BuyCapacity)
            {
                score += Math.Max(0, HorseMarketDoctrine.TargetBufferPercent - context.Capacity.CurrentBufferPercent) * 4;
                score += candidate.CapacityDeltaEstimate;
            }

            score += candidate.ExpectedProfit * 0.5;
            score += candidate.ProjectedBufferPercent * 0.2;

            if (candidate.ProjectedBufferPercent < HorseMarketDoctrine.TargetBufferPercent
                && candidate.ActionType == HorseMarketActionType.BuyProfit)
            {
                score += HorseMarketDoctrine.HardPenaltyBreaksBuffer;
            }

            if (candidate.TotalCost > context.Player.SpendableGold)
            {
                score += HorseMarketDoctrine.HardPenaltyInsufficientGold;
            }

            if (candidate.Classification == HorseAnimalClassification.UnknownHorse
                && (candidate.ActionType == HorseMarketActionType.BuyCapacity
                    || candidate.ActionType == HorseMarketActionType.BuyProfit
                    || candidate.ActionType == HorseMarketActionType.SellExcess))
            {
                score += HorseMarketDoctrine.PenaltyUnknownClassification;
            }

            if ((candidate.ActionType == HorseMarketActionType.SellExcess)
                && (candidate.Classification == HorseAnimalClassification.WarMount
                    || candidate.Classification == HorseAnimalClassification.NobleMount))
            {
                score += HorseMarketDoctrine.PenaltyWarNobleSellWithoutProof;
            }

            if (context.Herd.HerdPenaltyObserved == true)
            {
                score -= 5;
            }

            candidate.Score = score;
            return score;
        }

        private static double ProjectBufferAfterBuy(HorseMarketCapacitySnapshot capacity, float capacityDelta)
        {
            if (capacity.CurrentCapacity <= 0f)
            {
                return capacity.CurrentBufferPercent;
            }

            var projectedFree = capacity.CurrentFreeCapacity + capacityDelta;
            return Math.Max(0, projectedFree / capacity.CurrentCapacity * 100.0);
        }

        private static bool underBufferNoPack(HorseMarketAnalysisContext context, List<HorseAnimalSnapshot> packCandidates)
        {
            return context.Capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent
                   && packCandidates.Count == 0;
        }

        private static string BuildVerdict(
            HorseMarketAnalysisContext context,
            List<HorseMarketActionCandidate> recommendations,
            HorseMarketActionCandidate top)
        {
            if (!context.Settlement.MarketAvailable)
            {
                return "blocked — no settlement market";
            }

            if (context.Capacity.CurrentBufferPercent >= HorseMarketDoctrine.TargetBufferPercent)
            {
                return top != null
                    ? $"capacity buffer satisfied ({context.Capacity.CurrentBufferPercent:0}%) — {top.ActionType}"
                    : $"capacity buffer satisfied ({context.Capacity.CurrentBufferPercent:0}%)";
            }

            return top != null
                ? $"under buffer ({context.Capacity.CurrentBufferPercent:0}%) — top action {top.ActionType}"
                : $"under buffer ({context.Capacity.CurrentBufferPercent:0}%) — no safe buy found";
        }

        private static string ResolveBlockedReason(
            HorseMarketAnalysisContext context,
            List<HorseMarketActionCandidate> recommendations)
        {
            var blocked = recommendations.FirstOrDefault(r =>
                r.ActionType == HorseMarketActionType.BlockedNoMarket
                || r.ActionType == HorseMarketActionType.BlockedInsufficientGold
                || r.ActionType == HorseMarketActionType.BlockedWouldBreakCapacityBuffer);

            return blocked?.Reasons.FirstOrDefault();
        }

        private static void WriteJsonReport(HorseMarketReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, HorseMarketJsonWriter.Serialize(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG HORSE] Failed to write JSON: {ex.Message}", showInGame: false);
            }
        }

        private static void WriteStructuredReport(string source, HorseMarketReport report, bool suppressInGameFeed = false)
        {
            var formatter = ReportFormatter.BeginReport("HORSE MARKET", source, "horse-market");
            formatter.Section("Context");
            formatter.Line("sessionPhase", report.SessionPhase ?? string.Empty);
            formatter.Line("settlementResolve", report.SettlementResolveMethod ?? string.Empty);
            formatter.Line("settlement", report.Settlement?.Name ?? "unknown");
            formatter.Line("market", report.Settlement?.MarketAvailable == true ? "available" : "blocked");
            formatter.Line(
                "capacity buffer",
                $"{report.Capacity.CurrentBufferPercent:0}% / target {report.Capacity.TargetBufferPercent:0}%");
            formatter.Line("spendable gold", report.Player.SpendableGold.ToString());
            formatter.Line("verdict", report.Verdict ?? string.Empty);

            EmitSummaryLines(formatter, report);

            formatter.EndReport(
                emitInGame: !suppressInGameFeed && IsPrimaryHorseCommand(source),
                emitToFile: true);
        }

        private static void EmitSummaryLines(ReportFormatter formatter, HorseMarketReport report)
        {
            var bufferLine =
                $"TBG HORSE: capacity buffer {report.Capacity.CurrentBufferPercent:0}% / target {report.Capacity.TargetBufferPercent:0}%";
            if (report.Capacity.CurrentBufferPercent < HorseMarketDoctrine.TargetBufferPercent)
            {
                formatter.SummaryLine(bufferLine + " — buy pack animals first.", ReportLineStyle.CapacityWarn);
            }
            else
            {
                formatter.SummaryLine(bufferLine + ".", ReportLineStyle.Info);
            }

            foreach (var recommendation in report.Recommendations.Take(6))
            {
                formatter.SummaryLine(FormatRecommendationLine(recommendation, report), StyleFor(recommendation));
            }

            if (!string.IsNullOrEmpty(report.BlockedReason))
            {
                formatter.SummaryLine($"TBG HORSE BLOCKED: {report.BlockedReason}", ReportLineStyle.Blocked);
            }
        }

        private static string FormatRecommendationLine(
            HorseMarketActionCandidate recommendation,
            HorseMarketReport report)
        {
            var tag = $"[{recommendation.Classification.ToString().ToUpperInvariant()}]";
            switch (recommendation.ActionType)
            {
                case HorseMarketActionType.BuyCapacity:
                case HorseMarketActionType.BuyProfit:
                    return
                        $"TBG HORSE BUY: {tag} {recommendation.ItemName} x{recommendation.Quantity} @ {recommendation.UnitPrice} each | buffer {report.Capacity.CurrentBufferPercent:0}% -> {recommendation.ProjectedBufferPercent:0}%";
                case HorseMarketActionType.SellExcess:
                    return
                        $"TBG HORSE SELL: [EXCESS] {recommendation.ItemName} x{recommendation.Quantity} only if price >= {Math.Max(recommendation.UnitPrice, 1)}";
                case HorseMarketActionType.HoldUpgradeReserve:
                case HorseMarketActionType.HoldCapacityReserve:
                    return $"TBG HORSE HOLD: {tag} {recommendation.ItemName} x{recommendation.Quantity} | {recommendation.Reasons.FirstOrDefault()}";
                case HorseMarketActionType.WatchPrice:
                    return $"TBG HORSE WATCH: {tag} {recommendation.ItemName} | {recommendation.Reasons.FirstOrDefault()}";
                case HorseMarketActionType.BlockedNoMarket:
                case HorseMarketActionType.BlockedInsufficientGold:
                case HorseMarketActionType.BlockedWouldBreakCapacityBuffer:
                case HorseMarketActionType.BlockedUnknownClassification:
                    return $"TBG HORSE BLOCKED: {recommendation.Reasons.FirstOrDefault()}";
                default:
                    return $"TBG HORSE: {recommendation.ActionType} {recommendation.ItemName}";
            }
        }

        private static ReportLineStyle StyleFor(HorseMarketActionCandidate recommendation)
        {
            switch (recommendation.ActionType)
            {
                case HorseMarketActionType.BuyCapacity:
                case HorseMarketActionType.BuyProfit:
                    return ReportLineStyle.Buy;
                case HorseMarketActionType.SellExcess:
                    return ReportLineStyle.Sell;
                case HorseMarketActionType.HoldUpgradeReserve:
                case HorseMarketActionType.HoldCapacityReserve:
                    return recommendation.Classification == HorseAnimalClassification.NobleMount
                        ? ReportLineStyle.Premium
                        : ReportLineStyle.Hold;
                case HorseMarketActionType.WatchPrice:
                    return ReportLineStyle.Watch;
                case HorseMarketActionType.BlockedNoMarket:
                case HorseMarketActionType.BlockedInsufficientGold:
                case HorseMarketActionType.BlockedWouldBreakCapacityBuffer:
                case HorseMarketActionType.BlockedUnknownClassification:
                    return ReportLineStyle.Blocked;
                default:
                    return ReportLineStyle.Info;
            }
        }

        private static bool IsPrimaryHorseCommand(string source)
        {
            return string.Equals(source, AnalyzeHorseMarketCommand, StringComparison.Ordinal)
                   || string.Equals(source, ShowHorseMarketIntelCommand, StringComparison.Ordinal)
                   || string.Equals(source, RankHorseMarketActionsCommand, StringComparison.Ordinal);
        }
    }
}
