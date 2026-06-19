using System.Collections.Generic;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class AutoCharacterBuildProfile
    {
        public const string DefaultProfileId = "ForgeQuartermasterWarlord";

        public string Id { get; set; }

        public string DisplayName { get; set; }

        public string Description { get; set; }

        public AutoCharacterBuildModeKind ModeKind { get; set; }

        public bool IsDefault { get; set; }

        public IReadOnlyDictionary<CharacterAttribute, int> AttributeTargets { get; set; }

        public IReadOnlyDictionary<SkillObject, int> FocusTargets { get; set; }

        public IReadOnlyDictionary<SkillObject, int> SkillFloorTargets { get; set; }
    }
}
