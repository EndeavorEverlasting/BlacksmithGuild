using System;
using System.Runtime.InteropServices;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Detects and dismisses the Bannerlord escape (pause) menu via Win32 keybd_event.
    /// The escape menu blocks all automation: time is stopped, command inbox is frozen,
    /// and ClockResumeHelper refuses to resume. This helper sends an Escape key press
    /// to close the menu, then the caller can resume the clock.
    /// </summary>
    public static class EscapeMenuHelper
    {
        private const byte VK_ESCAPE = 0x1B;
        private const uint KEYEVENTF_KEYUP = 0x0002;

        [DllImport("user32.dll", SetLastError = true)]
        private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

        private static bool _lastKnownEscapeMenu;
        private static DateTime _lastDismissAttemptUtc = DateTime.MinValue;
        private static readonly TimeSpan DismissCooldown = TimeSpan.FromSeconds(2);

        /// <summary>
        /// Returns true if the escape menu is currently open.
        /// Uses the same detection as GameplaySurfaceClassifier but exposes it
        /// as a direct boolean check for helpers that need it.
        /// </summary>
        public static bool IsEscapeMenuOpen()
        {
            try
            {
                var activeState = GameSessionState.GetActiveStateName() ?? "";
                var menuId = GameSessionState.ActiveMenuId ?? GameSessionState.MapMenuId ?? "";
                var combined = $"{menuId}|{activeState}".ToLowerInvariant();
                return combined.IndexOf("escape", StringComparison.OrdinalIgnoreCase) >= 0;
            }
            catch
            {
                return false;
            }
        }

        /// <summary>
        /// True when the last probe detected an escape menu and we haven't yet confirmed dismissal.
        /// </summary>
        public static bool EscapeMenuActive => _lastKnownEscapeMenu;

        /// <summary>
        /// Attempt to dismiss the escape menu by sending an Escape key press.
        /// Returns true if the menu was detected and a dismissal was attempted.
        /// Returns false if the menu was not open or dismissal was throttled.
        /// 
        /// Callers should:
        /// 1. Check IsEscapeMenuOpen() 
        /// 2. Call DismissIfOpen()
        /// 3. Wait ~200ms for the game to process the key
        /// 4. Then call ClockResumeHelper.EnsureClockRunning()
        /// </summary>
        public static bool DismissIfOpen()
        {
            if (!IsEscapeMenuOpen())
            {
                _lastKnownEscapeMenu = false;
                return false;
            }

            _lastKnownEscapeMenu = true;

            // Throttle dismissal attempts to avoid key flooding
            var now = DateTime.UtcNow;
            if (now - _lastDismissAttemptUtc < DismissCooldown)
            {
                return false;
            }

            _lastDismissAttemptUtc = now;
            SimulateEscapeKeyPress();
            DebugLogger.Test("[TBG ESCAPE] dismiss attempted via keybd_event(VK_ESCAPE)", showInGame: false);
            return true;
        }

        /// <summary>
        /// Force a dismiss attempt regardless of throttle. Use sparingly.
        /// </summary>
        public static void ForceDismiss()
        {
            _lastDismissAttemptUtc = DateTime.MinValue;
            DismissIfOpen();
        }

        /// <summary>
        /// Combined helper: detect escape menu, dismiss it, wait, then resume clock.
        /// Returns a tuple indicating what happened.
        /// </summary>
        public static (bool escapeMenuWasOpen, bool dismissAttempted, bool clockResumed) DismissAndResume(string caller)
        {
            var wasOpen = IsEscapeMenuOpen();
            var attempted = false;
            var clockResumed = false;

            if (wasOpen)
            {
                attempted = DismissIfOpen();
                // Give the game ~300ms to process the Escape key and close the menu
                System.Threading.Thread.Sleep(300);
            }

            clockResumed = CampaignClockResumeHelper.EnsureClockRunning(caller ?? "EscapeMenuHelper");

            if (wasOpen)
            {
                DebugLogger.Test(
                    $"[TBG ESCAPE] dismiss-and-resume caller={caller} wasOpen=true attempted={attempted} clockResumed={clockResumed}",
                    showInGame: false);
            }

            return (wasOpen, attempted, clockResumed);
        }

        private static void SimulateEscapeKeyPress()
        {
            try
            {
                // Key down
                keybd_event(VK_ESCAPE, 0, 0, UIntPtr.Zero);
                // Key up
                keybd_event(VK_ESCAPE, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG ESCAPE] keybd_event failed: {ex.Message}", showInGame: false);
            }
        }
    }
}
