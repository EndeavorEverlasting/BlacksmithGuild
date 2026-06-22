using System.Collections.Generic;
using System.Text;

namespace BlacksmithGuild.TavernHeroes
{
    public static class TavernHeroJsonWriter
    {
        public static string SerializeIntel(TavernHeroIntelReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"readOnly\": {(report.ReadOnly ? "true" : "false")},");
            builder.AppendLine($"  \"mutationApplied\": {(report.MutationApplied ? "true" : "false")},");
            builder.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");
            AppendSettlement(builder, report.Settlement);
            AppendPlayer(builder, report.Player);
            AppendCompanionState(builder, report.CompanionState);
            builder.AppendLine("  \"candidates\": [");
            AppendCandidates(builder, report.Candidates);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"recommendations\": [");
            AppendRecommendations(builder, report.Recommendations);
            builder.AppendLine("  ],");
            builder.AppendLine("  \"topRecommendation\": ");
            AppendRecommendation(builder, report.TopRecommendation, "  ", false);
            builder.AppendLine(",");
            builder.AppendLine($"  \"blockedReason\": {FormatNullableString(report.BlockedReason)},");
            builder.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\"");
            builder.AppendLine("}");
            return builder.ToString();
        }

        public static string SerializeRecruitment(TavernHeroRecruitmentReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"legitimacyMode\": \"{Escape(report.LegitimacyMode)}\",");
            builder.AppendLine("  \"visibleMode\": {");
            builder.AppendLine($"    \"enabled\": {(report.VisibleModeEnabled ? "true" : "false")},");
            builder.AppendLine($"    \"decisionPauseMs\": {report.DecisionPauseMs}");
            builder.AppendLine("  },");
            builder.AppendLine("  \"selectedCandidate\": ");
            AppendRecommendation(builder, report.SelectedCandidate, "  ", true);
            builder.AppendLine(",");
            AppendState(builder, "before", report.Before);
            builder.AppendLine("  \"actions\": [");
            AppendActions(builder, report.Actions);
            builder.AppendLine("  ],");
            AppendState(builder, "after", report.After);
            builder.AppendLine("  \"mutationAudit\": {");
            builder.AppendLine($"    \"goldMutatedByVanillaRecruitment\": {(report.MutationAudit.GoldMutatedByVanillaRecruitment ? "true" : "false")},");
            builder.AppendLine($"    \"partyChangedByVanillaRecruitment\": {(report.MutationAudit.PartyChangedByVanillaRecruitment ? "true" : "false")},");
            builder.AppendLine($"    \"directHeroInjectionUsed\": {(report.MutationAudit.DirectHeroInjectionUsed ? "true" : "false")},");
            builder.AppendLine($"    \"freeRecruitmentUsed\": {(report.MutationAudit.FreeRecruitmentUsed ? "true" : "false")}");
            builder.AppendLine("  },");
            builder.AppendLine($"  \"blockedReason\": {FormatNullableString(report.BlockedReason)},");
            builder.AppendLine($"  \"verdict\": \"{Escape(report.Verdict)}\"");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendSettlement(StringBuilder builder, TavernHeroSettlementSnapshot settlement)
        {
            builder.AppendLine("  \"settlement\": {");
            builder.AppendLine($"    \"name\": {FormatNullableString(settlement?.Name)},");
            builder.AppendLine($"    \"stringId\": {FormatNullableString(settlement?.StringId)},");
            builder.AppendLine($"    \"type\": {FormatNullableString(settlement?.Type)},");
            builder.AppendLine($"    \"hasTavern\": {FormatNullableBool(settlement?.HasTavern)},");
            builder.AppendLine($"    \"playerInSettlement\": {(settlement?.PlayerInSettlement ?? false ? "true" : "false")},");
            builder.AppendLine($"    \"playerInTavern\": {(settlement?.PlayerInTavern ?? false ? "true" : "false")},");
            builder.AppendLine($"    \"activeMenuId\": {FormatNullableString(settlement?.ActiveMenuId)},");
            builder.AppendLine($"    \"currentLocationId\": {FormatNullableString(settlement?.CurrentLocationId)},");
            builder.AppendLine($"    \"blockedReason\": {FormatNullableString(settlement?.BlockedReason)}");
            builder.AppendLine("  },");
        }

        private static void AppendPlayer(StringBuilder builder, TavernHeroPlayerSnapshot player)
        {
            builder.AppendLine("  \"player\": {");
            builder.AppendLine($"    \"gold\": {player?.Gold ?? 0},");
            builder.AppendLine($"    \"safeGoldReserve\": {player?.SafeGoldReserve ?? 0},");
            builder.AppendLine($"    \"spendableGold\": {player?.SpendableGold ?? 0}");
            builder.AppendLine("  },");
        }

        private static void AppendCompanionState(StringBuilder builder, TavernHeroCompanionStateSnapshot companionState)
        {
            builder.AppendLine("  \"companionState\": {");
            builder.AppendLine($"    \"currentCompanionCount\": {FormatNullableInt(companionState?.CurrentCompanionCount)},");
            builder.AppendLine($"    \"companionLimit\": {FormatNullableInt(companionState?.CompanionLimit)},");
            builder.AppendLine($"    \"remainingSlots\": {FormatNullableInt(companionState?.RemainingSlots)},");
            builder.AppendLine($"    \"limitAvailable\": {(companionState?.LimitAvailable ?? false ? "true" : "false")},");
            builder.AppendLine("    \"partyHeroes\": [");
            AppendStringArray(builder, companionState?.PartyHeroes, "      ");
            builder.AppendLine("    ],");
            builder.AppendLine("    \"smithingCrewCandidates\": [");
            AppendStringArray(builder, companionState?.SmithingCrewCandidates, "      ");
            builder.AppendLine("    ]");
            builder.AppendLine("  },");
        }

        private static void AppendCandidates(StringBuilder builder, List<TavernHeroCandidate> candidates)
        {
            if (candidates == null || candidates.Count == 0)
            {
                return;
            }

            for (var i = 0; i < candidates.Count; i++)
            {
                var candidate = candidates[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"heroId\": {FormatNullableString(candidate.HeroId)},");
                builder.AppendLine($"      \"name\": {FormatNullableString(candidate.Name)},");
                builder.AppendLine($"      \"recruitmentAvailable\": {FormatNullableBool(candidate.RecruitmentAvailable)},");
                builder.AppendLine($"      \"recruitmentCost\": {FormatNullableInt(candidate.RecruitmentCost)},");
                builder.AppendLine($"      \"score\": {candidate.Score:0.##},");
                builder.AppendLine("      \"riskFlags\": [");
                AppendStringArray(builder, candidate.RiskFlags, "        ");
                builder.AppendLine("      ]");
                builder.Append(i < candidates.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendRecommendations(StringBuilder builder, List<TavernHeroRecommendation> recommendations)
        {
            if (recommendations == null || recommendations.Count == 0)
            {
                return;
            }

            for (var i = 0; i < recommendations.Count; i++)
            {
                AppendRecommendation(builder, recommendations[i], "    ", i < recommendations.Count - 1);
                builder.AppendLine();
            }
        }

        private static void AppendRecommendation(
            StringBuilder builder,
            TavernHeroRecommendation recommendation,
            string indent,
            bool trailingComma)
        {
            if (recommendation == null)
            {
                builder.Append($"{indent}null");
                return;
            }

            builder.AppendLine($"{indent}{{");
            builder.AppendLine($"{indent}  \"heroId\": {FormatNullableString(recommendation.HeroId)},");
            builder.AppendLine($"{indent}  \"name\": {FormatNullableString(recommendation.Name)},");
            builder.AppendLine($"{indent}  \"label\": {FormatNullableString(recommendation.Label)},");
            builder.AppendLine($"{indent}  \"score\": {recommendation.Score:0.##},");
            builder.AppendLine($"{indent}  \"recruitmentCost\": {FormatNullableInt(recommendation.RecruitmentCost)},");
            builder.AppendLine($"{indent}  \"reasons\": [");
            AppendStringArray(builder, recommendation.Reasons, indent + "    ");
            builder.Append($"{indent}  ]");
            builder.AppendLine();
            builder.Append(trailingComma ? $"{indent}}}," : $"{indent}}}");
        }

        private static void AppendState(StringBuilder builder, string key, TavernHeroRecruitmentStateSnapshot state)
        {
            builder.AppendLine($"  \"{key}\": {{");
            builder.AppendLine($"    \"gold\": {state?.Gold ?? 0},");
            builder.AppendLine($"    \"goldDelta\": {FormatNullableInt(state?.GoldDelta)},");
            builder.AppendLine($"    \"companionCount\": {FormatNullableInt(state?.CompanionCount)},");
            builder.AppendLine($"    \"candidateInParty\": {FormatNullableBool(state?.CandidateInParty)},");
            builder.AppendLine("    \"partyHeroes\": [");
            AppendStringArray(builder, state?.PartyHeroes, "      ");
            builder.AppendLine("    ]");
            builder.AppendLine("  },");
        }

        private static void AppendActions(StringBuilder builder, List<TavernHeroRecruitmentActionStep> actions)
        {
            if (actions == null || actions.Count == 0)
            {
                return;
            }

            for (var i = 0; i < actions.Count; i++)
            {
                var action = actions[i];
                builder.AppendLine("    {");
                builder.AppendLine($"      \"step\": {FormatNullableString(action.Step)},");
                builder.AppendLine($"      \"mode\": {FormatNullableString(action.Mode)},");
                builder.AppendLine($"      \"result\": {FormatNullableString(action.Result)},");
                builder.AppendLine($"      \"detail\": {FormatNullableString(action.Detail)}");
                builder.Append(i < actions.Count - 1 ? "    }," : "    }");
                builder.AppendLine();
            }
        }

        private static void AppendStringArray(StringBuilder builder, List<string> values, string indent)
        {
            if (values == null || values.Count == 0)
            {
                return;
            }

            for (var i = 0; i < values.Count; i++)
            {
                builder.Append($"{indent}\"{Escape(values[i])}\"");
                if (i < values.Count - 1)
                {
                    builder.AppendLine(",");
                }
                else
                {
                    builder.AppendLine();
                }
            }
        }

        private static string FormatNullableString(string value)
        {
            return string.IsNullOrEmpty(value) ? "null" : $"\"{Escape(value)}\"";
        }

        private static string FormatNullableInt(int? value)
        {
            return value.HasValue ? value.Value.ToString() : "null";
        }

        private static string FormatNullableBool(bool? value)
        {
            return value.HasValue ? (value.Value ? "true" : "false") : "null";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
