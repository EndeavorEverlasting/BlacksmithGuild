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
        private const int DeferredHookMinTicks = 5;
        private const float PostMapReadyStabilizationSec = 20f;

        private static bool _immediateCompleted;
        private static bool _immediateHooksCompleted;
        private static bool _deferredCompleted;
        private static bool _deferredScheduled;
        private static int _deferredTicksWaited;
        private static float _stabilizationSecRemaining;
        private static bool _hasRunAgentAutoLoop;
        private static string _lastOrchestratorDeferKey;

        /// <summary>True after immediate map-ready hooks finish (deferred may still be pending).</summary>
        public static bool ImmediateHooksCompleted => _immediateHooksCompleted;

        /// <summary>True for a short wall-clock window after map-ready hooks — blocks heavy campaign tick drivers.</summary>
        public static bool IsPostMapReadyStabilizationWindow => _stabilizationSecRemaining > 0f;

        public static bool ShouldRunOrchestratorTick()
        {
            return !TryGetOrchestratorDeferReason(out _);
        }

        internal static void ResetForNewCampaign()
        {
            _immediateCompleted = false;
            _immediateHooksCompleted = false;
            _deferredCompleted = false;
            _deferredScheduled = false;
            _deferredTicksWaited = 0;
            _stabilizationSecRemaining = 0f;
            _hasRunAgentAutoLoop = false;
            _lastOrchestratorDeferKey = null;
        }

        public static void OnApplicationTick(float dt)
        {
            if (_stabilizationSecRemaining <= 0f)
            {
                return;
            }

            if (dt > 0f)
            {
                _stabilizationSecRemaining -= dt;
                if (_stabilizationSecRemaining < 0f)
                {
                    _stabilizationSecRemaining = 0f;
                }
            }

            if (_stabilizationSecRemaining <= 0f)
            {
                RuntimeTrace.Run("MapReady", "StabilizationEnd", () =>
                {
                    DebugLogger.Test("[TBG MAPREADY] post-map-ready stabilization window ended.", showInGame: false);
                });
            }
        }

        public static void OnCampaignTick(float dt)
        {
            if (!DevToolsConfig.DevToolsEnabled || Campaign.Current == null)
            {
                return;
            }

            if (MapTransitionGuard.TraceGuardCheck("MapReadyPrecheck"))
            {
                return;
            }

            GameSessionState.Refresh();

            if (_stabilizationSecRemaining > 0f && GameSessionState.IsCampaignSessionReady)
            {
                RuntimeTrace.Run("MapReady", "SyncForgeStatusHeartbeat", GameSessionState.SyncForgeStatus);
            }

            if (!_immediateCompleted)
            {
                if (TryGetOrchestratorDeferReason(out var deferReason))
                {
                    LogOrchestratorDeferred(deferReason);
                    return;
                }

                RuntimeTrace.LogDeferOnce(
                    "orchestrator_allowed",
                    "MapReady",
                    "OrchestratorAllowed",
                    GameSessionState.GetCommandReadyBlockDetail());

                RuntimeTrace.Run("MapReady", "OrchestratorTickEntered", () =>
                {
                    DebugLogger.Test("[TBG MAPREADY] orchestrator tick entered", showInGame: false);
                    RunImmediateHooks();
                });
                return;
            }

            if (_deferredScheduled && !_deferredCompleted)
            {
                if (!GameSessionState.IsCampaignSessionReady)
                {
                    DebugLogger.Test(
                        "[TBG MAPREADY] deferred hooks skipped: campaign no longer ready.",
                        showInGame: false);
                    _deferredCompleted = true;
                    _deferredScheduled = false;
                    return;
                }

                if (_deferredTicksWaited < DeferredHookMinTicks)
                {
                    _deferredTicksWaited++;
                    DebugLogger.Test(
                        $"[TBG MAPREADY] deferred hooks waiting tick {_deferredTicksWaited}",
                        showInGame: false);
                    return;
                }

                RunDeferredHooks();
            }
        }

        private static bool TryGetOrchestratorDeferReason(out string reason)
        {
            reason = null;

            if (!GameSessionState.IsMainHeroReady)
            {
                reason = "main_hero_not_ready";
                return true;
            }

            if (!GameSessionState.IsCampaignSessionReady)
            {
                reason = "campaign_session_not_ready";
                return true;
            }

            if (CampaignSetupStateTracker.IsMapLoadTransitionWindow
                && !MapTransitionGuard.TryDetectCampaignSessionLoaded(out _))
            {
                reason = "map_load_transition";
                return true;
            }

            if (MapTransitionGuard.IsUnsafeContinueLoadWindow())
            {
                reason = "map_load_transition";
                return true;
            }

            if (LaunchPathInference.IsContinueOnlyMapReadyBlocked())
            {
                reason = "play_setup_active";
                return true;
            }

            return false;
        }

        private static void LogOrchestratorDeferred(string reason)
        {
            var key = $"{reason}|{LaunchPathInference.GetPathLabel()}|{CampaignSetupStateTracker.Phase}";
            if (string.Equals(_lastOrchestratorDeferKey, key, StringComparison.Ordinal))
            {
                return;
            }

            _lastOrchestratorDeferKey = key;
            DebugLogger.Test(
                $"[TBG MAPREADY] orchestrator deferred: reason={reason} path={LaunchPathInference.GetPathLabel()} phase={CampaignSetupStateTracker.Phase}",
                showInGame: false);
        }

        private static void RunImmediateHooks()
        {
            _immediateCompleted = true;

            DebugLogger.Test("[TBG MAPREADY] immediate hooks begin", showInGame: false);

            RunHook(MapReadyHookFlags.StatusFlush, "StatusFlush", RunStatusFlush);

            RunHook(MapReadyHookFlags.NotifySetupTracker, "NotifySetupTracker", () =>
            {
                CampaignSetupStateTracker.NotifyCampaignMapReady();
            });

            RunHook(MapReadyHookFlags.InGameNotices, "InGameNotices", () =>
            {
                RuntimeTrace.Run("MapReady", "EmitReadyLine", () =>
                {
                    InGameNotice.Ready("campaign map ready. Press F8 for commands.");
                });
                InGameNotice.Info(ModDisplay.CompactLine("Market", "Press Ctrl+Alt+M for market intel."));
                DebugLogger.Test("Campaign map ready; dev hotkeys are now meaningful.", showInGame: false);
            });

            RunHook(MapReadyHookFlags.HotkeyTrace, "HotkeyTrace", HotkeyTraceService.OnMapReady);

            DebugLogger.Test("[TBG MAPREADY] immediate hooks complete", showInGame: false);
            _immediateHooksCompleted = true;
            _stabilizationSecRemaining = PostMapReadyStabilizationSec;
            DebugLogger.Test(
                $"[TBG MAPREADY] stabilization window started ({PostMapReadyStabilizationSec:N0}s wall clock).",
                showInGame: false);
            RuntimeTrace.Run("MapReady", "SyncForgeStatusAfterImmediate", GameSessionState.SyncForgeStatus);

            if (HasAnyEnabled(DevToolsConfig.MapReadyHookMask & MapReadyHookFlags.Deferred))
            {
                _deferredScheduled = true;
                _deferredTicksWaited = 0;
                DebugLogger.Test(
                    $"[TBG MAPREADY] deferred hooks scheduled (min {DeferredHookMinTicks} campaign ticks).",
                    showInGame: false);
            }
            else
            {
                _deferredCompleted = true;
                DebugLogger.Test("[TBG MAPREADY] deferred hooks skipped (mask)", showInGame: false);
            }
        }

        private static void RunStatusFlush()
        {
            RuntimeTrace.Run("StatusFlush", "Refresh", () => GameSessionState.Refresh());

            var mapReady = RuntimeTrace.Run("StatusFlush", "ReadCampaignMapReady", () => GameSessionState.IsCampaignMapReady);
            var heroReady = RuntimeTrace.Run("StatusFlush", "ReadMainHeroReady", () => GameSessionState.IsMainHeroReady);

            RuntimeTrace.Run("StatusFlush", "UpdateReadiness", () =>
            {
                ForgeStatus.UpdateReadiness(mapReady, heroReady);
            });

            var inboxReady = RuntimeTrace.Run("StatusFlush", "CalcFileInboxReady", () => GameSessionState.CanPollFileInbox);

            if (mapReady && heroReady)
            {
                RuntimeTrace.Run("StatusFlush", "SetTestMapReady", () =>
                {
                    ForgeStatus.SetTest("map_ready", "PASS", "campaign map ready (immediate status flush)");
                });
            }
            else
            {
                DebugLogger.Test(
                    $"[TBG MAPREADY] StatusFlush partial: mapReady={mapReady.ToString().ToLowerInvariant()} heroReady={heroReady.ToString().ToLowerInvariant()} canPollFileInbox={inboxReady.ToString().ToLowerInvariant()} ({GameSessionState.GetCampaignMapBlockDetail()})",
                    showInGame: false);
            }

            RuntimeTrace.Run("StatusFlush", "SyncForgeStatus", GameSessionState.SyncForgeStatus);
        }

        private static void RunDeferredHooks()
        {
            DebugLogger.Test("[TBG MAPREADY] deferred hooks begin", showInGame: false);

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
            DebugLogger.Test("[TBG MAPREADY] deferred hooks complete", showInGame: false);
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
                DebugLogger.Test($"[TBG MAPREADY] {name} begin", showInGame: false);
                action();
                DebugLogger.Test($"[TBG MAPREADY] {name} ok", showInGame: false);
            }
            catch (Exception ex)
            {
                RuntimeTrace.LogFail("MapReady", name, ex);
                DebugLogger.Test($"[TBG MAPREADY] {name} failed: {ex}", showInGame: false);
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
