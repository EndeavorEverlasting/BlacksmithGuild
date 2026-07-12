using System;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Market;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class SmithingSmeltService
    {
        public const string ProbeWeaponSmeltNowCommand = "ProbeWeaponSmeltNow";
        public const string RunWeaponSmeltNowCommand = "RunWeaponSmeltNow";
        public const string ProbeReportFileName = "BlacksmithGuild_SmithingSmeltProbe.json";
        public const string ExecutionReportFileName = "BlacksmithGuild_SmithingSmeltExecution.json";

        private static readonly string ProbeReportPath = Path.Combine(BasePath.Name, ProbeReportFileName);
        private static readonly string ExecutionReportPath = Path.Combine(BasePath.Name, ExecutionReportFileName);

        public static bool LastProbeAvailable { get; private set; }
        public static SmithingSmeltExecutionResult LastExecutionResult { get; private set; }
        public static string LastBlockedReason { get; private set; }

        public static bool RunSmeltApiProbeNow(string source = ProbeWeaponSmeltNowCommand)
        {
            try
            {
                if (Campaign.Current == null || !GameSessionState.IsCampaignMapReady)
                {
                    DebugLogger.Test("[TBG SMITHING] ProbeWeaponSmeltNow blocked: campaign map not ready.", showInGame: false);
                    return false;
                }

                var mapped = SmithingSmeltApi.RunSmeltApiProbe(out var detail);
                var hero = Hero.MainHero;
                var candidate = SmithingLootWeaponScanner.SelectBestCandidate();
                var canSmelt = false;
                string smeltDetail = null;
                if (candidate != null && hero != null)
                {
                    canSmelt = SmithingSmeltApi.CanInvokeSmeltWeapon(hero, ResolveItem(candidate), out smeltDetail);
                }
                LastProbeAvailable = mapped && canSmelt;

                WriteProbeJson(source, mapped, detail, canSmelt, smeltDetail, candidate);
                DebugLogger.Test(
                    $"[TBG SMITHING] ProbeWeaponSmeltNow mapped={mapped} canSmelt={canSmelt} detail={detail}",
                    showInGame: false);
                InGameNotice.Info(
                    ModDisplay.CompactLine(
                        "Weapon Smelt Probe",
                        mapped
                            ? $"DoSmelting mapped; canSmelt={canSmelt}"
                            : $"blocked: {detail}"));
                InGameNotice.Info(ModDisplay.CompactLine("Weapon Smelt Probe", $"json={ProbeReportFileName}"));
                return mapped;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG SMITHING] ProbeWeaponSmeltNow failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool TrySmeltOneLootWeaponNow(string source = RunWeaponSmeltNowCommand)
        {
            LastBlockedReason = null;
            LastExecutionResult = null;

            try
            {
                if (!GameSessionState.IsCampaignMapReady)
                {
                    LastBlockedReason = GameSessionState.GetCampaignMapBlockDetail();
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                var workers = SmithingWorkerSelector.GetPartyWorkers();
                var grunt = SmithingWorkerSelector.SelectGruntWorker(workers);
                var hero = ResolveHero(grunt);
                if (hero == null)
                {
                    LastBlockedReason = "no grunt worker available";
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                var candidate = SmithingLootWeaponScanner.SelectBestCandidate();
                if (candidate == null)
                {
                    LastBlockedReason = "no smeltable loot weapons in party";
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                var item = ResolveItem(candidate);
                if (item == null)
                {
                    LastBlockedReason = "selected weapon item unavailable";
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                if (!SmithingStaminaReader.TrySetActiveCraftingHero(hero, out var setHeroDetail))
                {
                    LastBlockedReason = setHeroDetail ?? "SetActiveCraftingHero failed";
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                var weaponsBefore = SmithingLootWeaponScanner.CountSmeltableWeapons();
                var ironBefore = SmithingPartyInventory.CountSmeltOutputs();
                var charcoalBefore = SmithingPartyInventory.CountCharcoal();

                if (!SmithingSmeltApi.TryInvokeSmeltWeapon(hero, item, out var invokeDetail))
                {
                    LastBlockedReason = invokeDetail ?? "smelt invocation failed";
                    WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                    return false;
                }

                var weaponsAfter = SmithingLootWeaponScanner.CountSmeltableWeapons();
                var ironAfter = SmithingPartyInventory.CountSmeltOutputs();
                var charcoalAfter = SmithingPartyInventory.CountCharcoal();
                var success = weaponsAfter < weaponsBefore
                    && (ironAfter > ironBefore || charcoalAfter > charcoalBefore);

                var result = new SmithingSmeltExecutionResult
                {
                    WeaponItemId = candidate.ItemId,
                    WeaponName = candidate.ItemName,
                    WeaponsBefore = weaponsBefore,
                    WeaponsAfter = weaponsAfter,
                    IronBefore = ironBefore,
                    IronAfter = ironAfter,
                    CharcoalBefore = charcoalBefore,
                    CharcoalAfter = charcoalAfter,
                    ExecutionMethod = SmithingSmeltApi.LastMappedSignature ?? "DoSmelting",
                    ActorName = ResolveActorLabel(grunt, hero),
                    AttemptSuccess = success,
                    Detail = invokeDetail
                };

                LastExecutionResult = result;
                WriteExecutionJson(source, result);

                DebugLogger.Test(
                    $"[TBG FORGE] action=SmeltWeapon actor={result.ActorName} weapon={result.WeaponName} weaponsBefore={weaponsBefore} weaponsAfter={weaponsAfter} ironBefore={ironBefore} ironAfter={ironAfter}",
                    showInGame: false);

                if (success)
                {
                    MarketIntelligenceService.InvalidateCache("smithing_inventory_changed");
                    InGameNotice.Success(
                        ModDisplay.CompactLine("Weapon Smelt", $"{candidate.ItemName} smelted by {result.ActorName}."));
                }
                else
                {
                    LastBlockedReason = "smelt invoked but inventory delta not proven";
                    InGameNotice.Warn(
                        ModDisplay.CompactLine("Weapon Smelt", LastBlockedReason));
                }

                return success;
            }
            catch (Exception ex)
            {
                LastBlockedReason = ex.Message;
                WriteExecutionJson(source, BuildBlockedResult(LastBlockedReason));
                DebugLogger.Test($"[TBG SMITHING] RunWeaponSmeltNow failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static SmithingSmeltExecutionResult BuildBlockedResult(string reason)
        {
            return new SmithingSmeltExecutionResult
            {
                AttemptSuccess = false,
                Detail = reason,
                WeaponsBefore = SmithingLootWeaponScanner.CountSmeltableWeapons(),
                WeaponsAfter = SmithingLootWeaponScanner.CountSmeltableWeapons(),
                IronBefore = SmithingPartyInventory.CountSmeltOutputs(),
                IronAfter = SmithingPartyInventory.CountSmeltOutputs(),
                CharcoalBefore = SmithingPartyInventory.CountCharcoal(),
                CharcoalAfter = SmithingPartyInventory.CountCharcoal()
            };
        }

        private static ItemObject ResolveItem(SmithingLootWeaponCandidate candidate)
        {
            if (candidate == null || string.IsNullOrEmpty(candidate.ItemId))
            {
                return null;
            }

            return Game.Current?.ObjectManager?.GetObject<ItemObject>(candidate.ItemId);
        }

        private static Hero ResolveHero(SmithingWorkerProfile worker)
        {
            if (worker?.IsMainHero == true)
            {
                return Hero.MainHero;
            }

            return Hero.MainHero;
        }

        private static string ResolveActorLabel(SmithingWorkerProfile worker, Hero hero)
        {
            if (!string.IsNullOrWhiteSpace(worker?.Name))
            {
                return worker.Name;
            }

            return hero?.Name?.ToString() ?? "MainHero";
        }

        private static void WriteProbeJson(
            string source,
            bool mapped,
            string detail,
            bool canSmelt,
            string smeltDetail,
            SmithingLootWeaponCandidate candidate)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"readOnly\": false,");
            sb.AppendLine($"  \"doSmeltingMapped\": {(mapped ? "true" : "false")},");
            sb.AppendLine($"  \"mappedSignature\": {NullableString(SmithingSmeltApi.LastMappedSignature)},");
            sb.AppendLine($"  \"detail\": {NullableString(detail)},");
            sb.AppendLine($"  \"canSmeltWeapon\": {(canSmelt ? "true" : "false")},");
            sb.AppendLine($"  \"canSmeltDetail\": {NullableString(smeltDetail)},");
            sb.AppendLine($"  \"candidateWeaponId\": {NullableString(candidate?.ItemId)},");
            sb.AppendLine($"  \"candidateWeaponName\": {NullableString(candidate?.ItemName)},");
            sb.AppendLine($"  \"weaponsInParty\": {SmithingLootWeaponScanner.CountSmeltableWeapons()},");
            sb.AppendLine("  \"methodHints\": [");
            var hints = SmithingSmeltApi.LastProbeHints.ToList();
            for (var i = 0; i < hints.Count; i++)
            {
                sb.Append($"    \"{Escape(hints[i])}\"");
                sb.AppendLine(i < hints.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ],");
            sb.AppendLine($"  \"attemptSuccess\": {(mapped && canSmelt ? "true" : "false")},");
            sb.AppendLine($"  \"verdict\": \"{(mapped && canSmelt ? "ProbeSmeltSuccess" : "ProbeSmeltBlocked")}\"");
            sb.AppendLine("}");

            File.WriteAllText(ProbeReportPath, sb.ToString(), Encoding.UTF8);
            MirrorEvidence(ProbeReportFileName);
        }

        private static void WriteExecutionJson(string source, SmithingSmeltExecutionResult result)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine($"  \"attemptSuccess\": {result.AttemptSuccess.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"detail\": {NullableString(result.Detail)},");
            sb.AppendLine($"  \"weaponItemId\": {NullableString(result.WeaponItemId)},");
            sb.AppendLine($"  \"weaponName\": {NullableString(result.WeaponName)},");
            sb.AppendLine($"  \"weaponsBefore\": {result.WeaponsBefore},");
            sb.AppendLine($"  \"weaponsAfter\": {result.WeaponsAfter},");
            sb.AppendLine($"  \"ironBefore\": {result.IronBefore},");
            sb.AppendLine($"  \"ironAfter\": {result.IronAfter},");
            sb.AppendLine($"  \"charcoalBefore\": {result.CharcoalBefore},");
            sb.AppendLine($"  \"charcoalAfter\": {result.CharcoalAfter},");
            sb.AppendLine($"  \"executionMethod\": {NullableString(result.ExecutionMethod)},");
            sb.AppendLine($"  \"actorName\": {NullableString(result.ActorName)},");
            sb.AppendLine($"  \"verdict\": \"{(result.AttemptSuccess ? "SmeltSuccess" : "SmeltBlocked")}\"");
            sb.AppendLine("}");

            File.WriteAllText(ExecutionReportPath, sb.ToString(), Encoding.UTF8);
            MirrorEvidence(ExecutionReportFileName);
        }

        private static void MirrorEvidence(string fileName)
        {
            try
            {
                var repoRoot = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..", "..", "..", ".."));
                var mirrorDir = Path.Combine(repoRoot, "docs", "evidence", "latest");
                if (!Directory.Exists(mirrorDir))
                {
                    return;
                }

                File.Copy(Path.Combine(BasePath.Name, fileName), Path.Combine(mirrorDir, fileName), overwrite: true);
            }
            catch
            {
            }
        }

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
