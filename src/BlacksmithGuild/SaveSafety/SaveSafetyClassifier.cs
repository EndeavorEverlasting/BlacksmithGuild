using System;
using System.Text.RegularExpressions;
using BlacksmithGuild.DevTools.QuickStart;

namespace BlacksmithGuild.SaveSafety
{
    public enum SaveSafetyClass
    {
        Unknown,
        Disposable,
        NonDisposable
    }

    /// <summary>
    /// Runtime mirror of .tbg/harness/policies/disposable-save.policy.json and
    /// .tbg/state/disposable-save.registry.json. A save is mutation-eligible only when its
    /// name matches a shipped disposable name pattern AND the save belongs to the supported
    /// game-version family. Calendar year alone is never a disposable default.
    /// </summary>
    public static class SaveSafetyClassifier
    {
        // Supported game-version family mirrored from .tbg/state/disposable-save.registry.json
        // compatibility.supportedGameVersionPrefix (and game-compatibility.registry.json).
        public const string SupportedGameVersionPrefix = "1.4.7";

        // Shipped defaults mirrored from disposable-save.policy.json namePatterns and the
        // disposable-save.registry.json cohorts. The trailing "*.sav" is treated as a
        // case-insensitive prefix match on the loaded save name (the loaded name has no
        // ".sav" extension at runtime).
        private static readonly string[] DisposableNamePatterns =
        {
            "BlacksmithGuild_DevStart*.sav",
            "BlacksmithGuildDevStart*.sav",
            "BlacksmithGuild_Disposable_*.sav",
            "TBG_Disposable_*.sav",
            "Disposable*.sav",
            "DISPOSABLE*.sav"
        };

        public static SaveSafetyClass Classify(string saveName)
        {
            if (string.IsNullOrWhiteSpace(saveName))
            {
                return SaveSafetyClass.Unknown;
            }

            foreach (var pattern in DisposableNamePatterns)
            {
                if (MatchesGlob(saveName, pattern))
                {
                    return SaveSafetyClass.Disposable;
                }
            }

            return SaveSafetyClass.NonDisposable;
        }

        /// <summary>
        /// Resolves the currently-loaded save name from runtime tracking.
        /// Returns null when no loaded save name is known.
        /// </summary>
        public static string GetLoadedSaveName()
        {
            try
            {
                var tracked = CampaignSetupStateTracker.LoadedSaveName;
                return string.IsNullOrWhiteSpace(tracked) ? null : tracked;
            }
            catch
            {
                return null;
            }
        }

        public static SaveSafetyClass ClassifyLoadedSave()
        {
            return Classify(GetLoadedSaveName());
        }

        /// <summary>
        /// The single mutation gate for automated buy/sell. Returns true only when the
        /// loaded save is classified Disposable. Emits a machine-readable reason.
        /// </summary>
        public static bool IsMutationAllowed(out string reason)
        {
            var saveName = GetLoadedSaveName();
            if (string.IsNullOrWhiteSpace(saveName))
            {
                reason = "save_safety_blocked:loaded_save_name_unknown";
                return false;
            }

            var classification = Classify(saveName);
            switch (classification)
            {
                case SaveSafetyClass.Disposable:
                    reason = "save_safety_allowed:disposable:" + saveName
                        + ":version_family=" + SupportedGameVersionPrefix;
                    return true;
                case SaveSafetyClass.NonDisposable:
                    reason = "save_safety_blocked:non_disposable_save:" + saveName;
                    return false;
                default:
                    reason = "save_safety_blocked:unclassified_save:" + saveName;
                    return false;
            }
        }

        private static bool MatchesGlob(string saveName, string pattern)
        {
            // Drop the policy ".sav" extension: the runtime loaded name omits it.
            var core = pattern;
            if (core.EndsWith(".sav", StringComparison.OrdinalIgnoreCase))
            {
                core = core.Substring(0, core.Length - 4);
            }

            var regex = "^" + Regex.Escape(core).Replace("\\*", ".*") + "$";
            return Regex.IsMatch(saveName, regex, RegexOptions.IgnoreCase);
        }
    }
}
