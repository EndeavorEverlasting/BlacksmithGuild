using System;
using System.Reflection;
using HarmonyLib;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Library;
using TaleWorlds.ObjectSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class CharacterCreationReflection
    {
        private static Type _stateType;
        private static Type _managerType;
        private static PropertyInfo _managerProperty;
        private static MethodInfo _nextStageMethod;
        private static PropertyInfo _currentStageProperty;
        private static PropertyInfo _characterCreationContentProperty;
        private static PropertyInfo _characterCreationMenuCountProperty;
        private static MethodInfo _getCurrentMenuOptionsMethod;
        private static MethodInfo _runConsequenceMethod;
        private static bool _probeLogged;

        public static Type StateType => EnsureBindings();

        public static bool IsAvailable => EnsureBindings() != null && _managerType != null && _nextStageMethod != null;

        public static object GetManager(object state)
        {
            return _managerProperty?.GetValue(state);
        }

        public static object GetCurrentStage(object state)
        {
            var manager = GetManager(state);
            return manager == null ? null : _currentStageProperty?.GetValue(manager);
        }

        public static string GetCurrentStageName(object state)
        {
            return GetCurrentStage(state)?.GetType().Name ?? "unknown";
        }

        public static void NextStage(object state)
        {
            var manager = GetManager(state);
            _nextStageMethod?.Invoke(manager, null);
        }

        public static object GetCharacterCreation(object state)
        {
            return GetManager(state);
        }

        public static object GetCharacterCreationContent(object state)
        {
            var manager = GetManager(state);
            return manager == null ? null : _characterCreationContentProperty?.GetValue(manager);
        }

        public static void SkipCultureStage(object state)
        {
            var content = GetCharacterCreationContent(state);
            if (content == null)
            {
                NextStage(state);
                return;
            }

            if (TryGetSelectedCulture(content) != null)
            {
                NextStage(state);
                return;
            }

            var cultures = TryGetCultures(content);
            if (cultures == null || cultures.Count == 0)
            {
                return;
            }

            TrySetSelectedCulture(content, cultures[0], GetCharacterCreation(state));
            NextStage(state);
        }

        public static void SkipNarrativeStage(object state)
        {
            var manager = GetCharacterCreation(state);
            if (manager == null)
            {
                return;
            }

            var menuCount = (int)(_characterCreationMenuCountProperty?.GetValue(manager) ?? 0);
            for (var i = 0; i < menuCount; i++)
            {
                var options = _getCurrentMenuOptionsMethod?.Invoke(manager, new object[] { i }) as System.Collections.IList;
                if (options == null || options.Count == 0)
                {
                    continue;
                }

                object selected = null;
                foreach (var option in options)
                {
                    if (option == null)
                    {
                        continue;
                    }

                    var onCondition = option.GetType().GetMethod("OnCondition", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                    if (onCondition == null)
                    {
                        selected = option;
                        break;
                    }

                    var conditionResult = onCondition.Invoke(option, null) as bool?;
                    if (conditionResult != false)
                    {
                        selected = option;
                        break;
                    }
                }

                selected ??= options[0];
                if (selected != null && _runConsequenceMethod != null)
                {
                    _runConsequenceMethod.Invoke(manager, new[] { selected, i, (object)false });
                }
            }

            NextStage(state);
        }

        public static bool IsStoryModeContent(object state)
        {
            try
            {
                var content = GetCharacterCreationContent(state);
                return content != null
                    && content.GetType().FullName?.IndexOf("StoryMode", StringComparison.OrdinalIgnoreCase) >= 0;
            }
            catch
            {
                return false;
            }
        }

        private static Type EnsureBindings()
        {
            if (_stateType != null)
            {
                return _stateType;
            }

            _stateType = AccessTools.TypeByName("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationState")
                ?? AccessTools.TypeByName("TaleWorlds.CampaignSystem.GameState.CharacterCreationState");

            if (_stateType == null)
            {
                LogProbe("state=missing manager=missing nextStage=missing");
                return null;
            }

            _managerProperty = AccessTools.Property(_stateType, "CharacterCreationManager");
            _managerType = _managerProperty?.PropertyType
                ?? AccessTools.TypeByName("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationManager");

            if (_managerType == null)
            {
                LogProbe("state=found manager=missing nextStage=missing");
                return _stateType;
            }

            _nextStageMethod = AccessTools.Method(_managerType, "NextStage");
            _currentStageProperty = AccessTools.Property(_managerType, "CurrentStage");
            _characterCreationContentProperty = AccessTools.Property(_managerType, "CharacterCreationContent");
            _characterCreationMenuCountProperty = AccessTools.Property(_managerType, "CharacterCreationMenuCount");
            _getCurrentMenuOptionsMethod = AccessTools.Method(_managerType, "GetCurrentMenuOptions", new[] { typeof(int) });
            _runConsequenceMethod = AccessTools.Method(_managerType, "RunConsequence")
                ?? AccessTools.Method(_managerType, "OnNarrativeMenuOptionSelected");

            LogProbe(
                $"state=found manager=found nextStage={(_nextStageMethod != null ? "found" : "missing")} " +
                $"menus={(_getCurrentMenuOptionsMethod != null ? "found" : "missing")}");

            return _stateType;
        }

        private static void LogProbe(string detail)
        {
            if (_probeLogged)
            {
                return;
            }

            _probeLogged = true;
            GuildLog.Info($"[TBG QUICKSTART] API probe: {detail}", showInGame: false);
        }

        private static CultureObject TryGetSelectedCulture(object content)
        {
            try
            {
                var method = content.GetType().GetMethod(
                    "GetSelectedCulture",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic
                );
                return method?.Invoke(content, null) as CultureObject;
            }
            catch
            {
                return null;
            }
        }

        private static MBReadOnlyList<CultureObject> TryGetCultures(object content)
        {
            try
            {
                var method = content.GetType().GetMethod(
                    "GetCultures",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic
                );
                return method?.Invoke(content, null) as MBReadOnlyList<CultureObject>;
            }
            catch
            {
                return null;
            }
        }

        private static void TrySetSelectedCulture(object content, CultureObject culture, object characterCreation)
        {
            try
            {
                var method = content.GetType().GetMethod(
                    "SetSelectedCulture",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic
                );
                method?.Invoke(content, new[] { culture, characterCreation });
            }
            catch
            {
            }
        }
    }
}
