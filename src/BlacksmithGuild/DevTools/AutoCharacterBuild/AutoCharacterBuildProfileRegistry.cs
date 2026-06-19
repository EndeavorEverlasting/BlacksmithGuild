using System;
using System.Collections.Generic;
using System.Linq;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class AutoCharacterBuildProfileRegistry
    {
        public const string DefaultProfileId = AutoCharacterBuildProfile.DefaultProfileId;

        private static readonly Dictionary<string, AutoCharacterBuildProfile> Profiles =
            new Dictionary<string, AutoCharacterBuildProfile>(StringComparer.OrdinalIgnoreCase);

        private static string _selectedProfileId = DefaultProfileId;

        static AutoCharacterBuildProfileRegistry()
        {
            Register(BuildForgeQuartermasterWarlord());
            Register(BuildSmithEconomist());
            Register(BuildKingdomFounder());
            Register(BuildStewardSurgeonEngineer());
            Register(BuildWarCaptain());
            Register(BuildLightTouchVanillaPlus());
            Register(BuildShadowTrader());
        }

        public static AutoCharacterBuildProfile GetSelectedProfile()
        {
            return TryGetProfile(_selectedProfileId, out var profile)
                ? profile
                : Profiles[DefaultProfileId];
        }

        public static bool SetSelectedProfile(string profileId, out string error)
        {
            error = null;
            if (string.IsNullOrWhiteSpace(profileId))
            {
                error = "Profile id is required.";
                return false;
            }

            if (!Profiles.ContainsKey(profileId))
            {
                error = $"Unknown profile id: {profileId}";
                return false;
            }

            _selectedProfileId = profileId;
            return true;
        }

        public static bool TryGetProfile(string profileId, out AutoCharacterBuildProfile profile)
        {
            return Profiles.TryGetValue(profileId ?? string.Empty, out profile);
        }

        public static IReadOnlyList<AutoCharacterBuildProfile> GetAllProfiles()
        {
            return Profiles.Values.OrderBy(entry => entry.Id, StringComparer.OrdinalIgnoreCase).ToList();
        }

        public static IReadOnlyList<string> GetAllProfileIds()
        {
            return GetAllProfiles().Select(profile => profile.Id).ToList();
        }

        public static string GetAvailableProfilesCsv()
        {
            return string.Join(", ", GetAllProfileIds());
        }

        private static void Register(AutoCharacterBuildProfile profile)
        {
            Profiles[profile.Id] = profile;
        }

        private static AutoCharacterBuildProfile Build(
            string id,
            string description,
            AutoCharacterBuildModeKind modeKind,
            bool isDefault,
            Dictionary<CharacterAttribute, int> attributes,
            Dictionary<SkillObject, int> focus,
            Dictionary<SkillObject, int> floors)
        {
            return new AutoCharacterBuildProfile
            {
                Id = id,
                DisplayName = id,
                Description = description,
                ModeKind = modeKind,
                IsDefault = isDefault,
                AttributeTargets = attributes,
                FocusTargets = focus,
                SkillFloorTargets = floors
            };
        }

        private static AutoCharacterBuildProfile BuildForgeQuartermasterWarlord()
        {
            return Build(
                DefaultProfileId,
                "Smithing economy + party logistics + leadership scaling.",
                AutoCharacterBuildModeKind.QuartermasterWarlord,
                isDefault: true,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Intelligence, 8 },
                    { DefaultCharacterAttributes.Endurance, 8 },
                    { DefaultCharacterAttributes.Social, 7 },
                    { DefaultCharacterAttributes.Cunning, 4 },
                    { DefaultCharacterAttributes.Vigor, 3 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 5 },
                    { DefaultSkills.Crafting, 5 },
                    { DefaultSkills.Leadership, 5 },
                    { DefaultSkills.Medicine, 3 },
                    { DefaultSkills.Engineering, 3 },
                    { DefaultSkills.Charm, 3 },
                    { DefaultSkills.Trade, 3 },
                    { DefaultSkills.Athletics, 2 },
                    { DefaultSkills.Riding, 2 },
                    { DefaultSkills.Scouting, 2 },
                    { DefaultSkills.Tactics, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 100 },
                    { DefaultSkills.Crafting, 100 },
                    { DefaultSkills.Leadership, 75 },
                    { DefaultSkills.Medicine, 50 },
                    { DefaultSkills.Engineering, 50 },
                    { DefaultSkills.Charm, 50 },
                    { DefaultSkills.Trade, 40 },
                    { DefaultSkills.Athletics, 30 },
                    { DefaultSkills.Riding, 30 },
                    { DefaultSkills.Scouting, 25 },
                    { DefaultSkills.Tactics, 25 }
                });
        }

        private static AutoCharacterBuildProfile BuildSmithEconomist()
        {
            return Build(
                "SmithEconomist",
                "Forge-money loop: Crafting, Trade, and Steward.",
                AutoCharacterBuildModeKind.SmithEconomist,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Endurance, 10 },
                    { DefaultCharacterAttributes.Social, 7 },
                    { DefaultCharacterAttributes.Intelligence, 7 },
                    { DefaultCharacterAttributes.Cunning, 3 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Crafting, 5 },
                    { DefaultSkills.Trade, 5 },
                    { DefaultSkills.Steward, 5 },
                    { DefaultSkills.Charm, 3 },
                    { DefaultSkills.Riding, 2 },
                    { DefaultSkills.Athletics, 2 },
                    { DefaultSkills.Engineering, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Crafting, 125 },
                    { DefaultSkills.Trade, 75 },
                    { DefaultSkills.Steward, 75 },
                    { DefaultSkills.Charm, 40 },
                    { DefaultSkills.Riding, 30 },
                    { DefaultSkills.Athletics, 30 }
                });
        }

        private static AutoCharacterBuildProfile BuildKingdomFounder()
        {
            return Build(
                "KingdomFounder",
                "Politics, lord relations, and kingdom-scale leadership.",
                AutoCharacterBuildModeKind.KingdomFounder,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Social, 9 },
                    { DefaultCharacterAttributes.Intelligence, 8 },
                    { DefaultCharacterAttributes.Cunning, 5 },
                    { DefaultCharacterAttributes.Endurance, 5 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Leadership, 5 },
                    { DefaultSkills.Charm, 5 },
                    { DefaultSkills.Steward, 5 },
                    { DefaultSkills.Trade, 4 },
                    { DefaultSkills.Tactics, 3 },
                    { DefaultSkills.Scouting, 3 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Leadership, 100 },
                    { DefaultSkills.Charm, 75 },
                    { DefaultSkills.Steward, 75 },
                    { DefaultSkills.Trade, 50 },
                    { DefaultSkills.Tactics, 40 },
                    { DefaultSkills.Scouting, 40 }
                });
        }

        private static AutoCharacterBuildProfile BuildStewardSurgeonEngineer()
        {
            return Build(
                "StewardSurgeonEngineer",
                "Campaign infrastructure: logistics, medicine, and siege engineering.",
                AutoCharacterBuildModeKind.StewardSurgeonEngineer,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Intelligence, 10 },
                    { DefaultCharacterAttributes.Social, 6 },
                    { DefaultCharacterAttributes.Endurance, 5 },
                    { DefaultCharacterAttributes.Cunning, 4 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 5 },
                    { DefaultSkills.Medicine, 5 },
                    { DefaultSkills.Engineering, 5 },
                    { DefaultSkills.Leadership, 3 },
                    { DefaultSkills.Charm, 3 },
                    { DefaultSkills.Scouting, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 100 },
                    { DefaultSkills.Medicine, 75 },
                    { DefaultSkills.Engineering, 75 },
                    { DefaultSkills.Leadership, 50 },
                    { DefaultSkills.Charm, 40 }
                });
        }

        private static AutoCharacterBuildProfile BuildWarCaptain()
        {
            return Build(
                "WarCaptain",
                "Battle command: leadership, tactics, and scouting.",
                AutoCharacterBuildModeKind.WarCaptain,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Social, 8 },
                    { DefaultCharacterAttributes.Cunning, 8 },
                    { DefaultCharacterAttributes.Endurance, 6 },
                    { DefaultCharacterAttributes.Vigor, 5 },
                    { DefaultCharacterAttributes.Control, 5 },
                    { DefaultCharacterAttributes.Intelligence, 4 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Leadership, 5 },
                    { DefaultSkills.Tactics, 5 },
                    { DefaultSkills.Scouting, 5 },
                    { DefaultSkills.Riding, 3 },
                    { DefaultSkills.Athletics, 3 },
                    { DefaultSkills.OneHanded, 3 },
                    { DefaultSkills.Polearm, 3 },
                    { DefaultSkills.Bow, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Leadership, 100 },
                    { DefaultSkills.Tactics, 75 },
                    { DefaultSkills.Scouting, 75 },
                    { DefaultSkills.Riding, 50 },
                    { DefaultSkills.Athletics, 50 },
                    { DefaultSkills.OneHanded, 40 },
                    { DefaultSkills.Polearm, 40 }
                });
        }

        private static AutoCharacterBuildProfile BuildLightTouchVanillaPlus()
        {
            return Build(
                "LightTouchVanillaPlus",
                "Light help without nuking natural progression.",
                AutoCharacterBuildModeKind.LightTouchVanillaPlus,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Intelligence, 6 },
                    { DefaultCharacterAttributes.Endurance, 6 },
                    { DefaultCharacterAttributes.Social, 5 },
                    { DefaultCharacterAttributes.Cunning, 3 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 4 },
                    { DefaultSkills.Crafting, 4 },
                    { DefaultSkills.Leadership, 4 },
                    { DefaultSkills.Medicine, 2 },
                    { DefaultSkills.Engineering, 2 },
                    { DefaultSkills.Charm, 2 },
                    { DefaultSkills.Trade, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Steward, 50 },
                    { DefaultSkills.Crafting, 50 },
                    { DefaultSkills.Leadership, 40 },
                    { DefaultSkills.Medicine, 25 },
                    { DefaultSkills.Engineering, 25 },
                    { DefaultSkills.Charm, 25 },
                    { DefaultSkills.Trade, 25 }
                });
        }

        private static AutoCharacterBuildProfile BuildShadowTrader()
        {
            return Build(
                "ShadowTrader",
                "Trade, scouting, charm, and roguery skeleton for stealth/caravan loops.",
                AutoCharacterBuildModeKind.ShadowTrader,
                isDefault: false,
                new Dictionary<CharacterAttribute, int>
                {
                    { DefaultCharacterAttributes.Social, 8 },
                    { DefaultCharacterAttributes.Cunning, 7 },
                    { DefaultCharacterAttributes.Endurance, 5 },
                    { DefaultCharacterAttributes.Intelligence, 5 },
                    { DefaultCharacterAttributes.Vigor, 2 },
                    { DefaultCharacterAttributes.Control, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Trade, 5 },
                    { DefaultSkills.Charm, 4 },
                    { DefaultSkills.Scouting, 4 },
                    { DefaultSkills.Roguery, 4 },
                    { DefaultSkills.Leadership, 3 },
                    { DefaultSkills.Riding, 2 },
                    { DefaultSkills.Athletics, 2 }
                },
                new Dictionary<SkillObject, int>
                {
                    { DefaultSkills.Trade, 100 },
                    { DefaultSkills.Charm, 60 },
                    { DefaultSkills.Scouting, 60 },
                    { DefaultSkills.Roguery, 50 },
                    { DefaultSkills.Leadership, 40 }
                });
        }
    }
}
