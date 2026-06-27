using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.HorseMarket
{
    public enum HerdLedgerPosture
    {
        CapacityDeficitBuyPack,
        TradeLoadPrepareCapacity,
        RecruitmentPrepareMounts,
        UpgradeReserveHold,
        HerdPenaltySellExcess,
        ProfitBuyIfUnderpriced,
        ProfitSellNextMarket,
        HoldBalanced,
        CashCrisisLiquidate,
        BlockedUnknownClassification,
        BlockedInsufficientGold
    }

    public sealed class HerdLedgerSnapshot
    {
        public string GeneratedUtc;
        public int PartyGold;
        public int SafeGoldReserve;
        public int SpendableGold;
        public float CurrentCapacity;
        public float CurrentCarriedWeight;
        public float CurrentFreeCapacity;
        public float CurrentBufferPercent;
        public float TargetBufferPercent;
        public float ProjectedTradeLoadWeight;
        public float ProjectedSmithingInputLoadWeight;
        public float ProjectedFoodLoadWeight;
        public float ProjectedLootBufferWeight;
        public int ProjectedRecruitmentNeed;
        public int ProjectedCavalryUpgradeNeed;
        public int PackAnimalCount;
        public int RidingMountCount;
        public int WarMountCount;
        public int NobleMountCount;
        public int LivestockCount;
        public int UnknownHorseCount;
        public bool? HerdPenaltyObserved;
        public string SpeedSummary;
        public string CapacityNeed;
        public string TradeLoadNeed;
        public string RecruitmentMountNeed;
        public string UpgradeReserveNeed;
        public int ExcessSellableCount;
        public int ProfitTradeCandidatesCount;
        public bool UnknownClassificationMutationBlocked;
        public bool PackAnimalReserveProtected;
        public bool WarNobleReserveProtected;
        public bool LocalVerificationRequiredBeforeBuySell;
        public string BuyPosture;
        public string SellPosture;
        public string RecommendedPosture;
        public bool ReadOnly = true;
    }

    public static class HerdLedgerService
    {
        public const string AnalyzeHerdLedgerCommand = "AnalyzeHerdLedger";
        public const string ShowHerdLedgerCommand = "ShowHerdLedger";
        public const string ReportFileName = "BlacksmithGuild_HerdLedger.json";

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);
        public static HerdLedgerSnapshot LastSnapshot { get; private set; }

        public static bool RunAnalyzeNow(string source = AnalyzeHerdLedgerCommand)
        {
            if (Campaign.Current == null || MobileParty.MainParty == null)
            {
                DebugLogger.Test("[TBG HERD] blocked: campaign not ready.", showInGame: false);
                return false;
            }

            var snapshot = BuildSnapshot();
            LastSnapshot = snapshot;
            WriteJson(snapshot);
            InGameNotice.Info(ModDisplay.CompactLine("HerdLedger", $"posture={snapshot.RecommendedPosture} pack={snapshot.PackAnimalCount} buf={snapshot.CurrentBufferPercent:0.#}%"));
            return true;
        }

        public static bool ShowLast()
        {
            if (LastSnapshot == null) return RunAnalyzeNow(ShowHerdLedgerCommand);
            WriteJson(LastSnapshot);
            InGameNotice.Info(ModDisplay.CompactLine("HerdLedger", $"posture={LastSnapshot.RecommendedPosture}"));
            return true;
        }

        public static bool IsMissingOrStale(out string reason)
        {
            if (LastSnapshot == null)
            {
                reason = "herd ledger missing; nextAction=AnalyzeHerdLedger";
                return true;
            }

            if (!DateTime.TryParse(LastSnapshot.GeneratedUtc, out var generated))
            {
                reason = "herd ledger timestamp unreadable; nextAction=AnalyzeHerdLedger";
                return true;
            }

            var ageHours = (DateTime.UtcNow - generated.ToUniversalTime()).TotalHours;
            if (ageHours > DevToolsConfig.HerdLedgerFreshnessHours)
            {
                reason = $"herd ledger stale ageHours={ageHours:0.#}; nextAction=AnalyzeHerdLedger";
                return true;
            }

            reason = null;
            return false;
        }

        public static HerdLedgerSnapshot BuildSnapshot()
        {
            var party = MobileParty.MainParty;
            var gold = 0;
            try { gold = Hero.MainHero?.Gold ?? 0; } catch { }
            var reserve = HorseMarketDoctrine.DefaultSafeGoldReserve;
            var spendable = Math.Max(0, gold - reserve);

            float capacity = 0f, carried = 0f;
            try { capacity = party.InventoryCapacity; } catch { }
            try { carried = party.TotalWeightCarried; } catch { }
            var free = Math.Max(0f, capacity - carried);
            var bufferPct = capacity > 0f ? free / capacity * 100f : 0f;
            var targetBuffer = (float)DevToolsConfig.MapTradeTargetCapacityBufferPercent;

            float speed = 0f;
            bool? herdPenalty = null;
            try { speed = party.Speed; } catch { }
            var troopCount = 0;
            try { troopCount = party.MemberRoster?.TotalManCount ?? 0; } catch { }

            // Count herd by classification
            int packCount = 0, ridingCount = 0, warCount = 0, nobleCount = 0, livestockCount = 0, unknownCount = 0;
            int excessSellable = 0;
            bool unknownPresent = false;
            var roster = party.ItemRoster;
            if (roster != null)
            {
                for (var i = 0; i < roster.Count; i++)
                {
                    var element = roster.GetElementCopyAtIndex(i);
                    var item = element.EquipmentElement.Item;
                    if (item == null || element.Amount <= 0 || !HorseMarketClassifier.IsHorseOrAnimalCandidate(item)) continue;

                    var cls = HorseMarketClassifier.Classify(item);
                    switch (cls.Classification)
                    {
                        case HorseAnimalClassification.PackAnimal: packCount += element.Amount; break;
                        case HorseAnimalClassification.RidingMount: ridingCount += element.Amount; break;
                        case HorseAnimalClassification.WarMount: warCount += element.Amount; break;
                        case HorseAnimalClassification.NobleMount: nobleCount += element.Amount; break;
                        case HorseAnimalClassification.Livestock: livestockCount += element.Amount; excessSellable += element.Amount; break;
                        default: unknownCount += element.Amount; unknownPresent = true; break;
                    }
                }

                // Herd penalty: spare mounts > troops/4
                try
                {
                    var spareMounts = packCount + ridingCount + warCount + nobleCount + livestockCount + unknownCount;
                    herdPenalty = spareMounts > Math.Max(2, troopCount / 4);
                    if (herdPenalty == true) excessSellable += Math.Max(0, livestockCount + ridingCount / 2);
                }
                catch { }
            }

            // Determine posture
            var hasProfitCandidate = HorseMarketAtlasService.LastReport != null && HorseMarketAtlasService.LastReport.TopDestination != null;
            var projectedRecruitmentNeed = ridingCount < Math.Max(1, troopCount / 20) ? Math.Max(1, troopCount / 20) - ridingCount : 0;
            var projectedUpgradeNeed = (warCount + nobleCount) < Math.Max(1, troopCount / 25) ? Math.Max(1, troopCount / 25) - (warCount + nobleCount) : 0;
            var posture = DeterminePosture(bufferPct, targetBuffer, packCount, spendable, unknownPresent, herdPenalty, gold, reserve, hasProfitCandidate);

            var snapshot = new HerdLedgerSnapshot
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                PartyGold = gold,
                SafeGoldReserve = reserve,
                SpendableGold = spendable,
                CurrentCapacity = capacity,
                CurrentCarriedWeight = carried,
                CurrentFreeCapacity = free,
                CurrentBufferPercent = bufferPct,
                TargetBufferPercent = targetBuffer,
                ProjectedTradeLoadWeight = Math.Max(0f, capacity * 0.15f),
                ProjectedSmithingInputLoadWeight = Math.Max(0f, capacity * 0.05f),
                ProjectedFoodLoadWeight = Math.Max(0f, troopCount * 2f),
                ProjectedLootBufferWeight = Math.Max(0f, capacity * 0.10f),
                ProjectedRecruitmentNeed = projectedRecruitmentNeed,
                ProjectedCavalryUpgradeNeed = projectedUpgradeNeed,
                PackAnimalCount = packCount,
                RidingMountCount = ridingCount,
                WarMountCount = warCount,
                NobleMountCount = nobleCount,
                LivestockCount = livestockCount,
                UnknownHorseCount = unknownCount,
                HerdPenaltyObserved = herdPenalty,
                SpeedSummary = $"speed={speed:0.##}",
                CapacityNeed = bufferPct < targetBuffer ? $"deficit buffer={bufferPct:0.#}%<{targetBuffer:0.#}%" : "ok",
                TradeLoadNeed = "not_computed",
                RecruitmentMountNeed = ridingCount < 1 ? "low" : "ok",
                UpgradeReserveNeed = (warCount + nobleCount) < 1 ? "unknown" : "ok",
                ExcessSellableCount = excessSellable,
                ProfitTradeCandidatesCount = hasProfitCandidate ? 1 : 0,
                UnknownClassificationMutationBlocked = unknownPresent,
                PackAnimalReserveProtected = bufferPct < targetBuffer || packCount <= 1,
                WarNobleReserveProtected = (warCount + nobleCount) > 0,
                LocalVerificationRequiredBeforeBuySell = true,
                BuyPosture = posture == HerdLedgerPosture.CapacityDeficitBuyPack ? "buy_pack_animal" : "hold",
                SellPosture = herdPenalty == true ? "sell_excess_livestock_or_surplus_riding; protect_pack_war_noble_reserve" : "hold",
                RecommendedPosture = posture.ToString()
            };

            return snapshot;
        }

        private static HerdLedgerPosture DeterminePosture(float bufferPct, float targetBuffer, int packCount, int spendable, bool unknownPresent, bool? herdPenalty, int gold, int reserve, bool hasProfitCandidate)
        {
            if (unknownPresent)
                return HerdLedgerPosture.BlockedUnknownClassification;
            if (gold <= reserve)
                return HerdLedgerPosture.BlockedInsufficientGold;
            if (bufferPct < targetBuffer && packCount == 0)
                return HerdLedgerPosture.CapacityDeficitBuyPack;
            if (bufferPct < targetBuffer)
                return HerdLedgerPosture.TradeLoadPrepareCapacity;
            if (herdPenalty == true)
                return HerdLedgerPosture.HerdPenaltySellExcess;
            if (hasProfitCandidate && spendable > 0)
                return HerdLedgerPosture.ProfitBuyIfUnderpriced;
            return HerdLedgerPosture.HoldBalanced;
        }

        private static void WriteJson(HerdLedgerSnapshot s)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            Str(sb, "generatedUtc", s.GeneratedUtc, true);
            sb.AppendLine($"  \"readOnly\": true,");
            sb.AppendLine($"  \"partyGold\": {s.PartyGold},");
            sb.AppendLine($"  \"safeGoldReserve\": {s.SafeGoldReserve},");
            sb.AppendLine($"  \"spendableGold\": {s.SpendableGold},");
            sb.AppendLine($"  \"currentCapacity\": {s.CurrentCapacity:0.##},");
            sb.AppendLine($"  \"currentCarriedWeight\": {s.CurrentCarriedWeight:0.##},");
            sb.AppendLine($"  \"currentFreeCapacity\": {s.CurrentFreeCapacity:0.##},");
            sb.AppendLine($"  \"currentBufferPercent\": {s.CurrentBufferPercent:0.##},");
            sb.AppendLine($"  \"targetBufferPercent\": {s.TargetBufferPercent:0.##},");
            sb.AppendLine($"  \"projectedTradeLoadWeight\": {s.ProjectedTradeLoadWeight:0.##},");
            sb.AppendLine($"  \"projectedSmithingInputLoadWeight\": {s.ProjectedSmithingInputLoadWeight:0.##},");
            sb.AppendLine($"  \"projectedFoodLoadWeight\": {s.ProjectedFoodLoadWeight:0.##},");
            sb.AppendLine($"  \"projectedLootBufferWeight\": {s.ProjectedLootBufferWeight:0.##},");
            sb.AppendLine($"  \"projectedRecruitmentNeed\": {s.ProjectedRecruitmentNeed},");
            sb.AppendLine($"  \"projectedCavalryUpgradeNeed\": {s.ProjectedCavalryUpgradeNeed},");
            sb.AppendLine($"  \"packAnimalCount\": {s.PackAnimalCount},");
            sb.AppendLine($"  \"ridingMountCount\": {s.RidingMountCount},");
            sb.AppendLine($"  \"warMountCount\": {s.WarMountCount},");
            sb.AppendLine($"  \"nobleMountCount\": {s.NobleMountCount},");
            sb.AppendLine($"  \"livestockCount\": {s.LivestockCount},");
            sb.AppendLine($"  \"unknownHorseCount\": {s.UnknownHorseCount},");
            sb.AppendLine($"  \"herdPenaltyObserved\": {(s.HerdPenaltyObserved.HasValue ? (s.HerdPenaltyObserved.Value ? "true" : "false") : "null")},");
            Str(sb, "speedSummary", s.SpeedSummary, true);
            Str(sb, "capacityNeed", s.CapacityNeed, true);
            Str(sb, "tradeLoadNeed", s.TradeLoadNeed, true);
            Str(sb, "recruitmentMountNeed", s.RecruitmentMountNeed, true);
            Str(sb, "upgradeReserveNeed", s.UpgradeReserveNeed, true);
            sb.AppendLine($"  \"excessSellableCount\": {s.ExcessSellableCount},");
            sb.AppendLine($"  \"profitTradeCandidatesCount\": {s.ProfitTradeCandidatesCount},");
            sb.AppendLine($"  \"unknownClassificationMutationBlocked\": {(s.UnknownClassificationMutationBlocked ? "true" : "false")},");
            sb.AppendLine($"  \"packAnimalReserveProtected\": {(s.PackAnimalReserveProtected ? "true" : "false")},");
            sb.AppendLine($"  \"warNobleReserveProtected\": {(s.WarNobleReserveProtected ? "true" : "false")},");
            sb.AppendLine($"  \"localVerificationRequiredBeforeBuySell\": {(s.LocalVerificationRequiredBeforeBuySell ? "true" : "false")},");
            Str(sb, "buyPosture", s.BuyPosture, true);
            Str(sb, "sellPosture", s.SellPosture, true);
            Str(sb, "recommendedPosture", s.RecommendedPosture, false);
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
