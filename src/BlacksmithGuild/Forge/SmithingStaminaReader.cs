using System;
using System.Reflection;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.CampaignBehaviors;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingStaminaReader
    {
        private static MethodInfo _getStaminaMethod;
        private static MethodInfo _setActiveHeroMethod;
        private static bool _methodsResolved;

        public static bool TryReadStamina(Hero hero, out int current, out int max)
        {
            current = 0;
            max = 100;

            if (hero == null || Campaign.Current == null)
            {
                return false;
            }

            if (!EnsureMethodsResolved())
            {
                return false;
            }

            try
            {
                var behavior = Campaign.Current.GetCampaignBehavior<CraftingCampaignBehavior>();
                if (behavior == null || _getStaminaMethod == null)
                {
                    return false;
                }

                var result = _getStaminaMethod.Invoke(behavior, new object[] { hero });
                if (result is float floatValue)
                {
                    current = (int)Math.Max(0, floatValue);
                    max = Math.Max(current, 100);
                    return true;
                }

                if (result is int intValue)
                {
                    current = Math.Max(0, intValue);
                    max = Math.Max(current, 100);
                    return true;
                }
            }
            catch
            {
                return false;
            }

            return false;
        }

        public static bool TrySetActiveCraftingHero(Hero hero, out string detail)
        {
            detail = null;

            if (hero == null || Campaign.Current == null)
            {
                detail = "hero or campaign unavailable";
                return false;
            }

            if (!EnsureMethodsResolved() || _setActiveHeroMethod == null)
            {
                detail = "SetActiveCraftingHero not exposed";
                return false;
            }

            try
            {
                _setActiveHeroMethod.Invoke(
                    Campaign.Current.GetCampaignBehavior<CraftingCampaignBehavior>(),
                    new object[] { hero });
                return true;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                return false;
            }
        }

        public static bool CanInvokeRefineCharcoal(out string detail)
        {
            detail = "RefineCharcoal headless API not mapped — advisory only until Stage C probe succeeds";
            return false;
        }

        private static bool EnsureMethodsResolved()
        {
            if (_methodsResolved)
            {
                return _getStaminaMethod != null;
            }

            _methodsResolved = true;

            try
            {
                var behaviorType = typeof(CraftingCampaignBehavior);
                _getStaminaMethod = behaviorType.GetMethod(
                    "GetHeroCraftingStamina",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);

                _setActiveHeroMethod = behaviorType.GetMethod(
                    "SetActiveCraftingHero",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            }
            catch
            {
                _getStaminaMethod = null;
                _setActiveHeroMethod = null;
            }

            return _getStaminaMethod != null;
        }
    }
}
