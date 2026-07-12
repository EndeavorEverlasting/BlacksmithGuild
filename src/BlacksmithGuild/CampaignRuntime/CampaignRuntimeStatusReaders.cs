using System;
using System.Linq;
using BlacksmithGuild.ClanIntel;
using BlacksmithGuild.Food;
using BlacksmithGuild.Forge;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;
using BlacksmithGuild.TavernHeroes;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.CampaignRuntime
{
    internal static class CampaignRuntimeStatusReaders
    {
        public static string ReadSurface()
        {
            return GameSessionState.ReadinessSurface ?? GameSessionState.Phase.ToString();
        }

        public static string ReadGameHealth()
        {
            if (!GameSessionState.IsCampaignLoaded)
            {
                return "blocked:campaign_not_loaded";
            }

            if (!GameSessionState.IsMainHeroReady)
            {
                return "blocked:main_hero_not_ready";
            }

            if (!GameSessionState.IsCampaignSessionReady)
            {
                return "blocked:campaign_session_not_ready";
            }

            return "ok";
        }

        public static string ReadCurrentTown()
        {
            return GameSessionState.CurrentSettlementName ?? MobileParty.MainParty?.CurrentSettlement?.Name?.ToString();
        }

        public static FoodInventoryStatus ReadFood()
        {
            return FoodInventoryAnalyzer.Analyze(MobileParty.MainParty);
        }

        public static string ReadCapacityStatus()
        {
            var party = MobileParty.MainParty;
            if (party == null)
            {
                return "unknown:party_unavailable";
            }

            try
            {
                var capacity = party.InventoryCapacity;
                var carried = party.TotalWeightCarried;
                var free = Math.Max(0f, capacity - carried);
                var buffer = capacity > 0f ? free / capacity * 100f : 0f;
                var state = buffer < DevToolsConfig.MapTradeTargetCapacityBufferPercent ? "pressure" : "ok";
                return $"{state}:buffer={buffer:0.#}% free={free:0.#} capacity={capacity:0.#}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadHorseStatus()
        {
            var party = MobileParty.MainParty;
            if (party?.ItemRoster == null)
            {
                return "unknown:party_inventory_unavailable";
            }

            try
            {
                var horseLike = 0;
                for (var i = 0; i < party.ItemRoster.Count; i++)
                {
                    var element = party.ItemRoster.GetElementCopyAtIndex(i);
                    var item = element.EquipmentElement.Item;
                    if (item?.HorseComponent == null || element.Amount <= 0)
                    {
                        continue;
                    }

                    horseLike += element.Amount;
                }

                return $"observed:horseLike={horseLike} speed={party.Speed:0.##}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadStaminaStatus()
        {
            try
            {
                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var known = workers.Where(w => w.StaminaKnown).ToList();
                if (known.Count == 0)
                {
                    return $"unknown:workers={workers.Count}";
                }

                var lowest = known.Min(w => w.Stamina);
                return lowest <= 0 ? $"blocked:lowest={lowest}" : $"ok:lowest={lowest}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadMaterialStatus()
        {
            try
            {
                var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
                if (reserve.CharcoalHave < reserve.CharcoalFloor || reserve.HardwoodHave < reserve.HardwoodFloor)
                {
                    return $"short:charcoal={reserve.CharcoalHave}/{reserve.CharcoalFloor} hardwood={reserve.HardwoodHave}/{reserve.HardwoodFloor}";
                }

                return $"ok:charcoal={reserve.CharcoalHave}/{reserve.CharcoalFloor} hardwood={reserve.HardwoodHave}/{reserve.HardwoodFloor}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadTradeStatus()
        {
            if (!MarketIntelligenceService.HasCachedScan)
            {
                return "report_insufficient:no_cached_market_scan";
            }

            if (!MarketIntelligenceService.HasFreshCachedScan)
            {
                return "report_insufficient:stale_market_scan:" + MarketIntelligenceService.CacheStatusDetail;
            }

            var summary = MarketIntelligenceService.Summary;
            return $"cached:nearest={summary.NearestTown ?? "unknown"} spreads={summary.SpreadCount} routes={summary.RouteCount}";
        }

        public static string ReadSmithingStatus(string staminaStatus, string materialStatus)
        {
            if (staminaStatus != null && staminaStatus.StartsWith("blocked", StringComparison.OrdinalIgnoreCase))
            {
                return "blocked:stamina";
            }

            if (materialStatus != null && materialStatus.StartsWith("short", StringComparison.OrdinalIgnoreCase))
            {
                return "blocked:materials";
            }

            return "ready_or_advisory";
        }

        public static string ReadCompanionStatus()
        {
            try
            {
                if (!GameSessionState.IsSettlementInteriorReady && !GameSessionState.IsSettlementMenuReady)
                {
                    return "not_applicable:not_in_town";
                }

                var settlement = TavernHeroScanner.BuildSettlementSnapshot();
                var companions = TavernHeroScanner.BuildCompanionSnapshot(MobileParty.MainParty);

                if (settlement.HasTavern != true)
                {
                    return $"blocked:{settlement.BlockedReason ?? "no_tavern"} slots={companions.RemainingSlots}";
                }

                return $"available:tavern={settlement.Name} slots={companions.RemainingSlots}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadDiplomacyStatus()
        {
            try
            {
                var posture = FactionPowerPostureScanner.Scan();
                return $"{posture.AllegianceMode} power={posture.PowerVerdict} atWar={posture.IsAtWar}";
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadThreatStatus()
        {
            try
            {
                var risk = MapTradeBanditAvoidanceService.EvaluateRiskLevel();
                return string.IsNullOrWhiteSpace(risk) ? "unknown" : risk.ToLowerInvariant();
            }
            catch (Exception ex)
            {
                return $"unknown:{ex.Message}";
            }
        }

        public static string ReadDestinationCandidate()
        {
            try
            {
                // Governor status collection is observe-only and must never trigger full price
                // enumeration. A workflow or explicit market command owns refresh; the next
                // Governor cycle can consume that fresh cache.
                if (!MarketIntelligenceService.HasFreshCachedScan)
                {
                    return null;
                }

                var mission = MapTradeMissionSelector.SelectBestMission();
                if (mission == null || mission.MissionType == MapTradeMissionType.BlockedNoSafeMission)
                {
                    return null;
                }

                return mission.TargetSettlementName;
            }
            catch
            {
                return null;
            }
        }
    }
}
