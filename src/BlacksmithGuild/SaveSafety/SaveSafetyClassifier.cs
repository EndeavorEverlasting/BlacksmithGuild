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
    /// Runtime mirror of the tracked disposable-save name policy.
    ///
    /// This class is intentionally not a game-version authority. Exact save/game version
    /// compatibility is established prelaunch by scripts/tbg/Invoke-TbgSaveCompatibility.ps1.
    /// The runtime gate is the second line of defense: even after prelaunch certification,
    /// automated trade mutation is refused unless the currently tracked save name belongs to
    /// a shipped disposable cohort.
    /// </summary>
    public static class SaveSafetyClassifier
    {
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
        /// Returns the save identity tracked by the canonical QuickStart/Continue lifecycle.
        /// Null means runtime identity is not strong enough to authorize mutation.
        /// </summary>
        public static string GetLoadedSaveName()
        {
            try
            {
                var tracked = CampaignSetupStateTracker.DevSaveName;
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
        /// Runtime mutation gate for automated buy/sell chokepoints.
        ///
        /// A Disposable result does not itself prove version compatibility; automation entrypoints
        /// must first pass the canonical prelaunch exact-version save gate. This method prevents a
        /// personal or unidentified save from being mutated if a higher-level workflow is bypassed.
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
                        + ":prelaunch_exact_version_gate_required";
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
