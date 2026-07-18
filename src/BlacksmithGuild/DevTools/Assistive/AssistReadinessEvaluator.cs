using System;
using System.IO;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Automation;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class AssistReadinessEvaluator
    {
        private static string _lastTraceFingerprint;
        private static bool _attachReadyCheckpointEmitted;

        public static bool IsOpenMapReady =>
            GameSessionState.IsCampaignMapReady && GameSessionState.IsCampaignMapSurfaceOpen;

        public static bool IsTownMenuReady =>
            string.Equals(
                GameSessionState.ReadinessSurface,
                ReadinessSurfaceKinds.SettlementMenu,
                StringComparison.Ordinal);

        public static bool IsAssistSurfaceEligible()
        {
            var surface = GameSessionState.ReadinessSurface ?? ReadinessSurfaceKinds.Unknown;
            if (surface == ReadinessSurfaceKinds.SettlementMenu
                || surface == ReadinessSurfaceKinds.MapSurface)
            {
                return true;
            }

            if (surface == ReadinessSurfaceKinds.SettlementInterior)
            {
                return !GameSessionState.IsMissionActiveForTrace();
            }

            return false;
        }

        public static bool IsInGameAssistReady =>
            GameSessionState.CanPollFileInbox && IsAssistSurfaceEligible();

        public static bool CanAcceptAssistiveCommand =>
            IsInGameAssistReady && !IsAssistCommandBlocked(out _);

        public static void ApplyInboxAndAssistFlags(bool trace = true)
        {
            var inboxReady = EvaluateFileInboxReadiness(
                out var skipReason,
                out var failErrorType,
                trace);
            GameSessionState.SetCanPollFileInbox(inboxReady);
        }

        public static bool EvaluateFileInboxReadiness(
            out string skipReason,
            out string failErrorType,
            bool trace = true)
        {
            skipReason = null;
            failErrorType = null;

            if (!GameSessionState.IsCampaignSessionReady)
            {
                skipReason = "session_not_ready";
                TraceFileInboxReadiness(false, skipReason, null, trace);
                return false;
            }

            if (!IsAssistSurfaceEligible())
            {
                skipReason = $"surface_not_assist_eligible:{GameSessionState.ReadinessSurface}";
                TraceFileInboxReadiness(false, skipReason, null, trace);
                return false;
            }

            if (IsAssistCommandBlocked(out var blockReason))
            {
                skipReason = blockReason;
                TraceFileInboxReadiness(false, skipReason, null, trace);
                return false;
            }

            if (!TryProbeInboxFilesystem(out failErrorType))
            {
                TraceFileInboxReadiness(false, null, failErrorType, trace);
                return false;
            }

            TraceFileInboxReadiness(
                true,
                null,
                null,
                trace,
                GameSessionState.ReadinessSurface);
            return true;
        }

        private static bool IsAssistCommandBlocked(out string reason)
        {
            reason = null;

            if (!EngineToggleAuthority.IsEngineEnabled(EngineToggleKey.Assistive))
            {
                reason = "engine_toggle_manual:Assistive";
                return true;
            }

            if (GameSessionState.IsMissionActiveForTrace())
            {
                var gameplay = GameSessionState.LatestGameplaySurface;
                reason = !string.IsNullOrEmpty(gameplay?.MissionKind)
                    ? gameplay.MissionKind
                    : "mission_active";
                return true;
            }

            var activeState = GameSessionState.GetActiveStateName();
            if (string.Equals(activeState, "GameLoadingState", StringComparison.Ordinal))
            {
                reason = "loading";
                return true;
            }

            if (string.Equals(GameSessionState.ReadinessSurface, ReadinessSurfaceKinds.Loading, StringComparison.Ordinal)
                || string.Equals(GameSessionState.ReadinessSurface, ReadinessSurfaceKinds.MainMenu, StringComparison.Ordinal))
            {
                reason = $"surface_blocked:{GameSessionState.ReadinessSurface}";
                return true;
            }

            var surface = GameSessionState.LatestGameplaySurface;
            if (surface != null
                && !string.IsNullOrEmpty(surface.BlockReason)
                && !GameplaySurfaceClassifier.IsTravelExecuteSurface(surface.GameplaySurface)
                && surface.GameplaySurface != GameplaySurfaceKinds.SettlementInterior
                && surface.GameplaySurface != GameplaySurfaceKinds.SettlementCity)
            {
                reason = surface.BlockReason;
                return true;
            }

            if (MapTransitionGuard.IsUnsafeContinueLoadWindow()
                && !MapTransitionGuard.TryDetectCampaignSessionLoaded(out _))
            {
                reason = "map_load_transition";
                return true;
            }

            return false;
        }

        private static bool TryProbeInboxFilesystem(out string errorType)
        {
            errorType = null;
            try
            {
                var root = BasePath.Name;
                if (string.IsNullOrWhiteSpace(root))
                {
                    errorType = "base_path_missing";
                    return false;
                }

                if (!Directory.Exists(root))
                {
                    Directory.CreateDirectory(root);
                }

                var probePath = Path.Combine(root, ".tbg_inbox_probe");
                File.WriteAllText(probePath, DateTime.UtcNow.ToString("o"));
                File.Delete(probePath);
                return true;
            }
            catch (UnauthorizedAccessException)
            {
                errorType = "access_denied";
                return false;
            }
            catch (IOException)
            {
                errorType = "io_error";
                return false;
            }
            catch (Exception)
            {
                errorType = "filesystem_probe_failed";
                return false;
            }
        }

        private static void TraceFileInboxReadiness(
            bool ready,
            string skipReason,
            string failErrorType,
            bool trace,
            string surface = null)
        {
            if (!trace)
            {
                return;
            }

            var fingerprint = ready
                ? $"ok|{surface}|{GameSessionState.CanPollFileInbox}"
                : $"skip|{skipReason}|fail|{failErrorType}";
            if (string.Equals(fingerprint, _lastTraceFingerprint, StringComparison.Ordinal))
            {
                return;
            }

            _lastTraceFingerprint = fingerprint;
            surface = surface ?? GameSessionState.ReadinessSurface ?? ReadinessSurfaceKinds.Unknown;

            if (ready)
            {
                if (!_attachReadyCheckpointEmitted)
                {
                    _attachReadyCheckpointEmitted = true;
                    AutomationUserMessageService.Checkpoint(
                        AutomationCheckpointEvent.AttachReady,
                        "Assist attach ready.",
                        phase: "attach",
                        detailsJson: "{\"surface\":\"" + Escape(surface) + "\"}");
                }

                DebugLogger.Test(
                    $"[TBG TRACE] area=FileInboxReadiness op=Evaluate stage=ok surface={surface} canPollFileInbox=true",
                    showInGame: false);
                return;
            }

            if (!string.IsNullOrEmpty(failErrorType))
            {
                DebugLogger.Test(
                    $"[TBG TRACE] area=FileInboxReadiness op=Evaluate stage=failed errorType={failErrorType}",
                    showInGame: false);
                return;
            }

            DebugLogger.Test(
                $"[TBG TRACE] area=FileInboxReadiness op=Evaluate stage=skipped reason={skipReason ?? "unknown"}",
                showInGame: false);
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
