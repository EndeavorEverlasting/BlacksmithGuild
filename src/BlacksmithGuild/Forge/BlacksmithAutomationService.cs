using System;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class BlacksmithAutomationService
    {
        public const string RunBlacksmithAutomationNowCommand = "RunBlacksmithAutomationNow";
        public const string ReportFileName = "BlacksmithGuild_BlacksmithAutomation.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        public static bool LastWasGuardrailBlock { get; private set; }

        public static string LastBlockedReason { get; private set; }

        public static bool RunAutomationNow(string source = RunBlacksmithAutomationNowCommand)
        {
            LastWasGuardrailBlock = false;
            LastBlockedReason = null;

            try
            {
                GameSessionState.Refresh();
                if (!GameSessionState.IsCampaignMapReady)
                {
                    return WriteBlocked(
                        source,
                        "NoSafeAction",
                        GameSessionState.GetCampaignMapBlockDetail(),
                        "wait for campaign map");
                }

                var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
                var charcoalNeed = Math.Max(0, reserve.CharcoalFloor - reserve.CharcoalHave);
                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var grunt = SmithingWorkerSelector.SelectGruntWorker(workers);
                var hero = ResolveHero(grunt);
                var actorLabel = ResolveActorLabel(grunt, hero);

                if (charcoalNeed > 0 && reserve.HardwoodHave >= SmithingSafeActionService.MaxRefinePerInvocation)
                {
                    var staminaBefore = ReadStamina(hero);
                    var hardwoodBefore = reserve.HardwoodHave;
                    var charcoalBefore = reserve.CharcoalHave;

                    if (SmithingSafeActionService.RunSafeActionNow(source))
                    {
                        var reserveAfter = SmithingAdvisoryPlanner.BuildReserveHealth();
                        return WriteSuccess(
                            source,
                            "RefineCharcoal",
                            actorLabel,
                            charcoalBefore,
                            reserveAfter.CharcoalHave,
                            hardwoodBefore,
                            reserveAfter.HardwoodHave,
                            staminaBefore,
                            ReadStamina(hero),
                            "charcoal below floor; one hardwood→charcoal refine executed",
                            "RunSmithingAdvisoryNow or RunBlacksmithAutomationNow after reserves recover");
                    }

                    var blockReason = SmithingSafeActionService.LastBlockedReason ?? "refine blocked";
                    if (IsStaminaBlock(blockReason))
                    {
                        return WriteBlocked(source, "RestNeeded", blockReason, "RunSmithingRestPlanNow");
                    }

                    if (blockReason.IndexOf("hardwood", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return WriteBlocked(source, "BuyMaterialsFirst", blockReason, "buy hardwood at nearest town");
                    }

                    return WriteBlocked(source, "NoSafeAction", blockReason, "inspect SmithingSafeAction guardrails");
                }

                if (HasMaterialShortage(reserve, out var materialReason))
                {
                    return WriteBlocked(source, "BuyMaterialsFirst", materialReason, "buy forge inputs at nearest town");
                }

                if (SmithingLootWeaponScanner.SelectBestCandidate() != null
                    && SmithingSmeltService.TrySmeltOneLootWeaponNow(source))
                {
                    var smelt = SmithingSmeltService.LastExecutionResult;
                    return WriteSmeltSuccess(
                        source,
                        smelt?.ActorName ?? actorLabel,
                        smelt,
                        "loot weapon smelt executed");
                }

                if (!string.IsNullOrWhiteSpace(SmithingSmeltService.LastBlockedReason)
                    && SmithingSmeltService.LastBlockedReason.IndexOf("stamina", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return WriteBlocked(source, "RestNeeded", SmithingSmeltService.LastBlockedReason, "RunSmithingRestPlanNow");
                }

                if (NeedsRest(workers, out var restReason))
                {
                    return WriteBlocked(source, "RestNeeded", restReason, "RunSmithingRestPlanNow");
                }

                ForgeRecommendationService.RunRankNow(source: source);
                var topCandidate = ForgeRecommendationService.GetCachedTopCandidate();
                if (topCandidate != null)
                {
                    return WriteBlocked(
                        source,
                        "CraftManual",
                        $"top craft candidate {topCandidate.DesignName} requires manual smithy craft",
                        "enter smithy and craft manually until safe craft API is proven");
                }

                return WriteBlocked(source, "NoSafeAction", "no bounded safe automation available", "RunGuildLoopNow");
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG AUTO] {RunBlacksmithAutomationNowCommand} failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool HasMaterialShortage(SmithingReserveHealth reserve, out string reason)
        {
            if (reserve.CharcoalHave < reserve.CharcoalFloor)
            {
                reason = $"charcoal below floor ({reserve.CharcoalHave}/{reserve.CharcoalFloor}) and hardwood unavailable";
                return true;
            }

            if (reserve.HardwoodHave < reserve.HardwoodFloor)
            {
                reason = $"hardwood below floor ({reserve.HardwoodHave}/{reserve.HardwoodFloor})";
                return true;
            }

            reason = null;
            return false;
        }

        private static bool NeedsRest(System.Collections.Generic.IReadOnlyList<SmithingWorkerProfile> workers, out string reason)
        {
            var known = workers.Where(worker => worker.StaminaKnown).ToList();
            if (known.Count == 0)
            {
                reason = "smithing stamina unknown";
                return false;
            }

            var lowest = known.Min(worker => worker.Stamina);
            if (lowest <= 0)
            {
                reason = $"lowest smith stamina={lowest:0}";
                return true;
            }

            reason = null;
            return false;
        }

        private static bool IsStaminaBlock(string reason)
        {
            if (string.IsNullOrWhiteSpace(reason))
            {
                return false;
            }

            return reason.IndexOf("stamina", StringComparison.OrdinalIgnoreCase) >= 0
                || reason.IndexOf("CraftingHero", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static TaleWorlds.CampaignSystem.Hero ResolveHero(SmithingWorkerProfile worker)
        {
            if (worker == null)
            {
                return null;
            }

            if (worker.IsMainHero)
            {
                return TaleWorlds.CampaignSystem.Hero.MainHero;
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

                var heroName = hero.Name?.ToString();
                if (!string.IsNullOrWhiteSpace(worker.Name)
                    && string.Equals(heroName, worker.Name, StringComparison.Ordinal))
                {
                    return hero;
                }
            }

            return TaleWorlds.CampaignSystem.Hero.MainHero;
        }

        private static string ResolveActorLabel(SmithingWorkerProfile worker, TaleWorlds.CampaignSystem.Hero hero)
        {
            if (!string.IsNullOrWhiteSpace(worker?.Name))
            {
                return worker.Name;
            }

            return hero?.Name?.ToString() ?? "MainHero";
        }

        private static float ReadStamina(TaleWorlds.CampaignSystem.Hero hero)
        {
            if (hero == null)
            {
                return -1f;
            }

            return SmithingStaminaReader.TryReadStamina(hero, out var stamina, out _)
                ? stamina
                : -1f;
        }

        private static bool WriteSmeltSuccess(
            string source,
            string actor,
            SmithingSmeltExecutionResult smelt,
            string reason)
        {
            WriteJsonReport(new AutomationResult
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Action = "SmeltWeapon",
                Actor = actor,
                Executed = true,
                BlockedReason = null,
                Recommendation = "SmeltWeapon",
                Reason = reason,
                NextRecommendedAction = "RunBlacksmithAutomationNow or RunGuildLoopNow",
                CharcoalBefore = smelt?.CharcoalBefore ?? 0,
                CharcoalAfter = smelt?.CharcoalAfter ?? 0,
                HardwoodBefore = smelt?.WeaponsBefore ?? 0,
                HardwoodAfter = smelt?.WeaponsAfter ?? 0,
                StaminaBefore = -1f,
                StaminaAfter = -1f,
                WeaponName = smelt?.WeaponName,
                IronBefore = smelt?.IronBefore ?? 0,
                IronAfter = smelt?.IronAfter ?? 0
            });

            InGameNotice.Success(
                ModDisplay.CompactLine("Blacksmith Automation", $"SmeltWeapon by {actor} complete."));
            return true;
        }

        private static bool WriteSuccess(
            string source,
            string action,
            string actor,
            int charcoalBefore,
            int charcoalAfter,
            int hardwoodBefore,
            int hardwoodAfter,
            float staminaBefore,
            float staminaAfter,
            string reason,
            string nextRecommendedAction)
        {
            WriteJsonReport(new AutomationResult
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Action = action,
                Actor = actor,
                Executed = true,
                BlockedReason = null,
                Recommendation = action,
                Reason = reason,
                NextRecommendedAction = nextRecommendedAction,
                CharcoalBefore = charcoalBefore,
                CharcoalAfter = charcoalAfter,
                HardwoodBefore = hardwoodBefore,
                HardwoodAfter = hardwoodAfter,
                StaminaBefore = staminaBefore,
                StaminaAfter = staminaAfter
            });

            InGameNotice.Success(
                ModDisplay.CompactLine("Blacksmith Automation", $"{action} by {actor} complete."));
            return true;
        }

        private static bool WriteBlocked(
            string source,
            string recommendation,
            string reason,
            string nextRecommendedAction)
        {
            LastWasGuardrailBlock = true;
            LastBlockedReason = reason;

            var reserve = SmithingAdvisoryPlanner.BuildReserveHealth();
            WriteJsonReport(new AutomationResult
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source,
                Action = recommendation,
                Actor = null,
                Executed = false,
                BlockedReason = reason,
                Recommendation = recommendation,
                Reason = reason,
                NextRecommendedAction = nextRecommendedAction,
                CharcoalBefore = reserve.CharcoalHave,
                CharcoalAfter = reserve.CharcoalHave,
                HardwoodBefore = reserve.HardwoodHave,
                HardwoodAfter = reserve.HardwoodHave,
                StaminaBefore = -1f,
                StaminaAfter = -1f
            });

            DebugLogger.Test(
                $"[TBG AUTO] action={recommendation} blocked reason={reason}",
                showInGame: false);
            InGameNotice.Warn(
                ModDisplay.CompactLine("Blacksmith Automation", $"{recommendation}: {reason}"));
            return recommendation == "CraftManual";
        }

        private static void WriteJsonReport(AutomationResult result)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(result.GeneratedUtc)}\",");
            sb.AppendLine($"  \"source\": \"{Escape(result.Source)}\",");
            sb.AppendLine($"  \"action\": \"{Escape(result.Action)}\",");
            sb.AppendLine($"  \"actor\": {(result.Actor == null ? "null" : $"\"{Escape(result.Actor)}\"")},");
            sb.AppendLine($"  \"executed\": {result.Executed.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"blockedReason\": {(result.BlockedReason == null ? "null" : $"\"{Escape(result.BlockedReason)}\"")},");
            sb.AppendLine($"  \"recommendation\": \"{Escape(result.Recommendation)}\",");
            sb.AppendLine($"  \"reason\": \"{Escape(result.Reason)}\",");
            sb.AppendLine($"  \"nextRecommendedAction\": \"{Escape(result.NextRecommendedAction)}\",");
            sb.AppendLine("  \"inventory\": {");
            sb.AppendLine($"    \"charcoalBefore\": {result.CharcoalBefore},");
            sb.AppendLine($"    \"charcoalAfter\": {result.CharcoalAfter},");
            sb.AppendLine($"    \"hardwoodBefore\": {result.HardwoodBefore},");
            sb.AppendLine($"    \"hardwoodAfter\": {result.HardwoodAfter},");
            sb.AppendLine($"    \"ironBefore\": {result.IronBefore},");
            sb.AppendLine($"    \"ironAfter\": {result.IronAfter},");
            sb.AppendLine($"    \"weaponName\": {(result.WeaponName == null ? "null" : $"\"{Escape(result.WeaponName)}\"")}");
            sb.AppendLine("  },");
            sb.AppendLine("  \"stamina\": {");
            sb.AppendLine($"    \"before\": {FormatFloat(result.StaminaBefore)},");
            sb.AppendLine($"    \"after\": {FormatFloat(result.StaminaAfter)}");
            sb.AppendLine("  }");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static string FormatFloat(float value)
        {
            return value < 0f ? "null" : value.ToString("0.##");
        }

        private static string Escape(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            return value
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
        }

        private sealed class AutomationResult
        {
            public string GeneratedUtc { get; set; }
            public string Source { get; set; }
            public string Action { get; set; }
            public string Actor { get; set; }
            public bool Executed { get; set; }
            public string BlockedReason { get; set; }
            public string Recommendation { get; set; }
            public string Reason { get; set; }
            public string NextRecommendedAction { get; set; }
            public int CharcoalBefore { get; set; }
            public int CharcoalAfter { get; set; }
            public int HardwoodBefore { get; set; }
            public int HardwoodAfter { get; set; }
            public float StaminaBefore { get; set; }
            public float StaminaAfter { get; set; }
            public int IronBefore { get; set; }
            public int IronAfter { get; set; }
            public string WeaponName { get; set; }
        }
    }
}
