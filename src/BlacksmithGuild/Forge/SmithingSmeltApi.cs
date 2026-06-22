using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.CampaignBehaviors;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingSmeltApi
    {
        private static MethodInfo _doSmeltingMethod;
        private static MethodInfo _isItemSmeltableMethod;
        private static bool _methodsResolved;
        private static readonly List<string> ProbeHints = new List<string>();

        public static IReadOnlyList<string> LastProbeHints => ProbeHints;
        public static bool DoSmeltingMapped => _doSmeltingMethod != null;
        public static string LastMappedSignature { get; private set; }

        public static bool RunSmeltApiProbe(out string detail)
        {
            detail = null;
            ProbeHints.Clear();
            _methodsResolved = false;
            _doSmeltingMethod = null;
            _isItemSmeltableMethod = null;
            LastMappedSignature = null;

            if (Campaign.Current == null)
            {
                detail = "campaign unavailable";
                return false;
            }

            var behavior = Campaign.Current.GetCampaignBehavior<CraftingCampaignBehavior>();
            if (behavior == null)
            {
                detail = "CraftingCampaignBehavior not found";
                return false;
            }

            foreach (var member in behavior.GetType().GetMembers(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var name = member.Name ?? string.Empty;
                if (name.IndexOf("Smelt", StringComparison.OrdinalIgnoreCase) >= 0
                    || name.IndexOf("Recycle", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    ProbeHints.Add($"CraftingCampaignBehavior.{name} ({member.MemberType})");
                }
            }

            ResolveMethods(behavior.GetType());
            ResolveSmithingModelMethods();

            if (_doSmeltingMethod == null)
            {
                detail = "DoSmelting not exposed";
                return false;
            }

            detail = $"DoSmelting mapped ({LastMappedSignature}); hints={ProbeHints.Count}";
            return true;
        }

        public static bool CanInvokeSmeltWeapon(Hero hero, ItemObject item, out string detail)
        {
            detail = null;

            if (hero == null)
            {
                detail = "hero unavailable";
                return false;
            }

            if (item == null)
            {
                detail = "item unavailable";
                return false;
            }

            if (!EnsureMethodsResolved())
            {
                detail = "DoSmelting not exposed";
                return false;
            }

            if (!IsSmeltable(item, out var smeltDetail))
            {
                detail = smeltDetail ?? "item not smeltable";
                return false;
            }

            return true;
        }

        public static bool TryInvokeSmeltWeapon(Hero hero, ItemObject item, out string detail)
        {
            detail = null;

            if (!CanInvokeSmeltWeapon(hero, item, out detail))
            {
                return false;
            }

            var behavior = Campaign.Current?.GetCampaignBehavior<CraftingCampaignBehavior>();
            if (behavior == null)
            {
                detail = "CraftingCampaignBehavior unavailable";
                return false;
            }

            try
            {
                var equipmentElement = new EquipmentElement(item);
                var args = BuildInvokeArgs(hero, equipmentElement, item);
                _doSmeltingMethod.Invoke(behavior, args);
                detail = $"smelted {item.Name}";
                return true;
            }
            catch (Exception ex)
            {
                detail = ex.InnerException?.Message ?? ex.Message;
                return false;
            }
        }

        private static object[] BuildInvokeArgs(Hero hero, EquipmentElement equipmentElement, ItemObject item)
        {
            var parameters = _doSmeltingMethod.GetParameters();
            if (parameters.Length == 0)
            {
                return Array.Empty<object>();
            }

            if (parameters.Length == 1)
            {
                if (parameters[0].ParameterType == typeof(EquipmentElement))
                {
                    return new object[] { equipmentElement };
                }

                if (parameters[0].ParameterType == typeof(ItemObject))
                {
                    return new object[] { item };
                }
            }

            if (parameters.Length >= 2)
            {
                if (parameters[0].ParameterType == typeof(Hero))
                {
                    if (parameters[1].ParameterType == typeof(EquipmentElement))
                    {
                        return new object[] { hero, equipmentElement };
                    }

                    if (parameters[1].ParameterType == typeof(ItemObject))
                    {
                        return new object[] { hero, item };
                    }
                }
            }

            return new object[] { hero, equipmentElement };
        }

        private static bool IsSmeltable(ItemObject item, out string detail)
        {
            detail = null;

            if (_isItemSmeltableMethod != null)
            {
                try
                {
                    var smithingModel = ResolveSmithingModel();
                    if (smithingModel == null)
                    {
                        detail = "smithing model unavailable";
                        return false;
                    }

                    var parameters = _isItemSmeltableMethod.GetParameters();
                    if (parameters.Length == 1)
                    {
                        var result = _isItemSmeltableMethod.Invoke(smithingModel, new object[] { item });
                        if (result is bool boolValue)
                        {
                            if (!boolValue)
                            {
                                detail = "smithing model rejected item";
                            }

                            return boolValue;
                        }
                    }
                }
                catch (Exception ex)
                {
                    detail = ex.InnerException?.Message ?? ex.Message;
                    return false;
                }
            }

            return SmithingLootWeaponScanner.IsWeaponItem(item);
        }

        private static bool EnsureMethodsResolved()
        {
            if (_methodsResolved)
            {
                return _doSmeltingMethod != null;
            }

            _methodsResolved = true;
            var behavior = Campaign.Current?.GetCampaignBehavior<CraftingCampaignBehavior>();
            if (behavior != null)
            {
                ResolveMethods(behavior.GetType());
            }

            ResolveSmithingModelMethods();
            return _doSmeltingMethod != null;
        }

        private static void ResolveMethods(Type behaviorType)
        {
            foreach (var method in behaviorType.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var name = method.Name ?? string.Empty;
                if (name.IndexOf("DoSmelt", StringComparison.OrdinalIgnoreCase) < 0
                    && name.IndexOf("Smelt", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                if (name.IndexOf("Refin", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    continue;
                }

                var parameters = method.GetParameters();
                if (parameters.Length == 0 || parameters.Length > 3)
                {
                    continue;
                }

                _doSmeltingMethod = method;
                LastMappedSignature = string.Join(
                    ", ",
                    parameters.Select(parameter => parameter.ParameterType.Name));
                return;
            }
        }

        private static void ResolveSmithingModelMethods()
        {
            var smithingModel = ResolveSmithingModel();
            if (smithingModel == null)
            {
                return;
            }

            foreach (var method in smithingModel.GetType().GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                var name = method.Name ?? string.Empty;
                if (name.IndexOf("Smelt", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    continue;
                }

                if (name.IndexOf("Is", StringComparison.OrdinalIgnoreCase) >= 0
                    && method.GetParameters().Length == 1)
                {
                    _isItemSmeltableMethod = method;
                    ProbeHints.Add($"SmithingModel.{name} (Method)");
                }
            }
        }

        private static object ResolveSmithingModel()
        {
            if (Campaign.Current?.Models == null)
            {
                return null;
            }

            var modelsType = Campaign.Current.Models.GetType();
            foreach (var propertyName in new[] { "SmithingModel", "Smithing" })
            {
                var property = modelsType.GetProperty(
                    propertyName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var value = property?.GetValue(Campaign.Current.Models);
                if (value != null)
                {
                    return value;
                }
            }

            return null;
        }
    }
}
