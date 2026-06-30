using System;
using System.IO;
using System.Text;
using BlacksmithGuild.CampaignRuntime;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.Food
{
    public static class FoodAdvisoryService
    {
        public const string AnalyzeFoodCommand = "AnalyzeFood";
        public const string ReportFileName = "BlacksmithGuild_FoodAdvisory.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static string LastFailReason { get; private set; }
        public static FoodAdvisoryReport LastReport { get; private set; }

        public static bool RunAnalyzeNow(string source = AnalyzeFoodCommand)
        {
            LastFailReason = null;
            try
            {
                var party = MobileParty.MainParty;
                var food = FoodInventoryAnalyzer.Analyze(party);
                var plan = FoodProcurementPlanner.Plan(food);
                var candidates = FoodProcurementCandidatePlanner.Plan(plan);
                var marketStock = FoodMarketStockScanner.ScanCurrentSettlement(party);
                var marketMatches = FoodMarketCandidateMatcher.Match(candidates, marketStock);
                var request = BuildProposalRequest(source, plan);
                var gate = FoodProcurementExecutionGate.Evaluate(request, plan);

                var report = new FoodAdvisoryReport
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = source,
                    Report = "food_advisory",
                    Verdict = BuildVerdict(plan, marketStock, marketMatches),
                    NextAction = BuildNextAction(plan, marketStock, marketMatches),
                    Food = food,
                    Plan = plan,
                    Candidates = candidates,
                    MarketStock = marketStock,
                    MarketMatches = marketMatches,
                    Gate = gate,
                    MutationAuthorized = false,
                    FoodPurchaseDriverWired = false,
                    BuyFoodSupported = false,
                    Limitation = "Read-only food advisory only. This does not buy food. Food provisioning requires a proven vanilla food purchase driver."
                };

                LastReport = report;
                WriteReport(report);
                WriteNotice(report);
                DebugLogger.Test("[TBG FOOD] " + report.Verdict + ": " + report.NextAction, showInGame: false);
                return true;
            }
            catch (Exception ex)
            {
                LastFailReason = ex.Message;
                DebugLogger.Test("[TBG FOOD] AnalyzeFood failed: " + ex.Message, showInGame: false);
                return false;
            }
        }

        private static CampaignActivityRequest BuildProposalRequest(string source, FoodProcurementPlan plan)
        {
            var request = CampaignActivityFactory.Create(
                Guid.NewGuid().ToString("N"),
                CampaignRuntimePolicy.BranchFoodQuantity,
                CampaignActivityEngine.Food,
                "AnalyzeFoodOnly",
                plan?.Reason ?? "food advisory requested",
                CampaignRuntimePolicy.RankForBranch(CampaignRuntimePolicy.BranchFoodQuantity),
                false,
                null,
                null);
            request.Source = source;
            request.RequiresFreshMarketScan = true;
            request.RequiresVisibleSurface = true;
            request.RequiresInventoryDelta = true;
            request.RequiresGoldDelta = true;
            request.ExpectedProof = "read-only food advisory; no purchase authorized";
            request.BlockedReason = "food purchase driver is not wired; advisory only";
            return request;
        }

        private static string BuildVerdict(
            FoodProcurementPlan plan,
            FoodMarketStockSnapshot marketStock,
            FoodMarketCandidateMatchPlan marketMatches)
        {
            if (plan == null)
            {
                return "unknown";
            }

            if (!plan.ProcurementNeeded)
            {
                return "food_ok";
            }

            if (marketStock == null || !string.Equals(marketStock.Status, "scanned", StringComparison.OrdinalIgnoreCase))
            {
                return "food_need_market_scan";
            }

            if (marketMatches == null || string.Equals(marketMatches.Status, "unknown", StringComparison.OrdinalIgnoreCase))
            {
                return "food_need_candidate_match";
            }

            return "food_procurement_advised";
        }

        private static string BuildNextAction(
            FoodProcurementPlan plan,
            FoodMarketStockSnapshot marketStock,
            FoodMarketCandidateMatchPlan marketMatches)
        {
            if (plan == null)
            {
                return "Re-run AnalyzeFood after campaign map/session is ready.";
            }

            if (!plan.ProcurementNeeded)
            {
                return "No food purchase advised. Continue monitoring runway and diversity.";
            }

            if (marketStock == null || !string.Equals(marketStock.Status, "scanned", StringComparison.OrdinalIgnoreCase))
            {
                return "Move to a settlement market or run market intel before any food action path is considered.";
            }

            if (marketMatches == null || string.Equals(marketMatches.Status, "unknown", StringComparison.OrdinalIgnoreCase))
            {
                return "Review food candidates and market match status; no food purchase driver is wired.";
            }

            return "Manual food purchase may be appropriate. Automation must wait for a proven vanilla food purchase driver.";
        }

        private static void WriteNotice(FoodAdvisoryReport report)
        {
            if (report?.Plan == null)
            {
                InGameNotice.Blocked(ModDisplay.CompactLine("Food", "advisory unavailable"));
                return;
            }

            var line = report.Plan.ProcurementNeeded
                ? "procurement advised; manual only"
                : "food runway ok";
            InGameNotice.Info(ModDisplay.CompactLine("Food", line));
        }

        private static void WriteReport(FoodAdvisoryReport report)
        {
            File.WriteAllText(ReportPath, Serialize(report), Encoding.UTF8);
        }

        private static string Serialize(FoodAdvisoryReport report)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            JsonPair(sb, "generatedUtc", report.GeneratedUtc, comma: true);
            JsonPair(sb, "source", report.Source, comma: true);
            JsonPair(sb, "report", report.Report, comma: true);
            JsonPair(sb, "verdict", report.Verdict, comma: true);
            JsonPair(sb, "nextAction", report.NextAction, comma: true);
            JsonPair(sb, "limitation", report.Limitation, comma: true);
            sb.AppendLine("  \"mutationAuthorized\": false,");
            sb.AppendLine("  \"foodPurchaseDriverWired\": false,");
            sb.AppendLine("  \"buyFoodSupported\": false,");

            sb.AppendLine("  \"food\": {");
            sb.AppendLine("    \"totalFoodItems\": " + (report.Food?.TotalFoodItems ?? 0) + ",");
            sb.AppendLine("    \"uniqueFoodTypes\": " + (report.Food?.UniqueFoodTypes ?? 0) + ",");
            sb.AppendLine("    \"troopCount\": " + (report.Food?.TroopCount ?? 0) + ",");
            sb.AppendLine("    \"estimatedDailyFoodDemand\": " + Number(report.Food?.EstimatedDailyFoodDemand ?? 0f) + ",");
            sb.AppendLine("    \"estimatedDaysRemaining\": " + Number(report.Food?.EstimatedDaysRemaining ?? 0f) + ",");
            sb.AppendLine("    \"estimatedDaysUntilFloor\": " + Number(report.Food?.EstimatedDaysUntilFloor ?? 0f) + ",");
            JsonPair(sb, "quantityStatus", report.Food?.QuantityStatus, comma: true, indent: "    ");
            JsonPair(sb, "diversityStatus", report.Food?.DiversityStatus, comma: true, indent: "    ");
            JsonPair(sb, "forecastStatus", report.Food?.ForecastStatus, comma: true, indent: "    ");
            sb.AppendLine("    \"needsFoodProcurement\": " + Bool(report.Food?.NeedsFoodProcurement ?? false) + ",");
            JsonPair(sb, "detail", report.Food?.Detail, comma: false, indent: "    ");
            sb.AppendLine("  },");

            sb.AppendLine("  \"plan\": {");
            sb.AppendLine("    \"currentFoodItems\": " + (report.Plan?.CurrentFoodItems ?? 0) + ",");
            sb.AppendLine("    \"targetFoodItems\": " + (report.Plan?.TargetFoodItems ?? 0) + ",");
            sb.AppendLine("    \"foodShortfall\": " + (report.Plan?.FoodShortfall ?? 0) + ",");
            sb.AppendLine("    \"currentUniqueFoodTypes\": " + (report.Plan?.CurrentUniqueFoodTypes ?? 0) + ",");
            sb.AppendLine("    \"targetUniqueFoodTypes\": " + (report.Plan?.TargetUniqueFoodTypes ?? 0) + ",");
            sb.AppendLine("    \"uniqueFoodTypeShortfall\": " + (report.Plan?.UniqueFoodTypeShortfall ?? 0) + ",");
            sb.AppendLine("    \"troopCount\": " + (report.Plan?.TroopCount ?? 0) + ",");
            sb.AppendLine("    \"estimatedDailyDemand\": " + Number(report.Plan?.EstimatedDailyDemand ?? 0f) + ",");
            sb.AppendLine("    \"estimatedDaysRemaining\": " + Number(report.Plan?.EstimatedDaysRemaining ?? 0f) + ",");
            sb.AppendLine("    \"estimatedDaysUntilFloor\": " + Number(report.Plan?.EstimatedDaysUntilFloor ?? 0f) + ",");
            JsonPair(sb, "forecastStatus", report.Plan?.ForecastStatus, comma: true, indent: "    ");
            sb.AppendLine("    \"procurementNeeded\": " + Bool(report.Plan?.ProcurementNeeded ?? false) + ",");
            JsonPair(sb, "reason", report.Plan?.Reason, comma: true, indent: "    ");
            JsonPair(sb, "detail", report.Plan?.ToDetailString(), comma: false, indent: "    ");
            sb.AppendLine("  },");

            sb.AppendLine("  \"candidates\": {");
            JsonPair(sb, "status", report.Candidates?.Status, comma: true, indent: "    ");
            sb.AppendLine("    \"candidatePlanningNeeded\": " + Bool(report.Candidates?.CandidatePlanningNeeded ?? false) + ",");
            JsonPair(sb, "reason", report.Candidates?.Reason, comma: true, indent: "    ");
            sb.AppendLine("    \"items\": [");
            if (report.Candidates != null)
            {
                for (var i = 0; i < report.Candidates.Candidates.Count; i++)
                {
                    var candidate = report.Candidates.Candidates[i];
                    sb.AppendLine("      {");
                    JsonPair(sb, "candidateKind", candidate.CandidateKind, comma: true, indent: "        ");
                    JsonPair(sb, "targetItemId", candidate.TargetItemId, comma: true, indent: "        ");
                    JsonPair(sb, "targetItemName", candidate.TargetItemName, comma: true, indent: "        ");
                    sb.AppendLine("        \"desiredQuantity\": " + candidate.DesiredQuantity + ",");
                    JsonPair(sb, "reason", candidate.Reason, comma: false, indent: "        ");
                    sb.Append(i < report.Candidates.Candidates.Count - 1 ? "      }," : "      }");
                    sb.AppendLine();
                }
            }
            sb.AppendLine("    ]");
            sb.AppendLine("  },");

            sb.AppendLine("  \"marketStock\": {");
            JsonPair(sb, "status", report.MarketStock?.Status, comma: true, indent: "    ");
            JsonPair(sb, "reason", report.MarketStock?.Reason, comma: true, indent: "    ");
            JsonPair(sb, "settlementName", report.MarketStock?.SettlementName, comma: true, indent: "    ");
            sb.AppendLine("    \"itemCount\": " + (report.MarketStock?.Items.Count ?? 0) + ",");
            JsonPair(sb, "detail", report.MarketStock?.ToDetailString(), comma: false, indent: "    ");
            sb.AppendLine("  },");

            sb.AppendLine("  \"marketMatches\": {");
            JsonPair(sb, "status", report.MarketMatches?.Status, comma: true, indent: "    ");
            JsonPair(sb, "reason", report.MarketMatches?.Reason, comma: true, indent: "    ");
            sb.AppendLine("    \"matchCount\": " + (report.MarketMatches?.Matches.Count ?? 0) + ",");
            JsonPair(sb, "detail", report.MarketMatches?.ToDetailString(), comma: false, indent: "    ");
            sb.AppendLine("  },");

            sb.AppendLine("  \"executionGate\": {");
            JsonPair(sb, "status", report.Gate?.Status, comma: true, indent: "    ");
            sb.AppendLine("    \"proofRulesSatisfied\": " + Bool(report.Gate?.ProofRulesSatisfied ?? false) + ",");
            sb.AppendLine("    \"readyForVanillaDriver\": " + Bool(report.Gate?.ReadyForVanillaDriver ?? false) + ",");
            JsonPair(sb, "reason", report.Gate?.Reason, comma: true, indent: "    ");
            JsonPair(sb, "detail", report.Gate?.ToDetailString(), comma: false, indent: "    ");
            sb.AppendLine("  }");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void JsonPair(StringBuilder sb, string name, string value, bool comma, string indent = "  ")
        {
            sb.Append(indent);
            sb.Append("\"");
            sb.Append(Escape(name));
            sb.Append("\": \"");
            sb.Append(Escape(value));
            sb.Append("\"");
            if (comma)
            {
                sb.Append(",");
            }
            sb.AppendLine();
        }

        private static string Number(float value)
        {
            return value.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture);
        }

        private static string Bool(bool value)
        {
            return value ? "true" : "false";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
        }
    }

    public sealed class FoodAdvisoryReport
    {
        public string GeneratedUtc { get; set; }
        public string Source { get; set; }
        public string Report { get; set; }
        public string Verdict { get; set; }
        public string NextAction { get; set; }
        public string Limitation { get; set; }
        public bool MutationAuthorized { get; set; }
        public bool FoodPurchaseDriverWired { get; set; }
        public bool BuyFoodSupported { get; set; }
        public FoodInventoryStatus Food { get; set; }
        public FoodProcurementPlan Plan { get; set; }
        public FoodProcurementCandidatePlan Candidates { get; set; }
        public FoodMarketStockSnapshot MarketStock { get; set; }
        public FoodMarketCandidateMatchPlan MarketMatches { get; set; }
        public FoodProcurementExecutionGateResult Gate { get; set; }
    }
}
