using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    public static class AgentIterationConfigService
    {
        private const string ConfigFileName = "BlacksmithGuild_AgentIterationConfig.json";

        public static void TryLoadAtStartup()
        {
            TryLoad("startup");
        }

        public static bool TryLoadNow(string source)
        {
            return TryLoad(string.IsNullOrWhiteSpace(source) ? "unspecified" : source);
        }

        private static bool TryLoad(string source)
        {
            var path = Path.Combine(BasePath.Name, ConfigFileName);
            DebugLogger.Test($"[TBG AGENT] AgentIterationConfig load begin source={source} path={path}", showInGame: false);

            if (!File.Exists(path))
            {
                DebugLogger.Test($"[TBG AGENT] AgentIterationConfig missing source={source} path={path}", showInGame: false);
                return false;
            }

            try
            {
                var json = File.ReadAllText(path);
                ApplyFromJson(json);
                DebugLogger.Test($"[TBG AGENT] loaded AgentIterationConfig source={source} autoMapTradeRoute={DevToolsConfig.AgentAutoMapTradeRoute}", showInGame: false);
                return true;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG AGENT] failed to load AgentIterationConfig source={source}: {ex.Message}", showInGame: false);
                return false;
            }
        }
        public static void ApplyFromJson(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
            {
                return;
            }

            DevToolsConfig.AgentAutoLoop = ReadBool(json, "autoLoop", DevToolsConfig.AgentAutoLoop);
            DevToolsConfig.AgentAutoMapTradeRoute = ReadBool(json, "autoMapTradeRoute", DevToolsConfig.AgentAutoMapTradeRoute);
            DevToolsConfig.TavernHeroVisibleMode = ReadBool(json, "visibleMode", DevToolsConfig.TavernHeroVisibleMode);
            DevToolsConfig.TavernHeroDecisionPauseMs = ReadInt(json, "decisionPauseMs", DevToolsConfig.TavernHeroDecisionPauseMs);
            DevToolsConfig.TavernHeroSafeGoldReserve = ReadInt(json, "tavernHeroSafeGoldReserve", DevToolsConfig.TavernHeroSafeGoldReserve);
            DevToolsConfig.TavernHeroMaxRecruitmentsPerCommand =
                ReadInt(json, "tavernHeroMaxRecruitmentsPerCommand", DevToolsConfig.TavernHeroMaxRecruitmentsPerCommand);
            DevToolsConfig.TavernHeroAllowDirectInjection =
                ReadBool(json, "tavernHeroAllowDirectInjection", DevToolsConfig.TavernHeroAllowDirectInjection);
            DevToolsConfig.TavernHeroRequireDisposableSaveForRecruit =
                ReadBool(json, "requireDisposableSaveForRecruit", DevToolsConfig.TavernHeroRequireDisposableSaveForRecruit);
        }

        private static bool ReadBool(string json, string key, bool fallback)
        {
            var pattern = $"\"{key}\"";
            var index = json.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
            {
                return fallback;
            }

            var tail = json.Substring(index);
            if (tail.IndexOf("true", StringComparison.OrdinalIgnoreCase) >= 0
                && tail.IndexOf("true", StringComparison.OrdinalIgnoreCase) < 20)
            {
                return true;
            }

            if (tail.IndexOf("false", StringComparison.OrdinalIgnoreCase) >= 0
                && tail.IndexOf("false", StringComparison.OrdinalIgnoreCase) < 20)
            {
                return false;
            }

            return fallback;
        }

        private static int ReadInt(string json, string key, int fallback)
        {
            var pattern = $"\"{key}\"";
            var index = json.IndexOf(pattern, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
            {
                return fallback;
            }

            var colon = json.IndexOf(':', index);
            if (colon < 0)
            {
                return fallback;
            }

            var end = colon + 1;
            while (end < json.Length && char.IsWhiteSpace(json[end]))
            {
                end++;
            }

            var start = end;
            while (end < json.Length && (char.IsDigit(json[end]) || json[end] == '-'))
            {
                end++;
            }

            if (start == end)
            {
                return fallback;
            }

            return int.TryParse(json.Substring(start, end - start), out var value) ? value : fallback;
        }
    }
}
