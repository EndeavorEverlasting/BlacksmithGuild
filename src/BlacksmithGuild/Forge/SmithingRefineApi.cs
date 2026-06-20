using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.CampaignBehaviors;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingRefineApi
    {
        private const int WoodMaterial = 7;
        private const int CharcoalMaterial = 8;

        private static MethodInfo _doRefinementMethod;
        private static MethodInfo _getRefiningFormulasMethod;
        private static Type _refiningFormulaType;
        private static bool _methodsResolved;
        private static readonly List<string> ProbeHints = new List<string>();

        public static IReadOnlyList<string> LastProbeHints => ProbeHints;

        public static bool RunRefineApiProbe(out string detail)
        {
            detail = null;
            ProbeHints.Clear();
            _methodsResolved = false;
            _doRefinementMethod = null;
            _getRefiningFormulasMethod = null;
            _refiningFormulaType = null;

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
                if (name.IndexOf("Refin", StringComparison.OrdinalIgnoreCase) >= 0
                    || name.IndexOf("Smelt", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    ProbeHints.Add($"CraftingCampaignBehavior.{name} ({member.MemberType})");
                }
            }

            ResolveMethods(behavior.GetType());
            ResolveSmithingModelMethods();

            if (_doRefinementMethod == null)
            {
                detail = "DoRefinement not exposed";
                return false;
            }

            detail = $"DoRefinement mapped; formulaType={_refiningFormulaType?.FullName ?? "unknown"}; hints={ProbeHints.Count}";
            return true;
        }

        public static bool CanInvokeRefineCharcoal(Hero hero, out string detail)
        {
            detail = null;

            if (hero == null)
            {
                detail = "hero unavailable";
                return false;
            }

            if (!EnsureMethodsResolved())
            {
                detail = _doRefinementMethod == null
                    ? "DoRefinement not exposed"
                    : "GetRefiningFormulas not exposed";
                return false;
            }

            if (!TryFindHardwoodToCharcoalFormula(hero, out _, out var formulaDetail))
            {
                detail = formulaDetail ?? "hardwood→charcoal formula not found";
                return false;
            }

            return true;
        }

        public static bool TryInvokeRefineCharcoal(Hero hero, int count, out string detail)
        {
            detail = null;

            if (count <= 0)
            {
                detail = "refine count must be positive";
                return false;
            }

            if (!CanInvokeRefineCharcoal(hero, out detail))
            {
                return false;
            }

            if (!TryFindHardwoodToCharcoalFormula(hero, out var formula, out detail))
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
                for (var i = 0; i < count; i++)
                {
                    _doRefinementMethod.Invoke(behavior, new[] { hero, formula });
                }

                detail = $"refined x{count}";
                return true;
            }
            catch (Exception ex)
            {
                detail = ex.InnerException?.Message ?? ex.Message;
                return false;
            }
        }

        private static bool TryFindHardwoodToCharcoalFormula(Hero hero, out object formula, out string detail)
        {
            formula = null;
            detail = null;

            if (_getRefiningFormulasMethod == null || hero == null)
            {
                detail = "GetRefiningFormulas unavailable";
                return false;
            }

            try
            {
                var smithingModel = ResolveSmithingModel();
                if (smithingModel == null)
                {
                    detail = "Smithing model unavailable";
                    return false;
                }

                var formulasObj = _getRefiningFormulasMethod.Invoke(smithingModel, new object[] { hero });
                if (!(formulasObj is System.Collections.IEnumerable formulas))
                {
                    detail = "GetRefiningFormulas returned no enumerable";
                    return false;
                }

                foreach (var candidate in formulas)
                {
                    if (candidate == null || !MatchesHardwoodToCharcoal(candidate))
                    {
                        continue;
                    }

                    formula = candidate;
                    return true;
                }

                detail = "hardwood→charcoal formula not in GetRefiningFormulas";
                return false;
            }
            catch (Exception ex)
            {
                detail = ex.InnerException?.Message ?? ex.Message;
                return false;
            }
        }

        private static bool MatchesHardwoodToCharcoal(object formula)
        {
            if (formula == null)
            {
                return false;
            }

            var type = formula.GetType();
            var input1 = ReadEnumInt(type.GetProperty("Input1")?.GetValue(formula));
            var output = ReadEnumInt(type.GetProperty("Output")?.GetValue(formula));
            var input2 = ReadEnumInt(type.GetProperty("Input2")?.GetValue(formula));
            var input2Count = ReadInt(type.GetProperty("Input2Count")?.GetValue(formula));

            return input1 == WoodMaterial
                && output == CharcoalMaterial
                && (input2 < 0 || input2Count <= 0);
        }

        private static bool EnsureMethodsResolved()
        {
            if (_methodsResolved)
            {
                return _doRefinementMethod != null && _getRefiningFormulasMethod != null;
            }

            _methodsResolved = true;

            var behavior = Campaign.Current?.GetCampaignBehavior<CraftingCampaignBehavior>();
            if (behavior != null)
            {
                ResolveMethods(behavior.GetType());
            }

            ResolveSmithingModelMethods();
            return _doRefinementMethod != null && _getRefiningFormulasMethod != null;
        }

        private static void ResolveMethods(Type behaviorType)
        {
            _doRefinementMethod = behaviorType.GetMethod(
                "DoRefinement",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

            if (_doRefinementMethod != null)
            {
                var parameters = _doRefinementMethod.GetParameters();
                if (parameters.Length >= 2)
                {
                    _refiningFormulaType = parameters[1].ParameterType;
                }
            }
        }

        private static void ResolveSmithingModelMethods()
        {
            var smithingModel = ResolveSmithingModel();
            if (smithingModel == null)
            {
                return;
            }

            _getRefiningFormulasMethod = smithingModel.GetType().GetMethod(
                "GetRefiningFormulas",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
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

        private static int ReadEnumInt(object value)
        {
            if (value == null)
            {
                return -1;
            }

            try
            {
                return Convert.ToInt32(value);
            }
            catch
            {
                return -1;
            }
        }

        private static int ReadInt(object value)
        {
            if (value == null)
            {
                return 0;
            }

            try
            {
                return Convert.ToInt32(value);
            }
            catch
            {
                return 0;
            }
        }
    }
}
