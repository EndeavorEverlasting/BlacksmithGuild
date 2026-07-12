using System;
using System.Globalization;
using System.IO;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.MapTrade
{
    /// <summary>
    /// Writes one bounded latest-state artifact on explicit route-safety analysis. Campaign-tick
    /// monitoring never calls this writer, so threat evidence cannot become a per-frame log.
    /// </summary>
    public static class HostileEscapeEvidenceWriter
    {
        public const string FileName = "BlacksmithGuild_HostileEscapeAnalysis.json";

        public static void Write(MapTradeHostileSafetySnapshot snapshot, string source)
        {
            if (snapshot == null)
            {
                return;
            }

            var escape = snapshot.EscapeRecommendation;
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine("  \"evidenceMode\": \"latest_snapshot_overwrite\",");
            sb.AppendLine("  \"recommendationOnly\": true,");
            sb.AppendLine("  \"movementMutationApplied\": false,");
            sb.AppendLine($"  \"scanSucceeded\": {Boolean(snapshot.ScanSucceeded)},");
            sb.AppendLine($"  \"scanFailure\": {NullableString(snapshot.ScanFailure)},");
            sb.AppendLine($"  \"enumerationPasses\": {snapshot.EnumerationPasses},");
            sb.AppendLine($"  \"partiesEnumerated\": {snapshot.PartiesEnumerated},");
            sb.AppendLine($"  \"hostilesConsidered\": {snapshot.HostileCount},");
            sb.AppendLine($"  \"blocking\": {Boolean(snapshot.IsBlocking)},");
            sb.AppendLine($"  \"nearestHostileDistance\": {Number(NormalizeDistance(snapshot.NearestHostileDistance))},");
            sb.AppendLine("  \"escapeRecommendation\": {");
            sb.AppendLine($"    \"headingX\": {Number(escape?.EscapeHeadingX ?? 0f)},");
            sb.AppendLine($"    \"headingY\": {Number(escape?.EscapeHeadingY ?? 0f)},");
            sb.AppendLine($"    \"suggestedPositionX\": {Number(escape?.SuggestedPositionX ?? 0f)},");
            sb.AppendLine($"    \"suggestedPositionY\": {Number(escape?.SuggestedPositionY ?? 0f)},");
            sb.AppendLine($"    \"currentMinimumClearanceMargin\": {Number(escape?.CurrentMinimumClearanceMargin ?? -1f)},");
            sb.AppendLine($"    \"projectedMinimumClearanceMargin\": {Number(escape?.ProjectedMinimumClearanceMargin ?? -1f)},");
            sb.AppendLine($"    \"improvesMinimumClearance\": {Boolean(escape?.ImprovesMinimumClearance ?? false)},");
            sb.AppendLine($"    \"threatsSurroundProtectedParty\": {Boolean(escape?.ThreatsSurroundProtectedParty ?? false)},");
            sb.AppendLine($"    \"fallbackDirectionUsed\": {Boolean(escape?.FallbackDirectionUsed ?? false)},");
            sb.AppendLine($"    \"geometryConfidence\": {NullableString(escape?.GeometryConfidence)},");
            sb.AppendLine($"    \"urgency\": {NullableString(escape?.Urgency)},");
            sb.AppendLine($"    \"pairEvaluations\": {escape?.PairEvaluations ?? 0}");
            sb.AppendLine("  }");
            sb.AppendLine("}");

            File.WriteAllText(
                Path.Combine(BasePath.Name, FileName),
                sb.ToString(),
                new UTF8Encoding(encoderShouldEmitUTF8Identifier: false));
        }

        private static float NormalizeDistance(float value) =>
            float.IsNaN(value) || float.IsInfinity(value) || value == float.MaxValue ? -1f : value;

        private static string Number(float value) =>
            value.ToString("0.###", CultureInfo.InvariantCulture);

        private static string Boolean(bool value) => value ? "true" : "false";

        private static string NullableString(string value) =>
            value == null ? "null" : $"\"{Escape(value)}\"";

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
