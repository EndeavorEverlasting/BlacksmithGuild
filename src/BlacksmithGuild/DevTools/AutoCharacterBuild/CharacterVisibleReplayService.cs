using System;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterVisibleReplayService
    {
        public const string ReplayFileName = "BlacksmithGuild_CharacterVisibleReplay.json";

        private static readonly string ReplayPath = Path.Combine(BasePath.Name, ReplayFileName);
        private static bool _replayArmed;
        private static bool _completed;
        private static string _blockedReason;

        public static void ArmReplayFromBest()
        {
            _replayArmed = true;
            _completed = false;
            _blockedReason = null;

            var bestPath = Path.Combine(BasePath.Name, CharacterBuildBestSelector.BestFileName);
            if (!File.Exists(bestPath))
            {
                _blockedReason = "CharacterBuildBest.json missing — run SelectCharacterBuildBestNow first";
                WriteReplayJson();
                return;
            }

            var bestJson = File.ReadAllText(bestPath);
            if (bestJson.IndexOf("\"blockedReason\"", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                _blockedReason = "best selection blocked";
                WriteReplayJson();
            }
        }

        public static void MarkCompleted()
        {
            if (!_replayArmed)
            {
                return;
            }

            _completed = true;
            WriteReplayJson();
        }

        public static void MarkBlocked(string reason)
        {
            _blockedReason = reason;
            WriteReplayJson();
        }

        public static void ResetSession()
        {
            _replayArmed = false;
            _completed = false;
            _blockedReason = null;
        }

        public static void FinalizeOnMapReady()
        {
            if (!_replayArmed)
            {
                return;
            }

            if (string.IsNullOrEmpty(_blockedReason))
            {
                _completed = CharacterBuildRouteSelector.BlockedReason == null;
                if (!_completed && !string.IsNullOrEmpty(CharacterBuildRouteSelector.BlockedReason))
                {
                    _blockedReason = CharacterBuildRouteSelector.BlockedReason;
                }
            }

            WriteReplayJson();
        }

        private static void WriteReplayJson()
        {
            var legitimacy = _completed && string.IsNullOrEmpty(_blockedReason)
                ? "VanillaLegit"
                : _completed ? "VanillaPlausibleButIncompleteEvidence" : "Failed";

            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"completed\": {_completed.ToString().ToLowerInvariant()},");
            sb.AppendLine($"  \"visibleMode\": true,");
            sb.AppendLine($"  \"decisionPauseMs\": {DevToolsConfig.CharacterCreationDecisionPauseMs},");
            sb.AppendLine($"  \"blockedReason\": \"{Escape(_blockedReason)}\",");
            sb.AppendLine($"  \"legitimacyVerdict\": \"{legitimacy}\",");
            sb.AppendLine($"  \"finalVerdict\": \"{( _completed ? "ready for user checkpoint" : "blocked")}\"");
            sb.AppendLine("}");

            File.WriteAllText(ReplayPath, sb.ToString(), Encoding.UTF8);
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
