using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
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
        private static PropertyInfo _currentMenuIndexProperty;
        private static MethodInfo _getCurrentMenuOptionsMethod;
        private static MethodInfo _narrativeMenuOptionSelectedMethod;
        private static MethodInfo _legacyRunConsequenceMethod;
        private static MethodInfo _applyCultureMethod;
        private static bool _probeLogged;
        private static bool _cultureFailureLogged;
        private static readonly HashSet<int> LoggedNarrativeMenuSelections = new HashSet<int>();
        private static int _narrativeMenusCompleted;
        private static string _lastNarrativeFailureDetail;

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

        public static bool TrySkipCultureStage(object state)
        {
            var content = GetCharacterCreationContent(state);
            var manager = GetCharacterCreation(state);
            if (content == null || manager == null)
            {
                LogCultureFailureOnce("content or manager is null");
                return false;
            }

            if (TryGetSelectedCulture(content) != null)
            {
                NextStage(state);
                _cultureFailureLogged = false;
                return true;
            }

            var cultures = TryGetCultures(content);
            if (cultures == null || cultures.Count == 0)
            {
                LogCultureFailureOnce($"GetCultures returned {(cultures == null ? "null" : "empty")}");
                return false;
            }

            TrySetSelectedCulture(content, cultures[0], manager);
            TryApplyCulture(content, manager);

            if (TryGetSelectedCulture(content) == null)
            {
                LogCultureFailureOnce($"SelectedCulture still null after SetSelectedCulture ({cultures[0]?.Name})");
                return false;
            }

            NextStage(state);
            _cultureFailureLogged = false;
            GuildLog.Info(
                $"[TBG QUICKSTART] culture auto-selected: {cultures[0]?.Name} (count={cultures.Count})",
                showInGame: false);
            return true;
        }

        public static void SkipCultureStage(object state)
        {
            TrySkipCultureStage(state);
        }

        public static void ResetNarrativeSession()
        {
            LoggedNarrativeMenuSelections.Clear();
            _narrativeMenusCompleted = 0;
            _lastNarrativeFailureDetail = null;
        }

        public static string GetNarrativeStallDiagnostics()
        {
            return _lastNarrativeFailureDetail ?? "no narrative failure detail recorded";
        }

        public static bool TryNextStage(object state)
        {
            try
            {
                var manager = GetManager(state);
                if (manager == null || _nextStageMethod == null)
                {
                    return false;
                }

                _nextStageMethod.Invoke(manager, null);
                return true;
            }
            catch (TargetInvocationException ex)
            {
                var inner = ex.InnerException?.Message ?? ex.Message;
                GuildLog.Info($"[TBG QUICKSTART] NextStage failed: {inner}", showInGame: false);
                return false;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] NextStage failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static bool TryAdvanceNarrativeMenu(object state)
        {
            var manager = GetCharacterCreation(state);
            if (manager == null)
            {
                _lastNarrativeFailureDetail = "manager is null";
                return false;
            }

            if (_getCurrentMenuOptionsMethod == null)
            {
                _lastNarrativeFailureDetail = "GetCurrentMenuOptions is missing";
                return false;
            }

            var menuCount = (int)(_characterCreationMenuCountProperty?.GetValue(manager) ?? 0);
            if (menuCount <= 0)
            {
                _lastNarrativeFailureDetail = "menuCount is 0";
                return false;
            }

            var progressed = false;
            const int maxMenusPerTick = 12;

            for (var attempt = 0; attempt < maxMenusPerTick; attempt++)
            {
                var menuIndex = TryGetCurrentMenuIndex(manager);
                if (menuIndex >= menuCount)
                {
                    return progressed ? TryNextStage(state) : TryNextStage(state);
                }

                if (!TrySelectNarrativeOption(manager, menuIndex, menuCount, out var selected))
                {
                    break;
                }

                progressed = true;

                if (_currentMenuIndexProperty == null)
                {
                    _narrativeMenusCompleted++;
                    continue;
                }

                var nextIndex = TryGetCurrentMenuIndex(manager);
                if (nextIndex <= menuIndex)
                {
                    break;
                }
            }

            return progressed;
        }

        private static bool TrySelectNarrativeOption(
            object manager,
            int menuIndex,
            int menuCount,
            out object selected)
        {
            selected = null;
            var options = new List<object>();
            foreach (var option in EnumerateMenuOptions(_getCurrentMenuOptionsMethod.Invoke(manager, new object[] { menuIndex })))
            {
                if (option != null)
                {
                    options.Add(option);
                }
            }

            if (options.Count == 0)
            {
                _lastNarrativeFailureDetail = $"menu={menuIndex} optionCount=0 menuCount={menuCount}";
                return false;
            }

            foreach (var option in options)
            {
                if (!IsOptionAvailable(option))
                {
                    continue;
                }

                selected = option;
                break;
            }

            if (selected == null)
            {
                _lastNarrativeFailureDetail =
                    $"menu={menuIndex} no valid option ({options.Count} total) menuCount={menuCount}";
                return false;
            }

            try
            {
                InvokeNarrativeSelection(manager, selected, menuIndex);
            }
            catch (TargetInvocationException ex)
            {
                var inner = ex.InnerException?.Message ?? ex.Message;
                _lastNarrativeFailureDetail = $"menu={menuIndex} invoke failed: {inner}";
                return false;
            }
            catch (Exception ex)
            {
                _lastNarrativeFailureDetail = $"menu={menuIndex} invoke failed: {ex.Message}";
                return false;
            }

            if (!LoggedNarrativeMenuSelections.Contains(menuIndex))
            {
                LoggedNarrativeMenuSelections.Add(menuIndex);
                GuildLog.Info(
                    $"[TBG QUICKSTART] narrative auto-selected menu={menuIndex} option={DescribeNarrativeOption(selected)}",
                    showInGame: false);
            }

            _lastNarrativeFailureDetail = null;
            return true;
        }

        public static void SkipNarrativeStage(object state)
        {
            TryAdvanceNarrativeMenu(state);
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
            _currentMenuIndexProperty = AccessTools.Property(_managerType, "CurrentMenuIndex")
                ?? AccessTools.Property(_managerType, "CurrentMenu");
            _getCurrentMenuOptionsMethod = AccessTools.Method(_managerType, "GetCurrentMenuOptions", new[] { typeof(int) });

            _legacyRunConsequenceMethod = AccessTools.Method(_managerType, "RunConsequence");
            _narrativeMenuOptionSelectedMethod = AccessTools.Method(_managerType, "OnNarrativeMenuOptionSelected");

            var contentType = AccessTools.TypeByName("TaleWorlds.CampaignSystem.CharacterCreationContent.CharacterCreationContent");
            _applyCultureMethod = contentType == null
                ? null
                : AccessTools.Method(contentType, "ApplyCulture", new[] { _managerType });

            var narrativeBinding = _narrativeMenuOptionSelectedMethod != null
                ? "OnNarrativeMenuOptionSelected"
                : _legacyRunConsequenceMethod != null ? "RunConsequence" : "missing";

            LogProbe(
                $"state=found manager=found nextStage={(_nextStageMethod != null ? "found" : "missing")} " +
                $"menus={(_getCurrentMenuOptionsMethod != null ? "found" : "missing")} " +
                $"currentMenuIndex={(_currentMenuIndexProperty != null ? "found" : "missing")} " +
                $"culture={(_applyCultureMethod != null ? "found" : "missing")} " +
                $"narrative={narrativeBinding}");

            return _stateType;
        }

        private static void InvokeNarrativeSelection(object manager, object selected, int menuIndex)
        {
            if (_narrativeMenuOptionSelectedMethod != null
                && _narrativeMenuOptionSelectedMethod.GetParameters().Length == 1)
            {
                _narrativeMenuOptionSelectedMethod.Invoke(manager, new[] { selected });
                return;
            }

            if (_legacyRunConsequenceMethod != null)
            {
                var parameters = _legacyRunConsequenceMethod.GetParameters();
                if (parameters.Length == 3)
                {
                    _legacyRunConsequenceMethod.Invoke(manager, new[] { selected, menuIndex, (object)false });
                }
                else if (parameters.Length == 1)
                {
                    _legacyRunConsequenceMethod.Invoke(manager, new[] { selected });
                }
            }
        }

        private static int TryGetCurrentMenuIndex(object manager)
        {
            if (_currentMenuIndexProperty != null)
            {
                try
                {
                    var value = _currentMenuIndexProperty.GetValue(manager);
                    if (value is int index)
                    {
                        return index;
                    }

                    if (value != null && int.TryParse(value.ToString(), out var parsed))
                    {
                        return parsed;
                    }
                }
                catch
                {
                }
            }

            return _narrativeMenusCompleted;
        }

        private static bool IsOptionAvailable(object option)
        {
            try
            {
                var onCondition = option.GetType().GetMethod(
                    "OnCondition",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (onCondition == null)
                {
                    return true;
                }

                return onCondition.Invoke(option, null) as bool? != false;
            }
            catch
            {
                return false;
            }
        }

        private static string DescribeNarrativeOption(object option)
        {
            if (option == null)
            {
                return "null";
            }

            try
            {
                var stringIdProperty = option.GetType().GetProperty(
                    "StringId",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var stringId = stringIdProperty?.GetValue(option) as string;
                if (!string.IsNullOrWhiteSpace(stringId))
                {
                    return stringId;
                }

                var idField = option.GetType().GetField(
                    "Id",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var id = idField?.GetValue(option)?.ToString();
                if (!string.IsNullOrWhiteSpace(id))
                {
                    return id;
                }
            }
            catch
            {
            }

            return option.GetType().Name;
        }

        private static IEnumerable EnumerateMenuOptions(object optionsObject)
        {
            if (optionsObject == null)
            {
                yield break;
            }

            if (optionsObject is IEnumerable enumerable)
            {
                foreach (var option in enumerable)
                {
                    yield return option;
                }

                yield break;
            }

            yield return optionsObject;
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
                var selectedCultureProperty = content.GetType().GetProperty(
                    "SelectedCulture",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (selectedCultureProperty != null)
                {
                    return selectedCultureProperty.GetValue(content) as CultureObject;
                }

                var method = content.GetType().GetMethod(
                    "GetSelectedCulture",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                return method?.Invoke(content, null) as CultureObject;
            }
            catch
            {
                return null;
            }
        }

        private static List<CultureObject> TryGetCultures(object content)
        {
            try
            {
                var method = content.GetType().GetMethod(
                    "GetCultures",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var result = method?.Invoke(content, null);
                if (result == null)
                {
                    return null;
                }

                if (result is IEnumerable<CultureObject> typedEnumerable)
                {
                    return typedEnumerable.Where(culture => culture != null).ToList();
                }

                if (result is IEnumerable enumerable)
                {
                    return enumerable.Cast<CultureObject>().Where(culture => culture != null).ToList();
                }

                return null;
            }
            catch (Exception ex)
            {
                LogCultureFailureOnce($"GetCultures invoke failed: {ex.Message}");
                return null;
            }
        }

        private static void LogCultureFailureOnce(string detail)
        {
            if (_cultureFailureLogged)
            {
                return;
            }

            _cultureFailureLogged = true;
            GuildLog.Info($"[TBG QUICKSTART] culture skip failed: {detail}", showInGame: false);
        }

        private static void TrySetSelectedCulture(object content, CultureObject culture, object characterCreation)
        {
            try
            {
                var method = content.GetType().GetMethod(
                    "SetSelectedCulture",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                method?.Invoke(content, new[] { culture, characterCreation });
            }
            catch
            {
            }
        }

        private static void TryApplyCulture(object content, object manager)
        {
            if (_applyCultureMethod == null)
            {
                return;
            }

            try
            {
                _applyCultureMethod.Invoke(content, new[] { manager });
            }
            catch
            {
            }
        }
    }
}
