using System;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Treasury;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Runs campaign map-ready hooks with per-hook try/catch, deferred heavy init, and bisect mask support.
    /// </summary>
    public static class CampaignMapReadyOrchestrator
    {
        private const string StabilizationStatusCadenceWorker = "MapReady.StabilizationStatus";
        private const int DeferredHookMinTicks = 5;
        private const int PostStabilizationHeavyFlushMinTicks = 10;
        private const float PostMapReadyStabilizationSec = 20f;

        private static bool _immediateCompleted;
        private static bool _immediateHooksCompleted;
        private static bool _deferredCompleted;
        private static bool _deferredScheduled;
        private static int _deferredTicksWaited;
        private static float _stabilizationSecRemaining;
        private static int _postStabilizationGraceTicksRemaining;
        private static bool _hasRunAgentAutoLoop;
        private static bool _hasRunAgentAutoMapTradeRoute;
        private static string _lastOrchestratorDeferKey;

        /// <summary>True after immediate map-ready hooks finish (deferred may still be pending).</summary>
        public static bool ImmediateHooksCompleted => _immediateHooksCompleted;

        /// <summary>True after deferred map-ready hooks finish (or were skipped by mask).</summary>
        public static bool DeferredHooksCompleted => _deferredCompleted;

        /// <summary>True for a short wall-clock window after map-ready hooks — blocks heavy campaign tick drivers.</summary>
        public static bool IsPostMapReadyStabilizationWindow => _stabilizationSecRemaining > 0f;

        /// <summary>
        /// True when status flush must stay lightweight (stabilization, deferred pending, post-stabilization grace, or map not ready).
        /// </summary>
        public static bool ShouldDeferHeavyStatusFlush(out string reason)
        {
            if (IsPostMapReadyStabilizationWindow)
            {
                reason = "post_map_ready_stabilization";
                return true;
            }

            if (_deferredScheduled && !_deferredCompleted)
            {
                reason = "deferred_hooks_pending";
                return true;
            }

            if (_postStabilizationGraceTicksRemaining > 0)
            {
                reason = "post_stabilization_tick_budget";
                return true;
            }

            if (GameSessionState.IsMapStateActive && !GameSessionState.IsCampaignMapSurfaceOpen)
            {
                reason = "settlement_menu_open";
                return true;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                reason = "map_not_ready";
                return true;
            }

            reason = null;
            return false;
        }

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
            _postStabilizationGraceTicksRemaining = 0;
            _hasRunAgentAutoLoop = false;
            _hasRunAgentAutoMapTradeRoute = false;
            _lastOrchestratorDeferKey = null;
            RuntimeCadenceGate.Reset(StabilizationStatusCadenceWorker);
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
                    StartPostStabilizationHeavyFlushGrace();
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

            GameSessionState.RefreshForRealtimeTick();

            if (_stabilizationSecRemaining > 0f
                && GameSessionState.IsCampaignSessionReady
                && RuntimeCadenceGate.TryEnter(
                    StabilizationStatusCadenceWorker,
                    DevToolsConfig.StabilizationStatusSyncIntervalMs,
                    hardMinimumMs: 250))
            {
                GameSessionState.SyncForgeStatus();
            }

            TryAdvanceHeavyFlushGrace();

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

        private static void StartPostStabilizationHeavyFlushGrace()
        {
            _postStabilizationGraceTicksRemaining = PostStabilizationHeavyFlushMinTicks;
            RuntimeTrace.RunSafe("MapReady", "HeavyFlushGraceBegin", () =>
            {
                DebugLogger.Test(
                    $"[TBG MAPREADY] post-stabilization heavy-flush grace started ({PostStabilizationHeavyFlushMinTicks} campaign ticks).",
                    showInGame: false);
            });
        }

        private static void TryAdvanceHeavyFlushGrace()
        {
            if (_postStabilizationGraceTicksRemaining <= 0)
            {
                return;
            }

            _postStabilizationGraceTicksRemaining--;
            if (_postStabilizationGraceTicksRemaining > 0)
            {
                return;
            }

            if (!ShouldDeferHeavyStatusFlush(out var deferReason))
            {
                EmitHeavyFlushUnblocked(deferReason: null, skipped: false);
            }
            else
            {
                EmitHeavyFlushUnblocked(deferReason: deferReason, skipped: true);
            }
        }

        private static void EmitHeavyFlushUnblocked(string deferReason, bool skipped)
        {
            RuntimeTrace.RunSafe("StatusFlush", "HeavyFlushUnblocked", () =>
            {
                if (skipped)
                {
                    RuntimeTrace.LogSkipped("StatusFlush", "HeavyFlushUnblocked", deferReason ?? "deferred");
                    DebugLogger.Test(
                        $"[TBG MAPREADY] HeavyFlushUnblocked skipped: {deferReason}",
                        showInGame: false);
                    return;
                }

                DebugLogger.Test(
                    "[TBG MAPREADY] HeavyFlushUnblocked ok; full sync deferred to safe tick cadence.",
                    showInGame: false);
            }, emitEnd: true);
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
                    InGameNotice.Ready(GameSessionState.GetSessionReadyNoticeText());
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
            RuntimeTrace.RunSafe("MapReady", "SyncForgeStatusAfterImmediate", () => GameSessionState.SyncForgeStatus());

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
            RuntimeTrace.RunSafe("StatusFlush", "Refresh", () => GameSessionState.Refresh());

            RuntimeTrace.RunSafe(
                "StatusFlush",
                "ReadCampaignMapReady",
                () => GameSessionState.IsCampaignMapReady,
                out var mapReady);
            RuntimeTrace.RunSafe(
                "StatusFlush",
                "ReadMainHeroReady",
                () => GameSessionState.IsMainHeroReady,
                out var heroReady);

            RuntimeTrace.RunSafe("StatusFlush", "UpdateReadiness", () =>
            {
                ForgeStatus.UpdateReadiness(GameSessionState.IsCampaignMapReady, GameSessionState.IsMainHeroReady);
            });

            RuntimeTrace.RunSafe(
                "StatusFlush",
                "CalcFileInboxReady",
                () => GameSessionState.CanPollFileInbox,
                out var inboxReady);

            if (mapReady && heroReady && GameSessionState.IsCampaignMapSurfaceOpen)
            {
                RuntimeTrace.RunSafe("StatusFlush", "SetTestMapReady", () =>
                {
                    ForgeStatus.SetTest("map_ready", "PASS", "campaign map ready (immediate status flush)");
                });
            }
            else if (mapReady && heroReady && GameSessionState.IsMapMenuOpen)
            {
                var settlement = GameSessionState.CurrentSettlementName ?? "settlement";
                RuntimeTrace.RunSafe("StatusFlush", "SetTestMapReady", () =>
                {
                    ForgeStatus.SetTest(
                        "map_ready",
                        "PASS",
                        $"settlement town menu ({settlement}; mapReady=true surface=settlement_menu)");
                });
            }
            else
            {
                DebugLogger.Test(
                    $"[TBG MAPREADY] StatusFlush partial: mapReady={mapReady.ToString().ToLowerInvariant()} heroReady={heroReady.ToString().ToLowerInvariant()} canPollFileInbox={inboxReady.ToString().ToLowerInvariant()} ({GameSessionState.GetCampaignMapBlockDetail()})",
                    showInGame: false);
            }

            GameSessionState.SyncForgeStatus(skipRefresh: true);
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
            RunHook(MapReadyHookFlags.AgentAutoLoop, "AgentAutoMapTradeRoute", TryRunAgentAutoMapTradeRouteOnce);

            RuntimeTrace.RunSafe("MapReady", "SyncForgeStatusDeferred", () => GameSessionState.SyncForgeStatus());
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

        private static void TryRunAgentAutoMapTradeRouteOnce()
        {
            DebugLogger.Test(
                $"[TBG AGENT] AgentAutoMapTradeRoute gate reached hasRun={_hasRunAgentAutoMapTradeRoute} autoMapTradeRouteBeforeReload={DevToolsConfig.AgentAutoMapTradeRoute}",
                showInGame: false);

            if (_hasRunAgentAutoMapTradeRoute)
            {
                DebugLogger.Test("[TBG AGENT] AgentAutoMapTradeRoute skipped: already ran.", showInGame: false);
                return;
            }

            AgentIterationConfigService.TryLoadNow("CampaignMapReadyOrchestrator");

            DebugLogger.Test(
                $"[TBG AGENT] AgentAutoMapTradeRoute gate evaluated autoMapTradeRoute={DevToolsConfig.AgentAutoMapTradeRoute}",
                showInGame: false);

            if (!DevToolsConfig.AgentAutoMapTradeRoute)
            {
                DebugLogger.Test("[TBG AGENT] AgentAutoMapTradeRoute skipped: autoMapTradeRoute=false.", showInGame: false);
                return;
            }

            _hasRunAgentAutoMapTradeRoute = true;

            if (!CampaignSetupStateTracker.UsedDisposableQuickStartPath)
            {
                DebugLogger.Test(
                    "[TBG AGENT] AgentAutoMapTradeRoute skipped: requires disposable Forge.cmd bootstrap path.",
                    showInGame: false);
                return;
            }

            DebugLogger.Test("[TBG AGENT] AgentAutoMapTradeRoute starting StartRouteNow source=AgentAutoMapTradeRoute.", showInGame: false);
            if (MapTradeAutonomousService.StartRouteNow("AgentAutoMapTradeRoute"))
            {
                InGameNotice.Info($"{ModDisplay.Name} — Agent map-trade route started (one bounded route start).");
                return;
            }

            var reason = MapTradeAutonomousService.LastFailReason ?? "unknown";
            DebugLogger.Test($"[TBG AGENT] AgentAutoMapTradeRoute blocked: {reason}", showInGame: false);
            InGameNotice.Blocked($"{ModDisplay.Name} — Agent map-trade route blocked: {reason}.");
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
