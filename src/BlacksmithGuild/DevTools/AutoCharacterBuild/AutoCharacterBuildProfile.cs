using System.Collections.Generic;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class AutoCharacterBuildProfile
    {
        public const string DefaultProfileName = "ForgeQuartermasterWarlord";

        public string Name { get; set; } = DefaultProfileName;

        public IReadOnlyDictionary<CharacterAttribute, int> AttributeTargets { get; set; }

        public IReadOnlyDictionary<SkillObject, int> FocusTargets { get; set; }

        public IReadOnlyDictionary<SkillObject, int> SkillFloorTargets { get; set; }

        public static AutoCharacterBuildProfile CreateDefault()
        {
            return new AutoCharacterBuildProfile
            {
                Name = DefaultProfileName,
                AttributeTargets = new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Intelligence, 7 },
                    { DefaultCharacterAttributes.Endurance, 7 },
                    { DefaultCharacterAttributes.Social, 6 },
                    { DefaultCharacterAttributes.Cunning, 3 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                FocusTargets = new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 5 },
                    { DefaultSkills.Crafting, 5 },
                    { DefaultSkills.Leadership, 5 },
                    { DefaultSkills.Medicine, 3 },
                    { DefaultSkills.Engineering, 3 },
                    { DefaultSkills.Charm, 3 },
                    { DefaultSkills.Trade, 2 },
                    { DefaultSkills.Athletics, 2 },
                    { DefaultSkills.Riding, 2 },
                    { DefaultSkills.Scouting, 1 },
                    { DefaultSkills.Tactics, 1 }
                },
                SkillFloorTargets = new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 75 },
                    { DefaultSkills.Crafting, 75 },
                    { DefaultSkills.Leadership, 50 },
                    { DefaultSkills.Medicine, 40 },
                    { DefaultSkills.Engineering, 40 },
                    { DefaultSkills.Charm, 40 },
                    { DefaultSkills.Trade, 25 },
                    { DefaultSkills.Athletics, 25 },
                    { DefaultSkills.Riding, 25 }
                }
            };
        }
    }
}
