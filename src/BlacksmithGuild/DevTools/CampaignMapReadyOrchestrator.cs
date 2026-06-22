using System;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.Treasury;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Runs campaign map-ready hooks with per-hook try/catch, deferred heavy init, and bisect mask support.
    /// </summary>
    public static class CampaignMapReadyOrchestrator
    {
        private static bool _immediateCompleted;
        private static bool _deferredCompleted;
        private static bool _deferredScheduled;
        private static bool _hasRunAgentAutoLoop;

        internal static void ResetForNewCampaign()
        {
            _immediateCompleted = false;
            _deferredCompleted = false;
            _deferredScheduled = false;
            _hasRunAgentAutoLoop = false;
        }

        public static void OnCampaignTick(float dt)
        {
            if (!DevToolsConfig.DevToolsEnabled || Campaign.Current == null)
            {
                return;
            }

            if (!_immediateCompleted && GameSessionState.IsCampaignMapReady)
            {
                RunImmediateHooks();
                return;
            }

            if (_deferredScheduled && !_deferredCompleted)
            {
                RunDeferredHooks();
            }
        }

        private static void RunImmediateHooks()
        {
            _immediateCompleted = true;

            RunHook(MapReadyHookFlags.StatusFlush, "StatusFlush", () =>
            {
                GameSessionState.SyncForgeStatus();
                ForgeStatus.SetTest("map_ready", "PASS", "campaign map ready (immediate status flush)");
            });

            RunHook(MapReadyHookFlags.NotifySetupTracker, "NotifySetupTracker", () =>
            {
                CampaignSetupStateTracker.NotifyCampaignMapReady();
            });

            RunHook(MapReadyHookFlags.InGameNotices, "InGameNotices", () =>
            {
                InGameNotice.Ready("campaign map ready. Press F8 for commands.");
                InGameNotice.Info(ModDisplay.CompactLine("Market", "Press Ctrl+Alt+M for market intel."));
                DebugLogger.Test("Campaign map ready; dev hotkeys are now meaningful.", showInGame: false);
            });

            RunHook(MapReadyHookFlags.HotkeyTrace, "HotkeyTrace", HotkeyTraceService.OnMapReady);

            if (DevToolsConfig.MapReadyDeferHeavyHooks
                && HasAnyEnabled(DevToolsConfig.MapReadyHookMask & MapReadyHookFlags.Deferred))
            {
                _deferredScheduled = true;
                DebugLogger.Test(
                    "[TBG MAPREADY] deferred heavy hooks scheduled for next campaign tick.",
                    showInGame: false);
                return;
            }

            RunDeferredHooks();
        }

        private static void RunDeferredHooks()
        {
            _deferredCompleted = true;
            _deferredScheduled = false;

            RunHook(MapReadyHookFlags.ForgeAdvisorSmoke, "ForgeAdvisorSmoke", ForgeAdvisorSmokeTest.Run);
            RunHook(MapReadyHookFlags.TreasuryWatch, "TreasuryWatch", TreasuryDeltaWatchService.OnCampaignMapReady);
            RunHook(MapReadyHookFlags.AutoCharacterBuild, "AutoCharacterBuild", AutoCharacterBuildService.OnCampaignMapReady);
            RunHook(MapReadyHookFlags.CommandSurface, "CommandSurface", () =>
            {
                CommandSurfaceService.WriteCommandSurface("MapReady");
            });
            RunHook(MapReadyHookFlags.AgentAutoLoop, "AgentAutoLoop", TryRunAgentAutoLoopOnce);

            GameSessionState.SyncForgeStatus();
            DebugLogger.Test("[TBG MAPREADY] deferred hooks complete.", showInGame: false);
        }

        private static void RunHook(MapReadyHookFlags flag, string name, Action action)
        {
            if (!IsEnabled(flag))
            {
                DebugLogger.Test($"[TBG MAPREADY] skipped {name} (mask)", showInGame: false);
                return;
            }

            try
            {
                action();
                DebugLogger.Test($"[TBG MAPREADY] {name} ok", showInGame: false);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG MAPREADY] {name} failed: {ex.Message}", showInGame: false);
                ForgeStatus.SetTest("map_ready", "WARN", $"{name}: {ex.Message}");
            }
        }

        private static bool IsEnabled(MapReadyHookFlags flag)
        {
            return (DevToolsConfig.MapReadyHookMask & flag) != 0;
        }

        private static bool HasAnyEnabled(MapReadyHookFlags flags)
        {
            return (DevToolsConfig.MapReadyHookMask & flags) != 0;
        }

        private static void TryRunAgentAutoLoopOnce()
        {
            if (_hasRunAgentAutoLoop || !DevToolsConfig.AgentAutoLoop)
            {
                return;
            }

            _hasRunAgentAutoLoop = true;

            if (!CampaignSetupStateTracker.UsedDisposableQuickStartPath)
            {
                DebugLogger.Test(
                    "[TBG AGENT] AgentAutoLoop skipped: requires disposable Forge.cmd bootstrap path.",
                    showInGame: false);
                return;
            }

            DebugLogger.Test("[TBG AGENT] AgentAutoLoop starting RunAutonomousGuildLoopNow.", showInGame: false);
            if (AutonomousGuildLoopService.StartNow("AgentAutoLoop"))
            {
                InGameNotice.Info($"{ModDisplay.Name} — Agent auto-loop started (one bounded cycle).");
                return;
            }

            var reason = AutonomousGuildLoopService.LastFailReason ?? "unknown";
            DebugLogger.Test($"[TBG AGENT] AgentAutoLoop blocked: {reason}", showInGame: false);
            InGameNotice.Blocked($"{ModDisplay.Name} — Agent auto-loop blocked: {reason}.");
        }
    }
}
