using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools
{
    public static class HeroProgressionDevTools
    {
        private const int SkillXpChunk = 5_000;
        private const int MaxSkillXpIterations = 50;

        public static bool AddSmithingXp(Hero hero, float xpDelta)
        {
            return AddSkillXp(hero, DefaultSkills.Crafting, xpDelta);
        }

        public static bool AddSmithingFocus(Hero hero, int focusDelta)
        {
            return EnsureFocus(hero, DefaultSkills.Crafting, GetCurrentFocus(hero, DefaultSkills.Crafting) + focusDelta);
        }

        public static bool AddEnduranceAttribute(Hero hero, int attributeDelta)
        {
            return EnsureAttribute(
                hero,
                DefaultCharacterAttributes.Endurance,
                GetCurrentAttribute(hero, DefaultCharacterAttributes.Endurance) + attributeDelta);
        }

        public static bool AddSkillXp(Hero hero, SkillObject skill, float xpDelta)
        {
            if (hero?.HeroDeveloper == null || skill == null || xpDelta <= 0)
            {
                return false;
            }

            try
            {
                hero.HeroDeveloper.AddSkillXp(skill, xpDelta, false, false);
                return true;
            }
            catch
            {
                return false;
            }
        }

        public static bool EnsureAttribute(Hero hero, CharacterAttribute attribute, int target)
        {
            if (hero?.HeroDeveloper == null || attribute == null)
            {
                return false;
            }

            try
            {
                var current = hero.GetAttributeValue(attribute);
                var delta = target - current;
                if (delta <= 0)
                {
                    return true;
                }

                var developer = hero.HeroDeveloper;
                if (developer.UnspentAttributePoints < delta)
                {
                    developer.UnspentAttributePoints += delta - developer.UnspentAttributePoints;
                }

                developer.AddAttribute(attribute, delta, false);
                return hero.GetAttributeValue(attribute) >= target;
            }
            catch
            {
                return false;
            }
        }

        public static bool EnsureFocus(Hero hero, SkillObject skill, int target)
        {
            if (hero?.HeroDeveloper == null || skill == null)
            {
                return false;
            }

            try
            {
                var developer = hero.HeroDeveloper;
                var current = developer.GetFocus(skill);
                var delta = target - current;
                if (delta <= 0)
                {
                    return true;
                }

                if (developer.UnspentFocusPoints < delta)
                {
                    developer.UnspentFocusPoints += delta - developer.UnspentFocusPoints;
                }

                developer.AddFocus(skill, delta, false);
                return developer.GetFocus(skill) >= target;
            }
            catch
            {
                return false;
            }
        }

        public static bool EnsureSkillFloor(Hero hero, SkillObject skill, int targetLevel)
        {
            if (hero?.HeroDeveloper == null || skill == null || targetLevel <= 0)
            {
                return false;
            }

            try
            {
                if (hero.GetSkillValue(skill) >= targetLevel)
                {
                    return true;
                }

                for (var iteration = 0; iteration < MaxSkillXpIterations; iteration++)
                {
                    if (hero.GetSkillValue(skill) >= targetLevel)
                    {
                        return true;
                    }

                    if (!AddSkillXp(hero, skill, SkillXpChunk))
                    {
                        return false;
                    }
                }

                return hero.GetSkillValue(skill) >= targetLevel;
            }
            catch
            {
                return false;
            }
        }

        private static int GetCurrentFocus(Hero hero, SkillObject skill)
        {
            try
            {
                return hero?.HeroDeveloper?.GetFocus(skill) ?? 0;
            }
            catch
            {
                return 0;
            }
        }

        private static int GetCurrentAttribute(Hero hero, CharacterAttribute attribute)
        {
            try
            {
                return hero?.GetAttributeValue(attribute) ?? 0;
            }
            catch
            {
                return 0;
            }
        }
    }
}
