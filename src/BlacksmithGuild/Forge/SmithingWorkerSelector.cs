using System.Collections.Generic;
using System.Linq;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Core;

namespace BlacksmithGuild.Forge
{
    internal static class SmithingWorkerSelector
    {
        public static List<SmithingWorkerProfile> GetPartyWorkers()
        {
            var workers = new List<SmithingWorkerProfile>();
            var party = MobileParty.MainParty;
            if (party?.MemberRoster == null)
            {
                return workers;
            }

            foreach (var element in party.MemberRoster.GetTroopRoster())
            {
                var hero = element.Character?.HeroObject;
                if (hero == null)
                {
                    continue;
                }

                var profile = new SmithingWorkerProfile
                {
                    Name = hero.Name?.ToString() ?? "(unnamed)",
                    IsMainHero = hero == Hero.MainHero,
                    CraftingSkill = SafeSkill(hero, DefaultSkills.Crafting)
                };

                if (SmithingStaminaReader.TryReadStamina(hero, out var stamina, out var maxStamina))
                {
                    profile.Stamina = stamina;
                    profile.MaxStamina = maxStamina;
                    profile.StaminaKnown = true;
                }

                workers.Add(profile);
            }

            return workers.OrderBy(worker => worker.CraftingSkill).ToList();
        }

        public static SmithingWorkerProfile SelectGruntWorker(IReadOnlyList<SmithingWorkerProfile> workers)
        {
            if (workers == null || workers.Count == 0)
            {
                return null;
            }

            var candidates = workers
                .Where(worker => !worker.IsMainHero || workers.Count == 1)
                .Where(worker => !worker.StaminaKnown || worker.Stamina > 0)
                .OrderBy(worker => worker.CraftingSkill)
                .ThenByDescending(worker => worker.StaminaKnown ? worker.Stamina : 0)
                .ToList();

            if (candidates.Count > 0)
            {
                return candidates[0];
            }

            return workers.OrderBy(worker => worker.CraftingSkill).FirstOrDefault();
        }

        public static SmithingWorkerProfile SelectCraftWorker(
            IReadOnlyList<SmithingWorkerProfile> workers,
            ForgeCandidate topCandidate)
        {
            if (workers == null || workers.Count == 0)
            {
                return null;
            }

            return workers
                .Where(worker => !worker.StaminaKnown || worker.Stamina > 0)
                .OrderByDescending(worker => worker.CraftingSkill)
                .ThenByDescending(worker => worker.StaminaKnown ? worker.Stamina : 0)
                .FirstOrDefault()
                ?? workers.OrderByDescending(worker => worker.CraftingSkill).FirstOrDefault();
        }

        private static int SafeSkill(Hero hero, SkillObject skill)
        {
            try
            {
                return hero.GetSkillValue(skill);
            }
            catch
            {
                return -1;
            }
        }
    }
}
