using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BlacksmithGuild.DevTools.QuickStart;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.AutoCharacterBuild
{
    public sealed class CatalogOptionRecord
    {
        public string Stage { get; set; }
        public string MenuId { get; set; }
        public string OptionId { get; set; }
        public int OptionIndex { get; set; }
        public string OptionText { get; set; }
        public string VisibleDescription { get; set; }
        public Dictionary<string, int> ParsedRewards { get; set; }
        public string RawRewardText { get; set; }
        public bool Enabled { get; set; } = true;
        public string SelectionMode { get; set; } = "RuntimeCatalog";
        public string ExtractionMethod { get; set; }
        public List<string> ExtractionErrors { get; } = new List<string>();
    }

    public static class CharacterCreationChoiceCatalogBuilder
    {
        public const string CatalogFileName = "BlacksmithGuild_CharacterChoiceCatalog.json";

        private static readonly string CatalogPath = Path.Combine(BasePath.Name, CatalogFileName);
        private static readonly Dictionary<string, CatalogOptionRecord> OptionsByKey =
            new Dictionary<string, CatalogOptionRecord>(StringComparer.OrdinalIgnoreCase);
        private static readonly List<string> GlobalExtractionErrors = new List<string>();
        private static readonly List<string> CultureIds = new List<string>();
        private static bool _finalized;
        private static bool _enumerationAttempted;

        public static void ResetSession()
        {
            OptionsByKey.Clear();
            GlobalExtractionErrors.Clear();
            CultureIds.Clear();
            _finalized = false;
            _enumerationAttempted = false;
        }

        public static void RecordCultures(IEnumerable<CultureObject> cultures)
        {
            if (cultures == null)
            {
                GlobalExtractionErrors.Add("GetCultures returned null during catalog capture");
                return;
            }

            foreach (var culture in cultures)
            {
                if (culture == null)
                {
                    continue;
                }

                var id = culture.StringId ?? culture.Name?.ToString() ?? "unknown";
                if (!CultureIds.Contains(id))
                {
                    CultureIds.Add(id);
                }
            }
        }

        public static void TryEnumerateNarrativeMenus(object manager, object content)
        {
            if (_enumerationAttempted || manager == null)
            {
                return;
            }

            _enumerationAttempted = true;
            try
            {
                var getMenuMethod = manager.GetType().GetMethod(
                    "GetNarrativeMenuWithId",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (getMenuMethod == null)
                {
                    GlobalExtractionErrors.Add("GetNarrativeMenuWithId unavailable for enumeration pass");
                    return;
                }

                var knownMenuIds = DiscoverMenuIds(content, manager, getMenuMethod);
                foreach (var menuId in knownMenuIds)
                {
                    var menu = getMenuMethod.Invoke(manager, new object[] { menuId });
                    if (menu == null)
                    {
                        GlobalExtractionErrors.Add($"enumeration: menu not found id={menuId}");
                        continue;
                    }

                    RecordAllOptionsForMenu(manager, menu, menuId, "Reflection");
                }
            }
            catch (Exception ex)
            {
                GlobalExtractionErrors.Add($"enumeration failed: {ex.Message}");
            }
        }

        public static void RecordMenuVisit(object manager, object currentMenu, string menuId)
        {
            RecordAllOptionsForMenu(manager, currentMenu, menuId, "UIModel");
        }

        public static void FinalizeCatalog()
        {
            if (_finalized)
            {
                return;
            }

            _finalized = true;
            WriteCatalogJson();
        }

        public static bool IsCatalogComplete()
        {
            return GlobalExtractionErrors.Count == 0 && OptionsByKey.Count > 0;
        }

        public static string GetCatalogVerdict()
        {
            if (OptionsByKey.Count == 0)
            {
                return "IncompleteCatalog";
            }

            return GlobalExtractionErrors.Count == 0 ? "CompleteCatalog" : "IncompleteCatalog";
        }

        private static void RecordAllOptionsForMenu(
            object manager,
            object currentMenu,
            string menuId,
            string defaultMethod)
        {
            if (string.IsNullOrWhiteSpace(menuId))
            {
                menuId = "unknown";
            }

            var stage = AseraiTradeSmithDecisionMap.InferStage(menuId);
            var options = GetAllMenuOptions(manager, currentMenu);
            for (var index = 0; index < options.Count; index++)
            {
                var option = options[index];
                if (option == null)
                {
                    continue;
                }

                var optionId = DescribeOption(option);
                var key = $"{menuId}|{optionId}|{index}";
                if (OptionsByKey.ContainsKey(key))
                {
                    continue;
                }

                var optionText = AseraiTradeSmithDecisionMap.ExtractOptionText(option);
                var positive = ReadMemberString(option, "PositiveEffectText");
                var negative = ReadMemberString(option, "NegativeEffectText");
                var parse = CharacterCreationRewardTextParser.Parse(optionText, positive, negative);

                var record = new CatalogOptionRecord
                {
                    Stage = stage,
                    MenuId = menuId,
                    OptionId = optionId,
                    OptionIndex = index,
                    OptionText = optionText,
                    VisibleDescription = ReadMemberString(option, "Description") ?? optionText,
                    ParsedRewards = parse.ParsedRewards.Count > 0 ? parse.ParsedRewards : null,
                    RawRewardText = parse.RawRewardText,
                    Enabled = IsOptionAvailable(option, manager),
                    SelectionMode = "RuntimeCatalog",
                    ExtractionMethod = parse.ParsedRewards.Count > 0 ? parse.ExtractionMethod : defaultMethod
                };

                record.ExtractionErrors.AddRange(parse.ExtractionErrors);
                if (record.ParsedRewards == null && string.IsNullOrWhiteSpace(record.RawRewardText))
                {
                    record.ExtractionMethod = "FallbackSeed";
                    record.ExtractionErrors.Add("rewards unparseable; tagged FallbackSeed");
                }

                OptionsByKey[key] = record;
            }
        }

        private static List<string> DiscoverMenuIds(object content, object manager, MethodInfo getMenuMethod)
        {
            var menuIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            TryCollectMenuIdsFromMember(content, menuIds);
            TryCollectMenuIdsFromMember(manager, menuIds);

            if (menuIds.Count == 0)
            {
                GlobalExtractionErrors.Add("enumeration: no narrative menu registry discovered");
            }

            return new List<string>(menuIds);
        }

        private static void TryCollectMenuIdsFromMember(object target, HashSet<string> menuIds)
        {
            if (target == null)
            {
                return;
            }

            foreach (var member in target.GetType().GetMembers(BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic))
            {
                object value = null;
                if (member is PropertyInfo property)
                {
                    try { value = property.GetValue(target); } catch { continue; }
                }
                else if (member is FieldInfo field)
                {
                    try { value = field.GetValue(target); } catch { continue; }
                }
                else
                {
                    continue;
                }

                if (value is string stringId && stringId.IndexOf("menu", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    menuIds.Add(stringId);
                }
                else if (value is IEnumerable enumerable)
                {
                    foreach (var item in enumerable)
                    {
                        var id = ReadMenuId(item);
                        if (!string.IsNullOrWhiteSpace(id))
                        {
                            menuIds.Add(id);
                        }
                    }
                }
            }
        }

        private static string ReadMenuId(object menu)
        {
            if (menu == null)
            {
                return null;
            }

            return ReadMemberString(menu, "StringId")
                ?? ReadMemberString(menu, "Id")
                ?? (menu is string s ? s : null);
        }

        private static List<object> GetAllMenuOptions(object manager, object currentMenu)
        {
            var options = new List<object>();
            if (currentMenu != null)
            {
                var optionsProperty = currentMenu.GetType().GetProperty(
                    "CharacterCreationMenuOptions",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (optionsProperty?.GetValue(currentMenu) is IEnumerable rawOptions)
                {
                    foreach (var option in rawOptions)
                    {
                        if (option != null)
                        {
                            options.Add(option);
                        }
                    }
                }
            }

            if (options.Count > 0)
            {
                return options;
            }

            var suitableMethod = manager.GetType().GetMethod(
                "GetSuitableNarrativeMenuOptions",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (suitableMethod != null)
            {
                try
                {
                    if (suitableMethod.Invoke(manager, null) is IEnumerable suitable)
                    {
                        foreach (var option in suitable)
                        {
                            if (option != null)
                            {
                                options.Add(option);
                            }
                        }
                    }
                }
                catch
                {
                }
            }

            return options;
        }

        private static void WriteCatalogJson()
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{DateTime.UtcNow:o}\",");
            sb.AppendLine($"  \"build\": \"{Escape(CharacterDoctrineConfig.DefaultBuildId)}\",");
            sb.AppendLine($"  \"preferredCultureId\": \"{Escape(CharacterDoctrineConfig.PreferredCultureId)}\",");
            sb.AppendLine($"  \"verdict\": \"{GetCatalogVerdict()}\",");
            sb.AppendLine("  \"cultures\": [");
            for (var i = 0; i < CultureIds.Count; i++)
            {
                sb.Append($"    \"{Escape(CultureIds[i])}\"");
                sb.AppendLine(i < CultureIds.Count - 1 ? "," : string.Empty);
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"extractionErrors\": [");
            WriteStringArray(sb, GlobalExtractionErrors, 4);
            sb.AppendLine("  ],");
            sb.AppendLine("  \"options\": [");

            var index = 0;
            foreach (var record in OptionsByKey.Values)
            {
                WriteOptionJson(sb, record, index < OptionsByKey.Count - 1);
                index++;
            }

            sb.AppendLine("  ]");
            sb.AppendLine("}");

            File.WriteAllText(CatalogPath, sb.ToString(), Encoding.UTF8);
            GuildLog.Info(
                $"[TBG CHARACTER] catalog written options={OptionsByKey.Count} verdict={GetCatalogVerdict()}",
                showInGame: false);
        }

        private static void WriteOptionJson(StringBuilder sb, CatalogOptionRecord record, bool trailingComma)
        {
            sb.AppendLine("    {");
            sb.AppendLine($"      \"stage\": \"{Escape(record.Stage)}\",");
            sb.AppendLine($"      \"menuId\": \"{Escape(record.MenuId)}\",");
            sb.AppendLine($"      \"optionId\": \"{Escape(record.OptionId)}\",");
            sb.AppendLine($"      \"optionIndex\": {record.OptionIndex},");
            sb.AppendLine($"      \"optionText\": \"{Escape(record.OptionText)}\",");
            sb.AppendLine($"      \"visibleDescription\": \"{Escape(record.VisibleDescription)}\",");
            if (record.ParsedRewards != null && record.ParsedRewards.Count > 0)
            {
                sb.AppendLine("      \"parsedRewards\": {");
                var rewardIndex = 0;
                foreach (var reward in record.ParsedRewards)
                {
                    sb.Append($"        \"{Escape(reward.Key)}\": {reward.Value}");
                    sb.AppendLine(rewardIndex < record.ParsedRewards.Count - 1 ? "," : string.Empty);
                    rewardIndex++;
                }

                sb.AppendLine("      },");
            }
            else
            {
                sb.AppendLine("      \"parsedRewards\": null,");
            }

            sb.AppendLine($"      \"rawRewardText\": \"{Escape(record.RawRewardText)}\",");
            sb.AppendLine($"      \"enabled\": {record.Enabled.ToString().ToLowerInvariant()},");
            sb.AppendLine($"      \"selectionMode\": \"{Escape(record.SelectionMode)}\",");
            sb.AppendLine($"      \"extractionMethod\": \"{Escape(record.ExtractionMethod)}\",");
            sb.AppendLine("      \"extractionErrors\": [");
            WriteStringArray(sb, record.ExtractionErrors, 8);
            sb.AppendLine("      ]");
            sb.Append(trailingComma ? "    }," : "    }");
            sb.AppendLine();
        }

        private static void WriteStringArray(StringBuilder sb, IReadOnlyList<string> values, int indent)
        {
            var pad = new string(' ', indent);
            for (var i = 0; i < values.Count; i++)
            {
                sb.Append(pad);
                sb.Append($"\"{Escape(values[i])}\"");
                sb.AppendLine(i < values.Count - 1 ? "," : string.Empty);
            }
        }

        private static bool IsOptionAvailable(object option, object manager)
        {
            try
            {
                var onCondition = option.GetType().GetMethod(
                    "OnCondition",
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (onCondition == null)
                {
                    return true;
                }

                var parameters = onCondition.GetParameters();
                if (parameters.Length == 1 && parameters[0].ParameterType.IsInstanceOfType(manager))
                {
                    return onCondition.Invoke(option, new[] { manager }) as bool? != false;
                }

                return onCondition.Invoke(option, null) as bool? != false;
            }
            catch
            {
                return false;
            }
        }

        private static string DescribeOption(object option)
        {
            var stringId = ReadMemberString(option, "StringId");
            if (!string.IsNullOrWhiteSpace(stringId))
            {
                return stringId;
            }

            var id = ReadMemberString(option, "Id");
            return !string.IsNullOrWhiteSpace(id) ? id : option.GetType().Name;
        }

        private static string ReadMemberString(object target, string memberName)
        {
            try
            {
                var field = target.GetType().GetField(
                    memberName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                var fieldValue = field?.GetValue(target);
                if (fieldValue != null)
                {
                    return fieldValue.ToString();
                }

                var property = target.GetType().GetProperty(
                    memberName,
                    BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                return property?.GetValue(target)?.ToString();
            }
            catch
            {
                return null;
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty)
                .Replace("\\", "\\\\")
                .Replace("\"", "\\\"")
                .Replace("\r", "\\r")
                .Replace("\n", "\\n");
        }
    }
}
