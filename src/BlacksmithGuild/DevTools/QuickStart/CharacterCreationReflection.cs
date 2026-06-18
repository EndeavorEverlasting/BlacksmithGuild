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
        private static MethodInfo _nextStageMethod;
        private static PropertyInfo _currentStageProperty;
        private static PropertyInfo _characterCreationProperty;
        private static PropertyInfo _characterCreationContentProperty;
        private static PropertyInfo _characterCreationMenuCountProperty;
        private static MethodInfo _getCurrentMenuOptionsMethod;
        private static MethodInfo _runConsequenceMethod;

        public static Type StateType => EnsureStateType();

        public static bool IsAvailable => EnsureStateType() != null && _nextStageMethod != null;

        public static object GetCurrentStage(object state)
        {
            return _currentStageProperty?.GetValue(state);
        }

        public static string GetCurrentStageName(object state)
        {
            return GetCurrentStage(state)?.GetType().Name ?? "unknown";
        }

        public static void NextStage(object state)
        {
            _nextStageMethod?.Invoke(state, null);
        }

        public static object GetCharacterCreation(object state)
        {
            return _characterCreationProperty?.GetValue(state);
        }

        public static object GetCharacterCreationContent(object state)
        {
            return _characterCreationContentProperty?.GetValue(state);
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
            var charCreation = GetCharacterCreation(state);
            if (charCreation == null)
            {
                return;
            }

            var menuCount = (int)(_characterCreationMenuCountProperty?.GetValue(charCreation) ?? 0);
            for (var i = 0; i < menuCount; i++)
            {
                var options = _getCurrentMenuOptionsMethod?.Invoke(charCreation, new object[] { i }) as System.Collections.IList;
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
                if (selected != null)
                {
                    _runConsequenceMethod?.Invoke(charCreation, new[] { selected, i, (object)false });
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

        private static Type EnsureStateType()
        {
            if (_stateType != null)
            {
                return _stateType;
            }

            _stateType = AccessTools.TypeByName("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationState")
                ?? AccessTools.TypeByName("TaleWorlds.CampaignSystem.GameState.CharacterCreationState");

            if (_stateType == null)
            {
                return null;
            }

            _nextStageMethod = AccessTools.DeclaredMethod(_stateType, "NextStage");
            _currentStageProperty = AccessTools.Property(_stateType, "CurrentStage");
            _characterCreationProperty = AccessTools.Property(_stateType, "CharacterCreation");
            _characterCreationContentProperty = AccessTools.Property(_stateType, "CharacterCreationContent");

            var charCreationType = _characterCreationProperty?.PropertyType;
            if (charCreationType != null)
            {
                _characterCreationMenuCountProperty = AccessTools.Property(charCreationType, "CharacterCreationMenuCount");
                _getCurrentMenuOptionsMethod = AccessTools.Method(charCreationType, "GetCurrentMenuOptions", new[] { typeof(int) });
                _runConsequenceMethod = AccessTools.Method(
                    charCreationType,
                    "RunConsequence",
                    new[] { charCreationType.Assembly.GetType("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationOption"), typeof(int), typeof(bool) }
                );

                if (_runConsequenceMethod == null)
                {
                    _runConsequenceMethod = AccessTools.Method(charCreationType, "RunConsequence");
                }
            }

            return _stateType;
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
