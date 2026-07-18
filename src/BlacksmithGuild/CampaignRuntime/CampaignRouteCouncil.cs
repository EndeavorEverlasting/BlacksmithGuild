using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.HorseMarket;
using TaleWorlds.Library;

namespace BlacksmithGuild.CampaignRuntime
{
    // ── Route vote model ───────────────────────────────────────────────────────
    public sealed class CampaignRouteVote
    {
        public string VoterEngine;
        public string ProposedActivity;
        public string ProposedDestination;
        public double Weight;
        public string Reason;
        public string Confidence;
        public bool IsBlockingVeto;
        public List<string> RiskFlags = new List<string>();
    }

    public static class CampaignRouteVoteKind
    {
        public const string Food = "food";
        public const string Trade = "trade";
        public const string Horse = "horse";
        public const string Safety = "safety";
        public const string Observe = "observe";
        public const string Recovery = "recovery";
    }

    public sealed class CampaignRouteCouncilDecision
    {
        public string GeneratedUtc;
        public string Source;
        public string Surface;
        public string GameHealth;
        public bool ReadOnly = true;
        public List<CampaignRouteVote> Votes = new List<CampaignRouteVote>();
        public string WinningEngine;
        public string RecommendedActivity;
        public string RecommendedDestination;
        public double WinningWeight;
        public string RunnerUpEngine;
        public string TieBreakReason;
        public string BlockedReason;
        public string NextAction;
        public string Verdict;
    }

    // ── Route council ──────────────────────────────────────────────────────────
    public static class CampaignRouteCouncil
    {
        public const string ConveneRouteCouncilCommand = "ConveneRouteCouncil";
        public const string ShowRouteCouncilCommand = "ShowRouteCouncil";
        public const string ReportFileName = "BlacksmithGuild_RouteCouncil.json";

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);
        public static CampaignRouteCouncilDecision LastResult { get; internal set; }

        public static bool Convene(string source = ConveneRouteCouncilCommand)
        {
            var result = Build(source);
            LastResult = result;
            WriteJson(result);
            InGameNotice.Info(ModDisplay.CompactLine("RouteCouncil",
                $"win={result.WinningEngine ?? "none"} dest={result.RecommendedDestination ?? "none"} verdict={result.Verdict}"));
            return true;
        }

        public static bool ShowLast()
        {
            if (LastResult == null) return Convene(ShowRouteCouncilCommand);
            WriteJson(LastResult);
            InGameNotice.Info(ModDisplay.CompactLine("RouteCouncil",
                $"win={LastResult.WinningEngine ?? "none"} verdict={LastResult.Verdict}"));
            return true;
        }

        public static void Record(CampaignRouteCouncilDecision decision)
        {
            if (decision == null) return;
            LastResult = decision;
            WriteJson(decision);
        }

        public static CampaignRouteCouncilDecision Build(string source)
        {
            var decision = CampaignRuntimeGovernor.LastDecision;
            if (decision == null)
            {
                var result = new CampaignRouteCouncilDecision
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = source,
                    Surface = CampaignRuntimeStatusReaders.ReadSurface(),
                    GameHealth = CampaignRuntimeStatusReaders.ReadGameHealth(),
                    BlockedReason = "no_governor_decision",
                    NextAction = "RunCampaignGovernorCycleNow",
                    Verdict = "blocked_no_decision"
                };
                return result;
            }

