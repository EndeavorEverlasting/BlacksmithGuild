using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    public sealed class ForgeRealCandidateMapResult
    {
        public IReadOnlyList<ForgeCandidate> Candidates { get; set; } = Array.Empty<ForgeCandidate>();
        public int TemplateCount { get; set; }
        public int MappedCount { get; set; }
        public int SkippedCount { get; set; }
        public int ExactEconomicsCount { get; set; }
        public int HeuristicEconomicsCount { get; set; }
        public string EconomicsMode { get; set; } = "heuristic";
        public string Detail { get; set; }
    }

    public static class ForgeRealCandidateMapper
    {
        public const string SourceName = "real";
        public const int MaxMappedTemplates = 100;

        private static ForgeRealCandidateMapResult _lastResult = new ForgeRealCandidateMapResult();

        public static ForgeRealCandidateMapResult LastResult => _lastResult;

        public static ForgeRealCandidateMapResult TryMapTemplates(Hero hero)
        {
            var result = new ForgeRealCandidateMapResult();

            try
            {
                if (hero == null)
                {
                    result.Detail = "Hero unavailable for real candidate mapping.";
                    return Store(result);
                }

                var templates = ReadAllTemplates();
                result.TemplateCount = templates.Count;

                if (templates.Count == 0)
                {
                    result.Detail = "No crafting templates available.";
                    return Store(result);
                }

                var smithingSkill = hero.GetSkillValue(DefaultSkills.Crafting);
                var candidates = new List<ForgeCandidate>();

                foreach (var template in templates.Take(MaxMappedTemplates))
                {
                    var templateId = template.StringId ?? template.Id.ToString();

                    try
                    {
                        var gateReason = "skill gate unreadable — included";
                        if (ForgeRecipeEconomics.TryEvaluateSkillGate(template, hero, out var difficulty, out var blocked))
                        {
                            gateReason = blocked
                                ? $"skill gate difficulty={difficulty} skill={smithingSkill}"
                                : $"skill ok difficulty={difficulty}";

                            if (blocked)
                            {
                                result.SkippedCount++;
                                continue;
                            }
                        }

                        var economics = ForgeRecipeEconomics.Estimate(template, hero);
                        if (economics.UsedExactCosts)
                        {
                            result.ExactEconomicsCount++;
                        }
                        else
                        {
                            result.HeuristicEconomicsCount++;
                        }

                        candidates.Add(new ForgeCandidate
                        {
                            Id = $"real.template.{templateId}",
                            DesignName = ResolveDesignName(template),
                            WeaponClass = ResolveWeaponClass(template),
                            Source = SourceName,
                            EstimatedValue = economics.Value,
                            EstimatedMaterialCost = economics.MaterialCost,
                            RareMaterialPenalty = economics.RareMaterialPenalty,
                            Reason = $"economics={economics.Detail}; skill={smithingSkill}; {gateReason}"
                        });
                    }
                    catch (Exception ex)
                    {
                        result.SkippedCount++;
                        DebugLogger.Test(
                            $"[TBG FORGE] Real candidate map skipped template {templateId}: {ex.Message}",
                            showInGame: false);
                    }
                }

                result.MappedCount = candidates.Count;
                result.Candidates = candidates;
                result.EconomicsMode = ResolveEconomicsMode(result);
                result.Detail =
                    $"mapped {result.MappedCount}/{result.TemplateCount} templates (cap {MaxMappedTemplates}); economicsMode={result.EconomicsMode}; exact={result.ExactEconomicsCount}; heuristic={result.HeuristicEconomicsCount}";

                DebugLogger.Test(
                    $"[TBG FORGE] Real candidate map complete {result.Detail}",
                    showInGame: false);
            }
            catch (Exception ex)
            {
                result.Detail = $"Real candidate mapping failed: {ex.Message}";
                DebugLogger.Test($"[TBG FORGE] {result.Detail}", showInGame: false);
            }

            return Store(result);
        }

        private static ForgeRealCandidateMapResult Store(ForgeRealCandidateMapResult result)
        {
            _lastResult = result;
            return result;
        }

        private static List<CraftingTemplate> ReadAllTemplates()
        {
            var allProperty = typeof(CraftingTemplate).GetProperty(
                "All",
                BindingFlags.Public | BindingFlags.Static);
            if (allProperty == null)
            {
                return new List<CraftingTemplate>();
            }

            if (!(allProperty.GetValue(null) is IEnumerable<CraftingTemplate> templates))
            {
                return new List<CraftingTemplate>();
            }

            return templates.Where(template => template != null).ToList();
        }

        private static string ResolveDesignName(CraftingTemplate template)
        {
            var name = template.GetName();
            if (name != null && !string.IsNullOrEmpty(name.ToString()))
            {
                return name.ToString();
            }

            return template.StringId ?? template.Id.ToString();
        }

        private static string ResolveWeaponClass(CraftingTemplate template)
        {
            var description = template.WeaponDescriptions?.FirstOrDefault();
            if (description != null)
            {
                return FormatWeaponClass(description.WeaponClass);
            }

            return FormatItemType(template.ItemType);
        }

        private static string FormatWeaponClass(WeaponClass weaponClass)
        {
            switch (weaponClass)
            {
                case WeaponClass.TwoHandedSword:
                    return "Two-Handed Sword";
                case WeaponClass.TwoHandedAxe:
                    return "Two-Handed Axe";
                case WeaponClass.TwoHandedMace:
                    return "Two-Handed Mace";
                case WeaponClass.OneHandedSword:
                    return "One-Handed Sword";
                case WeaponClass.OneHandedAxe:
                    return "One-Handed Axe";
                case WeaponClass.OneHandedPolearm:
                case WeaponClass.TwoHandedPolearm:
                case WeaponClass.LowGripPolearm:
                    return "Polearm";
                default:
                    return weaponClass.ToString();
            }
        }

        private static string FormatItemType(ItemObject.ItemTypeEnum itemType)
        {
            switch (itemType)
            {
                case ItemObject.ItemTypeEnum.TwoHandedWeapon:
                    return "Two-Handed Weapon";
                case ItemObject.ItemTypeEnum.OneHandedWeapon:
                    return "One-Handed Weapon";
                case ItemObject.ItemTypeEnum.Polearm:
                    return "Polearm";
                default:
                    return itemType.ToString();
            }
        }

        private static string ResolveEconomicsMode(ForgeRealCandidateMapResult result)
        {
            if (result.ExactEconomicsCount > 0 && result.HeuristicEconomicsCount == 0)
            {
                return "exact";
            }

            if (result.HeuristicEconomicsCount > 0 && result.ExactEconomicsCount == 0)
            {
                return "heuristic";
            }

            if (result.ExactEconomicsCount > 0 && result.HeuristicEconomicsCount > 0)
            {
                return "mixed";
            }

            return "heuristic";
        }
    }
}
