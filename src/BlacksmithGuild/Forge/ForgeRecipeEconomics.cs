using System;
using System.Linq;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Localization;

namespace BlacksmithGuild.Forge
{
    public sealed class ForgeRecipeEconomicsResult
    {
        public int Value { get; set; }
        public int MaterialCost { get; set; }
        public int RareMaterialPenalty { get; set; }
        public bool UsedExactCosts { get; set; }
        public string Detail { get; set; }
    }

    public static class ForgeRecipeEconomics
    {
        private const int DefaultScalePercentage = 100;
        private const int SkillGateSlack = 25;

        public static bool TryEvaluateSkillGate(CraftingTemplate template, Hero hero, out int difficulty, out bool blocked)
        {
            difficulty = 0;
            blocked = false;

            if (template == null || hero == null)
            {
                return false;
            }

            try
            {
                if (!TryBuildDefaultWeaponDesign(template, out var design))
                {
                    return false;
                }

                var smithingModel = Campaign.Current?.Models?.SmithingModel;
                if (smithingModel == null)
                {
                    return false;
                }

                difficulty = smithingModel.CalculateWeaponDesignDifficulty(design);
                blocked = difficulty > hero.GetSkillValue(DefaultSkills.Crafting) + SkillGateSlack;
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static ForgeRecipeEconomicsResult Estimate(CraftingTemplate template, Hero hero)
        {
            if (template == null)
            {
                return HeuristicEstimate(null, hero, "missing template");
            }

            try
            {
                if (TryBuildDefaultWeaponDesign(template, out var design))
                {
                    var smithingModel = Campaign.Current?.Models?.SmithingModel;
                    if (smithingModel != null)
                    {
                        var costs = smithingModel.GetSmithingCostsForWeaponDesign(design);
                        if (costs != null && costs.Length > 0)
                        {
                            var materialCost = SumMaterialCost(costs, smithingModel);
                            var rarePenalty = ComputeRarePenalty(costs, smithingModel);
                            var difficulty = smithingModel.CalculateWeaponDesignDifficulty(design);
                            var value = EstimateValueFromDesign(template, design, materialCost, difficulty);

                            return new ForgeRecipeEconomicsResult
                            {
                                Value = value,
                                MaterialCost = materialCost,
                                RareMaterialPenalty = rarePenalty,
                                UsedExactCosts = true,
                                Detail = $"exact costs difficulty={difficulty}"
                            };
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                return HeuristicEstimate(template, hero, $"exact path failed: {ex.Message}");
            }

            return HeuristicEstimate(template, hero, "exact costs unavailable");
        }

        private static bool TryBuildDefaultWeaponDesign(CraftingTemplate template, out WeaponDesign design)
        {
            design = null;

            var buildOrders = template.BuildOrders;
            if (buildOrders == null || buildOrders.Length == 0)
            {
                return false;
            }

            var slotCount = GetPieceSlotCount();
            var elements = new WeaponDesignElement[slotCount];
            for (var slot = 0; slot < slotCount; slot++)
            {
                elements[slot] = WeaponDesignElement.GetInvalidPieceForType((CraftingPiece.PieceTypes)slot);
            }

            foreach (var order in buildOrders.OrderBy(entry => entry.Order))
            {
                var pieceType = order.PieceType;
                var index = (int)pieceType;
                if (index < 0 || index >= slotCount)
                {
                    continue;
                }

                elements[index] = ResolveElement(template, pieceType);
            }

            foreach (var order in buildOrders)
            {
                var index = (int)order.PieceType;
                if (index < 0 || index >= slotCount)
                {
                    return false;
                }

                var element = elements[index];
                if (element == null || !element.IsValid)
                {
                    return false;
                }
            }

            var name = template.GetName();
            if (name == null || string.IsNullOrEmpty(name.ToString()))
            {
                name = new TextObject(template.StringId ?? "weapon");
            }

            design = new WeaponDesign(template, name, elements, template.StringId ?? template.Id.ToString());
            return design != null;
        }

        private static int GetPieceSlotCount()
        {
            return (int)CraftingPiece.PieceTypes.NumberOfPieceTypes;
        }

        private static WeaponDesignElement ResolveElement(CraftingTemplate template, CraftingPiece.PieceTypes pieceType)
        {
            var piece = template.Pieces?
                .FirstOrDefault(candidate =>
                    candidate != null
                    && candidate.IsValid
                    && candidate.PieceType == pieceType
                    && template.IsPieceTypeUsable(pieceType));

            if (piece != null)
            {
                return WeaponDesignElement.CreateUsablePiece(piece, DefaultScalePercentage);
            }

            return WeaponDesignElement.GetInvalidPieceForType(pieceType);
        }

        private static int SumMaterialCost(int[] costs, TaleWorlds.CampaignSystem.ComponentInterfaces.SmithingModel model)
        {
            var total = 0;
            var limit = Math.Min(costs.Length, (int)CraftingMaterials.NumCraftingMats);

            for (var index = 0; index < limit; index++)
            {
                var amount = costs[index];
                if (amount <= 0)
                {
                    continue;
                }

                var material = (CraftingMaterials)index;
                var item = model.GetCraftingMaterialItem(material);
                var unitValue = item?.Value ?? HeuristicMaterialUnitValue(material);
                total += amount * unitValue;
            }

            return total;
        }

        private static int ComputeRarePenalty(
            int[] costs,
            TaleWorlds.CampaignSystem.ComponentInterfaces.SmithingModel model)
        {
            var rareUnits = 0;
            var rareMaterials = new[]
            {
                CraftingMaterials.Iron4,
                CraftingMaterials.Iron5,
                CraftingMaterials.Iron6
            };

            foreach (var material in rareMaterials)
            {
                var index = (int)material;
                if (index < costs.Length)
                {
                    rareUnits += costs[index];
                }
            }

            if (rareUnits <= 0)
            {
                return 0;
            }

            var iron6Item = model.GetCraftingMaterialItem(CraftingMaterials.Iron6);
            var unitPenalty = iron6Item?.Value ?? 450;
            return rareUnits * unitPenalty;
        }

        private static int EstimateValueFromDesign(
            CraftingTemplate template,
            WeaponDesign design,
            int materialCost,
            int difficulty)
        {
            var statBonus = 0f;
            var weaponDescription = template.WeaponDescriptions?.FirstOrDefault();
            if (weaponDescription != null)
            {
                try
                {
                    var stats = template.GetStatDatas(
                        weaponDescription.StringId,
                        DamageTypes.Invalid,
                        DamageTypes.Invalid);

                    foreach (var stat in stats)
                    {
                        if (stat.Key == CraftingTemplate.CraftingStatTypes.SwingDamage
                            || stat.Key == CraftingTemplate.CraftingStatTypes.ThrustDamage
                            || stat.Key == CraftingTemplate.CraftingStatTypes.MissileDamage)
                        {
                            statBonus += stat.Value;
                        }
                    }
                }
                catch
                {
                    // Stats are optional for value estimation.
                }
            }

            return Math.Max(
                materialCost + 200,
                (int)(materialCost * 1.75f + difficulty * 120f + statBonus * 35f));
        }

        private static ForgeRecipeEconomicsResult HeuristicEstimate(
            CraftingTemplate template,
            Hero hero,
            string reason)
        {
            var itemType = template?.ItemType ?? ItemObject.ItemTypeEnum.Invalid;
            var tierFactor = 1 + Math.Max(0, (hero?.GetSkillValue(DefaultSkills.Crafting) ?? 0) / 50);

            var baseValue = itemType switch
            {
                ItemObject.ItemTypeEnum.TwoHandedWeapon => 9000,
                ItemObject.ItemTypeEnum.Polearm => 7500,
                ItemObject.ItemTypeEnum.OneHandedWeapon => 5200,
                ItemObject.ItemTypeEnum.Shield => 2800,
                ItemObject.ItemTypeEnum.Thrown => 1800,
                ItemObject.ItemTypeEnum.Bow => 4200,
                ItemObject.ItemTypeEnum.Crossbow => 4800,
                _ => 3500
            };

            var value = baseValue * tierFactor;
            var materialCost = (int)(value * 0.22f);
            var rarePenalty = itemType == ItemObject.ItemTypeEnum.TwoHandedWeapon
                ? (int)(materialCost * 0.18f)
                : (int)(materialCost * 0.08f);

            return new ForgeRecipeEconomicsResult
            {
                Value = value,
                MaterialCost = materialCost,
                RareMaterialPenalty = rarePenalty,
                UsedExactCosts = false,
                Detail = $"heuristic {reason}"
            };
        }

        private static int HeuristicMaterialUnitValue(CraftingMaterials material)
        {
            switch (material)
            {
                case CraftingMaterials.IronOre: return 25;
                case CraftingMaterials.Iron1: return 40;
                case CraftingMaterials.Iron2: return 75;
                case CraftingMaterials.Iron3: return 120;
                case CraftingMaterials.Iron4: return 220;
                case CraftingMaterials.Iron5: return 350;
                case CraftingMaterials.Iron6: return 500;
                case CraftingMaterials.Wood: return 15;
                case CraftingMaterials.Charcoal: return 20;
                default: return 50;
            }
        }
    }
}
