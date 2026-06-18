using System;
using System.Globalization;
using System.IO;
using System.Reflection;
using System.Text.RegularExpressions;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Detects when a newer mod DLL was installed while Bannerlord is still running.
    /// Read-only — never attempts hot reload.
    /// </summary>
    public static class PendingReloadWatcher
    {
        private const string MarkerFileName = "BlacksmithGuild_PendingReload.json";
        private static readonly string MarkerPath = Path.Combine(BasePath.Name, MarkerFileName);

        private static DateTime _loadedDllWriteUtc;
        private static string _loadedVersion = "unknown";
        private static float _pollAccumulator;
        private static DateTime? _lastNotifiedDllWriteUtc;
        private static bool _reloadPending;

        public static bool IsReloadPending => _reloadPending;

        public static void OnModuleLoad()
        {
            try
            {
                var location = Assembly.GetExecutingAssembly().Location;
                if (!string.IsNullOrEmpty(location) && File.Exists(location))
                {
                    _loadedDllWriteUtc = File.GetLastWriteTimeUtc(location);
                }

                _loadedVersion = ReadInstalledVersion() ?? "unknown";
                ForgeStatus.Log(
                    $"[TBG RELOAD] module loaded dllUtc={_loadedDllWriteUtc:o} version={_loadedVersion}"
                );
            }
            catch (Exception ex)
            {
                ForgeStatus.Log($"[TBG RELOAD] module load stamp failed: {ex.Message}");
            }
        }

        public static void Poll(float deltaSeconds)
        {
            _pollAccumulator += deltaSeconds;
            if (_pollAccumulator < 2f)
            {
                return;
            }

            _pollAccumulator = 0f;

            try
            {
                EvaluatePendingReload();
            }
            catch (Exception ex)
            {
                ForgeStatus.Log($"[TBG RELOAD] poll failed: {ex.Message}");
            }
        }

        private static void EvaluatePendingReload()
        {
            if (!File.Exists(MarkerPath))
            {
                _reloadPending = false;
                return;
            }

            var markerJson = File.ReadAllText(MarkerPath);
            if (!TryParseUtcField(markerJson, "dllLastWriteUtc", out var markerDllWriteUtc))
            {
                return;
            }

            if (markerDllWriteUtc <= _loadedDllWriteUtc)
            {
                _reloadPending = false;
                return;
            }

            _reloadPending = true;

            if (_lastNotifiedDllWriteUtc.HasValue &&
                _lastNotifiedDllWriteUtc.Value == markerDllWriteUtc)
            {
                return;
            }

            _lastNotifiedDllWriteUtc = markerDllWriteUtc;
            var version = TryParseStringField(markerJson, "version") ?? _loadedVersion;
            ForgeStatus.Log("[TBG RELOAD] pending install detected");
            GuildLog.Display(
                $"TBG RELOAD: New mod build installed ({version}). Restart Bannerlord to load it."
            );
        }

        private static string ReadInstalledVersion()
        {
            var subModulePath = Path.Combine(
                BasePath.Name,
                "Modules",
                "BlacksmithGuild",
                "SubModule.xml"
            );

            if (!File.Exists(subModulePath))
            {
                return null;
            }

            var xml = File.ReadAllText(subModulePath);
            var match = Regex.Match(xml, "<Version value=\"([^\"]+)\"");
            return match.Success ? match.Groups[1].Value : null;
        }

        private static bool TryParseUtcField(string json, string fieldName, out DateTime value)
        {
            value = default;
            var stringValue = TryParseStringField(json, fieldName);
            if (string.IsNullOrEmpty(stringValue))
            {
                return false;
            }

            return DateTime.TryParse(
                stringValue,
                CultureInfo.InvariantCulture,
                DateTimeStyles.RoundtripKind,
                out value
            );
        }

        private static string TryParseStringField(string json, string fieldName)
        {
            if (string.IsNullOrEmpty(json))
            {
                return null;
            }

            var match = Regex.Match(
                json,
                $"\"{Regex.Escape(fieldName)}\"\\s*:\\s*\"([^\"]*)\"",
                RegexOptions.CultureInvariant
            );

            return match.Success ? match.Groups[1].Value : null;
        }
    }
}
