using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text.RegularExpressions;
using HarmonyLib;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class MainMenuAutoLauncher
    {
        private const string IntentFileName = "BlacksmithGuild_LaunchIntent.json";

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
        private static bool _executedPrimary;
        private static bool _executedSandBox;
        private static float _sandBoxWaitSeconds;

        public static bool HasActiveIntent => !string.IsNullOrEmpty(_launchIntent) && !_intentConsumed;

        public static void ResetForNewSession()
        {
            _launchIntent = null;
            _intentConsumed = false;
            _optionsProbed = false;
            _executedPrimary = false;
            _executedSandBox = false;
            _sandBoxWaitSeconds = 0f;
        }

        public static void Poll(float dt)
        {
            if (!DevToolsConfig.AutoLaunchFromMainMenu)
            {
                return;
            }

            if (string.IsNullOrEmpty(_launchIntent) && !_intentConsumed)
            {
                TryLoadLaunchIntent();
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
                if (_executedPrimary && string.Equals(_launchIntent, "play", StringComparison.OrdinalIgnoreCase))
                {
                    _sandBoxWaitSeconds += dt;
                    if (_sandBoxWaitSeconds > 30f && !_executedSandBox)
                    {
                        GuildLog.Info("[TBG QUICKSTART] SandBox auto-select timed out on main menu.", showInGame: false);
                        _intentConsumed = true;
                    }
                }

                return;
            }

            ProbeOptionsOnce();

            if (string.Equals(_launchIntent, "continue", StringComparison.OrdinalIgnoreCase))
            {
                if (TryExecuteOption("Continue"))
                {
                    GuildLog.Info("[TBG QUICKSTART] auto-selecting Continue Campaign.", showInGame: false);
                    GuildLog.Display("TBG QUICKSTART: auto-selecting Continue Campaign.");
                    _intentConsumed = true;
                }

                return;
            }

            if (!_executedPrimary)
            {
                if (TryExecuteOption("SandBox"))
                {
                    GuildLog.Info("[TBG QUICKSTART] auto-selecting SandBox (direct).", showInGame: false);
                    GuildLog.Display("TBG QUICKSTART: auto-selecting SandBox.");
                    _executedPrimary = true;
                    _executedSandBox = true;
                    _intentConsumed = true;
                    return;
                }

                if (TryExecuteOption("NewGame"))
                {
                    GuildLog.Info("[TBG QUICKSTART] auto-selecting New Campaign.", showInGame: false);
                    GuildLog.Display("TBG QUICKSTART: auto-selecting New Campaign.");
                    _executedPrimary = true;
                }

                return;
            }

            if (!_executedSandBox && TryExecuteOption("SandBox"))
            {
                GuildLog.Info("[TBG QUICKSTART] auto-selecting SandBox.", showInGame: false);
                GuildLog.Display("TBG QUICKSTART: auto-selecting SandBox.");
                _executedSandBox = true;
                _intentConsumed = true;
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
            var moduleType = AccessTools.TypeByName("TaleWorlds.MountAndBlade.Module");
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

        private static void ProbeOptionsOnce()
        {
            if (_optionsProbed)
            {
                return;
            }

            _optionsProbed = true;

            try
            {
                var module = GetCurrentModule();
                if (module == null)
                {
                    GuildLog.Info("[TBG QUICKSTART] main menu probe: Module.CurrentModule is null.", showInGame: false);
                    return;
                }

                var optionsObject = _getInitialStateOptionsMethod?.Invoke(module, null) as IEnumerable;
                var options = optionsObject?.Cast<object>().ToList() ?? new List<object>();
                if (options.Count == 0)
                {
                    GuildLog.Info("[TBG QUICKSTART] main menu probe: no options.", showInGame: false);
                    return;
                }

                var summary = string.Join(
                    " ",
                    options.Select(DescribeOption));

                GuildLog.Info($"[TBG QUICKSTART] launch intent: {_launchIntent}", showInGame: false);
                GuildLog.Info($"[TBG QUICKSTART] main menu probe: {summary}", showInGame: false);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG QUICKSTART] main menu probe failed: {ex.Message}", showInGame: false);
            }
        }

        private static string DescribeOption(object option)
        {
            var id = _optionIdProperty?.GetValue(option) as string ?? "?";
            var hidden = InvokeBoolFunc(_optionIsHiddenProperty?.GetValue(option));
            return $"{id}={(hidden ? "hidden" : "visible")}";
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
                    File.Delete(path);
                    GuildLog.Info($"[TBG QUICKSTART] consumed launch intent from {path}", showInGame: false);
                    return;
                }
                catch (Exception ex)
                {
                    GuildLog.Info($"[TBG QUICKSTART] launch intent read failed ({path}): {ex.Message}", showInGame: false);
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
