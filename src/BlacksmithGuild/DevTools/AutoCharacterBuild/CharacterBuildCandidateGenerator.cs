using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public static class CharacterBuildCandidateGenerator
    {
        public const string MatrixFileName = "BlacksmithGuild_CharacterBuildCandidateMatrix.json";

        private static readonly string MatrixPath = Path.Combine(BasePath.Name, MatrixFileName);

        public static bool TryGenerateFromCatalogPath(string catalogPath, out string error)
        {
            error = null;
            if (!File.Exists(catalogPath))
            {
                error = $"catalog missing: {catalogPath}";
                return false;
            }

            var catalogJson = File.ReadAllText(catalogPath);
            if (catalogJson.IndexOf("IncompleteCatalog", StringComparison.OrdinalIgnoreCase) >= 0
                && catalogJson.IndexOf("\"verdict\": \"CompleteCatalog\"", StringComparison.OrdinalIgnoreCase) < 0)
            {
                error = "catalog verdict IncompleteCatalog — block candidate generation";
                WriteBlockedMatrix(error);
                return false;
            }

            var options = ParseCatalogOptions(catalogJson);
            if (options.Count == 0)
            {
                error = "catalog has zero options";
                WriteBlockedMatrix(error);
                return false;
            }

            var menus = options
                .GroupBy(option => option.MenuId, StringComparer.OrdinalIgnoreCase)
                .OrderBy(group => StageOrder(group.First().Stage))
                .ThenBy(group => group.Key, StringComparer.OrdinalIgnoreCase)
                .Select(group => group.ToList())
                .ToList();

            var routes = EnumerateRoutes(menus, maxRoutes: 5000);
            var candidates = new List<CharacterBuildCandidate>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            foreach (var route in routes)
            {
                var routeKey = string.Join(">", route.Select(step => $"{step.MenuId}:{step.OptionId}"));
                if (!seen.Add(routeKey))
                {
                    continue;
                }

                var candidate = BuildCandidate(route, options);
                var lowConfidence = route.Any(step =>
                    options.First(o => o.MenuId == step.MenuId && o.OptionId == step.OptionId).ParsedRewards == null);

                CharacterBuildCandidateScorer.ScoreCandidate(candidate, "AseraiTradeSmithBalanced", lowConfidence);
                candidates.Add(candidate);
            }

            var balanced = PickTop(candidates, "AseraiTradeSmithBalanced", 8);
            foreach (var candidate in candidates)
            {
                CharacterBuildCandidateScorer.ScoreCandidate(candidate, "ScreenshotReplayNearest", candidate.Confidence == "Low");
            }

            var screenshot = PickTop(candidates, "ScreenshotReplayNearest", 4);
            foreach (var candidate in candidates)
            {
                CharacterBuildCandidateScorer.ScoreCandidate(candidate, "AseraiSmithingMax", candidate.Confidence == "Low");
            }

            var smithingMax = PickTop(candidates, "AseraiSmithingMax", 4);
            var selected = new List<CharacterBuildCandidate>();
            selected.AddRange(balanced);
            foreach (var candidate in screenshot)
            {
                if (!selected.Any(x => x.CandidateId == candidate.CandidateId))
                {
                    selected.Add(candidate);
                }
            }

            foreach (var candidate in smithingMax)
            {
                if (!selected.Any(x => x.CandidateId == candidate.CandidateId))
                {
                    selected.Add(candidate);
                }
            }

            WriteMatrixJson(selected, catalogPath);
            return true;
        }

        public static bool TryGenerateDefault(out string error)
        {
            var catalogPath = Path.Combine(BasePath.Name, CharacterCreationChoiceCatalogBuilder.CatalogFileName);
            return TryGenerateFromCatalogPath(catalogPath, out error);
        }

        private static List<CharacterBuildCandidate> PickTop(
            List<CharacterBuildCandidate> candidates,
            string profile,
            int count)
        {
            foreach (var candidate in candidates)
            {
                CharacterBuildCandidateScorer.ScoreCandidate(
                    candidate,
                    profile,
                    candidate.Confidence == "Low");
            }

            return candidates
                .OrderByDescending(candidate => candidate.Score)
                .ThenBy(candidate => candidate.CandidateId, StringComparer.OrdinalIgnoreCase)
                .Take(count)
                .ToList();
        }

        private static CharacterBuildCandidate BuildCandidate(
            List<CharacterBuildRouteStep> route,
            List<CatalogOptionRecord> options)
        {
            var candidate = new CharacterBuildCandidate
            {
                CandidateId = BuildCandidateId(route)
            };
            candidate.Route.AddRange(route);

            foreach (var step in route)
            {
                var option = options.FirstOrDefault(o =>
                    string.Equals(o.MenuId, step.MenuId, StringComparison.OrdinalIgnoreCase)
                    && string.Equals(o.OptionId, step.OptionId, StringComparison.OrdinalIgnoreCase));
                if (option?.ParsedRewards == null)
                {
                    continue;
                }

                foreach (var reward in option.ParsedRewards)
                {
                    if (IsAttribute(reward.Key))
                    {
                        if (candidate.ProjectedAttributes.ContainsKey(reward.Key))
                        {
                            candidate.ProjectedAttributes[reward.Key] += reward.Value;
                        }
                        else
                        {
                            candidate.ProjectedAttributes[reward.Key] = reward.Value;
                        }
                    }
                    else
                    {
                        if (candidate.ProjectedSkills.ContainsKey(reward.Key))
                        {
                            candidate.ProjectedSkills[reward.Key] += reward.Value;
                        }
                        else
                        {
                            candidate.ProjectedSkills[reward.Key] = reward.Value;
                        }
                    }
                }
            }

            return candidate;
        }

        private static bool IsAttribute(string key)
        {
            return key.Equals("Endurance", StringComparison.OrdinalIgnoreCase)
                || key.Equals("Social", StringComparison.OrdinalIgnoreCase)
                || key.Equals("Intelligence", StringComparison.OrdinalIgnoreCase)
                || key.Equals("Vigor", StringComparison.OrdinalIgnoreCase)
                || key.Equals("Control", StringComparison.OrdinalIgnoreCase)
                || key.Equals("Cunning", StringComparison.OrdinalIgnoreCase);
        }

        private static string BuildCandidateId(List<CharacterBuildRouteStep> route)
        {
            var parts = route.Select(step => $"{step.Stage}_{step.OptionId}").ToArray();
            var raw = string.Join("__", parts);
            if (raw.Length <= 80)
            {
                return SanitizeId(raw);
            }

            return SanitizeId(raw.Substring(0, 80));
        }

        private static string SanitizeId(string value)
        {
            return Regex.Replace(value ?? "candidate", @"[^A-Za-z0-9_]+", "_");
        }

        private static List<List<CharacterBuildRouteStep>> EnumerateRoutes(
            List<List<CatalogOptionRecord>> menus,
            int maxRoutes)
        {
            var results = new List<List<CharacterBuildRouteStep>>();
            if (menus.Count == 0)
            {
                return results;
            }

            void Walk(int menuIndex, List<CharacterBuildRouteStep> current)
            {
                if (results.Count >= maxRoutes)
                {
                    return;
                }

                if (menuIndex >= menus.Count)
                {
                    results.Add(new List<CharacterBuildRouteStep>(current));
                    return;
                }

                foreach (var option in menus[menuIndex])
                {
                    current.Add(new CharacterBuildRouteStep
                    {
                        Stage = option.Stage,
                        MenuId = option.MenuId,
                        OptionId = option.OptionId,
                        OptionIndex = option.OptionIndex
                    });
                    Walk(menuIndex + 1, current);
                    current.RemoveAt(current.Count - 1);
                    if (results.Count >= maxRoutes)
                    {
                        return;
                    }
                }
            }

            Walk(0, new List<CharacterBuildRouteStep>());
            return results;
        }

        private static int StageOrder(string stage)
        {
            switch (stage?.ToLowerInvariant())
            {
                case "parent": return 0;
                case "childhood": return 1;
                case "education": return 2;
                case "youth": return 3;
                case "adulthood": return 4;
                case "age": return 5;
                default: return 9;
            }
        }

        private static List<CatalogOptionRecord> ParseCatalogOptions(string catalogJson)
        {
            var options = new List<CatalogOptionRecord>();
            var optionBlocks = Regex.Matches(catalogJson, "\\{[^{}]*\"menuId\"[^{}]*\\}");
            foreach (Match block in optionBlocks)
            {
                var menuId = ReadString(block.Value, "menuId");
                var optionId = ReadString(block.Value, "optionId");
                if (string.IsNullOrWhiteSpace(menuId) || string.IsNullOrWhiteSpace(optionId))
                {
                    continue;
                }

                var record = new CatalogOptionRecord
                {
                    Stage = ReadString(block.Value, "stage") ?? "unknown",
                    MenuId = menuId,
                    OptionId = optionId,
                    OptionIndex = ReadInt(block.Value, "optionIndex", 0),
                    OptionText = ReadString(block.Value, "optionText"),
                    RawRewardText = ReadString(block.Value, "rawRewardText"),
                    ExtractionMethod = ReadString(block.Value, "extractionMethod")
                };

                if (block.Value.IndexOf("\"parsedRewards\": null", StringComparison.OrdinalIgnoreCase) < 0)
                {
                    record.ParsedRewards = ParseRewards(block.Value);
                }

                options.Add(record);
            }

            return options;
        }

        private static Dictionary<string, int> ParseRewards(string optionJson)
        {
            var rewards = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var match = Regex.Match(optionJson, "\"parsedRewards\"\\s*:\\s*\\{([^}]*)\\}");
            if (!match.Success)
            {
                return rewards;
            }

            foreach (Match reward in Regex.Matches(match.Groups[1].Value, "\"([^\"]+)\"\\s*:\\s*(-?\\d+)"))
            {
                rewards[reward.Groups[1].Value] = int.Parse(reward.Groups[2].Value);
            }

            return rewards;
        }

        private static void WriteMatrixJson(IReadOnlyList<CharacterBuildCandidate> candidates, string catalogPath)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"catalogSource\": \"{Escape(catalogPath)}\",");
            sb.AppendLine($"  \"candidateCount\": {candidates.Count},");
            sb.AppendLine("  \"candidates\": [");

            for (var i = 0; i < candidates.Count; i++)
            {
                WriteCandidateJson(sb, candidates[i], i < candidates.Count - 1);
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");

            File.WriteAllText(MatrixPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteBlockedMatrix(string reason)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"blockedReason\": \"{Escape(reason)}\",");
            sb.AppendLine("  \"candidateCount\": 0,");
            sb.AppendLine("  \"candidates\": []");
            sb.AppendLine("}");
            File.WriteAllText(MatrixPath, sb.ToString(), Encoding.UTF8);
        }

        private static void WriteCandidateJson(StringBuilder sb, CharacterBuildCandidate candidate, bool trailingComma)
        {
            sb.AppendLine("    {");
            sb.AppendLine($"      \"candidateId\": \"{Escape(candidate.CandidateId)}\",");
            sb.AppendLine($"      \"profile\": \"{Escape(candidate.Profile)}\",");
            sb.AppendLine($"      \"score\": {candidate.Score.ToString("0.##")},");
            sb.AppendLine($"      \"confidence\": \"{Escape(candidate.Confidence)}\",");
            sb.AppendLine("      \"route\": [");
            for (var i = 0; i < candidate.Route.Count; i++)
            {
                var step = candidate.Route[i];
                sb.AppendLine("        {");
                sb.AppendLine($"          \"stage\": \"{Escape(step.Stage)}\",");
                sb.AppendLine($"          \"menuId\": \"{Escape(step.MenuId)}\",");
                sb.AppendLine($"          \"optionId\": \"{Escape(step.OptionId)}\",");
                sb.AppendLine($"          \"optionIndex\": {step.OptionIndex}");
                sb.Append(i < candidate.Route.Count - 1 ? "        }," : "        }");
                sb.AppendLine();
            }

            sb.AppendLine("      ],");
            WriteIntMap(sb, "projectedSkills", candidate.ProjectedSkills, 6);
            WriteIntMap(sb, "projectedAttributes", candidate.ProjectedAttributes, 6, trailingSectionComma: true);
            sb.AppendLine("      \"reasons\": [");
            for (var i = 0; i < candidate.Reasons.Count; i++)
            {
                sb.Append($"        \"{Escape(candidate.Reasons[i])}\"");
                sb.AppendLine(i < candidate.Reasons.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("      ]");
            sb.Append(trailingComma ? "    }," : "    }");
            sb.AppendLine();
        }

        private static void WriteIntMap(
            StringBuilder sb,
            string name,
            Dictionary<string, int> values,
            int indent,
            bool trailingSectionComma = false)
        {
            var pad = new string(' ', indent);
            sb.AppendLine($"{pad}\"{name}\": {{");
            var index = 0;
            foreach (var entry in values)
            {
                sb.Append($"{pad}  \"{Escape(entry.Key)}\": {entry.Value}");
                sb.AppendLine(index < values.Count - 1 ? "," : string.Empty);
                index++;
            }

            sb.Append($"{pad}}}");
            sb.AppendLine(trailingSectionComma ? "," : string.Empty);
        }

        private static string ReadString(string json, string key)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*\"([^\"]*)\"");
            return match.Success ? Unescape(match.Groups[1].Value) : null;
        }

        private static int ReadInt(string json, string key, int fallback)
        {
            var match = Regex.Match(json, $"\"{key}\"\\s*:\\s*(-?\\d+)");
            return match.Success && int.TryParse(match.Groups[1].Value, out var value) ? value : fallback;
        }

        private static string Unescape(string value)
        {
            return (value ?? string.Empty).Replace("\\\"", "\"").Replace("\\\\", "\\");
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"");
        }
    }
}