            return BuildFromDecision(decision, source);
        }

        public static CampaignRouteCouncilDecision BuildFromDecision(CampaignRuntimeDecision decision, string source)
        {
            var result = new CampaignRouteCouncilDecision
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
            };

            if (decision == null)
            {
                result.BlockedReason = "no_governor_decision";
                result.NextAction = "RunCampaignGovernorCycleNow";
                result.Verdict = "blocked_no_decision";
                return result;
            }

            result.Surface = decision.Surface;
            result.GameHealth = decision.GameHealth;
            GatherVotes(result, decision);
            Tally(result);
            return result;
        }

        private static void GatherVotes(CampaignRouteCouncilDecision result, CampaignRuntimeDecision d)
        {
            if (!string.Equals(d.GameHealth, "ok", StringComparison.OrdinalIgnoreCase))
            {
                AddVote(result, CampaignRouteVoteKind.Safety, "fail_safe_hold", null, 1000, d.GameHealth, "high", true);
                return;
            }

            var threat = d.ThreatStatus ?? "unknown";
            if (StartsWithAny(threat, "high", "critical", "unknown") || Contains(threat, "unsafe"))
                AddVote(result, CampaignRouteVoteKind.Safety, "avoid_threat_hold", null, 1000, $"safety veto: threat={threat}", "high", true);

            if (StartsWithAny(d.FoodStatus, "critical", "low") || StartsWithAny(d.FoodForecastStatus, "critical", "low"))
            {
                // food critical override: food outranks horse and trade unless safety veto blocks travel.
                AddVote(result, CampaignRouteVoteKind.Food, "resupply_food", d.DestinationCandidate ?? d.CurrentTown, 950,
                    $"food critical override: food={d.FoodStatus} forecast={d.FoodForecastStatus}", "high", false);
                return;
            }

            if (HorseMarketAtlasService.IsMissingOrStale(out var atlasReason))
                AddVote(result, CampaignRouteVoteKind.Horse, "RefreshHorseAtlas", null, 85, atlasReason, "medium", false);
            if (HerdLedgerService.IsMissingOrStale(out var ledgerReason))
                AddVote(result, CampaignRouteVoteKind.Horse, "AnalyzeHerdLedger", null, 84, ledgerReason, "medium", false);

            var herdPosture = HerdLedgerService.LastSnapshot?.RecommendedPosture;
            var atlasTop = HorseMarketAtlasService.LastReport?.TopDestination;
            var ledger = HerdLedgerService.LastSnapshot;
            var capacityPressure = StartsWithAny(d.CapacityStatus, "pressure")
                || string.Equals(herdPosture, "CapacityDeficitBuyPack", StringComparison.Ordinal)
                || string.Equals(herdPosture, "TradeLoadPrepareCapacity", StringComparison.Ordinal);
            if (capacityPressure)
                AddVote(result, CampaignRouteVoteKind.Horse, "buy_pack_capacity", atlasTop ?? d.DestinationCandidate, 80,
                    $"horse capacity vs trade interaction: capacity={d.CapacityStatus} herd={herdPosture ?? "n/a"}", "medium", false);

            if (string.Equals(herdPosture, "RecruitmentPrepareMounts", StringComparison.Ordinal))
                AddVote(result, CampaignRouteVoteKind.Horse, "prepare_recruitment_mounts", atlasTop ?? d.DestinationCandidate, 75,
                    $"horse recruitment need: projectedRecruitmentNeed={ledger?.ProjectedRecruitmentNeed ?? 0}", "medium", false);

            if (string.Equals(herdPosture, "UpgradeReserveHold", StringComparison.Ordinal))
                AddVote(result, CampaignRouteVoteKind.Horse, "hold_or_find_war_mount_reserve", atlasTop ?? d.DestinationCandidate, 74,
                    $"horse upgrade reserve need: projectedCavalryUpgradeNeed={ledger?.ProjectedCavalryUpgradeNeed ?? 0}", "medium", false);

            if (!capacityPressure && StartsWithAny(d.TradeStatus, "report_insufficient"))
                AddVote(result, CampaignRouteVoteKind.Recovery, "map_scan", null, 40, $"trade={d.TradeStatus}", "low", false);
            else if (!capacityPressure && (Contains(d.TradeStatus, "profitable") || Contains(d.TradeStatus, "opportunity") || CachedTradeRoutesAvailable(d.TradeStatus)))
                AddVote(result, CampaignRouteVoteKind.Trade, "profitable_trade", d.DestinationCandidate, 60, $"trade={d.TradeStatus}", "medium", false);

            if (Contains(d.HorseStatus, "deficit") || Contains(d.HorseStatus, "low"))
                AddVote(result, CampaignRouteVoteKind.Horse, "improve_party_speed", atlasTop ?? d.DestinationCandidate, 50,
                    $"horse={d.HorseStatus}", "low", false);

            if (!capacityPressure && ledger?.ProfitPostureBasesCovered == true && string.Equals(herdPosture, "ProfitBuyIfUnderpriced", StringComparison.Ordinal) && atlasTop != null)
                AddVote(result, CampaignRouteVoteKind.Horse, "horse_profit", atlasTop, 70,
                    $"horse profit only when bases covered: food/safety/capacity/recruitment/upgrade/gold clear and atlas candidate exists profitCandidates={ledger.ProfitTradeCandidatesCount}", "medium", false);

            AddVote(result, CampaignRouteVoteKind.Observe, "observe_only", null, 10, "no dominant route signal", "low", false);
        }

        private static void Tally(CampaignRouteCouncilDecision result)
        {
            var veto = result.Votes.FirstOrDefault(v => v.IsBlockingVeto);
            if (veto != null)
            {
                result.WinningEngine = veto.VoterEngine;
                result.RecommendedActivity = veto.ProposedActivity;
                result.RecommendedDestination = veto.ProposedDestination;
                result.WinningWeight = veto.Weight;
                result.BlockedReason = veto.Reason;
                result.NextAction = "HoldOrFindSafeRoute: " + veto.Reason;
                result.Verdict = "vetoed";
                return;
            }

            var ranked = result.Votes.OrderByDescending(v => v.Weight).ToList();
            var winner = ranked.FirstOrDefault();
            var runnerUp = ranked.Count > 1 ? ranked[1] : null;
            if (winner == null)
            {
                result.Verdict = "no_votes";
                return;
            }

            result.WinningEngine = winner.VoterEngine;
            result.RecommendedActivity = winner.ProposedActivity;
            result.RecommendedDestination = winner.ProposedDestination;
            result.WinningWeight = winner.Weight;
            result.RunnerUpEngine = runnerUp?.VoterEngine;
            result.NextAction = BuildNextAction(winner);
            if (runnerUp != null && Math.Abs(runnerUp.Weight - winner.Weight) < 0.001)
                result.TieBreakReason = "weight_tie_resolved_by_gather_order";

            result.Verdict = winner.VoterEngine == "observe"
                ? "observe_only"
                : (winner.ProposedDestination != null ? "destination_recommended" : "activity_recommended");
        }

        private static string BuildNextAction(CampaignRouteVote winner)
        {
            if (winner == null) return null;
            if (string.Equals(winner.ProposedActivity, "RefreshHorseAtlas", StringComparison.OrdinalIgnoreCase)) return "ScanHorseAtlas";
            if (string.Equals(winner.ProposedActivity, "AnalyzeHerdLedger", StringComparison.OrdinalIgnoreCase)) return "AnalyzeHerdLedger";
            if (string.Equals(winner.ProposedActivity, "buy_pack_capacity", StringComparison.OrdinalIgnoreCase)) return "LocalVerifyHorseMarketBeforeBuySell at " + (winner.ProposedDestination ?? "current settlement");
            if (string.Equals(winner.ProposedActivity, "horse_profit", StringComparison.OrdinalIgnoreCase)) return "LocalVerifyHorseMarketBeforeBuySell at " + (winner.ProposedDestination ?? "candidate settlement");
            if (string.Equals(winner.ProposedActivity, "prepare_recruitment_mounts", StringComparison.OrdinalIgnoreCase)) return "ScanHorseAtlas then local verify recruitment mount at " + (winner.ProposedDestination ?? "candidate settlement");
            if (string.Equals(winner.ProposedActivity, "hold_or_find_war_mount_reserve", StringComparison.OrdinalIgnoreCase)) return "Protect war/noble reserve; scan atlas for upgrade mount at " + (winner.ProposedDestination ?? "candidate settlement");
            if (string.Equals(winner.ProposedActivity, "profitable_trade", StringComparison.OrdinalIgnoreCase)) return "EvaluateOrExecuteTradeRoute when bounded execution is enabled";
            if (string.Equals(winner.ProposedActivity, "map_scan", StringComparison.OrdinalIgnoreCase)) return "RefreshMarketScan";
            if (string.Equals(winner.ProposedActivity, "resupply_food", StringComparison.OrdinalIgnoreCase)) return "AcquireFoodBeforeRunwayBreach";
            return winner.ProposedActivity;
        }

        private static void AddVote(CampaignRouteCouncilDecision r, string engine, string activity, string destination,
            double weight, string reason, string confidence, bool veto)
        {
            r.Votes.Add(new CampaignRouteVote
            {
                VoterEngine = engine,
                ProposedActivity = activity,
                ProposedDestination = destination,
                Weight = weight,
                Reason = reason,
                Confidence = confidence,
                IsBlockingVeto = veto
            });
        }

        private static bool StartsWithAny(string value, params string[] prefixes)
        {
            if (string.IsNullOrEmpty(value)) return false;
            foreach (var p in prefixes)
                if (value.StartsWith(p, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }

        private static bool Contains(string value, string needle) =>
            !string.IsNullOrEmpty(value) && value.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0;

        private static bool CachedTradeRoutesAvailable(string status) =>
            !string.IsNullOrEmpty(status)
            && status.StartsWith("cached", StringComparison.OrdinalIgnoreCase)
            && status.IndexOf("routes=0", StringComparison.OrdinalIgnoreCase) < 0;

        private static void WriteJson(CampaignRouteCouncilDecision r)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            Str(sb, "generatedUtc", r.GeneratedUtc, true);
            Str(sb, "source", r.Source, true);
            Str(sb, "surface", r.Surface, true);
            Str(sb, "gameHealth", r.GameHealth, true);
            sb.AppendLine("  \"readOnly\": true,");
            Str(sb, "winningEngine", r.WinningEngine, true);
            Str(sb, "recommendedActivity", r.RecommendedActivity, true);
            Str(sb, "recommendedDestination", r.RecommendedDestination, true);
            sb.AppendLine($"  \"winningWeight\": {r.WinningWeight:0.##},");
            Str(sb, "runnerUpEngine", r.RunnerUpEngine, true);
            Str(sb, "tieBreakReason", r.TieBreakReason, true);
            Str(sb, "blockedReason", r.BlockedReason, true);
            Str(sb, "nextAction", r.NextAction, true);
            Str(sb, "verdict", r.Verdict, true);
            sb.AppendLine("  \"votes\": [");
            for (var i = 0; i < r.Votes.Count; i++)
            {
                var v = r.Votes[i];
                sb.Append("    { ");
                sb.Append($"\"engine\": \"{Esc(v.VoterEngine)}\", ");
                sb.Append($"\"activity\": \"{Esc(v.ProposedActivity)}\", ");
                sb.Append(v.ProposedDestination == null ? "\"destination\": null, " : $"\"destination\": \"{Esc(v.ProposedDestination)}\", ");
                sb.Append($"\"weight\": {v.Weight:0.##}, ");
                sb.Append($"\"confidence\": \"{Esc(v.Confidence)}\", ");
                sb.Append($"\"blockingVeto\": {(v.IsBlockingVeto ? "true" : "false")}, ");
                sb.Append($"\"reason\": \"{Esc(v.Reason)}\" }}");
                sb.AppendLine(i < r.Votes.Count - 1 ? "," : string.Empty);
            }
            sb.AppendLine("  ]");
            sb.AppendLine("}");
            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static void Str(StringBuilder sb, string key, string value, bool comma)
        {
            sb.Append("  \"").Append(key).Append("\": ");
            sb.Append(value == null ? "null" : "\"" + Esc(value) + "\"");
            if (comma) sb.Append(",");
            sb.AppendLine();
        }

        private static string Esc(string v) => (v ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
