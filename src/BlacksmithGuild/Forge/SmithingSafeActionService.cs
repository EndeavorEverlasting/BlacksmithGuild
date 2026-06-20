using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class SmithingSafeActionService
    {
        public const string RunSmithingSafeActionNowCommand = "RunSmithingSafeActionNow";
        public const string ReportFileName = "BlacksmithGuild_SmithingSafeAction.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static bool RunSafeActionNow(string source = RunSmithingSafeActionNowCommand)
        {
            try
            {
                if (!GameSessionState.IsCampaignMapReady)
                {
                    DebugLogger.Test(
                        $"[TBG FORGE] {RunSmithingSafeActionNowCommand} blocked: {GameSessionState.GetCampaignMapBlockDetail()}",
                        showInGame: false);
                    return false;
                }

                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
                var grunt = SmithingWorkerSelector.SelectGruntWorker(workers);
                var charcoalNeed = Math.Max(
                    0,
                    SmithingReservePolicy.CharcoalFloor - reserve.CharcoalHave);

                var hero = ResolveHero(grunt);
                var blockedReason = (string)null;
                var executed = false;
                string action = "RefineCharcoal";

                if (hero == null)
                {
                    blockedReason = "no grunt worker available";
                }
                else if (charcoalNeed <= 0)
                {
                    blockedReason = "charcoal reserve already at floor";
                    action = "None";
                }
                else if (reserve.HardwoodHave < charcoalNeed)
                {
                    blockedReason = $"hardwood shortage (have {reserve.HardwoodHave}, need {charcoalNeed})";
                }
                else if (!SmithingStaminaReader.TrySetActiveCraftingHero(hero, out var setHeroDetail))
                {
                    blockedReason = setHeroDetail ?? "SetActiveCraftingHero failed";
                }
                else if (!SmithingStaminaReader.CanInvokeRefineCharcoal(out var refineDetail))
                {
                    blockedReason = refineDetail;
                }

                if (blockedReason == null && hero != null)
                {
                    executed = false;
                    blockedReason = "RefineCharcoal API not mapped — use smithy UI or wait for Stage C probe";
                }

                WriteJsonReport(new SafeActionResult
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = source,
                    Action = action,
                    Actor = grunt?.Name,
                    Executed = executed,
                    BlockedReason = blockedReason,
                    CharcoalBefore = reserve.CharcoalHave,
                    HardwoodBefore = reserve.HardwoodHave,
                    CharcoalNeed = charcoalNeed
                });

                if (executed)
                {
                    DebugLogger.Test(
                        $"[TBG FORGE] action={action} actor={grunt?.Name} reserveBefore charcoal={reserve.CharcoalHave} hardwood={reserve.HardwoodHave}",
                        showInGame: false);
                    InGameNotice.Success(
                        ModDisplay.CompactLine("Smithing Safe Action", $"{action} by {grunt?.Name} complete."));
                    return true;
                }

                DebugLogger.Test(
                    $"[TBG FORGE] action={action} actor={grunt?.Name} blocked={blockedReason}",
                    showInGame: false);
                InGameNotice.Warn(
                    ModDisplay.CompactLine("Smithing Safe Action", $"blocked: {blockedReason}"));
                return false;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] {RunSmithingSafeActionNowCommand} failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static Hero ResolveHero(SmithingWorkerProfile profile)
        {
            if (profile == null)
            {
                return null;
            }

            if (profile.IsMainHero)
            {
                return Hero.MainHero;
            }

            var party = TaleWorlds.CampaignSystem.Party.MobileParty.MainParty;
            if (party?.MemberRoster == null)
            {
                return null;
            }

            foreach (var element in party.MemberRoster.GetTroopRoster())
            {
                var hero = element.Character?.HeroObject;
                if (hero == null)
                {
                    continue;
                }

                if (string.Equals(hero.Name?.ToString(), profile.Name, StringComparison.Ordinal))
                {
                    return hero;
                }
            }

            return null;
        }

        private static void WriteJsonReport(SafeActionResult result)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(result.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(result.Source)}\",");
            sb.AppendLine($"  \"action\": \"{Escape(result.Action)}\",");
            sb.AppendLine($"  \"actor\": {(result.Actor == null ? "null" : $"\"{Escape(result.Actor)}\"")},");
            sb.AppendLine($"  \"executed\": {result.Executed.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"blockedReason\": {(result.BlockedReason == null ? "null" : $"\"{Escape(result.BlockedReason)}\"")},");
            sb.AppendLine($"  \"charcoalBefore\": {result.CharcoalBefore},");
            sb.AppendLine($"  \"hardwoodBefore\": {result.HardwoodBefore},");
            sb.AppendLine($"  \"charcoalNeed\": {result.CharcoalNeed}");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private sealed class SafeActionResult
        {
            public string GeneratedUtc { get; set; }
            public string Source { get; set; }
            public string Action { get; set; }
            public string Actor { get; set; }
            public bool Executed { get; set; }
            public string BlockedReason { get; set; }
            public int CharcoalBefore { get; set; }
            public int HardwoodBefore { get; set; }
            public int CharcoalNeed { get; set; }
        }
    }
}
