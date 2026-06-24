using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistiveTravelSettlementIdentity
    {
        public static void ApplyCurrent(AssistiveTravelExecutionResult result, Settlement current)
        {
            if (result == null)
            {
                return;
            }

            result.CurrentSettlementId = current?.StringId
                ?? GameSessionState.CurrentSettlementStringId
                ?? "";
            result.CurrentSettlementName = current?.Name?.ToString()
                ?? GameSessionState.CurrentSettlementName
                ?? "";
            result.CurrentSettlement = !string.IsNullOrWhiteSpace(result.CurrentSettlementName)
                ? result.CurrentSettlementName
                : result.CurrentSettlementId;
        }

        public static void ApplyTarget(AssistiveTravelExecutionResult result, Settlement target, string resolvedName)
        {
            if (result == null)
            {
                return;
            }

            result.TargetSettlementId = target?.StringId ?? "";
            result.TargetSettlementName = target?.Name?.ToString() ?? resolvedName ?? "";
            result.TargetSettlement = !string.IsNullOrWhiteSpace(result.TargetSettlementName)
                ? result.TargetSettlementName
                : !string.IsNullOrWhiteSpace(resolvedName)
                    ? resolvedName
                    : result.TargetSettlementId;
        }
    }
}
