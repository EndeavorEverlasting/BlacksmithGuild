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
        public const int MaxRefinePerInvocation = 1;

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
                var refineCount = charcoalNeed > 0 ? MaxRefinePerInvocation : 0;

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
                else if (reserve.HardwoodHave < refineCount)
                {
                    blockedReason = $"hardwood shortage (have {reserve.HardwoodHave}, need {refineCount})";
                }
                else if (!SmithingStaminaReader.TrySetActiveCraftingHero(hero, out var setHeroDetail))
                {
                    blockedReason = setHeroDetail ?? "SetActiveCraftingHero failed";
                }
                else if (!SmithingStaminaReader.CanInvokeRefineCharcoal(hero, out var refineDetail))
                {
                    blockedReason = refineDetail;
                }

                var charcoalBefore = reserve.CharcoalHave;
                var hardwoodBefore = reserve.HardwoodHave;
                var charcoalAfter = charcoalBefore;
                var hardwoodAfter = hardwoodBefore;

                if (blockedReason == null && hero != null)
                {
                    executed = SmithingRefineApi.TryInvokeRefineCharcoal(hero, refineCount, out var invokeDetail);
                    charcoalAfter = SmithingPartyInventory.CountCharcoal();
                    hardwoodAfter = SmithingPartyInventory.CountHardwood();

                    if (!executed)
                    {
                        blockedReason = invokeDetail ?? "RefineCharcoal invocation failed";
                    }
                }

                WriteJsonReport(new SafeActionResult
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = source,
                    Action = action,
                    Actor = grunt?.Name,
                    Executed = executed,
                    BlockedReason = blockedReason,
                    CharcoalBefore = charcoalBefore,
                    CharcoalAfter = charcoalAfter,
                    HardwoodBefore = hardwoodBefore,
                    HardwoodAfter = hardwoodAfter,
                    CharcoalNeed = charcoalNeed,
                    RefineCount = refineCount
                });

                if (executed)
                {
                    DebugLogger.Test(
                        $"[TBG FORGE] action={action} actor={grunt?.Name} refineCount={refineCount} reserveBefore charcoal={charcoalBefore} hardwood={hardwoodBefore} reserveAfter charcoal={charcoalAfter} hardwood={hardwoodAfter}",
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
            sb.AppendLine($"  \"charcoalAfter\": {result.CharcoalAfter},");
            sb.AppendLine($"  \"hardwoodBefore\": {result.HardwoodBefore},");
            sb.AppendLine($"  \"hardwoodAfter\": {result.HardwoodAfter},");
            sb.AppendLine($"  \"charcoalNeed\": {result.CharcoalNeed},");
            sb.AppendLine($"  \"refineCount\": {result.RefineCount}");
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
            public int CharcoalAfter { get; set; }
            public int HardwoodBefore { get; set; }
            public int HardwoodAfter { get; set; }
            public int CharcoalNeed { get; set; }
            public int RefineCount { get; set; }
        }
    }
}
