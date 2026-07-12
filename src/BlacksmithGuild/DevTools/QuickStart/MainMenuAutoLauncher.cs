using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using BlacksmithGuild.DevTools.Reporting;
using HarmonyLib;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class MainMenuAutoLauncher
    {
        private const string IntentFileName = "BlacksmithGuild_LaunchIntent.json";
        private const float MainMenuTimeoutSeconds = 30f;

        private static readonly string[] PlayOptionIds =
        {
            "SandBoxNewGame",
            "SandBox",
            "NewGame",
            "StoryModeNewGame"
        };

        private static readonly string[] ContinueOptionIds =
        {
            "ContinueCampaign",
            "Continue",
            "CampaignResumeGame"
        };

        private static MethodInfo _getInitialStateOptionsMethod;
        private static MethodInfo _getInitialStateOptionWithIdMethod;
        private static MethodInfo _executeInitialStateOptionWithIdMethod;
        private static PropertyInfo _currentModuleProperty;
        private static PropertyInfo _optionIdProperty;
        private static PropertyInfo _optionIsHiddenProperty;
        private static PropertyInfo _optionIsDisabledProperty;

        private static string _launchIntent;
        private static bool _intentConsumed;
        private static bool _optionsProbed;
        private static bool _loggedMainMenuTimeout;
        private static float _mainMenuWaitSeconds;
        private static float _initialStateStableSeconds;
        private static List<string> _intentSourcePaths = new List<string>();
        private static bool _forwardLaunchInProgress;
        private static bool _forwardLaunchCompletedThisProcess;
        private static bool _exactSaveLoadAttempted;
        private static readonly HashSet<string> LoggedBlockReasons = new HashSet<string>(StringComparer.Ordinal);

        private const float InitialStateWarmupSeconds = 1.0f;

        public static bool HasActiveIntent => !string.IsNullOrEmpty(_launchIntent) && !_intentConsumed;

        public static bool IsForwardLaunchInProgress => _forwardLaunchInProgress;

        public static bool ForwardLaunchCompletedThisProcess => _forwardLaunchCompletedThisProcess;

        internal static string CurrentLaunchIntentLabel =>
            string.IsNullOrEmpty(_launchIntent) ? "none" : _launchIntent;

        public static void ClearForwardLaunchInProgress()
        {
            _forwardLaunchInProgress = false;
        }

        public static void ResetForNewSession()
        {
            _launchIntent = null;
            _intentConsumed = false;
            _forwardLaunchInProgress = false;
            _forwardLaunchCompletedThisProcess = false;
            _exactSaveLoadAttempted = false;
            _optionsProbed = false;
            _loggedMainMenuTimeout = false;
            _mainMenuWaitSeconds = 0f;
            _initialStateStableSeconds = 0f;
            _intentSourcePaths = new List<string>();
            LoggedBlockReasons.Clear();
        }

        public static void Poll(float dt)
        {
            if (!DevToolsConfig.AutoLaunchFromMainMenu)
            {
                return;
            }

            if (IsCampaignLoaded())
            {
                return;
            }

            if (string.IsNullOrEmpty(_launchIntent) && !_intentConsumed)
            {
                TryLoadLaunchIntent();
            }

            if (_intentConsumed
                || _forwardLaunchCompletedThisProcess
                || CampaignSetupStateTracker.ForwardLaunchCompletedThisProcess)
            {
                if (IsOnMainMenu())
                {
                    var blockReason = _intentConsumed
                        ? "intent already consumed"
                        : "forward launch already completed this process";
                    LogMainMenuIntentDecision("block", blockReason);
                }

                return;
            }

            if (string.IsNullOrEmpty(_launchIntent))
            {
                return;
            }

            if (!EnsureBindings())
            {
                return;
            }

            if (!IsOnMainMenu())
            {
                return;
            }

            _mainMenuWaitSeconds += dt;
            ProbeOptionsOnce();

            if (IsReadyForMenuExecute())
            {
                _initialStateStableSeconds += dt;
            }
            else
            {
                _initialStateStableSeconds = 0f;
            }

            if (!IsReadyForMenuExecute() || _initialStateStableSeconds < InitialStateWarmupSeconds)
            {
                return;
            }

            var executed = false;
            if (string.Equals(_launchIntent, "continue", StringComparison.OrdinalIgnoreCase))
            {
                if (RuntimeProofContext.HasVisibleTradeCycleRequest)
                {
                    var requestedSaveId = RuntimeProofContext.RequestedSaveId;
                    if (!_exactSaveLoadAttempted)
                    {
                        _exactSaveLoadAttempted = true;
                        LogMainMenuIntentDecision("auto-select", $"exact visible-trade save {requestedSaveId}");
                        if (DevSaveResolver.TryGetExactApproved(requestedSaveId, out var requestedSave)
                            && DevSaveAutoLoader.TryLoad(requestedSave))
                        {
                            CompleteIntent($"auto-loading exact requested dev save {requestedSaveId}.");
                            executed = true;
                        }
                        else
                        {
                            LogMainMenuIntentDecision("block", $"exact requested dev save unavailable {requestedSaveId}");
                        }
                    }
                }
                else
                {
                    LogMainMenuIntentDecision("auto-select", "continue intent");
                    if (TryExecuteFirstAvailable(ContinueOptionIds, "Continue Campaign", out var selectedId))
                    {
                        CompleteIntent($"auto-selecting {selectedId} (Continue Campaign).");
                        executed = true;
                    }
                }
            }
            else if (TryExecuteFirstAvailable(PlayOptionIds, "SandBox", out var playId))
            {
                LogMainMenuIntentDecision("auto-select", "play intent");
                CompleteIntent($"auto-selecting {playId} (SandBox).");
                executed = true;
            }

            if (!executed && _mainMenuWaitSeconds >= MainMenuTimeoutSeconds && !_loggedMainMenuTimeout)
            {
                _loggedMainMenuTimeout = true;
                LogVisibleOptions("main menu auto-select timed out");
            }
        }

        private static void CompleteIntent(string message)
        {
            LaunchPathInference.RecordIntent(_launchIntent);
            GuildLog.Info($"[TBG QUICKSTART] {message}", showInGame: false);
            GuildLog.Display($"TBG QUICKSTART: {message}");
            DeleteIntentFiles("intent consumed after main menu action");
            _intentConsumed = true;
            _launchIntent = null;
            _forwardLaunchInProgress = true;
            _forwardLaunchCompletedThisProcess = true;
            LogMainMenuIntentDecision("delete", "intent consumed");
        }

        internal static void DisarmForSessionEnd(string reason)
        {
            DeleteIntentFiles($"session ended: {reason}");
            _intentConsumed = true;
            _launchIntent = null;
            _forwardLaunchCompletedThisProcess = true;
            _forwardLaunchInProgress = false;
            LogMainMenuIntentDecision("block", "session ended");
        }

        internal static void EnsureIntentFilesCleared(string reason)
        {
            DeleteIntentFiles(reason);
        }

        internal static void LogLaunchIntentFileStatus(string trigger)
        {
            foreach (var path in GetIntentCandidatePaths().Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var exists = File.Exists(path);
                GuildLog.Info(
                    $"[TBG QUICKSTART] launch intent file ({trigger}): path={path} exists={exists}",
                    showInGame: false);
            }
        }

        private static void LogMainMenuIntentDecision(string decision, string reason)
        {
            if (string.Equals(decision, "block", StringComparison.OrdinalIgnoreCase))
            {
                var logKey = $"{decision}|{reason}";
                if (!LoggedBlockReasons.Add(logKey))
                {
                    return;
                }
            }

            var source = _intentSourcePaths.Count > 0
                ? string.Join("|", _intentSourcePaths)
                : "memory";
            GuildLog.Info(
                $"[TBG QUICKSTART] main menu intent decision: intent={CurrentLaunchIntentLabel} " +
                $"source={source} consumed={_intentConsumed} phase={CampaignSetupStateTracker.Phase} " +
                $"ready={CampaignSetupStateTracker.BootstrapCompletedThisProcess} decision={decision} reason={reason}",
                showInGame: false);
        }

        private static bool IsCampaignLoaded()
        {
            try
            {
                return Campaign.Current != null;
            }
            catch
            {
                return false;
            }
        }

        private static bool EnsureBindings()
        {
            if (_executeInitialStateOptionWithIdMethod != null)
            {
                return true;
            }

            var moduleType = AccessTools.TypeByName("TaleWorlds.MountAndBlade.Module");
            if (moduleType == null)
            {
                return false;
            }

            _currentModuleProperty = AccessTools.Property(moduleType, "CurrentModule");
            _getInitialStateOptionsMethod = AccessTools.Method(moduleType, "GetInitialStateOptions");
            _getInitialStateOptionWithIdMethod = AccessTools.Method(moduleType, "GetInitialStateOptionWithId", new[] { typeof(string) });
            _executeInitialStateOptionWithIdMethod = AccessTools.Method(moduleType, "ExecuteInitialStateOptionWithId", new[] { typeof(string) });

            var optionType = AccessTools.TypeByName("TaleWorlds.MountAndBlade.InitialStateOption");
            if (optionType != null)
            {
                _optionIdProperty = AccessTools.Property(optionType, "Id");
                _optionIsHiddenProperty = AccessTools.Property(optionType, "IsHidden");
                _optionIsDisabledProperty = AccessTools.Property(optionType, "IsDisabledAndReason");
            }

            return _currentModuleProperty != null && _executeInitialStateOptionWithIdMethod != null;
        }

        private static object GetCurrentModule()
        {
            return _currentModuleProperty?.GetValue(null, null);
        }

        private static bool IsOnMainMenu()
        {
            try
            {
                var activeStateName = GameSessionState.GetActiveStateName();
                if (string.Equals(activeStateName, "InitialState", StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }

                return Game.Current == null
                    && (string.IsNullOrEmpty(activeStateName)
                        || activeStateName == "null"
                        || activeStateName == "unknown");
            }
            catch
            {
                return false;
            }
        }

        private static bool IsReadyForMenuExecute()
        {
            try
            {
                var activeStateName = GameSessionState.GetActiveStateName();
                return string.Equals(activeStateName, "InitialState", StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return false;
            }
        }

        private static void ProbeOptionsOnce()
        {
            if (_optionsProbed)
            {
                return;
            }

            _optionsProbed = true;
            LogVisibleOptions("main menu probe");
        }

        private static void LogVisibleOptions(string label)
        {
            try
            {
                var module = GetCurrentModule();
                if (module == null)
                {
                    GuildLog.Info($"[TBG QUICKSTART] {label}: Module.CurrentModule is null.", showInGame: false);
                    return;
                }

                var optionsObject = _getInitialStateOptionsMethod?.Invoke(module, null) as IEnumerable;
                var options = optionsObject?.Cast<object>().ToList() ?? new List<object>();
                if (options.Count == 0)
                {
                    GuildLog.Info($"[TBG QUICKSTART] {label}: no options.", showInGame: false);
                    return;
                }

                var summary = string.Join(" ", options.Select(DescribeOption));
                GuildLog.Info($"[TBG QUICKSTART] launch intent: {_launchIntent}", showInGame: false);
                GuildLog.Info($"[TBG QUICKSTART] {label}: {summary}", showInGame: false);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] {label} failed: {ex.Message}", showInGame: false);
            }
        }

        private static string DescribeOption(object option)
        {
            var id = _optionIdProperty?.GetValue(option) as string ?? "?";
            var hidden = InvokeBoolFunc(_optionIsHiddenProperty?.GetValue(option));
            return $"{id}={(hidden ? "hidden" : "visible")}";
        }

        private static bool TryExecuteFirstAvailable(string[] optionIds, string label, out string selectedId)
        {
            selectedId = null;
            foreach (var optionId in optionIds)
            {
                if (!TryExecuteOption(optionId))
                {
                    continue;
                }

                selectedId = optionId;
                return true;
            }

            return false;
        }

        private static bool TryExecuteOption(string optionId)
        {
            try
            {
                var module = GetCurrentModule();
                if (module == null)
                {
                    return false;
                }

                var option = _getInitialStateOptionWithIdMethod?.Invoke(module, new object[] { optionId });
                if (option == null)
                {
                    return false;
                }

                if (InvokeBoolFunc(_optionIsHiddenProperty?.GetValue(option)))
                {
                    return false;
                }

                if (IsOptionDisabled(option, out var reason))
                {
                    GuildLog.Info($"[TBG QUICKSTART] option {optionId} disabled: {reason}", showInGame: false);
                    return false;
                }

                _executeInitialStateOptionWithIdMethod.Invoke(module, new object[] { optionId });
                return true;
            }
            catch (TargetInvocationException ex)
            {
                var inner = ex.InnerException?.Message ?? "no inner";
                GuildLog.Info($"[TBG QUICKSTART] ExecuteInitialStateOptionWithId({optionId}) failed: {inner}", showInGame: false);
                return false;
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] ExecuteInitialStateOptionWithId({optionId}) failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        private static bool IsOptionDisabled(object option, out string reason)
        {
            reason = null;
            var disabledFunc = _optionIsDisabledProperty?.GetValue(option);
            if (disabledFunc == null)
            {
                return false;
            }

            try
            {
                var result = disabledFunc.GetType().GetMethod("Invoke")?.Invoke(disabledFunc, null);
                if (result == null)
                {
                    return false;
                }

                var resultType = result.GetType();
                var item1 = resultType.GetField("Item1")?.GetValue(result) as bool?;
                var item2 = resultType.GetField("Item2")?.GetValue(result);
                if (item1 == true)
                {
                    reason = item2?.ToString() ?? "disabled";
                    return true;
                }
            }
            catch
            {
            }

            return false;
        }

        private static bool InvokeBoolFunc(object func)
        {
            if (func == null)
            {
                return false;
            }

            try
            {
                return func.GetType().GetMethod("Invoke")?.Invoke(func, null) as bool? == true;
            }
            catch
            {
                return false;
            }
        }

        private static void TryLoadLaunchIntent()
        {
            foreach (var path in GetIntentCandidatePaths())
            {
                if (!File.Exists(path))
                {
                    continue;
                }

                try
                {
                    var json = File.ReadAllText(path);
                    var match = Regex.Match(json, "\"intent\"\\s*:\\s*\"(?<intent>play|continue)\"", RegexOptions.IgnoreCase);
                    if (!match.Success)
                    {
                        continue;
                    }

                    _launchIntent = match.Groups["intent"].Value.ToLowerInvariant();
                    LaunchPathInference.RecordIntent(_launchIntent);
                    if (!_intentSourcePaths.Contains(path, StringComparer.OrdinalIgnoreCase))
                    {
                        _intentSourcePaths.Add(path);
                    }

                    GuildLog.Info($"[TBG QUICKSTART] loaded launch intent={_launchIntent} from {path}", showInGame: false);
                    return;
                }
                catch (Exception ex)
                {
                    GuildLog.Info($"[TBG QUICKSTART] launch intent read failed ({path}): {ex.Message}", showInGame: false);
                }
            }
        }

        private static void DeleteIntentFiles(string reason)
        {
            foreach (var path in GetIntentCandidatePaths().Concat(_intentSourcePaths).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                try
                {
                    if (File.Exists(path))
                    {
                        File.Delete(path);
                        GuildLog.Info($"[TBG QUICKSTART] launch intent deleted: path={path} reason={reason}", showInGame: false);
                    }
                }
                catch (Exception ex)
                {
                    GuildLog.Info($"[TBG QUICKSTART] launch intent delete failed: path={path} reason={ex.Message}", showInGame: false);
                }
            }
        }

        private static string[] GetIntentCandidatePaths()
        {
            var paths = new List<string>();
            var fromDll = TryResolveBannerlordRootFromDll();
            if (!string.IsNullOrEmpty(fromDll))
            {
                paths.Add(Path.Combine(fromDll, IntentFileName));
            }

            paths.Add(Path.Combine(BasePath.Name, IntentFileName));
            return paths.Distinct(StringComparer.OrdinalIgnoreCase).ToArray();
        }

        private static string TryResolveBannerlordRootFromDll()
        {
            try
            {
                var location = Assembly.GetExecutingAssembly().Location;
                if (string.IsNullOrEmpty(location))
                {
                    return null;
                }

                var moduleDir = Directory.GetParent(location)?.Parent?.FullName;
                var modulesDir = Directory.GetParent(moduleDir ?? string.Empty)?.FullName;
                if (modulesDir == null
                    || !string.Equals(Path.GetFileName(modulesDir), "Modules", StringComparison.OrdinalIgnoreCase))
                {
                    return null;
                }

                return Directory.GetParent(modulesDir)?.FullName;
            }
            catch
            {
                return null;
            }
        }
    }
}
