using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class SmithingRestPlanService
    {
        public const string RunSmithingRestPlanNowCommand = "RunSmithingRestPlanNow";
        public const string ReportFileName = "BlacksmithGuild_SmithingRestPlan.json";

        private const double RestStaminaFraction = 0.5;

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static bool RunRestPlanNow(string source = RunSmithingRestPlanNowCommand)
        {
            try
            {
                GameSessionState.Refresh();
                if (!GameSessionState.IsCampaignMapReady)
                {
                    DebugLogger.Test(
                        $"[TBG REST] {RunSmithingRestPlanNowCommand} blocked: {GameSessionState.GetCampaignMapBlockDetail()}",
                        showInGame: false);
                    return false;
                }

                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
                var location = BuildLocationContext();
                var stamina = BuildStaminaSummary(workers);
                var recommendation = BuildRecommendation(workers, reserve, location, stamina);

                WriteJsonReport(source, location, stamina, reserve, recommendation);

                InGameNotice.Info(
                    ModDisplay.CompactLine(
                        "Smithing Rest Plan",
                        $"{recommendation.Action}: {recommendation.Reason}"));

                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG REST] {RunSmithingRestPlanNowCommand} failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static RestLocationContext BuildLocationContext()
        {
            var party = MobileParty.MainParty;
            var settlement = party?.CurrentSettlement;
            var settlementName = settlement?.Name?.ToString();
            var isInSettlement = settlement != null;
            var canRestHere = settlement != null && (settlement.IsTown || settlement.IsCastle || settlement.IsVillage);

            return new RestLocationContext
            {
                Settlement = settlementName,
                IsInTownOrTownMenu = isInSettlement || GameSessionState.IsMapMenuOpen,
                CanRestHere = canRestHere
            };
        }

        private static RestStaminaSummary BuildStaminaSummary(IReadOnlyList<SmithingWorkerProfile> workers)
        {
            var heroes = new List<RestHeroStamina>();
            foreach (var worker in workers)
            {
                heroes.Add(new RestHeroStamina
                {
                    Name = worker.Name,
                    CraftingSkill = worker.CraftingSkill,
                    Stamina = worker.StaminaKnown ? worker.Stamina : 0,
                    MaxStamina = worker.StaminaKnown ? worker.MaxStamina : 0,
                    StaminaKnown = worker.StaminaKnown
                });
            }

            var known = heroes.Where(hero => hero.StaminaKnown).ToList();
            return new RestStaminaSummary
            {
                Heroes = heroes,
                Lowest = known.Count > 0 ? known.Min(hero => hero.Stamina) : 0,
                Highest = known.Count > 0 ? known.Max(hero => hero.Stamina) : 0,
                NeedsRest = known.Any(NeedsRest)
            };
        }

        private static RestRecommendation BuildRecommendation(
            IReadOnlyList<SmithingWorkerProfile> workers,
            SmithingReserveHealth reserve,
            RestLocationContext location,
            RestStaminaSummary stamina)
        {
            if (workers == null || workers.Count == 0)
            {
                return new RestRecommendation
                {
                    Action = "NoSmithingHeroesFound",
                    Reason = "No party heroes available for smithing crew analysis.",
                    NextStep = "Ensure companions or main hero are in the party."
                };
            }

            var charcoalNeed = Math.Max(0, SmithingReservePolicy.CharcoalFloor - reserve.CharcoalHave);
            if (charcoalNeed > 0 && reserve.HardwoodHave < SmithingReservePolicy.HardwoodFloor)
            {
                return new RestRecommendation
                {
                    Action = "BuyMaterialsFirst",
                    Reason = $"Charcoal need {charcoalNeed} but hardwood={reserve.HardwoodHave} below floor.",
                    NextStep = "Enter town, buy hardwood, then refine or run Stage C safe action."
                };
            }

            if (!stamina.NeedsRest)
            {
                return new RestRecommendation
                {
                    Action = "NoRestNeeded",
                    Reason = "All known smithing heroes are above rest threshold.",
                    NextStep = "Proceed with refine or craft from smithing crew advisory."
                };
            }

            if (location.CanRestHere)
            {
                return new RestRecommendation
                {
                    Action = "RestInTown",
                    Reason = $"Low stamina detected (lowest={stamina.Lowest}); party is in {location.Settlement}.",
                    NextStep = "Wait in settlement to recover crafting stamina (manual — no time mutation in Stage D read-only)."
                };
            }

            return new RestRecommendation
            {
                Action = "MoveToTown",
                Reason = $"Low stamina detected (lowest={stamina.Lowest}); not currently in a rest-capable settlement.",
                NextStep = "Ride to nearest friendly town and wait to recover stamina."
            };
        }

        private static bool NeedsRest(RestHeroStamina hero)
        {
            if (!hero.StaminaKnown || hero.MaxStamina <= 0)
            {
                return false;
            }

            return hero.Stamina < hero.MaxStamina * RestStaminaFraction;
        }

        private static void WriteJsonReport(
            string source,
            RestLocationContext location,
            RestStaminaSummary stamina,
            SmithingReserveHealth reserve,
            RestRecommendation recommendation)
        {
            var charcoalNeed = Math.Max(0, SmithingReservePolicy.CharcoalFloor - reserve.CharcoalHave);
            var materialBlocked = charcoalNeed > 0 && reserve.HardwoodHave < SmithingReservePolicy.HardwoodFloor;

            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine("  \"executedMutation\": false,");
            sb.AppendLine("  \"location\": {");
            sb.AppendLine($"    \"settlement\": {(string.IsNullOrEmpty(location.Settlement) ? "null" : $"\"{Escape(location.Settlement)}\"")},");
            sb.AppendLine($"    \"isInTownOrTownMenu\": {location.IsInTownOrTownMenu.ToString().ToLowerInvariant()},");
            sb.AppendLine($"    \"canRestHere\": {location.CanRestHere.ToString().ToLowerInvariant()}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"stamina\": {");
            sb.AppendLine("    \"heroes\": [");
            for (var i = 0; i < stamina.Heroes.Count; i++)
            {
                var hero = stamina.Heroes[i];
                sb.AppendLine("      {");
                sb.AppendLine($"        \"name\": \"{Escape(hero.Name)}\",");
                sb.AppendLine($"        \"craftingSkill\": {hero.CraftingSkill},");
                sb.AppendLine($"        \"stamina\": {hero.Stamina},");
                sb.AppendLine($"        \"maxStamina\": {hero.MaxStamina},");
                sb.AppendLine($"        \"staminaKnown\": {hero.StaminaKnown.ToString().ToLowerInvariant()}");
                sb.Append(i < stamina.Heroes.Count - 1 ? "      }," : "      }");
                sb.AppendLine();
            }

            sb.AppendLine("    ],");
            sb.AppendLine($"    \"lowest\": {stamina.Lowest},");
            sb.AppendLine($"    \"highest\": {stamina.Highest},");
            sb.AppendLine($"    \"needsRest\": {stamina.NeedsRest.ToString().ToLowerInvariant()}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"materials\": {");
            sb.AppendLine($"    \"hardwood\": {reserve.HardwoodHave},");
            sb.AppendLine($"    \"charcoal\": {reserve.CharcoalHave},");
            sb.AppendLine($"    \"charcoalNeed\": {charcoalNeed},");
            sb.AppendLine($"    \"materialBlocked\": {materialBlocked.ToString().ToLowerInvariant()}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"recommendation\": {");
            sb.AppendLine($"    \"action\": \"{Escape(recommendation.Action)}\",");
            sb.AppendLine($"    \"reason\": \"{Escape(recommendation.Reason)}\",");
            sb.AppendLine($"    \"nextStep\": \"{Escape(recommendation.NextStep)}\"");
            sb.AppendLine("  }");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private sealed class RestLocationContext
        {
            public string Settlement { get; set; }
            public bool IsInTownOrTownMenu { get; set; }
            public bool CanRestHere { get; set; }
        }

        private sealed class RestHeroStamina
        {
            public string Name { get; set; }
            public int CraftingSkill { get; set; }
            public int Stamina { get; set; }
            public int MaxStamina { get; set; }
            public bool StaminaKnown { get; set; }
        }

        private sealed class RestStaminaSummary
        {
            public List<RestHeroStamina> Heroes { get; set; } = new List<RestHeroStamina>();
            public int Lowest { get; set; }
            public int Highest { get; set; }
            public bool NeedsRest { get; set; }
        }

        private sealed class RestRecommendation
        {
            public string Action { get; set; }
            public string Reason { get; set; }
            public string NextStep { get; set; }
        }
    }
}
