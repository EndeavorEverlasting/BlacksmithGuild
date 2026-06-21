using System.Collections.Generic;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class HeroBuildSnapshotCapture
    {
        public Dictionary<string, int> Attributes { get; } = new Dictionary<string, int>();
        public Dictionary<string, int> Focus { get; } = new Dictionary<string, int>();
        public Dictionary<string, int> Skills { get; } = new Dictionary<string, int>();
        public int Gold { get; set; }
        public int Renown { get; set; }
        public string EquipmentSummary { get; set; }

        public static HeroBuildSnapshotCapture CaptureFull(Hero hero)
        {
            var snapshot = new HeroBuildSnapshotCapture();
            if (hero == null)
            {
                return snapshot;
            }

            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Vigor);
            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Control);
            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Endurance);
            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Cunning);
            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Social);
            TryCaptureAttribute(hero, snapshot.Attributes, DefaultCharacterAttributes.Intelligence);

            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.OneHanded);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.TwoHanded);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Polearm);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Bow);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Crossbow);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Throwing);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Riding);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Athletics);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Crafting);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Tactics);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Scouting);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Roguery);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Charm);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Leadership);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Trade);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Steward);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Medicine);
            TryCaptureSkill(hero, snapshot.Skills, DefaultSkills.Engineering);

            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Crafting);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Trade);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Steward);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Leadership);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Riding);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Polearm);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Charm);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Tactics);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Roguery);
            TryCaptureFocus(hero, snapshot.Focus, DefaultSkills.Medicine);

            try
            {
                snapshot.Gold = hero.Gold;
            }
            catch
            {
            }

            try
            {
                snapshot.Renown = (int)hero.Clan?.Renown;
            }
            catch
            {
            }

            snapshot.EquipmentSummary = BuildEquipmentSummary(hero);
            return snapshot;
        }

        public void CopySkillsTo(Dictionary<string, int> target)
        {
            CopyTo(Skills, target);
        }

        public void CopyAttributesTo(Dictionary<string, int> target)
        {
            CopyTo(Attributes, target);
        }

        public void CopyFocusTo(Dictionary<string, int> target)
        {
            CopyTo(Focus, target);
        }

        private static void CopyTo(Dictionary<string, int> source, Dictionary<string, int> target)
        {
            target.Clear();
            foreach (var entry in source)
            {
                target[entry.Key] = entry.Value;
            }
        }

        private static void TryCaptureAttribute(
            Hero hero,
            Dictionary<string, int> target,
            CharacterAttribute attribute)
        {
            try
            {
                target[attribute.StringId] = hero.GetAttributeValue(attribute);
            }
            catch
            {
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
            }
        }

        private static string BuildEquipmentSummary(Hero hero)
        {
            try
            {
                var battle = hero.BattleEquipment;
                if (battle == null)
                {
                    return "unavailable";
                }

                var parts = new List<string>();
                for (var slot = 0; slot < 12; slot++)
                {
                    var element = battle[slot];
                    if (element.Item == null)
                    {
                        continue;
                    }

                    parts.Add(element.Item.Name?.ToString() ?? element.Item.StringId);
                }

                return parts.Count == 0 ? "empty" : string.Join(", ", parts);
            }
            catch
            {
                return "unavailable";
            }
        }
    }
}
