using System.Collections.Generic;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class CharacterBuildSnapshot
    {
        public Dictionary<string, int> Attributes { get; } = new Dictionary<string, int>();
        public Dictionary<string, int> Focus { get; } = new Dictionary<string, int>();
        public Dictionary<string, int> Skills { get; } = new Dictionary<string, int>();

        public static CharacterBuildSnapshot Capture(Hero hero, AutoCharacterBuildProfile profile)
        {
            var snapshot = new CharacterBuildSnapshot();

            if (hero == null || profile == null)
            {
                return snapshot;
            }

            foreach (var entry in profile.AttributeTargets)
            {
                TryCaptureAttribute(hero, snapshot.Attributes, entry.Key);
            }

            foreach (var entry in profile.FocusTargets)
            {
                TryCaptureFocus(hero, snapshot.Focus, entry.Key);
            }

            foreach (var entry in profile.SkillFloorTargets)
            {
                TryCaptureSkill(hero, snapshot.Skills, entry.Key);
            }

            return snapshot;
        }

        public void CopyAttributesTo(Dictionary<string, int> target)
        {
            CopyTo(Attributes, target);
        }

        public void CopyFocusTo(Dictionary<string, int> target)
        {
            CopyTo(Focus, target);
        }

        public void CopySkillsTo(Dictionary<string, int> target)
        {
            CopyTo(Skills, target);
        }

        private static void CopyTo(Dictionary<string, int> source, Dictionary<string, int> target)
        {
            target.Clear();
            foreach (var entry in source)
            {
                target[entry.Key] = entry.Value;
            }
        }

        private static void TryCaptureAttribute(Hero hero, Dictionary<string, int> target, CharacterAttribute attribute)
        {
            try
            {
                target[attribute.StringId] = hero.GetAttributeValue(attribute);
            }
            catch
            {
                // Attribute unavailable — omit from snapshot.
            }
        }

        private static void TryCaptureFocus(Hero hero, Dictionary<string, int> target, SkillObject skill)
        {
            var developer = hero.HeroDeveloper;
            if (developer == null)
            {
                return;
            }

            try
            {
                target[skill.StringId] = developer.GetFocus(skill);
            }
            catch
            {
                // Focus unavailable — omit from snapshot.
            }
        }

        private static void TryCaptureSkill(Hero hero, Dictionary<string, int> target, SkillObject skill)
        {
            try
            {
                target[skill.StringId] = hero.GetSkillValue(skill);
            }
            catch
            {
                // Skill unavailable — omit from snapshot.
            }
        }
    }
}
