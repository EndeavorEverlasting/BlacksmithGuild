using System.Text.RegularExpressions;

namespace BlacksmithGuild.DevTools.Assistive
{
    public sealed class AssistiveCommandInboxPayload
    {
        public bool? ExecuteRequested { get; set; }
        public string TargetSettlement { get; set; }
        public string CommandId { get; set; }
        public string RunId { get; set; }
        public string CorrelationId { get; set; }
        public string RequestedUtc { get; set; }

        public static bool TryParseFromJson(string json, out AssistiveCommandInboxPayload payload)
        {
            payload = new AssistiveCommandInboxPayload();
            if (string.IsNullOrWhiteSpace(json))
            {
                return false;
            }

            var executeMatch = Regex.Match(json, "\"execute\"\\s*:\\s*(true|false)", RegexOptions.IgnoreCase);
            if (executeMatch.Success)
            {
                payload.ExecuteRequested = string.Equals(
                    executeMatch.Groups[1].Value,
                    "true",
                    System.StringComparison.OrdinalIgnoreCase);
            }

            var targetMatch = Regex.Match(
                json,
                "\"targetSettlement\"\\s*:\\s*\"([^\"]+)\"",
                RegexOptions.IgnoreCase);
            if (targetMatch.Success)
            {
                payload.TargetSettlement = targetMatch.Groups[1].Value;
            }

            payload.CommandId = ReadString(json, "commandId");
            payload.RunId = ReadString(json, "runId");
            payload.CorrelationId = ReadString(json, "correlationId");
            payload.RequestedUtc = ReadString(json, "requestedUtc");

            return true;
        }

        private static string ReadString(string json, string propertyName)
        {
            var match = Regex.Match(
                json,
                "\"" + Regex.Escape(propertyName) + "\"\\s*:\\s*\"([^\"]+)\"",
                RegexOptions.IgnoreCase);
            return match.Success ? match.Groups[1].Value : null;
        }
    }
}
