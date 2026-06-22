using System;
using System.Collections.Generic;
using System.Reflection;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Conversation;

namespace BlacksmithGuild.ClanIntel
{
    public static class CourtshipProbeService
    {
        public const string ProbeCourtshipApiCommand = "ProbeCourtshipApi";

        public static bool RunProbeNow(string source = ProbeCourtshipApiCommand)
        {
            GameSessionState.Refresh();
            var hints = new List<CourtshipProbeHint>
            {
                Hint("Campaign.Current.Models.MarriageModel", Campaign.Current?.Models?.MarriageModel != null),
                Hint("Campaign.Current.Models.PersuasionModel", Campaign.Current?.Models?.PersuasionModel != null),
                Hint("ConversationManager.OpenMapConversation", typeof(ConversationManager).GetMethod("OpenMapConversation", BindingFlags.Public | BindingFlags.Instance) != null),
                Hint("ConversationManager.DoOption", typeof(ConversationManager).GetMethod("DoOption", BindingFlags.Public | BindingFlags.Instance, null, new[] { typeof(int) }, null) != null
                    || typeof(ConversationManager).GetMethod("DoOption", BindingFlags.Public | BindingFlags.Instance, null, new[] { typeof(string) }, null) != null),
                Hint("Hero.GetRelation", typeof(Hero).GetMethod("GetRelation", BindingFlags.Public | BindingFlags.Instance) != null),
                Hint("Hero.Spouse", typeof(Hero).GetProperty("Spouse", BindingFlags.Public | BindingFlags.Instance) != null)
            };

            var report = new CourtshipProbeReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                Hints = hints,
                Verdict = hints.TrueForAll(h => h.Available)
                    ? "all courtship probe hints available"
                    : "partial courtship API surface — check hints before visible courtship cert"
            };

            ClanJsonWriter.WriteCourtshipProbe(report);
            InGameNotice.Info($"TBG COURTSHIP PROBE: {report.Verdict}");
            return true;
        }

        private static CourtshipProbeHint Hint(string name, bool available)
        {
            return new CourtshipProbeHint { Name = name, Available = available };
        }
    }
}
