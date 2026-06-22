using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using BlacksmithGuild.DevTools;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class CharacterBuildRouteStep
    {
        public string MenuId { get; set; }
        public string OptionId { get; set; }
        public int OptionIndex { get; set; } = -1;
        public string Stage { get; set; }
    }

    public sealed class CharacterBuildVariantConfig
    {
        public string Mode { get; set; } = "doctrine";
        public string CandidateId { get; set; }
        public string SelectedBuildMode { get; set; }
        public bool VisibleMode { get; set; }
        public int DecisionPauseMs { get; set; } = 750;
        public bool CatalogMode { get; set; }
        public bool ReplayMode { get; set; }
        public string TestSavePrefix { get; set; } = "BSG_ASR_TEST_";
        public string TestSaveName { get; set; }
        public double Score { get; set; }
        public List<CharacterBuildRouteStep> Route { get; } = new List<CharacterBuildRouteStep>();
        public string BlockedReason { get; set; }
    }

    public static class CharacterBuildVariantConfigService
    {
        public const string ConfigFileName = "BlacksmithGuild_CharacterBuildVariantConfig.json";

        private static readonly string ConfigPath = Path.Combine(BasePath.Name, ConfigFileName);
        private static CharacterBuildVariantConfig _activeConfig;
        private static bool _appliedRuntimeFlags;

        public static CharacterBuildVariantConfig ActiveConfig => _activeConfig;

        public static bool HasActiveVariantRoute =>
            _activeConfig != null
            && _activeConfig.Route.Count > 0
            && string.Equals(_activeConfig.Mode, "variant", StringComparison.OrdinalIgnoreCase);

        public static bool IsCatalogMode =>
            DevToolsConfig.CharacterBuildCatalogMode
            || (_activeConfig != null && _activeConfig.CatalogMode);

        public static bool IsReplayMode =>
            _activeConfig != null && _activeConfig.ReplayMode;

        public static void TryLoadAtStartup()
        {
            _activeConfig = null;
            _appliedRuntimeFlags = false;

            if (!File.Exists(ConfigPath))
            {
                return;
            }

            try
            {
                _activeConfig = ParseConfig(File.ReadAllText(ConfigPath));
                ApplyRuntimeFlags();
                GuildLog.Info(
                    $"[TBG CHARACTER] variant config loaded mode={_activeConfig.Mode} routeSteps={_activeConfig.Route.Count}",
                    showInGame: false);
            }
            catch (Exception ex)
            {
                GuildLog.Info($"[TBG CHARACTER] variant config load failed: {ex.Message}", showInGame: false);
            }
        }

        public static void ResetSession()
        {
            _appliedRuntimeFlags = false;
            if (_activeConfig == null)
            {
                return;
            }

            ApplyRuntimeFlags();
        }

        private static void ApplyRuntimeFlags()
        {
            if (_activeConfig == null || _appliedRuntimeFlags)
            {
                return;
            }

            _appliedRuntimeFlags = true;
            DevToolsConfig.LegitimacyMode = CharacterLegitimacyMode.VanillaLegit;
            DevToolsConfig.AutoApplyCharacterBuild = false;

            if (_activeConfig.CatalogMode || string.Equals(_activeConfig.Mode, "catalog", StringComparison.OrdinalIgnoreCase))
            {
                DevToolsConfig.CharacterBuildCatalogMode = true;
                DevToolsConfig.CharacterCreationVisibleMode = false;
            }
            else
            {
                DevToolsConfig.CharacterBuildCatalogMode = false;
            }

            if (string.Equals(_activeConfig.Mode, "personal", StringComparison.OrdinalIgnoreCase))
            {
                DevToolsConfig.CharacterCreationVisibleMode = true;
                DevToolsConfig.CharacterCreationDecisionPauseMs = _activeConfig.DecisionPauseMs > 0
                    ? _activeConfig.DecisionPauseMs
                    : 2000;
            }
            else if (_activeConfig.ReplayMode || string.Equals(_activeConfig.Mode, "replay", StringComparison.OrdinalIgnoreCase))
            {
                DevToolsConfig.CharacterCreationVisibleMode = _activeConfig.VisibleMode;
                DevToolsConfig.CharacterCreationDecisionPauseMs = _activeConfig.DecisionPauseMs > 0
                    ? _activeConfig.DecisionPauseMs
                    : 750;
            }
            else if (!DevToolsConfig.CharacterBuildCatalogMode)
            {
                DevToolsConfig.CharacterCreationVisibleMode = _activeConfig.VisibleMode;
                if (_activeConfig.DecisionPauseMs > 0)
                {
                    DevToolsConfig.CharacterCreationDecisionPauseMs = _activeConfig.DecisionPauseMs;
                }
            }
        }

        private static CharacterBuildVariantConfig ParseConfig(string json)
        {
            var config = new CharacterBuildVariantConfig();
            if (string.IsNullOrWhiteSpace(json))
            {
                return config;
            }

            config.Mode = ReadString(json, "mode") ?? config.Mode;
            config.CandidateId = ReadString(json, "candidateId");
            config.SelectedBuildMode = ReadString(json, "selectedBuildMode");
            config.TestSavePrefix = ReadString(json, "testSavePrefix") ?? config.TestSavePrefix;
            config.TestSaveName = ReadString(json, "testSaveName");
            config.BlockedReason = ReadString(json, "blockedReason");
            config.CatalogMode = ReadBool(json, "catalogMode");
            config.ReplayMode = ReadBool(json, "replayMode")
                || string.Equals(config.Mode, "replay", StringComparison.OrdinalIgnoreCase);
            config.VisibleMode = ReadBool(json, "visibleMode");
            config.DecisionPauseMs = ReadInt(json, "decisionPauseMs", config.DecisionPauseMs);
            config.Score = ReadDouble(json, "score");

            var routeMatch = Regex.Match(json, "\"route\"\\s*:\\s*\\[(.*?)\\]", RegexOptions.Singleline);
            if (!routeMatch.Success)
            {
                return config;
            }

            foreach (Match stepMatch in Regex.Matches(routeMatch.Groups[1].Value, "\\{[^}]+\\}"))
            {
                var stepJson = stepMatch.Value;
                config.Route.Add(new CharacterBuildRouteStep
                {
                    MenuId = ReadString(stepJson, "menuId"),
                    OptionId = ReadString(stepJson, "optionId"),
                    OptionIndex = ReadInt(stepJson, "optionIndex", -1),
                    Stage = ReadString(stepJson, "stage")
                });
            }

            return config;
        }

        private static string ReadString(string json, string key)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*\"([^\"]*)\"");
            return match.Success ? Unescape(match.Groups[1].Value) : null;
        }

        private static bool ReadBool(string json, string key)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*(true|false)", RegexOptions.IgnoreCase);
            return match.Success && string.Equals(match.Groups[1].Value, "true", StringComparison.OrdinalIgnoreCase);
        }

        private static int ReadInt(string json, string key, int fallback)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*(-?\\d+)");
            return match.Success && int.TryParse(match.Groups[1].Value, out var value) ? value : fallback;
        }

        private static double ReadDouble(string json, string key)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*(-?\\d+(?:\\.\\d+)?)");
            return match.Success && double.TryParse(match.Groups[1].Value, out var value) ? value : 0d;
        }

        private static string Unescape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\\"", "\"")
                .Replace("\\\\", "\\");
        }
    }
}
