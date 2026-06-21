using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
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
        private static PropertyInfo _currentMenuProperty;
        private static PropertyInfo _selectedOptionsProperty;
        private static FieldInfo _selectedOptionsField;
        private static MethodInfo _getCurrentMenuOptionsMethod;
        private static MethodInfo _getSuitableNarrativeMenuOptionsMethod;
        private static MethodInfo _trySwitchToNextMenuMethod;
        private static MethodInfo _startNarrativeStageMethod;
        private static MethodInfo _getNarrativeMenuWithIdMethod;
        private static MethodInfo _narrativeMenuOptionSelectedMethod;
        private static MethodInfo _legacyRunConsequenceMethod;
        private static MethodInfo _applyCultureMethod;
        private static bool _probeLogged;
        private static bool _cultureFailureLogged;
        private static bool _narrativeStageInitialized;
        private static bool _narrativeStageInitLogged;
        private static readonly HashSet<string> LoggedNarrativeMenuSelections =
            new HashSet<string>(StringComparer.OrdinalIgnoreCase);
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

            if (CharacterBuildVariantConfigService.IsCatalogMode)
            {
                CharacterCreationChoiceCatalogBuilder.RecordCultures(cultures);
            }

            GuildLog.Info(
                $"[TBG QUICKSTART] preferred culture: {CharacterDoctrineConfig.PreferredCultureId}",
                showInGame: false);
            CharacterBuildProvenanceService.LogVisibleTraversalOnce();

            var selectedCulture = CharacterCultureResolver.ResolvePreferredCulture(
                cultures,
                out var preferredUsed,
                out var fallbackUsed,
                out _,
                out _);
            if (selectedCulture == null)
            {
                LogCultureFailureOnce("culture resolver returned null");
                return false;
            }

            TrySetSelectedCulture(content, selectedCulture, manager);
            TryApplyCulture(content, manager);

            if (TryGetSelectedCulture(content) == null)
            {
                LogCultureFailureOnce($"SelectedCulture still null after SetSelectedCulture ({selectedCulture?.Name})");
                return false;
            }

            CharacterBuildProvenanceService.RecordCultureSelection(
                selectedCulture,
                preferredUsed,
                fallbackUsed,
                cultures.Count);

            if (DevToolsConfig.CharacterCreationVisibleMode)
            {
                var cultureLabel = selectedCulture?.Name?.ToString() ?? selectedCulture?.StringId ?? "unknown";
                InGameNotice.Info($"TBG: culture → {cultureLabel}");
            }

            NextStage(state);
            _cultureFailureLogged = false;

            if (fallbackUsed)
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] culture auto-selected fallback: {selectedCulture?.Name} (count={cultures.Count})",
                    showInGame: false);
            }
            else
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] culture auto-selected: {selectedCulture?.Name} (count={cultures.Count})",
                    showInGame: false);
            }

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
            _narrativeStageInitialized = false;
            _narrativeStageInitLogged = false;
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

            var content = GetCharacterCreationContent(state);
            if (content == null || TryGetSelectedCulture(content) == null)
            {
                _lastNarrativeFailureDetail = "culture not selected";
                return false;
            }

            if (!TryEnsureNarrativeStageInitialized(manager))
            {
                return false;
            }

            var menuCount = (int)(_characterCreationMenuCountProperty?.GetValue(manager) ?? 0);
            if (menuCount <= 0)
            {
                _lastNarrativeFailureDetail = "menuCount is 0";
                return false;
            }

            if (_getSuitableNarrativeMenuOptionsMethod == null
                && _getCurrentMenuOptionsMethod == null
                && _currentMenuProperty == null)
            {
                _lastNarrativeFailureDetail = "no narrative option APIs available";
                return false;
            }

            var progressed = false;
            var maxStepsPerTick = DevToolsConfig.CharacterCreationVisibleMode ? 1 : 12;

            for (var step = 0; step < maxStepsPerTick; step++)
            {
                var currentMenu = GetCurrentMenuObject(manager);
                var menuId = GetMenuId(currentMenu) ?? TryGetCurrentMenuIndex(manager).ToString();
                var outputMenuId = GetFieldString(currentMenu, "OutputMenuId") ?? "unknown";
                var selectedOptions = GetSelectedOptions(manager);
                var selectedCount = selectedOptions?.Count ?? 0;

                if (IsCurrentMenuSelected(currentMenu, selectedOptions))
                {
                    if (TryAdvanceFromSelectedMenu(manager, currentMenu, menuId, outputMenuId, ref progressed))
                    {
                        continue;
                    }

                    if (selectedCount >= menuCount)
                    {
                        return progressed || TryNextStage(state);
                    }

                    if (TryClearMenuSelection(manager, currentMenu))
                    {
                        continue;
                    }

                    _lastNarrativeFailureDetail =
                        $"currentMenu={menuId} outputMenu={outputMenuId} selectedCount={selectedCount} switchToNextMenu=false manualAdvance=failed";
                    break;
                }

                var options = GetSuitableMenuOptions(manager, currentMenu);
                var suitableCount = options.Count;

                if (CharacterBuildVariantConfigService.IsCatalogMode)
                {
                    CharacterCreationChoiceCatalogBuilder.RecordMenuVisit(manager, currentMenu, menuId);
                }

                object selected = null;
                NarrativeOptionDecision doctrineDecision = null;

                if (DevToolsConfig.LegitimacyMode == CharacterLegitimacyMode.VanillaLegit)
                {
                    if (CharacterBuildVariantConfigService.HasActiveVariantRoute)
                    {
                        doctrineDecision = CharacterBuildRouteSelector.SelectRouteOption(options, menuId, manager);
                    }
                    else
                    {
                        doctrineDecision = AseraiTradeSmithDecisionMap.SelectOption(options, menuId, manager);
                    }

                    selected = doctrineDecision?.SelectedOption;
                }
                else
                {
                    var onConditionFailures = 0;
                    foreach (var option in options)
                    {
                        if (IsOptionAvailable(option, manager))
                        {
                            selected = option;
                            break;
                        }

                        onConditionFailures++;
                    }

                    if (selected == null)
                    {
                        _lastNarrativeFailureDetail =
                            $"currentMenu={menuId} suitableCount={suitableCount} selectedCount={selectedCount} onConditionFailures={onConditionFailures}";
                        break;
                    }
                }

                if (selected == null)
                {
                    _lastNarrativeFailureDetail =
                        $"currentMenu={menuId} suitableCount={suitableCount} selectedCount={selectedCount} doctrineSelection=failed";
                    break;
                }

                try
                {
                    InvokeNarrativeSelection(manager, selected, menuId);
                }
                catch (TargetInvocationException ex)
                {
                    var inner = ex.InnerException?.Message ?? ex.Message;
                    _lastNarrativeFailureDetail = $"currentMenu={menuId} invoke failed: {inner}";
                    break;
                }
                catch (Exception ex)
                {
                    _lastNarrativeFailureDetail = $"currentMenu={menuId} invoke failed: {ex.Message}";
                    break;
                }

                if (!LoggedNarrativeMenuSelections.Contains(menuId))
                {
                    LoggedNarrativeMenuSelections.Add(menuId);
                    GuildLog.Info(
                        $"[TBG QUICKSTART] narrative auto-selected menu={menuId} option={DescribeNarrativeOption(selected)} (suitable={suitableCount})",
                        showInGame: false);
                }

                if (doctrineDecision != null)
                {
                    CharacterBuildProvenanceService.RecordUpbringingChoice(
                        AseraiTradeSmithDecisionMap.InferStage(menuId),
                        menuId,
                        doctrineDecision.OptionId,
                        doctrineDecision.OptionText,
                        doctrineDecision.Reason,
                        doctrineDecision.ExpectedBenefits,
                        doctrineDecision.OpportunityCosts,
                        doctrineDecision.BenefitSource,
                        doctrineDecision.RejectedOptions);

                    if (DevToolsConfig.CharacterCreationVisibleMode)
                    {
                        var stage = AseraiTradeSmithDecisionMap.InferStage(menuId);
                        var optionLabel = TruncateForNotice(doctrineDecision.OptionId, 48);
                        InGameNotice.Info($"TBG: {stage} → {optionLabel}");
                    }
                }

                progressed = true;
                _lastNarrativeFailureDetail = null;

                currentMenu = GetCurrentMenuObject(manager);
                menuId = GetMenuId(currentMenu) ?? menuId;
                outputMenuId = GetFieldString(currentMenu, "OutputMenuId") ?? outputMenuId;

                if (TryAdvanceFromSelectedMenu(manager, currentMenu, menuId, outputMenuId, ref progressed))
                {
                    continue;
                }

                selectedOptions = GetSelectedOptions(manager);
                selectedCount = selectedOptions?.Count ?? 0;
                if (selectedCount >= menuCount)
                {
                    return TryNextStage(state);
                }

                break;
            }

            return progressed;
        }

        private static bool TryAdvanceFromSelectedMenu(
            object manager,
            object currentMenu,
            string menuId,
            string outputMenuId,
            ref bool progressed)
        {
            if (TryInvokeSwitchToNextMenu(manager))
            {
                GuildLog.Info(
                    "[TBG QUICKSTART] narrative advanced to next menu (TrySwitchToNextMenu)",
                    showInGame: false);
                progressed = true;
                _lastNarrativeFailureDetail = null;
                return true;
            }

            if (TryManualSwitchToNextMenu(manager, currentMenu, out var resolvedOutputMenuId))
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] narrative advanced to next menu (manual OutputMenuId={resolvedOutputMenuId})",
                    showInGame: false);
                progressed = true;
                _lastNarrativeFailureDetail = null;
                return true;
            }

            return false;
        }

        private static bool TryEnsureNarrativeStageInitialized(object manager)
        {
            if (_narrativeStageInitialized)
            {
                return true;
            }

            if (_startNarrativeStageMethod == null)
            {
                _narrativeStageInitialized = true;
                return true;
            }

            try
            {
                _startNarrativeStageMethod.Invoke(manager, null);
                _narrativeStageInitialized = true;
                if (CharacterBuildVariantConfigService.IsCatalogMode)
                {
                    var content = _characterCreationContentProperty?.GetValue(manager);
                    CharacterCreationChoiceCatalogBuilder.TryEnumerateNarrativeMenus(manager, content);
                }

                if (!_narrativeStageInitLogged)
                {
                    _narrativeStageInitLogged = true;
                    GuildLog.Info("[TBG QUICKSTART] narrative stage initialized", showInGame: false);
                }

                return true;
            }
            catch (TargetInvocationException ex)
            {
                var inner = ex.InnerException?.Message ?? ex.Message;
                _lastNarrativeFailureDetail = $"StartNarrativeStage failed: {inner}";
                return false;
            }
            catch (Exception ex)
            {
                _lastNarrativeFailureDetail = $"StartNarrativeStage failed: {ex.Message}";
                return false;
            }
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
            _currentMenuIndexProperty = AccessTools.Property(_managerType, "CurrentMenuIndex");
            _currentMenuProperty = AccessTools.Property(_managerType, "CurrentMenu");
            _selectedOptionsProperty = AccessTools.Property(_managerType, "SelectedOptions");
            _selectedOptionsField = AccessTools.Field(_managerType, "SelectedOptions");
            _getCurrentMenuOptionsMethod = AccessTools.Method(_managerType, "GetCurrentMenuOptions", new[] { typeof(int) });
            _getSuitableNarrativeMenuOptionsMethod = AccessTools.Method(_managerType, "GetSuitableNarrativeMenuOptions");
            _trySwitchToNextMenuMethod = AccessTools.Method(_managerType, "TrySwitchToNextMenu");
            _startNarrativeStageMethod = AccessTools.Method(_managerType, "StartNarrativeStage");
            _getNarrativeMenuWithIdMethod = AccessTools.Method(_managerType, "GetNarrativeMenuWithId", new[] { typeof(string) });

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
                $"suitableOptions={(_getSuitableNarrativeMenuOptionsMethod != null ? "found" : "missing")} " +
                $"trySwitchToNextMenu={(_trySwitchToNextMenuMethod != null ? "found" : "missing")} " +
                $"startNarrativeStage={(_startNarrativeStageMethod != null ? "found" : "missing")} " +
                $"getNarrativeMenuWithId={(_getNarrativeMenuWithIdMethod != null ? "found" : "missing")} " +
                $"currentMenu={(_currentMenuProperty != null ? "found" : "missing")} " +
                $"currentMenuIndex={(_currentMenuIndexProperty != null ? "found" : "missing")} " +
                $"culture={(_applyCultureMethod != null ? "found" : "missing")} " +
                $"narrative={narrativeBinding}");

            return _stateType;
        }

        private static void InvokeNarrativeSelection(object manager, object selected, string menuId)
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
                if (parameters.Length == 3 && int.TryParse(menuId, out var menuIndex))
                {
                    _legacyRunConsequenceMethod.Invoke(manager, new[] { selected, menuIndex, (object)false });
                    return;
                }

                if (parameters.Length == 1)
                {
                    _legacyRunConsequenceMethod.Invoke(manager, new[] { selected });
                    return;
                }
            }

            if (TryInvokeOptionCallback(selected, "OnSelect", manager))
            {
                return;
            }

            TryInvokeOptionCallback(selected, "OnConsequence", manager);
        }

        private static bool TryInvokeOptionCallback(object option, string methodName, object manager)
        {
            try
            {
                var method = option.GetType().GetMethod(
                    methodName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (method == null)
                {
                    return false;
                }

                var parameters = method.GetParameters();
                if (parameters.Length == 1 && parameters[0].ParameterType.IsInstanceOfType(manager))
                {
                    method.Invoke(option, new[] { manager });
                    return true;
                }

                if (parameters.Length == 0)
                {
                    method.Invoke(option, null);
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static bool TryInvokeSwitchToNextMenu(object manager)
        {
            if (_trySwitchToNextMenuMethod == null)
            {
                return false;
            }

            try
            {
                return _trySwitchToNextMenuMethod.Invoke(manager, null) as bool? == true;
            }
            catch
            {
                return false;
            }
        }

        private static bool TryManualSwitchToNextMenu(object manager, object currentMenu, out string outputMenuId)
        {
            outputMenuId = GetFieldString(currentMenu, "OutputMenuId");
            if (string.IsNullOrWhiteSpace(outputMenuId)
                || _getNarrativeMenuWithIdMethod == null
                || _currentMenuProperty == null)
            {
                return false;
            }

            try
            {
                var nextMenu = _getNarrativeMenuWithIdMethod.Invoke(manager, new object[] { outputMenuId });
                if (nextMenu == null)
                {
                    return false;
                }

                _currentMenuProperty.SetValue(manager, nextMenu);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static bool TryClearMenuSelection(object manager, object currentMenu)
        {
            var selectedOptions = GetSelectedOptions(manager);
            if (selectedOptions == null || currentMenu == null)
            {
                return false;
            }

            try
            {
                if (selectedOptions.Contains(currentMenu))
                {
                    selectedOptions.Remove(currentMenu);
                    return true;
                }

                object keyToRemove = null;
                foreach (var key in selectedOptions.Keys)
                {
                    if (ReferenceEquals(key, currentMenu))
                    {
                        keyToRemove = key;
                        break;
                    }
                }

                if (keyToRemove == null)
                {
                    return false;
                }

                selectedOptions.Remove(keyToRemove);
                return true;
            }
            catch
            {
                return false;
            }
        }

        private static object GetCurrentMenuObject(object manager)
        {
            try
            {
                return _currentMenuProperty?.GetValue(manager);
            }
            catch
            {
                return null;
            }
        }

        private static IDictionary GetSelectedOptions(object manager)
        {
            try
            {
                if (_selectedOptionsProperty != null)
                {
                    return _selectedOptionsProperty.GetValue(manager) as IDictionary;
                }

                if (_selectedOptionsField != null)
                {
                    return _selectedOptionsField.GetValue(manager) as IDictionary;
                }
            }
            catch
            {
            }

            return null;
        }

        private static bool IsCurrentMenuSelected(object currentMenu, IDictionary selectedOptions)
        {
            if (currentMenu == null || selectedOptions == null)
            {
                return false;
            }

            foreach (var key in selectedOptions.Keys)
            {
                if (ReferenceEquals(key, currentMenu))
                {
                    return true;
                }
            }

            return false;
        }

        private static List<object> GetSuitableMenuOptions(object manager, object currentMenu)
        {
            var options = new List<object>();

            if (_getSuitableNarrativeMenuOptionsMethod != null)
            {
                foreach (var option in EnumerateMenuOptions(_getSuitableNarrativeMenuOptionsMethod.Invoke(manager, null)))
                {
                    if (option != null)
                    {
                        options.Add(option);
                    }
                }

                if (options.Count > 0)
                {
                    return options;
                }
            }

            if (currentMenu != null)
            {
                var optionsProperty = currentMenu.GetType().GetProperty(
                    "CharacterCreationMenuOptions",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (optionsProperty != null)
                {
                    foreach (var option in EnumerateMenuOptions(optionsProperty.GetValue(currentMenu)))
                    {
                        if (option != null)
                        {
                            options.Add(option);
                        }
                    }

                    if (options.Count > 0)
                    {
                        return options;
                    }
                }
            }

            if (_getCurrentMenuOptionsMethod != null)
            {
                var menuIndex = TryGetCurrentMenuIndex(manager);
                foreach (var option in EnumerateMenuOptions(_getCurrentMenuOptionsMethod.Invoke(manager, new object[] { menuIndex })))
                {
                    if (option != null)
                    {
                        options.Add(option);
                    }
                }
            }

            return options;
        }

        private static string GetMenuId(object menu)
        {
            if (menu == null)
            {
                return null;
            }

            var stringId = GetStringId(menu);
            if (!string.IsNullOrWhiteSpace(stringId))
            {
                return stringId;
            }

            var id = GetFieldString(menu, "Id");
            if (!string.IsNullOrWhiteSpace(id))
            {
                return id;
            }

            return menu.GetType().Name;
        }

        private static string GetStringId(object target)
        {
            if (target == null)
            {
                return null;
            }

            try
            {
                var stringIdField = target.GetType().GetField(
                    "StringId",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (stringIdField != null)
                {
                    var fieldValue = stringIdField.GetValue(target) as string;
                    if (!string.IsNullOrWhiteSpace(fieldValue))
                    {
                        return fieldValue;
                    }
                }

                var stringIdProperty = target.GetType().GetProperty(
                    "StringId",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (stringIdProperty != null)
                {
                    var propertyValue = stringIdProperty.GetValue(target) as string;
                    if (!string.IsNullOrWhiteSpace(propertyValue))
                    {
                        return propertyValue;
                    }
                }
            }
            catch
            {
            }

            return null;
        }

        private static string GetFieldString(object target, string fieldName)
        {
            if (target == null || string.IsNullOrWhiteSpace(fieldName))
            {
                return null;
            }

            try
            {
                var field = target.GetType().GetField(
                    fieldName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                return field?.GetValue(target) as string;
            }
            catch
            {
                return null;
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

        private static bool IsOptionAvailable(object option, object manager)
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

                var parameters = onCondition.GetParameters();
                if (parameters.Length == 1 && parameters[0].ParameterType.IsInstanceOfType(manager))
                {
                    return onCondition.Invoke(option, new object[] { manager }) as bool? != false;
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

            var stringId = GetStringId(option);
            if (!string.IsNullOrWhiteSpace(stringId))
            {
                return stringId;
            }

            var id = GetFieldString(option, "Id");
            if (!string.IsNullOrWhiteSpace(id))
            {
                return id;
            }

            return option.GetType().Name;
        }

        private static string TruncateForNotice(string value, int maxLength)
        {
            if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
            {
                return value ?? string.Empty;
            }

            return value.Substring(0, maxLength - 1) + "…";
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
