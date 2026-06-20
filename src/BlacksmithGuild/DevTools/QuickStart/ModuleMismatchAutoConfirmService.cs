using System;
using System.Reflection;
using HarmonyLib;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class ModuleMismatchAutoConfirmService
    {
        private const string HarmonyId = "com.endeavoreverlasting.blacksmithguild.modulemismatch";

        private static Harmony _harmony;
        private static bool _applied;
        private static bool _confirmedThisSession;
        private static bool _probeLogged;

        public static void TryApply()
        {
            if (!DevToolsConfig.DevToolsEnabled)
            {
                return;
            }

            if (_applied)
            {
                return;
            }

            try
            {
                _harmony = new Harmony(HarmonyId);
                var informationManagerType = AccessTools.TypeByName("TaleWorlds.Library.InformationManager");
                if (informationManagerType == null)
                {
                    LogProbeOnce("InformationManager type not found");
                    return;
                }

                var patched = 0;
                foreach (var method in informationManagerType.GetMethods(BindingFlags.Static | BindingFlags.Public))
                {
                    if (!string.Equals(method.Name, "ShowInquiry", StringComparison.Ordinal))
                    {
                        continue;
                    }

                    var parameters = method.GetParameters();
                    if (parameters.Length == 0)
                    {
                        continue;
                    }

                    var firstParam = parameters[0].ParameterType;
                    if (!firstParam.Name.Contains("Inquiry"))
                    {
                        continue;
                    }

                    var postfix = AccessTools.Method(
                        typeof(ModuleMismatchAutoConfirmService),
                        nameof(ShowInquiryPostfix));
                    _harmony.Patch(method, postfix: new HarmonyMethod(postfix));
                    patched++;
                }

                _applied = patched > 0;
                GuildLog.Info(
                    $"[TBG QUICKSTART] Module Mismatch auto-Yes patch: {( _applied ? $"OK ({patched} ShowInquiry overload(s))" : "SKIP (no ShowInquiry target)")}",
                    showInGame: false);
            }
            catch (Exception ex)
            {
                LogProbeOnce($"patch failed: {ex.Message}");
            }
        }

        public static void ResetForNewSession()
        {
            _confirmedThisSession = false;
        }

        public static void Poll(float dt)
        {
        }

        public static void ShowInquiryPostfix(object __0)
        {
            if (_confirmedThisSession || __0 == null)
            {
                return;
            }

            if (!IsModuleMismatchInquiry(__0))
            {
                return;
            }

            if (!TryInvokeAffirmativeAction(__0))
            {
                GuildLog.Info(
                    "[TBG QUICKSTART] Module Mismatch inquiry detected but AffirmativeAction unavailable",
                    showInGame: false);
                return;
            }

            _confirmedThisSession = true;
            GuildLog.Info("[TBG QUICKSTART] Module Mismatch auto-Yes (in-game)", showInGame: false);
        }

        private static bool IsModuleMismatchInquiry(object inquiryData)
        {
            var title = ReadInquiryText(inquiryData, "TitleText", "Title");
            var body = ReadInquiryText(inquiryData, "Text", "DescriptionText", "Description");

            return ContainsModuleMismatchFragment(title) || ContainsModuleMismatchFragment(body);
        }

        private static string ReadInquiryText(object inquiryData, params string[] memberNames)
        {
            if (inquiryData == null)
            {
                return string.Empty;
            }

            var type = inquiryData.GetType();
            foreach (var memberName in memberNames)
            {
                var property = type.GetProperty(memberName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (property != null)
                {
                    return property.GetValue(inquiryData)?.ToString() ?? string.Empty;
                }

                var field = type.GetField(memberName, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
                if (field != null)
                {
                    return field.GetValue(inquiryData)?.ToString() ?? string.Empty;
                }
            }

            return string.Empty;
        }

        private static bool ContainsModuleMismatchFragment(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            return value.IndexOf("Module Mismatch", StringComparison.OrdinalIgnoreCase) >= 0
                || value.IndexOf("different modules", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static bool TryInvokeAffirmativeAction(object inquiryData)
        {
            var type = inquiryData.GetType();
            var property = type.GetProperty(
                "AffirmativeAction",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (property?.GetValue(inquiryData) is Action affirmativeFromProperty)
            {
                affirmativeFromProperty.Invoke();
                return true;
            }

            var field = type.GetField(
                "AffirmativeAction",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            if (field?.GetValue(inquiryData) is Action affirmativeFromField)
            {
                affirmativeFromField.Invoke();
                return true;
            }

            return false;
        }

        private static void LogProbeOnce(string detail)
        {
            if (_probeLogged)
            {
                return;
            }

            _probeLogged = true;
            GuildLog.Info($"[TBG QUICKSTART] Module Mismatch auto-Yes patch: {detail}", showInGame: false);
        }
    }
}
