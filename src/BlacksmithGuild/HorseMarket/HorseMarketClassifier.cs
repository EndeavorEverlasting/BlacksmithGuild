using System;
using TaleWorlds.Core;

namespace BlacksmithGuild.HorseMarket
{
    public static class HorseMarketClassifier
    {
        public sealed class ClassificationResult
        {
            public HorseAnimalClassification Classification { get; set; }
            public ClassificationConfidence Confidence { get; set; }
            public string Reason { get; set; }
        }

        public static bool IsHorseOrAnimalCandidate(ItemObject item)
        {
            if (item == null)
            {
                return false;
            }

            try
            {
                if (item.ItemType == ItemObject.ItemTypeEnum.Horse)
                {
                    return true;
                }
            }
            catch
            {
                // Continue with other heuristics.
            }

            try
            {
                if (item.HorseComponent != null)
                {
                    return true;
                }
            }
            catch
            {
                // Continue with other heuristics.
            }

            var categoryId = GetCategoryId(item);
            if (ContainsAny(categoryId, "horse", "animal", "livestock", "camel", "mule"))
            {
                return true;
            }

            var stringId = item.StringId ?? string.Empty;
            var name = item.Name?.ToString() ?? string.Empty;
            return ContainsAny(stringId, "horse", "mule", "camel", "sumpter", "donkey")
                   || ContainsAny(name, "horse", "mule", "camel", "sumpter", "donkey");
        }

        public static ClassificationResult Classify(ItemObject item)
        {
            if (item == null)
            {
                return Unknown("item is null");
            }

            var stringId = item.StringId ?? string.Empty;
            var name = item.Name?.ToString() ?? string.Empty;
            var categoryId = GetCategoryId(item);
            var combined = $"{stringId} {name} {categoryId}".ToLowerInvariant();

            if (ContainsAny(categoryId, "livestock") && !HasHorseComponent(item))
            {
                return Result(
                    HorseAnimalClassification.Livestock,
                    ClassificationConfidence.High,
                    "item category indicates livestock");
            }

            if (ContainsAny(combined, "noble"))
            {
                return Result(
                    HorseAnimalClassification.NobleMount,
                    ClassificationConfidence.Medium,
                    "runtime id/name/category contains noble");
            }

            if (ContainsAny(combined, "war"))
            {
                return Result(
                    HorseAnimalClassification.WarMount,
                    ClassificationConfidence.Medium,
                    "runtime id/name/category contains war");
            }

            if (ContainsAny(combined, "mule", "sumpter", "pack", "camel", "donkey"))
            {
                return Result(
                    HorseAnimalClassification.PackAnimal,
                    ClassificationConfidence.Medium,
                    "runtime id/name/category suggests pack animal");
            }

            if (HasHorseComponent(item))
            {
                var tier = SafeTier(item);
                var maneuver = SafeManeuver(item);
                var charge = SafeChargeDamage(item);

                if (tier >= 3 || charge >= 20f || maneuver >= 50f)
                {
                    return Result(
                        HorseAnimalClassification.WarMount,
                        ClassificationConfidence.Medium,
                        "horse component tier/stats suggest war mount");
                }

                if (tier >= 2)
                {
                    return Result(
                        HorseAnimalClassification.RidingMount,
                        ClassificationConfidence.Medium,
                        "horse component tier suggests riding mount");
                }

                return Result(
                    HorseAnimalClassification.RidingMount,
                    ClassificationConfidence.Low,
                    "horse component present without clear pack/war/noble distinction");
            }

            try
            {
                if (item.ItemType == ItemObject.ItemTypeEnum.Horse)
                {
                    return Result(
                        HorseAnimalClassification.RidingMount,
                        ClassificationConfidence.Low,
                        "item type horse without horse component detail");
                }
            }
            catch
            {
                // Fall through.
            }

            if (ContainsAny(combined, "horse"))
            {
                return Result(
                    HorseAnimalClassification.UnknownHorse,
                    ClassificationConfidence.Low,
                    "horse-like name/id but runtime category did not expose pack/war/noble distinction cleanly");
            }

            return Unknown("item did not match horse/animal heuristics");
        }

        public static float EstimateCapacityContribution(ItemObject item, HorseAnimalClassification classification)
        {
            if (item == null)
            {
                return 0f;
            }

            switch (classification)
            {
                case HorseAnimalClassification.PackAnimal:
                    return Math.Max(10f, item.Weight * 4f);
                case HorseAnimalClassification.RidingMount:
                    return Math.Max(5f, item.Weight * 2f);
                case HorseAnimalClassification.WarMount:
                case HorseAnimalClassification.NobleMount:
                    return Math.Max(3f, item.Weight);
                default:
                    return Math.Max(0f, item.Weight);
            }
        }

        private static ClassificationResult Result(
            HorseAnimalClassification classification,
            ClassificationConfidence confidence,
            string reason)
        {
            return new ClassificationResult
            {
                Classification = classification,
                Confidence = confidence,
                Reason = reason
            };
        }

        private static ClassificationResult Unknown(string reason)
        {
            return Result(HorseAnimalClassification.UnknownHorse, ClassificationConfidence.Low, reason);
        }

        private static bool HasHorseComponent(ItemObject item)
        {
            try
            {
                return item?.HorseComponent != null;
            }
            catch
            {
                return false;
            }
        }

        private static string GetCategoryId(ItemObject item)
        {
            try
            {
                return item?.ItemCategory?.StringId ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }

        private static int SafeTier(ItemObject item)
        {
            try
            {
                return (int)item.Tier;
            }
            catch
            {
                return 0;
            }
        }

        private static float SafeManeuver(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.Maneuver ?? 0f;
            }
            catch
            {
                return 0f;
            }
        }

        private static float SafeChargeDamage(ItemObject item)
        {
            try
            {
                return item.HorseComponent?.ChargeDamage ?? 0f;
            }
            catch
            {
                return 0f;
            }
        }

        private static bool ContainsAny(string haystack, params string[] needles)
        {
            if (string.IsNullOrEmpty(haystack))
            {
                return false;
            }

            foreach (var needle in needles)
            {
                if (haystack.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }

            return false;
        }
    }
}
