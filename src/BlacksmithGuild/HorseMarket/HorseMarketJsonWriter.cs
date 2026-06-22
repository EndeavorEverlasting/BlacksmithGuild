using System.Collections.Generic;
using System.Text;

namespace BlacksmithGuild.HorseMarket
{
    public static class HorseMarketJsonWriter
    {
        public static string Serialize(HorseMarketReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"sessionPhase\": \"{Escape(report.SessionPhase)}\",");
            builder.AppendLine($"  \"settlementResolveMethod\": \"{Escape(report.SettlementResolveMethod)}\",");
            builder.AppendLine($"  \"readOnly\": {(report.ReadOnly ? "true" : "false")},");
            builder.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            AppendSettlement(builder, report.Settlement);
            AppendPlayer(builder, report.Player);
            AppendCapacity(builder, report.Capacity);
            AppendHerd(builder, report.Herd);
            builder.AppendLine($"  \"upgradeDemandAvailable\": {(report.UpgradeDemandAvailable ? "true" : "false")},");
            builder.AppendLine("  \"playerAnimals\": [");
            AppendAnimals(builder, report.PlayerAnimals);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"marketAnimals\": [");
            AppendAnimals(builder, report.MarketAnimals);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"recommendations\": [");
            AppendRecommendations(builder, report.Recommendations);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"topRecommendation\": ");
            AppendRecommendation(builder, report.TopRecommendation, trailingComma: false, indent: "  ");
            builder.AppendLine(",");
            builder.AppendLine($"  \"blockedReason\": {(report.BlockedReason == null ? "null" : $"\"{Escape(report.BlockedReason)}\"")},");
            builder.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\"");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendSettlement(StringBuilder builder, HorseMarketSettlementSnapshot settlement)
        {
            builder.AppendLine("  \"settlement\": {");
            builder.AppendLine($"    \"name\": \"{Escape(settlement?.Name)}\",");
            builder.AppendLine($"    \"stringId\": \"{Escape(settlement?.StringId)}\",");
            builder.AppendLine($"    \"type\": \"{Escape(settlement?.Type)}\",");
            builder.AppendLine($"    \"marketAvailable\": {((settlement?.MarketAvailable ?? false) ? "true" : "false")},");
            builder.AppendLine($"    \"blockedReason\": {(string.IsNullOrEmpty(settlement?.BlockedReason) ? "null" : $"\"{Escape(settlement.BlockedReason)}\"")}");
            builder.AppendLine("  },");
        }

        private static void AppendPlayer(StringBuilder builder, HorseMarketPlayerSnapshot player)
        {
            builder.AppendLine("  \"player\": {");
            builder.AppendLine($"    \"gold\": {player?.Gold ?? 0},");
            builder.AppendLine($"    \"safeGoldReserve\": {player?.SafeGoldReserve ?? 0},");
            builder.AppendLine($"    \"spendableGold\": {player?.SpendableGold ?? 0}");
            builder.AppendLine("  },");
        }

        private static void AppendCapacity(StringBuilder builder, HorseMarketCapacitySnapshot capacity)
        {
            builder.AppendLine("  \"capacity\": {");
            builder.AppendLine($"    \"targetBufferPercent\": {capacity?.TargetBufferPercent ?? 0:0.##},");
            builder.AppendLine($"    \"currentCapacity\": {capacity?.CurrentCapacity ?? 0f:0.##},");
            builder.AppendLine($"    \"currentCarriedWeight\": {capacity?.CurrentCarriedWeight ?? 0f:0.##},");
            builder.AppendLine($"    \"currentFreeCapacity\": {capacity?.CurrentFreeCapacity ?? 0f:0.##},");
            builder.AppendLine($"    \"currentBufferPercent\": {capacity?.CurrentBufferPercent ?? 0:0.##},");
            builder.AppendLine($"    \"capacityDeficit\": {capacity?.CapacityDeficit ?? 0f:0.##},");
            builder.AppendLine($"    \"projectedBufferAfterRecommendedBuys\": {capacity?.ProjectedBufferAfterRecommendedBuys ?? 0:0.##}");
            builder.AppendLine("  },");
        }

        private static void AppendHerd(StringBuilder builder, HorseMarketHerdSnapshot herd)
        {
            builder.AppendLine("  \"herd\": {");
            builder.AppendLine($"    \"herdModelAvailable\": {((herd?.HerdModelAvailable ?? false) ? "true" : "false")},");
            builder.AppendLine($"    \"herdPenaltyObserved\": {FormatNullableBool(herd?.HerdPenaltyObserved)},");
            builder.AppendLine($"    \"herdPenaltyText\": {(string.IsNullOrEmpty(herd?.HerdPenaltyText) ? "null" : $"\"{Escape(herd.HerdPenaltyText)}\"")},");
            builder.AppendLine($"    \"footmenOnHorsesBonus\": null,");
            builder.AppendLine($"    \"speedSummary\": {(string.IsNullOrEmpty(herd?.SpeedSummary) ? "null" : $"\"{Escape(herd.SpeedSummary)}\"")}");
            builder.AppendLine("  },");
        }

        private static void AppendAnimals(StringBuilder builder, List<HorseAnimalSnapshot> animals)
        {
            if (animals == null || animals.Count == 0)
            {
                return;
            }

            for (var i = 0; i < animals.Count; i++)
            {
                AppendAnimal(builder, animals[i], trailingComma: i < animals.Count - 1);
            }
        }

        private static void AppendAnimal(StringBuilder builder, HorseAnimalSnapshot animal, bool trailingComma)
        {
            builder.AppendLine("    {");
            builder.AppendLine($"      \"stringId\": \"{Escape(animal.StringId)}\",");
            builder.AppendLine($"      \"name\": \"{Escape(animal.Name)}\",");
            builder.AppendLine($"      \"count\": {animal.Count},");
            builder.AppendLine($"      \"value\": {animal.Value},");
            builder.AppendLine($"      \"weight\": {animal.Weight:0.##},");
            builder.AppendLine($"      \"itemCategory\": \"{Escape(animal.ItemCategory)}\",");
            builder.AppendLine($"      \"itemType\": \"{Escape(animal.ItemType)}\",");
            builder.AppendLine($"      \"tier\": {animal.Tier},");
            builder.AppendLine($"      \"horseComponent\": {(animal.HasHorseComponent ? "true" : "false")},");
            builder.AppendLine($"      \"speed\": {FormatNullableFloat(animal.Speed)},");
            builder.AppendLine($"      \"maneuver\": {FormatNullableFloat(animal.Maneuver)},");
            builder.AppendLine($"      \"chargeDamage\": {FormatNullableFloat(animal.ChargeDamage)},");
            builder.AppendLine($"      \"hitPoints\": {FormatNullableInt(animal.HitPoints)},");
            builder.AppendLine($"      \"isMountable\": {FormatNullableBool(animal.IsMountable)},");
            builder.AppendLine($"      \"classification\": \"{animal.Classification}\",");
            builder.AppendLine($"      \"classificationConfidence\": \"{animal.ClassificationConfidence}\",");
            builder.AppendLine($"      \"classificationReason\": \"{Escape(animal.ClassificationReason)}\",");
            builder.AppendLine($"      \"askPrice\": {FormatNullableInt(animal.AskPrice)},");
            builder.AppendLine($"      \"baseValue\": {animal.BaseValue ?? 0},");
            builder.AppendLine($"      \"qualityScore\": {animal.QualityScore:0.##},");
            builder.AppendLine($"      \"capacityUtilityScore\": {animal.CapacityUtilityScore:0.##},");
            builder.AppendLine($"      \"upgradeUtilityScore\": {animal.UpgradeUtilityScore:0.##},");
            builder.AppendLine($"      \"profitScore\": {animal.ProfitScore:0.##},");
            builder.AppendLine("      \"riskFlags\": [");
            AppendStringArray(builder, animal.RiskFlags, "        ");
            builder.AppendLine("      ]");
            builder.Append(trailingComma ? "    }," : "    }");
            builder.AppendLine();
        }

        private static void AppendRecommendations(StringBuilder builder, List<HorseMarketActionCandidate> recommendations)
        {
            if (recommendations == null || recommendations.Count == 0)
            {
                return;
            }

            for (var i = 0; i < recommendations.Count; i++)
            {
                AppendRecommendation(builder, recommendations[i], trailingComma: i < recommendations.Count - 1, indent: "    ");
            }
        }

        private static void AppendRecommendation(
            StringBuilder builder,
            HorseMarketActionCandidate recommendation,
            bool trailingComma,
            string indent)
        {
            if (recommendation == null)
            {
                builder.Append($"{indent}null");
                if (trailingComma)
                {
                    builder.AppendLine(",");
                }
                else
                {
                    builder.AppendLine();
                }

                return;
            }

            builder.AppendLine($"{indent}{{");
            builder.AppendLine($"{indent}  \"actionType\": \"{recommendation.ActionType}\",");
            builder.AppendLine($"{indent}  \"itemStringId\": \"{Escape(recommendation.ItemStringId)}\",");
            builder.AppendLine($"{indent}  \"itemName\": \"{Escape(recommendation.ItemName)}\",");
            builder.AppendLine($"{indent}  \"classification\": \"{recommendation.Classification}\",");
            builder.AppendLine($"{indent}  \"quantity\": {recommendation.Quantity},");
            builder.AppendLine($"{indent}  \"unitPrice\": {recommendation.UnitPrice},");
            builder.AppendLine($"{indent}  \"totalCost\": {recommendation.TotalCost},");
            builder.AppendLine($"{indent}  \"expectedProfit\": {recommendation.ExpectedProfit},");
            builder.AppendLine($"{indent}  \"capacityDeltaEstimate\": {recommendation.CapacityDeltaEstimate:0.##},");
            builder.AppendLine($"{indent}  \"projectedBufferPercent\": {recommendation.ProjectedBufferPercent:0.##},");
            builder.AppendLine($"{indent}  \"score\": {recommendation.Score:0.##},");
            builder.AppendLine($"{indent}  \"confidence\": \"{recommendation.Confidence}\",");
            builder.AppendLine($"{indent}  \"reasons\": [");
            AppendStringArray(builder, recommendation.Reasons, $"{indent}    ");
            builder.AppendLine($"{indent}  ],");
            builder.AppendLine($"{indent}  \"riskFlags\": [");
            AppendStringArray(builder, recommendation.RiskFlags, $"{indent}    ");
            builder.AppendLine($"{indent}  ]");
            builder.Append(trailingComma ? $"{indent}}}," : $"{indent}}}");
            builder.AppendLine();
        }

        private static void AppendStringArray(StringBuilder builder, List<string> values, string indent)
        {
            if (values == null || values.Count == 0)
            {
                return;
            }

            for (var i = 0; i < values.Count; i++)
            {
                builder.AppendLine($"{indent}\"{Escape(values[i])}\"{(i < values.Count - 1 ? "," : string.Empty)}");
            }
        }

        private static string FormatNullableBool(bool? value)
        {
            if (!value.HasValue)
            {
                return "null";
            }

            return value.Value ? "true" : "false";
        }

        private static string FormatNullableInt(int? value)
        {
            return value.HasValue ? value.Value.ToString() : "null";
        }

        private static string FormatNullableFloat(float? value)
        {
            return value.HasValue ? value.Value.ToString("0.##") : "null";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
