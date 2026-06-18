using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools
{
    public sealed class CharacterProgressionSnapshot
    {
        public int Gold { get; private set; }
        public int SmithingSkillLevel { get; private set; }
        public float SmithingXp { get; private set; }
        public int SmithingFocus { get; private set; }
        public int Endurance { get; private set; }
        public int UnspentFocusPoints { get; private set; }
        public int UnspentAttributePoints { get; private set; }

        public bool SmithingSkillAvailable { get; private set; }
        public bool SmithingXpAvailable { get; private set; }
        public bool SmithingFocusAvailable { get; private set; }
        public bool EnduranceAvailable { get; private set; }
        public bool UnspentFocusAvailable { get; private set; }
        public bool UnspentAttributeAvailable { get; private set; }

        public static CharacterProgressionSnapshot Capture(Hero hero)
        {
            var snapshot = new CharacterProgressionSnapshot();

            if (hero == null)
            {
                return snapshot;
            }

            snapshot.Gold = hero.Gold;

            try
            {
                snapshot.SmithingSkillLevel = hero.GetSkillValue(DefaultSkills.Crafting);
                snapshot.SmithingSkillAvailable = true;
            }
            catch
            {
                snapshot.SmithingSkillAvailable = false;
            }

            var developer = hero.HeroDeveloper;
            if (developer == null)
            {
                return snapshot;
            }

            try
            {
                snapshot.SmithingXp = developer.GetSkillXp(DefaultSkills.Crafting);
                snapshot.SmithingXpAvailable = true;
            }
            catch
            {
                snapshot.SmithingXpAvailable = false;
            }

            try
            {
                snapshot.SmithingFocus = developer.GetFocus(DefaultSkills.Crafting);
                snapshot.SmithingFocusAvailable = true;
            }
            catch
            {
                snapshot.SmithingFocusAvailable = false;
            }

            try
            {
                snapshot.Endurance = hero.GetAttributeValue(DefaultCharacterAttributes.Endurance);
                snapshot.EnduranceAvailable = true;
            }
            catch
            {
                snapshot.EnduranceAvailable = false;
            }

            try
            {
                snapshot.UnspentFocusPoints = developer.UnspentFocusPoints;
                snapshot.UnspentFocusAvailable = true;
            }
            catch
            {
                snapshot.UnspentFocusAvailable = false;
            }

            try
            {
                snapshot.UnspentAttributePoints = developer.UnspentAttributePoints;
                snapshot.UnspentAttributeAvailable = true;
            }
            catch
            {
                snapshot.UnspentAttributeAvailable = false;
            }

            return snapshot;
        }

        public void Log(string label)
        {
            DebugLogger.Test($"{label} gold: {Gold:N0}", showInGame: false);

            if (SmithingSkillAvailable)
            {
                DebugLogger.Test($"{label} smithing skill level: {SmithingSkillLevel}", showInGame: false);
            }
            else
            {
                DebugLogger.Test($"{label} smithing skill level: unavailable", showInGame: false);
            }

            if (SmithingXpAvailable)
            {
                DebugLogger.Test($"{label} smithing XP: {SmithingXp:N0}", showInGame: false);
            }
            else
            {
                DebugLogger.Test($"{label} smithing XP: unavailable", showInGame: false);
            }

            if (SmithingFocusAvailable)
            {
                DebugLogger.Test($"{label} smithing focus: {SmithingFocus}", showInGame: false);
            }
            else
            {
                DebugLogger.Test($"{label} smithing focus: unavailable", showInGame: false);
            }

            if (EnduranceAvailable)
            {
                DebugLogger.Test($"{label} endurance: {Endurance}", showInGame: false);
            }
            else
            {
                DebugLogger.Test($"{label} endurance: unavailable", showInGame: false);
            }

            if (UnspentFocusAvailable)
            {
                DebugLogger.Test($"{label} unspent focus points: {UnspentFocusPoints}", showInGame: false);
            }

            if (UnspentAttributeAvailable)
            {
                DebugLogger.Test($"{label} unspent attribute points: {UnspentAttributePoints}", showInGame: false);
            }
        }

        public bool AnyProgressionChanged(CharacterProgressionSnapshot after)
        {
            if (SmithingXpAvailable && after.SmithingXpAvailable && SmithingXp != after.SmithingXp)
            {
                return true;
            }

            if (SmithingSkillAvailable && after.SmithingSkillAvailable &&
                SmithingSkillLevel != after.SmithingSkillLevel)
            {
                return true;
            }

            if (SmithingFocusAvailable && after.SmithingFocusAvailable &&
                SmithingFocus != after.SmithingFocus)
            {
                return true;
            }

            if (EnduranceAvailable && after.EnduranceAvailable && Endurance != after.Endurance)
            {
                return true;
            }

            return false;
        }
    }
}
