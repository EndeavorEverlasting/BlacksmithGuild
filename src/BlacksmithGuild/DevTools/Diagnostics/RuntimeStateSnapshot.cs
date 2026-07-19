using System;
using System.Text;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.DevTools.Diagnostics
{
    // A deliberately small, non-save snapshot for before/after span boundaries.
    public sealed class RuntimeStateSnapshot
    {
        public string OperationId { get; private set; }
        public bool? CampaignReady { get; private set; }
        public bool? MapMenuOpen { get; private set; }
        public bool? MainPartyAvailable { get; private set; }
        public string Settlement { get; private set; }
        public string Destination { get; private set; }
        public bool? CachedMarketScan { get; private set; }
        public int? CandidateCount { get; private set; }

        public static RuntimeStateSnapshot Capture(
            string operationId,
            string settlement = null,
            string destination = null,
            int? candidateCount = null)
        {
            var snapshot = new RuntimeStateSnapshot
            {
                OperationId = RuntimeSpanContext.Bound(operationId, 128),
                Settlement = RuntimeSpanContext.Bound(settlement, 256),
                Destination = RuntimeSpanContext.Bound(destination, 256),
                CandidateCount = candidateCount
            };

            try { snapshot.CampaignReady = GameSessionState.IsCampaignMapReady; } catch { }
            try { snapshot.MapMenuOpen = GameSessionState.IsMapMenuOpen; } catch { }
            try { snapshot.MainPartyAvailable = MobileParty.MainParty != null; } catch { }
            try { snapshot.CachedMarketScan = MarketIntelligenceService.HasCachedScan; } catch { }
            return snapshot;
        }

        public string ToJson()
        {
            var builder = new StringBuilder("{");
            Append(builder, "operationId", OperationId);
            Append(builder, "campaignReady", CampaignReady);
            Append(builder, "mapMenuOpen", MapMenuOpen);
            Append(builder, "mainPartyAvailable", MainPartyAvailable);
            Append(builder, "settlement", Settlement);
            Append(builder, "destination", Destination);
            Append(builder, "cachedMarketScan", CachedMarketScan);
            Append(builder, "candidateCount", CandidateCount);
            builder.Length--;
            builder.Append("}");
            return builder.ToString();
        }

        private static void Append(StringBuilder builder, string name, string value)
        {
            builder.Append("\"").Append(name).Append("\":");
            builder.Append(value == null ? "null" : "\"" + Escape(value) + "\"").Append(",");
        }

        private static void Append(StringBuilder builder, string name, bool? value)
        {
            builder.Append("\"").Append(name).Append("\":");
            builder.Append(value.HasValue ? value.Value.ToString().ToLowerInvariant() : "null").Append(",");
        }

        private static void Append(StringBuilder builder, string name, int? value)
        {
            builder.Append("\"").Append(name).Append("\":");
            builder.Append(value.HasValue ? value.Value.ToString() : "null").Append(",");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n");
    }
}
