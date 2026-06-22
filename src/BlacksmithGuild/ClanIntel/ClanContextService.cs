using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;

namespace BlacksmithGuild.ClanIntel
{
    public static class ClanContextService
    {
        public const string AnalyzeClanContextCommand = "AnalyzeClanContext";
        public const string ShowClanContextCommand = "ShowClanContext";

        private static ClanContextReport _lastReport;

        public static bool AnalyzeNow(string source = AnalyzeClanContextCommand)
        {
            GameSessionState.Refresh();
            if (Campaign.Current == null || Hero.MainHero == null)
            {
                InGameNotice.Blocked("TBG CLAN: campaign not ready.");
                return false;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG CLAN: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            var report = BuildReport(source);
            _lastReport = report;
            ClanJsonWriter.WriteClanContext(report);
            WriteStructuredReport(source, report);
            InGameNotice.Info($"TBG CLAN: {report.Verdict}");
            return true;
        }

        public static bool ShowLast()
        {
            if (_lastReport == null)
            {
                return AnalyzeNow(ShowClanContextCommand);
            }

            ClanJsonWriter.WriteClanContext(_lastReport);
            WriteStructuredReport(ShowClanContextCommand, _lastReport);
            return true;
        }

        public static ClanContextReport BuildReport(string source)
        {
            var playerClan = ClanContextScanner.ScanPlayerClan();
            var kingdomPosture = ClanContextScanner.BuildKingdomPosture(playerClan);
            var priorities = BuildSocialPriorities(playerClan);
            var actions = BuildRecommendedActions(playerClan);

            return new ClanContextReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                PlayerClan = playerClan,
                SocialPriorities = priorities,
                RecommendedActions = actions,
                KingdomPosture = kingdomPosture,
                BlockedActions = new List<string>(),
                Verdict = BuildVerdict(playerClan, kingdomPosture)
            };
        }

        private static List<SocialPriority> BuildSocialPriorities(PlayerClanSnapshot clan)
        {
            var list = new List<SocialPriority>();
            if (clan.HasSpouse != true)
            {
                list.Add(new SocialPriority
                {
                    Type = "Marriage",
                    Priority = "High",
                    Reason = "Spouse adds hero capacity and long-term dynasty value"
                });
            }

            list.Add(new SocialPriority
            {
                Type = "AseraiNobleRelations",
                Priority = "High",
                Reason = "Supports culture-aligned political path"
            });

            if (clan.CompanionCount.HasValue && clan.CompanionLimit.HasValue
                && clan.CompanionCount.Value < clan.CompanionLimit.Value)
            {
                list.Add(new SocialPriority
                {
                    Type = "CompanionStaffing",
                    Priority = "Medium",
                    Reason = "Companion slots available for smithing crew and roles"
                });
            }

            return list;
        }

        private static List<RecommendedAction> BuildRecommendedActions(PlayerClanSnapshot clan)
        {
            var list = new List<RecommendedAction>();
            if (clan.HasSpouse != true)
            {
                list.Add(new RecommendedAction
                {
                    Command = MarriageCandidateService.AnalyzeMarriageCandidatesCommand,
                    Reason = "Find nearby eligible spouse candidates before kingdom lock"
                });
            }

            list.Add(new RecommendedAction
            {
                Command = NobleNetworkService.AnalyzeNobleNetworkCommand,
                Reason = "Build relation targets around Aserai trade/forge corridor"
            });
            list.Add(new RecommendedAction
            {
                Command = ClanRoleBoardService.AnalyzeClanRolesCommand,
                Reason = "Staff quartermaster, scout, and smithing crew roles"
            });
            return list;
        }

        private static string BuildVerdict(PlayerClanSnapshot clan, KingdomPostureBlock posture)
        {
            if (clan.Kingdom != null)
            {
                return $"{clan.Posture} clan tier {clan.Tier} — maintain relations and staffing";
            }

            return "Independent clan should prioritize spouse search, companion staffing, and Aserai noble relations";
        }

        private static void WriteStructuredReport(string source, ClanContextReport report)
        {
            var formatter = ReportFormatter.BeginReport("CLAN CONTEXT", source, "clan-context");
            formatter.Section("Clan");
            formatter.Line("name", report.PlayerClan.Name);
            formatter.Line("tier", report.PlayerClan.Tier?.ToString() ?? "unknown");
            formatter.Line("renown", report.PlayerClan.Renown?.ToString("0") ?? "unknown");
            formatter.Line("posture", report.KingdomPosture.RecommendedPosture);
            formatter.SummaryLine(report.Verdict);
            formatter.EndReport();
        }
    }
}
