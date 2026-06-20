using System;
using System.Reflection;
using HarmonyLib;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.QuickStart
{
    internal static class ModuleMismatchAutoConfirmService
    {
        private const string HarmonyId = "com.endeavoreverlasting.blacksmithguild.modulemismatch";

        private const float DeferredConfirmDelaySeconds = 0.25f;
        private const float PollRetryIntervalSeconds = 0.25f;
        private const float MaxConfirmRetrySeconds = 30f;
        private const float PollBackupIntervalSeconds = 0.5f;

        private static Harmony _harmony;
        private static bool _applied;
        private static bool _confirmedThisSession;
        private static bool _probeLogged;
        private static bool _eventSubscribed;

        private static object _pendingInquiry;
        private static float _deferredDelayRemaining;
        private static float _confirmRetryElapsed;
        private static float _pollBackupElapsed;
        private static bool _pollBackupLogged;
        private static bool _confirmFailedLogged;
        private static float _pendingQueuedElapsed;
        private static bool _queuedLogged;
        private static int _confirmAttemptCount;
        private static MethodInfo _isAnyInquiryActiveMethod;
        private static MethodInfo _hideInquiryMethod;

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

                _isAnyInquiryActiveMethod = informationManagerType.GetMethod(
                    "IsAnyInquiryActive",
                    BindingFlags.Static | BindingFlags.Public);
                _hideInquiryMethod = informationManagerType.GetMethod(
                    "HideInquiry",
                    BindingFlags.Static | BindingFlags.Public);

                var patched = PatchInquiryMethods(informationManagerType, "ShowInquiry");
                patched += PatchInquiryMethods(informationManagerType, "ShowTextInquiry");

                TrySubscribeOnShowInquiry();

                _applied = patched > 0 || _eventSubscribed;
                GuildLog.Info(
                    $"[TBG QUICKSTART] Module Mismatch auto-Yes patch: {( _applied ? $"OK ({patched} inquiry overload(s), event={(_eventSubscribed ? "yes" : "no")})" : "SKIP (no inquiry target)")}",
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
            _queuedLogged = false;
            _pollBackupLogged = false;
            _confirmFailedLogged = false;
            _confirmAttemptCount = 0;
            ClearPendingConfirm();
        }

        public static void Poll(float dt)
        {
            if (_confirmedThisSession || dt <= 0f)
            {
                return;
            }

            if (_pendingInquiry != null)
            {
                PollDeferredConfirm(dt);
                return;
            }

            PollBackupDetect(dt);
        }

        public static void ShowInquiryPostfix(object __0)
        {
            TryQueueFromInquiry(__0, "postfix");
        }

        private static void OnShowInquiryEvent(InquiryData inquiryData, bool pauseGame, bool prioritize)
        {
            TryQueueFromInquiry(inquiryData, "event");
        }

        private static void TryQueueFromInquiry(object inquiryData, string source)
        {
            if (_confirmedThisSession || inquiryData == null)
            {
                return;
            }

            if (!IsModuleMismatchInquiry(inquiryData))
            {
                return;
            }

            QueueDeferredConfirm(inquiryData, source);
        }

        private static void QueueDeferredConfirm(object inquiryData, string source)
        {
            if (_confirmedThisSession || inquiryData == null)
            {
                return;
            }

            var isNewInquiry = !ReferenceEquals(_pendingInquiry, inquiryData);
            _pendingInquiry = inquiryData;
            _deferredDelayRemaining = DeferredConfirmDelaySeconds;
            _confirmRetryElapsed = 0f;
            _pendingQueuedElapsed = 0f;
            _confirmFailedLogged = false;

            if (_queuedLogged && !isNewInquiry)
            {
                return;
            }

            _queuedLogged = true;
            GuildLog.Info(
                $"[TBG QUICKSTART] Module Mismatch inquiry queued ({source})",
                showInGame: false);
        }

        private static void PollDeferredConfirm(float dt)
        {
            _pendingQueuedElapsed += dt;

            if (_deferredDelayRemaining > 0f)
            {
                _deferredDelayRemaining -= dt;
                return;
            }

            _confirmRetryElapsed += dt;
            if (_confirmRetryElapsed < PollRetryIntervalSeconds)
            {
                return;
            }

            _confirmRetryElapsed = 0f;

            if (_pendingQueuedElapsed > MaxConfirmRetrySeconds)
            {
                GuildLog.Info(
                    "[TBG QUICKSTART] Module Mismatch auto-Yes deferred retries exhausted",
                    showInGame: false);
                _queuedLogged = false;
                ClearPendingConfirm();
                return;
            }

            if (!IsAnyInquiryActive())
            {
                MarkConfirmed("inquiry already cleared");
                return;
            }

            if (TryConfirmPending("deferred"))
            {
                return;
            }

            if (_confirmFailedLogged)
            {
                return;
            }

            _confirmFailedLogged = true;
            GuildLog.Info(
                "[TBG QUICKSTART] Module Mismatch inquiry detected but AffirmativeAction unavailable",
                showInGame: false);
        }

        private static void PollBackupDetect(float dt)
        {
            _pollBackupElapsed += dt;
            if (_pollBackupElapsed < PollBackupIntervalSeconds)
            {
                return;
            }

            _pollBackupElapsed = 0f;

            if (!IsAnyInquiryActive())
            {
                return;
            }

            if (_pollBackupLogged)
            {
                return;
            }

            _pollBackupLogged = true;
            GuildLog.Info(
                "[TBG QUICKSTART] Module Mismatch poll backup: inquiry active without queued data",
                showInGame: false);
        }

        private static bool TryConfirmPending(string source)
        {
            if (_pendingInquiry == null || _confirmedThisSession)
            {
                return false;
            }

            _confirmAttemptCount++;
            var invoked = TryInvokeAffirmativeAction(_pendingInquiry);
            if (invoked)
            {
                TryHideInquiry();
            }

            var inquiryActive = IsAnyInquiryActive();
            GuildLog.Info(
                $"[TBG QUICKSTART] Module Mismatch auto-Yes attempt={_confirmAttemptCount} inquiryActive={inquiryActive.ToString().ToLowerInvariant()}",
                showInGame: false);

            if (!inquiryActive)
            {
                MarkConfirmed(source);
                return true;
            }

            if (!invoked)
            {
                return false;
            }

            return false;
        }

        private static void MarkConfirmed(string source)
        {
            if (_confirmedThisSession)
            {
                return;
            }

            _confirmedThisSession = true;
            ClearPendingConfirm();
            GuildLog.Info(
                $"[TBG QUICKSTART] Module Mismatch auto-Yes confirmed (inquiry cleared) source={source}",
                showInGame: false);
        }

        private static void ClearPendingConfirm()
        {
            _pendingInquiry = null;
            _deferredDelayRemaining = 0f;
            _confirmRetryElapsed = 0f;
            _pendingQueuedElapsed = 0f;
            _confirmFailedLogged = false;
        }

        private static int PatchInquiryMethods(Type informationManagerType, string methodName)
        {
            var patched = 0;
            foreach (var method in informationManagerType.GetMethods(BindingFlags.Static | BindingFlags.Public))
            {
                if (!string.Equals(method.Name, methodName, StringComparison.Ordinal))
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

            return patched;
        }

        private static void TrySubscribeOnShowInquiry()
        {
            if (_eventSubscribed)
            {
                return;
            }

            try
            {
                InformationManager.OnShowInquiry += OnShowInquiryEvent;
                _eventSubscribed = true;
            }
            catch (Exception ex)
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] Module Mismatch OnShowInquiry subscribe failed: {ex.Message}",
                    showInGame: false);
            }
        }

        private static bool IsAnyInquiryActive()
        {
            if (_isAnyInquiryActiveMethod == null)
            {
                return true;
            }

            try
            {
                return _isAnyInquiryActiveMethod.Invoke(null, null) is true;
            }
            catch
            {
                return true;
            }
        }

        private static void TryHideInquiry()
        {
            if (_hideInquiryMethod == null)
            {
                return;
            }

            try
            {
                _hideInquiryMethod.Invoke(null, null);
            }
            catch
            {
            }
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
                || value.IndexOf("different modules", StringComparison.OrdinalIgnoreCase) >= 0
                || value.IndexOf("versions different", StringComparison.OrdinalIgnoreCase) >= 0
                || value.IndexOf("versions are different", StringComparison.OrdinalIgnoreCase) >= 0;
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
