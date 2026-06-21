using System;
using System.Collections.Generic;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    internal static class CharacterCultureResolver
    {
        public static CultureObject ResolvePreferredCulture(
            IList<CultureObject> cultures,
            out bool preferredUsed,
            out bool fallbackUsed,
            out string preferredCultureId,
            out string selectedCultureId)
        {
            preferredUsed = false;
            fallbackUsed = false;
            preferredCultureId = CharacterDoctrineConfig.PreferredCultureId;
            selectedCultureId = null;

            if (cultures == null || cultures.Count == 0)
            {
                return null;
            }

            var preferred = FindCulture(cultures, preferredCultureId);
            if (preferred != null)
            {
                preferredUsed = true;
                selectedCultureId = GetCultureStringId(preferred) ?? preferredCultureId;
                return preferred;
            }

            GuildLog.Info(
                $"[TBG QUICKSTART] preferred culture unavailable: {preferredCultureId}",
                showInGame: false);

            foreach (var fallbackId in CharacterDoctrineConfig.FallbackCultureIds)
            {
                var fallback = FindCulture(cultures, fallbackId);
                if (fallback == null)
                {
                    continue;
                }

                fallbackUsed = true;
                selectedCultureId = GetCultureStringId(fallback) ?? fallbackId;
                return fallback;
            }

            selectedCultureId = GetCultureStringId(cultures[0]);
            return cultures[0];
        }

        private static CultureObject FindCulture(IList<CultureObject> cultures, string cultureId)
        {
            if (string.IsNullOrWhiteSpace(cultureId))
            {
                return null;
            }

            foreach (var culture in cultures)
            {
                if (culture == null)
                {
                    continue;
                }

                var stringId = GetCultureStringId(culture);
                if (!string.IsNullOrWhiteSpace(stringId)
                    && string.Equals(stringId, cultureId, StringComparison.OrdinalIgnoreCase))
                {
                    return culture;
                }

                var name = culture.Name?.ToString();
                if (!string.IsNullOrWhiteSpace(name)
                    && name.IndexOf(cultureId, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return culture;
                }
            }

            if (string.Equals(cultureId, "aserai", StringComparison.OrdinalIgnoreCase))
            {
                foreach (var culture in cultures)
                {
                    var name = culture?.Name?.ToString();
                    if (!string.IsNullOrWhiteSpace(name)
                        && name.IndexOf("Aserai", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return culture;
                    }
                }
            }

            return null;
        }

        private static string GetCultureStringId(CultureObject culture)
        {
            if (culture == null)
            {
                return null;
            }

            try
            {
                return culture.StringId;
            }
            catch
            {
                return null;
            }
        }
    }
}
