using System;
using System.Collections.Generic;
using System.Linq;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Forge;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.ClanIntel
{
    public static class CourtshipPlanService
    {
        public const string ShowCourtshipPlanCommand = "ShowCourtshipPlan";

        private static CourtshipPlanReport _lastReport;

        public static bool ShowPlanNow(string source = ShowCourtshipPlanCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG COURTSHIP: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            if (MarriageCandidateService.LastReport == null)
            {
                MarriageCandidateService.AnalyzeNow("CourtshipPlan.PrefetchMarriage");
            }

            if (NobleNetworkService.LastReport == null)
            {
                NobleNetworkService.AnalyzeNow("CourtshipPlan.PrefetchNoble");
            }

            var marriage = MarriageCandidateService.LastReport;
            var noble = NobleNetworkService.LastReport;
            var top = marriage?.TopCandidate;
            var report = new CourtshipPlanReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                TopCandidate = top,
                NobleContext = noble?.TopTarget,
                TravelPlan = new TravelPlanBlock
                {
                    TargetHero = top?.Candidate,
                    Distance = top?.Distance,
                    RouteSafety = top?.RouteSafety,
                    RecommendedAction = top?.RecommendedAction ?? "AnalyzeMarriageCandidates"
                },
                NextSteps = BuildNextSteps(top),
                CertificationGaps = new List<string>
                {
                    "RunVisibleCourtshipAttemptNow not certified",
                    "Courtship dialogue path not yet certified",
                    "ProbeCourtshipApi should pass before visible courtship"
                },
                Verdict = top != null
                    ? $"courtship brief: pursue {top.Candidate} ({top.Category}) via visible conversation when certified"
                    : "no marriage candidate — run AnalyzeMarriageCandidates on campaign map"
            };

            _lastReport = report;
            ClanJsonWriter.WriteCourtshipPlan(report);
            var formatter = ReportFormatter.BeginReport("COURTSHIP PLAN", source, "courtship-plan");
            if (top != null)
            {
                formatter.Line("target", $"{top.Candidate} | {top.Category} | safety {top.RouteSafety}");
            }

            formatter.SummaryLine("CERT: courtship execution deferred until dialogue path proven");
            formatter.SummaryLine(report.Verdict);
            formatter.EndReport();
            InGameNotice.Info($"TBG COURTSHIP: {report.Verdict}");
            return true;
        }

        private static List<string> BuildNextSteps(MarriageCandidateEntry top)
        {
            var steps = new List<string>();
            if (top == null)
            {
                steps.Add("Run AnalyzeMarriageCandidates");
                return steps;
            }

            steps.Add($"Travel toward {top.Candidate} ({top.RouteSafety} route)");
            steps.Add("Open conversation when co-located");
            steps.Add("Record courtship dialogue options (future cert)");
            steps.Add("Do not use RunVisibleCourtshipAttemptNow until T3 cert");
            return steps;
        }
    }

    public static class ClanRoleBoardService
    {
        public const string AnalyzeClanRolesCommand = "AnalyzeClanRoles";

        public static bool AnalyzeNow(string source = AnalyzeClanRolesCommand)
        {
            GameSessionState.Refresh();
            if (!GameSessionState.IsCampaignMapReady)
            {
                InGameNotice.Blocked($"TBG CLAN ROLES: {GameSessionState.GetCampaignMapBlockDetail()}");
                return false;
            }

            var report = BuildReport(source);
            ClanJsonWriter.WriteClanRoles(report);
            InGameNotice.Info($"TBG CLAN ROLES: {report.Verdict}");
            return true;
        }

        private static ClanRolesReport BuildReport(string source)
        {
            var roles = new Dictionary<string, ClanRoleSlot>();
            var gaps = new List<string>();
            var heroes = CollectPartyHeroes();

            roles["Quartermaster"] = AssignBest(heroes, "Steward", 60);
            roles["Surgeon"] = AssignBest(heroes, "Medicine", 50);
            roles["Scout"] = AssignBest(heroes, "Scouting", 50);
            roles["Engineer"] = AssignBest(heroes, "Engineering", 40);
            roles["SmithingCrew"] = AssignSmithingCrew(heroes);
            roles["CaravanLeader"] = AssignBest(heroes, "Trade", 50, secondarySkill: "Scouting");
            roles["Governor"] = new ClanRoleSlot
            {
                Role = "Governor",
                Assigned = null,
                FitScore = null,
                MissingBetterCandidate = true,
                RecommendedRecruitment = "Future fief assignment — read-only advisory"
            };

            foreach (var pair in roles)
            {
                if (pair.Value.MissingBetterCandidate)
                {
                    gaps.Add(pair.Key);
                }
            }

            if (gaps.Count > 0)
            {
                gaps.Add("Consider AnalyzeTavernHeroes for recruitment gaps");
            }

            return new ClanRolesReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                ReadOnly = true,
                MutationApplied = false,
                Doctrine = ClanIntelDoctrine.DefaultDoctrine,
                Roles = roles,
                RecruitmentGaps = gaps,
                Verdict = gaps.Count == 0 ? "clan roles adequately staffed" : $"staffing gaps: {string.Join(", ", gaps)}"
            };
        }

        private static List<(string Name, Dictionary<string, int> Skills)> CollectPartyHeroes()
        {
            var list = new List<(string, Dictionary<string, int>)>();
            var party = MobileParty.MainParty;
            if (party?.MemberRoster == null)
            {
                return list;
            }

            foreach (var element in party.MemberRoster.GetTroopRoster())
            {
                var hero = element.Character?.HeroObject;
                if (hero == null)
                {
                    continue;
                }

                var skills = new Dictionary<string, int>();
                foreach (var skillName in new[] { "Smithing", "Trade", "Steward", "Medicine", "Scouting", "Engineering", "Leadership" })
                {
                    skills[skillName] = ReadSkill(hero, skillName);
                }

                list.Add((hero.Name?.ToString() ?? hero.StringId, skills));
            }

            return list;
        }

        private static ClanRoleSlot AssignBest(
            List<(string Name, Dictionary<string, int> Skills)> heroes,
            string primarySkill,
            int threshold,
            string secondarySkill = null)
        {
            var best = heroes
                .OrderByDescending(h => h.Skills.TryGetValue(primarySkill, out var v) ? v : 0)
                .FirstOrDefault();
            var score = best.Skills.TryGetValue(primarySkill, out var primary) ? primary : 0;
            if (!string.IsNullOrEmpty(secondarySkill) && best.Skills.TryGetValue(secondarySkill, out var secondary))
            {
                score = (score + secondary) / 2;
            }

            return new ClanRoleSlot
            {
                Role = primarySkill,
                Assigned = score >= threshold ? best.Name : null,
                FitScore = score,
                MissingBetterCandidate = score < threshold,
                RecommendedRecruitment = score < threshold ? $"Find wanderer with {primarySkill}" : null
            };
        }

        private static ClanRoleSlot AssignSmithingCrew(List<(string Name, Dictionary<string, int> Skills)> heroes)
        {
            var crew = heroes
                .Where(h => h.Skills.TryGetValue("Smithing", out var s) && s >= 30)
                .OrderByDescending(h => h.Skills["Smithing"])
                .Select(h => h.Name)
                .ToList();
            var stamina = 0;
            try
            {
                var advisory = SmithingAdvisoryService.CachedReport;
                stamina = advisory?.Workers?.Sum(w => w.Stamina) ?? 0;
            }
            catch
            {
            }

            return new ClanRoleSlot
            {
                Role = "SmithingCrew",
                AssignedHeroes = crew,
                Assigned = crew.FirstOrDefault(),
                FitScore = crew.Count > 0 ? 70 : 20,
                MissingBetterCandidate = crew.Count < 2,
                StaminaAvailable = stamina,
                RecommendedRecruitment = crew.Count < 2 ? "Find smith/steward wanderer via AnalyzeTavernHeroes" : null
            };
        }

        private static int ReadSkill(Hero hero, string skillName)
        {
            try
            {
                var skill = ResolveSkill(skillName);
                return skill == null ? 0 : hero.GetSkillValue(skill);
            }
            catch
            {
                return 0;
            }
        }

        private static SkillObject ResolveSkill(string skillName)
        {
            switch (skillName)
            {
                case "Smithing": return DefaultSkills.Crafting;
                case "Trade": return DefaultSkills.Trade;
                case "Steward": return DefaultSkills.Steward;
                case "Medicine": return DefaultSkills.Medicine;
                case "Scouting": return DefaultSkills.Scouting;
                case "Engineering": return DefaultSkills.Engineering;
                case "Leadership": return DefaultSkills.Leadership;
                default: return null;
            }
        }
    }
}
