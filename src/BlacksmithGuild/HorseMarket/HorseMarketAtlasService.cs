using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.HorseMarket
{
    public enum HorseMarketAtlasMode
    {
        LayOfLandScan,
        DiscoveredOnly,
        Hybrid
    }

    public sealed class HorseMarketAtlasEntry
    {
        public string SettlementId;
        public string SettlementName;
        public string SettlementType;
        public float Distance;
        public bool IsCurrentSettlement;
        public string DiscoveryState;      // "lay_of_land" | "discovered" | "observed"
        public string LastObservedUtc;
        public string ObservationSource;
        public string FreshnessState;
        public bool LocalVerificationRequiredBeforeBuySell;
        public bool MarketAvailable;
        public int PackAnimalCount;
        public int RidingMountCount;
        public int WarMountCount;
        public int NobleMountCount;
        public int LivestockCount;
        public int UnknownHorseCount;
        public string CheapestPackAnimalId;
        public string CheapestPackAnimalName;
        public int? CheapestPackAnimalPrice;
        public int? CheapestPackAnimalStock;
        public string BestRecruitmentMountId;
        public string BestRecruitmentMountName;
        public string BestWarMountId;
        public string BestWarMountName;
        public int? BestWarMountPrice;
        public int? BestWarMountStock;
        public string BestProfitBuyId;
        public string BestProfitBuyName;
        public int? BestProfitBuyPrice;
        public int? BestProfitExpectedMargin;
        public int? BestProfitBuyStock;
        public List<string> RiskFlags = new List<string>();
    }

    public sealed class HorseMarketAtlasReport
    {
        public string GeneratedUtc;
        public string Source;
        public string Mode;
        public bool ReadOnly = true;
        public string CurrentSettlement;
        public float PartyCapacity;
        public float PartyBufferPercent;
        public int PartyGold;
        public int SafeGoldReserve;
        public float UnderCapacityBuffer;
        public int AtlasFreshnessHours;
        public List<HorseMarketAtlasEntry> Entries = new List<HorseMarketAtlasEntry>();
        public List<string> DestinationCandidates = new List<string>();
        public string TopDestination;
        public bool LocalVerificationRequiredBeforeBuySell = true;
        public string BlockedReason;
        public string Verdict;
    }

    public static class HorseMarketAtlasService
    {
        public const string ScanHorseAtlasCommand = "ScanHorseAtlas";
        public const string ShowHorseAtlasCommand = "ShowHorseAtlas";
        public const string RankHorseDestinationsCommand = "RankHorseDestinations";
        public const string ReportFileName = "BlacksmithGuild_HorseAtlas.json";

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);
        public static HorseMarketAtlasReport LastReport { get; private set; }

        public static bool RunScanNow(string source = ScanHorseAtlasCommand)
        {
            if (Campaign.Current == null || MobileParty.MainParty == null)
            {
                DebugLogger.Test("[TBG ATLAS] scan blocked: campaign not ready.", showInGame: false);
                return false;
            }

            var party = MobileParty.MainParty;
            var capacity = TrySafeFloat(() => party.InventoryCapacity);
            var carried = TrySafeFloat(() => party.TotalWeightCarried);
            var free = Math.Max(0f, capacity - carried);
            var bufferPct = capacity > 0f ? free / capacity * 100f : 0f;
            var gold = TrySafeInt(() => Hero.MainHero?.Gold ?? 0);
            var currentSettlementId = GameSessionState.CurrentSettlementStringId;
            var mode = DevToolsConfig.HorseMarketAtlasMode;

            var report = new HorseMarketAtlasReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Mode = mode.ToString(),
                CurrentSettlement = GameSessionState.CurrentSettlementName,
                PartyCapacity = capacity,
                PartyBufferPercent = bufferPct,
                PartyGold = gold,
                SafeGoldReserve = HorseMarketDoctrine.DefaultSafeGoldReserve,
                UnderCapacityBuffer = Math.Max(0f, (float)(capacity * DevToolsConfig.MapTradeTargetCapacityBufferPercent / 100.0) - free),
                AtlasFreshnessHours = DevToolsConfig.HorseMarketAtlasFreshnessHours,
            };

            ScanSettlements(party, report, mode, currentSettlementId);
            RankDestinations(report, party, bufferPct, gold);

            LastReport = report;
            WriteJson(report);
            InGameNotice.Info(ModDisplay.CompactLine("HorseAtlas", $"entries={report.Entries.Count} top={report.TopDestination ?? "none"}"));
            return true;
        }

        public static bool ShowLastReport()
        {
            if (LastReport == null) return RunScanNow(ShowHorseAtlasCommand);
            WriteJson(LastReport);
            InGameNotice.Info(ModDisplay.CompactLine("HorseAtlas", $"top={LastReport.TopDestination ?? "none"} verdict={LastReport.Verdict}"));
            return true;
        }

        public static bool IsMissingOrStale(out string reason)
        {
            if (LastReport == null)
            {
                reason = "horse atlas missing; nextAction=RefreshHorseAtlas";
                return true;
            }

            if (!DateTime.TryParse(LastReport.GeneratedUtc, out var generated))
            {
                reason = "horse atlas timestamp unreadable; nextAction=RefreshHorseAtlas";
                return true;
            }

            var ageHours = (DateTime.UtcNow - generated.ToUniversalTime()).TotalHours;
            if (ageHours > DevToolsConfig.HorseMarketAtlasFreshnessHours)
            {
                reason = $"horse atlas stale ageHours={ageHours:0.#}; nextAction=RefreshHorseAtlas";
                return true;
            }

            reason = null;
            return false;
        }

        private static void ScanSettlements(MobileParty party, HorseMarketAtlasReport report, HorseMarketAtlasMode mode, string currentSettlementId)
        {
            List<Settlement> settlements;
            try { settlements = new List<Settlement>(Settlement.All); }
            catch { return; }

            foreach (var settlement in settlements)
            {
                if (settlement == null) continue;
                if (!settlement.IsTown && !settlement.IsVillage && !settlement.IsCastle) continue;
                if (settlement.ItemRoster == null) continue;

                var distance = CampaignMapMovementHelper.Distance(party, settlement);
                if (mode == HorseMarketAtlasMode.DiscoveredOnly)
                {
                    // DiscoveredOnly: only current or explicitly observed settlements
                    var isCurrent = string.Equals(settlement.StringId, currentSettlementId, StringComparison.Ordinal);
                    if (!isCurrent) continue;
                }

                var entry = BuildEntry(settlement, party, distance, currentSettlementId);
                report.Entries.Add(entry);
            }
        }

        private static HorseMarketAtlasEntry BuildEntry(Settlement settlement, MobileParty party, float distance, string currentSettlementId)
        {
            var isCurrent = string.Equals(settlement.StringId, currentSettlementId, StringComparison.Ordinal);
            var entry = new HorseMarketAtlasEntry
            {
                SettlementId = settlement.StringId,
                SettlementName = settlement.Name?.ToString() ?? settlement.StringId,
                SettlementType = settlement.IsTown ? "Town" : settlement.IsVillage ? "Village" : "Castle",
                Distance = distance,
                IsCurrentSettlement = isCurrent,
                DiscoveryState = "lay_of_land",
                LastObservedUtc = DateTime.UtcNow.ToString("o"),
                ObservationSource = "LayOfLandScan",
                FreshnessState = "fresh_lay_of_land",
                LocalVerificationRequiredBeforeBuySell = true,
                MarketAvailable = settlement.ItemRoster != null,
            };

            var roster = settlement.ItemRoster;
            if (roster == null) return entry;

            var town = settlement.Town;
            int? cheapestPackPrice = null;
            string cheapestPackId = null, cheapestPackName = null;
            int cheapestPackStock = 0;
            int? bestRecruitmentPrice = null;
            int? bestWarPrice = null;
            int bestWarStock = 0;
            int? bestProfitPrice = null;
            int? bestProfitMargin = null;
            string bestProfitId = null, bestProfitName = null;
            int bestProfitStock = 0;

            for (var i = 0; i < roster.Count; i++)
            {
                var element = roster.GetElementCopyAtIndex(i);
                var item = element.EquipmentElement.Item;
                if (item == null || element.Amount <= 0 || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item)) continue;

                var cls = HorseMarketClassifier.Classify(item);
                var price = TryGetMarketPrice(town, item, party);
                switch (cls.Classification)
                {
                    case HorseAnimalClassification.PackAnimal: entry.PackAnimalCount += element.Amount; break;
                    case HorseAnimalClassification.RidingMount: entry.RidingMountCount += element.Amount; break;
                    case HorseAnimalClassification.WarMount: entry.WarMountCount += element.Amount; break;
                    case HorseAnimalClassification.NobleMount: entry.NobleMountCount += element.Amount; break;
                    case HorseAnimalClassification.Livestock: entry.LivestockCount += element.Amount; break;
                    default: entry.UnknownHorseCount += element.Amount; break;
                }

                if (cls.Classification == HorseAnimalClassification.PackAnimal)
                {
                    if (price.HasValue && (!cheapestPackPrice.HasValue || price.Value < cheapestPackPrice.Value))
                    {
                        cheapestPackPrice = price;
                        cheapestPackId = item.StringId;
                        cheapestPackName = item.Name?.ToString();
                        cheapestPackStock = element.Amount;
                    }
                }

                if (cls.Classification == HorseAnimalClassification.WarMount
                    || cls.Classification == HorseAnimalClassification.NobleMount)
                {
                    if (entry.BestWarMountId == null || (price.HasValue && (!bestWarPrice.HasValue || price.Value < bestWarPrice.Value)))
                    {
                        entry.BestWarMountId = item.StringId;
                        entry.BestWarMountName = item.Name?.ToString();
                        bestWarPrice = price;
                        bestWarStock = element.Amount;
                    }
                }

                if (cls.Classification == HorseAnimalClassification.RidingMount
                    && (entry.BestRecruitmentMountId == null || (price.HasValue && (!bestRecruitmentPrice.HasValue || price.Value < bestRecruitmentPrice.Value))))
                {
                    entry.BestRecruitmentMountId = item.StringId;
                    entry.BestRecruitmentMountName = item.Name?.ToString();
                    bestRecruitmentPrice = price;
                }

                var expectedMargin = EstimateProfitMargin(item, price);
                if (expectedMargin.HasValue && expectedMargin.Value > 0
                    && (!bestProfitMargin.HasValue || expectedMargin.Value > bestProfitMargin.Value))
                {
                    bestProfitMargin = expectedMargin;
                    bestProfitPrice = price;
                    bestProfitId = item.StringId;
                    bestProfitName = item.Name?.ToString();
                    bestProfitStock = element.Amount;
                }

                if (cls.Classification == HorseAnimalClassification.WarMount && entry.BestWarMountId == null)
                    entry.BestWarMountId = item.StringId;
                if (cls.Classification == HorseAnimalClassification.RidingMount && entry.BestRecruitmentMountId == null)
                    entry.BestRecruitmentMountId = item.StringId;
            }

            entry.CheapestPackAnimalId = cheapestPackId;
            entry.CheapestPackAnimalName = cheapestPackName;
            entry.CheapestPackAnimalPrice = cheapestPackPrice;
            entry.CheapestPackAnimalStock = cheapestPackStock;
            entry.BestWarMountPrice = bestWarPrice;
            entry.BestWarMountStock = bestWarStock;
            entry.BestProfitBuyId = bestProfitId;
            entry.BestProfitBuyName = bestProfitName;
            entry.BestProfitBuyPrice = bestProfitPrice;
            entry.BestProfitExpectedMargin = bestProfitMargin;
            entry.BestProfitBuyStock = bestProfitStock;

            var totalAnimals = entry.PackAnimalCount + entry.RidingMountCount + entry.WarMountCount + entry.NobleMountCount + entry.LivestockCount + entry.UnknownHorseCount;
            if (totalAnimals == 0) entry.RiskFlags.Add("no_horse_animals_in_roster");
            if (entry.UnknownHorseCount > 0) entry.RiskFlags.Add("unknown_classification_present");

            return entry;
        }

        private static void RankDestinations(HorseMarketAtlasReport report, MobileParty party, float bufferPct, int gold)
        {
            var underBuffer = bufferPct < DevToolsConfig.MapTradeTargetCapacityBufferPercent;
            var spendable = Math.Max(0, gold - HorseMarketDoctrine.DefaultSafeGoldReserve);

            var candidates = report.Entries
                .Where(e => !e.IsCurrentSettlement && e.MarketAvailable && e.Distance < DevToolsConfig.MapTradeMaxRouteDistance)
                .Where(e => e.PackAnimalCount > 0 || e.BestRecruitmentMountId != null || e.BestWarMountId != null || e.BestProfitBuyId != null)
                .OrderByDescending(e => ScoreDestination(e, underBuffer, spendable))
                .ThenBy(e => e.Distance)
                .Take(DevToolsConfig.HorseMarketAtlasMaxDestinationCount)
                .ToList();

            report.DestinationCandidates = candidates.Select(e => e.SettlementName).ToList();
            report.TopDestination = candidates.FirstOrDefault()?.SettlementName;

            if (!report.Entries.Any())
                report.BlockedReason = "no settlements with market roster found";
            else if (!candidates.Any())
                report.BlockedReason = "no horse destination candidates within range";

            report.Verdict = report.TopDestination != null ? "destination_ranked" : "no_destination";
        }

        private static void WriteJson(HorseMarketAtlasReport r)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            Str(sb, "generatedUtc", r.GeneratedUtc, true);
            Str(sb, "source", r.Source, true);
            Str(sb, "mode", r.Mode, true);
            sb.AppendLine($"  \"readOnly\": true,");
            Str(sb, "currentSettlement", r.CurrentSettlement, true);
            sb.AppendLine($"  \"partyCapacity\": {r.PartyCapacity:0.##},");
            sb.AppendLine($"  \"partyBufferPercent\": {r.PartyBufferPercent:0.##},");
            sb.AppendLine($"  \"partyGold\": {r.PartyGold},");
            sb.AppendLine($"  \"safeGoldReserve\": {r.SafeGoldReserve},");
            sb.AppendLine($"  \"underCapacityBuffer\": {r.UnderCapacityBuffer:0.##},");
            sb.AppendLine($"  \"atlasFreshnessHours\": {r.AtlasFreshnessHours},");
            sb.AppendLine($"  \"entryCount\": {r.Entries.Count},");
            sb.AppendLine($"  \"destinationCandidates\": [{string.Join(", ", r.DestinationCandidates.Select(d => "\"" + Esc(d) + "\""))}],");
            Str(sb, "topDestination", r.TopDestination, true);
            sb.AppendLine($"  \"localVerificationRequiredBeforeBuySell\": {(r.LocalVerificationRequiredBeforeBuySell ? "true" : "false")},");
            Str(sb, "blockedReason", r.BlockedReason, true);
            Str(sb, "verdict", r.Verdict, true);
            sb.AppendLine("  \"entries\": [");
            for (var i = 0; i < r.Entries.Count; i++)
            {
                var e = r.Entries[i];
                sb.AppendLine("    {");
                Str(sb, "settlementId", e.SettlementId, true, "      ");
                Str(sb, "settlementName", e.SettlementName, true, "      ");
                Str(sb, "settlementType", e.SettlementType, true, "      ");
                sb.AppendLine($"      \"distance\": {e.Distance:0.##},");
                Str(sb, "freshnessState", e.FreshnessState, true, "      ");
                sb.AppendLine($"      \"packAnimalStock\": {e.PackAnimalCount},");
                sb.AppendLine($"      \"ridingMountStock\": {e.RidingMountCount},");
                sb.AppendLine($"      \"warMountStock\": {e.WarMountCount},");
                sb.AppendLine($"      \"nobleMountStock\": {e.NobleMountCount},");
                sb.AppendLine($"      \"unknownAnimalStock\": {e.UnknownHorseCount},");
                Str(sb, "cheapestPackAnimalId", e.CheapestPackAnimalId, true, "      ");
                Str(sb, "cheapestPackAnimalName", e.CheapestPackAnimalName, true, "      ");
                sb.AppendLine($"      \"cheapestPackAnimalPrice\": {(e.CheapestPackAnimalPrice.HasValue ? e.CheapestPackAnimalPrice.Value.ToString() : "null")},");
                sb.AppendLine($"      \"cheapestPackAnimalStock\": {e.CheapestPackAnimalStock},");
                Str(sb, "bestRecruitmentMountId", e.BestRecruitmentMountId, true, "      ");
                Str(sb, "bestRecruitmentMountName", e.BestRecruitmentMountName, true, "      ");
                Str(sb, "bestWarMountId", e.BestWarMountId, true, "      ");
                Str(sb, "bestWarMountName", e.BestWarMountName, true, "      ");
                sb.AppendLine($"      \"bestWarMountPrice\": {(e.BestWarMountPrice.HasValue ? e.BestWarMountPrice.Value.ToString() : "null")},");
                sb.AppendLine($"      \"bestWarMountStock\": {(e.BestWarMountStock.HasValue ? e.BestWarMountStock.Value.ToString() : "null")},");
                Str(sb, "bestProfitBuyId", e.BestProfitBuyId, true, "      ");
                Str(sb, "bestProfitBuyName", e.BestProfitBuyName, true, "      ");
                sb.AppendLine($"      \"bestProfitBuyPrice\": {(e.BestProfitBuyPrice.HasValue ? e.BestProfitBuyPrice.Value.ToString() : "null")},");
                sb.AppendLine($"      \"bestProfitExpectedMargin\": {(e.BestProfitExpectedMargin.HasValue ? e.BestProfitExpectedMargin.Value.ToString() : "null")},");
                sb.AppendLine($"      \"bestProfitBuyStock\": {(e.BestProfitBuyStock.HasValue ? e.BestProfitBuyStock.Value.ToString() : "null")},");
                sb.AppendLine($"      \"localVerificationRequiredBeforeBuySell\": {(e.LocalVerificationRequiredBeforeBuySell ? "true" : "false")}");
                sb.AppendLine(i < r.Entries.Count - 1 ? "    }," : "    }");
            }
            sb.AppendLine("  ]");
            sb.AppendLine("}");
            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static float TrySafeFloat(Func<float> fn) { try { return fn(); } catch { return 0f; } }
        private static int TrySafeInt(Func<int> fn) { try { return fn(); } catch { return 0; } }
        private static int? TryGetMarketPrice(TaleWorlds.CampaignSystem.Settlements.Town town, TaleWorlds.Core.ItemObject item, MobileParty party)
        {
            try { if (town != null && item != null) { var p = town.GetItemPrice(item, party, false); if (p > 0) return p; } } catch { }
            return null;
        }
        private static int? EstimateProfitMargin(TaleWorlds.Core.ItemObject item, int? askPrice)
        {
            if (item == null || !askPrice.HasValue) return null;
            try
            {
                var baseValue = item.Value;
                var threshold = (int)Math.Round(baseValue * HorseMarketDoctrine.ProfitVsBaseValueThreshold);
                return threshold > askPrice.Value ? threshold - askPrice.Value : 0;
            }
            catch { return null; }
        }
        private static double ScoreDestination(HorseMarketAtlasEntry e, bool underBuffer, int spendable)
        {
            var score = 0.0;
            if (underBuffer && e.PackAnimalCount > 0 && (!e.CheapestPackAnimalPrice.HasValue || e.CheapestPackAnimalPrice.Value <= spendable)) score += 1000;
            if (e.BestRecruitmentMountId != null) score += 120;
            if (e.BestWarMountId != null) score += 100;
            if (e.BestProfitExpectedMargin.HasValue && e.BestProfitExpectedMargin.Value > 0) score += 80 + e.BestProfitExpectedMargin.Value;
            score += Math.Max(0, 160 - e.Distance) * 0.1;
            return score;
        }
        private static void Str(StringBuilder sb, string key, string value, bool comma, string indent = "  ")
        {
            sb.Append(indent).Append("\"").Append(key).Append("\": ");
            sb.Append(value == null ? "null" : "\"" + Esc(value) + "\"");
            if (comma) sb.Append(",");
            sb.AppendLine();
        }
        private static string Esc(string v) => (v ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
