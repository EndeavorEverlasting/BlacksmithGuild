using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools
{
    public static class HeroProgressionDevTools
    {
        public static bool AddSmithingXp(Hero hero, float xpDelta)
        {
            if (hero?.HeroDeveloper == null)
            {
                return false;
            }

            hero.HeroDeveloper.AddSkillXp(DefaultSkills.Crafting, xpDelta, false, false);
            return true;
        }

        public static bool AddSmithingFocus(Hero hero, int focusDelta)
        {
            if (hero?.HeroDeveloper == null)
            {
                return false;
            }

            var developer = hero.HeroDeveloper;
            if (developer.UnspentFocusPoints < focusDelta)
            {
                developer.UnspentFocusPoints += focusDelta;
            }

            developer.AddFocus(DefaultSkills.Crafting, focusDelta, false);
            return true;
        }

        public static bool AddEnduranceAttribute(Hero hero, int attributeDelta)
        {
            if (hero?.HeroDeveloper == null)
            {
                return false;
            }

            var developer = hero.HeroDeveloper;
            if (developer.UnspentAttributePoints < attributeDelta)
            {
                developer.UnspentAttributePoints += attributeDelta;
            }

            developer.AddAttribute(DefaultCharacterAttributes.Endurance, attributeDelta, false);
            return true;
        }
    }
}
