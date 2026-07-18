using System;
using System.IO;
using BlacksmithGuild.DevTools.Reporting;

namespace BlacksmithGuild.DevTools.SessionIntent
{
    /// <summary>
    /// Reads BlacksmithGuild_SessionIntent.json from the Bannerlord root and documents directory.
    /// Falls back to BlacksmithGuild_LaunchIntent.json for backward compatibility.
    /// </summary>
    public static class SessionIntentReader
    {
        private static SessionIntentModel _cached;
        private static DateTime _lastReadUtc = DateTime.MinValue;
        private static readonly TimeSpan CacheTtl = TimeSpan.FromSeconds(10);

        public static SessionIntentModel Current
        {
            get
            {
                if (_cached != null && (DateTime.UtcNow - _lastReadUtc) < CacheTtl)
                {
                    return _cached;
                }

                _cached = ReadFromDisk();
                _lastReadUtc = DateTime.UtcNow;
                return _cached;
            }
        }

        public static SessionIntentModel ReadFromDisk()
        {
            var intent = TryReadSessionIntent() ?? TryReadLegacyLaunchIntent() ?? CreateUnknown();
            return intent;
        }

        public static string GetDrivenByLabel()
        {
            return Current?.DrivenBy ?? "unknown";
        }

        public static bool IsAutomationSession()
        {
            return Current?.IsAutomation ?? false;
        }

        public static bool IsHumanSession()
        {
            return Current?.IsHuman ?? true;
        }

        public static string GetActiveSprint()
        {
            return Current?.Sprint;
        }

        public static bool IsSprintActive(string sprintName)
        {
            if (string.IsNullOrWhiteSpace(sprintName) || Current?.Sprint == null)
            {
                return false;
            }

            return string.Equals(Current.Sprint, sprintName, StringComparison.OrdinalIgnoreCase);
        }

        private static SessionIntentModel TryReadSessionIntent()
        {
            var roots = new List<string>();

            try
            {
                var location = System.Reflection.Assembly.GetExecutingAssembly().Location;
                if (!string.IsNullOrWhiteSpace(location))
                {
                    roots.Add(Path.GetDirectoryName(location));
                }
            }
            catch { }

            try
            {
                roots.Add(TaleWorlds.Engine.Utilities.GetBasePath());
            }
            catch { }

            roots.Add(TaleWorlds.Library.BasePath.Name);

            foreach (var root in roots.Where(r => !string.IsNullOrWhiteSpace(r)).Distinct(StringComparer.OrdinalIgnoreCase))
            {
                var path = Path.Combine(root, SessionIntentModel.FileName);
                if (!File.Exists(path)) continue;

                try
                {
                    var json = File.ReadAllText(path);
                    var model = FastJson.Deserialize<SessionIntentModel>(json);
                    if (model != null && !string.IsNullOrWhiteSpace(model.DrivenBy))
                    {
                        DebugLogger.Test($"[TBG] SessionIntent loaded: drivenBy={model.DrivenBy} launchIntent={model.LaunchIntent} sprint={model.Sprint} sessionId={model.SessionId}");
                        return model;
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.Test($"[TBG] SessionIntent read failed: {ex.Message}");
                }
            }

            return null;
        }

        private static SessionIntentModel TryReadLegacyLaunchIntent()
        {
            foreach (var root in new[] { TaleWorlds.Library.BasePath.Name })
            {
                if (string.IsNullOrWhiteSpace(root)) continue;

                var path = Path.Combine(root, "BlacksmithGuild_LaunchIntent.json");
                if (!File.Exists(path)) continue;

                try
                {
                    var json = File.ReadAllText(path);
                    var match = System.Text.RegularExpressions.Regex.Match(json, @"""intent""\s*:\s*""(play|continue)""");
                    if (match.Success)
                    {
                        var launchIntent = match.Groups[1].Value;
                        DebugLogger.Test($"[TBG] Legacy LaunchIntent loaded: {launchIntent} (no session context)");
                        return new SessionIntentModel
                        {
                            Schema = "tbg.session-intent.v1",
                            GeneratedUtc = DateTime.UtcNow.ToString("o"),
                            DrivenBy = "unknown",
                            LaunchIntent = launchIntent,
                            SessionId = "legacy-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"),
                            PriorityEngineMode = "normal",
                        };
                    }
                }
                catch (Exception ex)
                {
                    DebugLogger.Test($"[TBG] Legacy LaunchIntent read failed: {ex.Message}");
                }
            }

            return null;
        }

        private static SessionIntentModel CreateUnknown()
        {
            return new SessionIntentModel
            {
                Schema = "tbg.session-intent.v1",
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                DrivenBy = "human_player",
                LaunchIntent = "none",
                SessionId = Guid.NewGuid().ToString("N"),
                PriorityEngineMode = "observe_only",
            };
        }

        public static void InvalidateCache()
        {
            _cached = null;
            _lastReadUtc = DateTime.MinValue;
        }
    }
}
