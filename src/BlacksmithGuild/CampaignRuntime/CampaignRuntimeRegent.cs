using System;
using System.IO;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.HorseMarket;
using TaleWorlds.Library;

namespace BlacksmithGuild.CampaignRuntime
{
    // ── Stagnation classes ───────────────────────────────────────────────────
    public static class RegentStagnationClass
    {
        public const string None = "none";
        public const string CampaignMapPaused = "campaign_map_paused";
        public const string EscapeMenuInterrupted = "escape_menu_interrupted";
        public const string LauncherMenuStagnant = "launcher_menu_stagnant";
        public const string MainMenuStagnant = "main_menu_stagnant";
        public const string LoadingStagnant = "loading_stagnant";
        public const string TownMenuIdle = "town_menu_idle";
        public const string CampaignMapIdle = "campaign_map_idle";
        public const string GovernorObserveLoop = "governor_observe_loop";
        public const string GovernorBlockLoop = "governor_block_loop";
        public const string ActivityDeferredLoop = "activity_deferred_loop";
        public const string HeartbeatStale = "heartbeat_stale";
        public const string CommandNotAcknowledged = "command_not_acknowledged";
        public const string OperatorStopRequested = "operator_stop_requested";
        public const string PersonalSaveBlock = "personal_save_block";
        public const string EnvironmentBlocked = "environment_blocked";
    }

    // ── Recovery actions ─────────────────────────────────────────────────────
    public static class RegentRecoveryAction
    {
        public const string ObserveOnly = "observe_only";
        public const string ResumeCampaignClock = "resume_campaign_clock";
        public const string RunGovernorCycle = "run_governor_cycle";
        public const string RefreshMarketScan = "refresh_market_scan";
        public const string SurfaceAdvisory = "surface_advisory";
        public const string ReissueLastSafeCommand = "reissue_last_safe_command";
        public const string BootstrapDevSave = "bootstrap_dev_save";
        public const string RequestLauncherRebind = "request_launcher_rebind";
        public const string RequestLauncherRestart = "request_launcher_restart";
        public const string RequestForgeStopApproval = "request_forge_stop_approval";
        public const string BlockPersonalSave = "block_personal_save";
        public const string OperatorInterventionRequired = "operator_intervention_required";
        public const string FailClosed = "fail_closed";
    }

    // ── Snapshot ─────────────────────────────────────────────────────────────
    public sealed class CampaignRuntimeRegentSnapshot
    {
        public string GeneratedUtc;
        public string Surface;
        public string Phase;
        public string Health;
        public string StagnationClass;
        public int SameSurfaceSeconds;
        public int SameDecisionCount;
        public int SameBlockedClassCount;
        public string LastGovernorBranch;
        public string LastGovernorReason;
        public string LastActivityStatus;
        public string LastActivityFailureClass;
        public string LastActivityDetail;
        public string MenuId;
        public bool SessionTimePaused;
        public bool OperatorInterruptionObserved;
        public string OperatorInterruptionReason;
        public string RecommendedRecovery;
        public bool CanRunGovernorCycle;
        public bool RequiresLauncherRecovery;
        public bool RequiresOperatorApproval;
        public bool MutationAllowed;
        public bool BoundedExecutionEnabled;
        public bool GovernorAutonomousEnabled;
        // Route Council integration
        public string RouteCouncilTopVote;
        public string RouteCouncilRecommendedDestination;
        public string RouteCouncilBlockedReason;
        public string HorseAtlasEvidenceState;
        public string HerdLedgerPosture;
    }

    // ── Regent policy ────────────────────────────────────────────────────────
    public static class CampaignRuntimeRegentPolicy
    {
        public static string ClassifyStagnation(string surface, string phase, int sameSurfaceSeconds, string lastBranch, int sameDecisionCount, bool sessionTimePaused)
        {
            if (string.Equals(surface, GameplaySurfaceKinds.EscapeMenu, StringComparison.Ordinal))
                return RegentStagnationClass.EscapeMenuInterrupted;
            if (string.Equals(surface, GameplaySurfaceKinds.CampaignMap, StringComparison.Ordinal) && sessionTimePaused)
                return RegentStagnationClass.CampaignMapPaused;
            if (surface != null && surface.Contains("launcher"))
                return sameSurfaceSeconds > 60 ? RegentStagnationClass.LauncherMenuStagnant : RegentStagnationClass.None;
            if (surface != null && surface.Contains("main_menu"))
                return sameSurfaceSeconds > 90 ? RegentStagnationClass.MainMenuStagnant : RegentStagnationClass.None;
            if (phase != null && phase.Contains("Loading"))
                return sameSurfaceSeconds > 120 ? RegentStagnationClass.LoadingStagnant : RegentStagnationClass.None;
            if (surface != null && surface.Contains("settlement_menu"))
                return sameSurfaceSeconds > 300 ? RegentStagnationClass.TownMenuIdle : RegentStagnationClass.None;
            if (surface != null && surface.Contains("campaign_map"))
                return sameSurfaceSeconds > 300 ? RegentStagnationClass.CampaignMapIdle : RegentStagnationClass.None;
            if (lastBranch == CampaignRuntimePolicy.BranchObserveOnly && sameDecisionCount >= 3)
                return RegentStagnationClass.GovernorObserveLoop;
            if (lastBranch != null && sameDecisionCount >= 5)
                return RegentStagnationClass.GovernorBlockLoop;
            return RegentStagnationClass.None;
        }

        public static string RecommendRecovery(string stagnationClass, string surface, bool canRunGovernor)
        {
            switch (stagnationClass)
            {
                case RegentStagnationClass.CampaignMapPaused:
                    return RegentRecoveryAction.ResumeCampaignClock;
                case RegentStagnationClass.EscapeMenuInterrupted:
                    return RegentRecoveryAction.OperatorInterventionRequired;
                case RegentStagnationClass.LauncherMenuStagnant:
                    return RegentRecoveryAction.RequestLauncherRebind;
                case RegentStagnationClass.MainMenuStagnant:
                    return RegentRecoveryAction.BootstrapDevSave;
                case RegentStagnationClass.LoadingStagnant:
                    return RegentRecoveryAction.ObserveOnly;
                case RegentStagnationClass.TownMenuIdle:
                    return canRunGovernor ? RegentRecoveryAction.RunGovernorCycle : RegentRecoveryAction.SurfaceAdvisory;
                case RegentStagnationClass.CampaignMapIdle:
                    return canRunGovernor ? RegentRecoveryAction.RunGovernorCycle : RegentRecoveryAction.ObserveOnly;
                case RegentStagnationClass.GovernorObserveLoop:
                    return RegentRecoveryAction.RefreshMarketScan;
                case RegentStagnationClass.GovernorBlockLoop:
                    return RegentRecoveryAction.OperatorInterventionRequired;
                case RegentStagnationClass.ActivityDeferredLoop:
                    return RegentRecoveryAction.ReissueLastSafeCommand;
                default:
                    return RegentRecoveryAction.ObserveOnly;
            }
        }
    }

    // ── Regent service ───────────────────────────────────────────────────────
    public static class CampaignRuntimeRegent
    {
        public const string ShowRuntimeRegentStateCommand = "ShowRuntimeRegentState";
        public const string ReportFileName = "BlacksmithGuild_RuntimeRegent.json";

        public static string ReportPath => Path.Combine(BasePath.Name, ReportFileName);

        public static CampaignRuntimeRegentSnapshot LastSnapshot { get; private set; }

        // Stagnation tracking
        private static string _lastSurface;
        private static DateTime _surfaceEnteredUtc = DateTime.UtcNow;
        private static string _lastDecisionBranch;
        private static int _sameDecisionCount;
        private static string _lastFailureClass;
        private static int _sameBlockedClassCount;

        public static CampaignRuntimeRegentSnapshot BuildSnapshot(GameplaySurfaceSnapshot gameplaySnapshot = null)
        {
            gameplaySnapshot = gameplaySnapshot ?? GameSessionState.LatestGameplaySurface;
            var surface = gameplaySnapshot?.GameplaySurface ?? GameSessionState.ReadinessSurface ?? GameSessionState.Phase.ToString();
            var phase = GameSessionState.Phase.ToString();
            var health = CampaignRuntimeStatusReaders.ReadGameHealth();
            var menuId = gameplaySnapshot?.MenuId;
            var sessionTimePaused = GameSessionState.IsTimePaused;
            var operatorInterruptionObserved = string.Equals(surface, GameplaySurfaceKinds.EscapeMenu, StringComparison.Ordinal);
            var operatorInterruptionReason = operatorInterruptionObserved ? "escape_menu_open" : null;

            // Surface stagnation timer
            var now = DateTime.UtcNow;
            if (!string.Equals(surface, _lastSurface, StringComparison.Ordinal))
            {
                _lastSurface = surface;
                _surfaceEnteredUtc = now;
            }
            var sameSurfaceSeconds = (int)(now - _surfaceEnteredUtc).TotalSeconds;

            // Decision stagnation tracker
            var lastDecision = CampaignRuntimeGovernor.LastDecision;
            var lastBranch = lastDecision?.SelectedBranch;
            var lastReason = lastDecision?.SelectedReason;
            var lastActivityStatus = lastDecision?.LatestActivityResult?.Status;
            var lastActivityFailureClass = lastDecision?.LatestActivityResult?.FailureClass;
            var lastActivityDetail = lastDecision?.LatestActivityResult?.Detail;
            var lastFailureClass = lastDecision?.FailureClass;

            if (string.Equals(lastBranch, _lastDecisionBranch, StringComparison.Ordinal))
                _sameDecisionCount++;
            else
            {
                _lastDecisionBranch = lastBranch;
                _sameDecisionCount = 1;
            }

            if (string.Equals(lastFailureClass, _lastFailureClass, StringComparison.Ordinal) && lastFailureClass != null)
                _sameBlockedClassCount++;
            else
            {
                _lastFailureClass = lastFailureClass;
                _sameBlockedClassCount = lastFailureClass != null ? 1 : 0;
            }

            var canRunGovernor = GameSessionState.IsCampaignSessionReady && !CampaignRuntimeGovernor.IsPaused;
            var stagnationClass = CampaignRuntimeRegentPolicy.ClassifyStagnation(surface, phase, sameSurfaceSeconds, lastBranch, _sameDecisionCount, sessionTimePaused);
            var recovery = CampaignRuntimeRegentPolicy.RecommendRecovery(stagnationClass, surface, canRunGovernor);

            var snapshot = new CampaignRuntimeRegentSnapshot
            {
                GeneratedUtc = now.ToString("o"),
                Surface = surface,
                Phase = phase,
                Health = health,
                StagnationClass = stagnationClass,
                SameSurfaceSeconds = sameSurfaceSeconds,
                SameDecisionCount = _sameDecisionCount,
                SameBlockedClassCount = _sameBlockedClassCount,
                LastGovernorBranch = lastBranch,
                LastGovernorReason = lastReason,
                LastActivityStatus = lastActivityStatus,
                LastActivityFailureClass = lastActivityFailureClass,
                LastActivityDetail = lastActivityDetail,
                MenuId = menuId,
                SessionTimePaused = sessionTimePaused,
                OperatorInterruptionObserved = operatorInterruptionObserved,
                OperatorInterruptionReason = operatorInterruptionReason,
                RecommendedRecovery = recovery,
                CanRunGovernorCycle = canRunGovernor,
                RequiresLauncherRecovery = stagnationClass == RegentStagnationClass.LauncherMenuStagnant,
                RequiresOperatorApproval = operatorInterruptionObserved
                    || stagnationClass == RegentStagnationClass.GovernorBlockLoop
                    || stagnationClass == RegentStagnationClass.EnvironmentBlocked,
                MutationAllowed = false, // Regent never enables mutation; only bounded execution gate does
                BoundedExecutionEnabled = DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution,
                GovernorAutonomousEnabled = DevToolsConfig.CampaignRuntimeGovernorAutonomousMode
            };

            var council = CampaignRouteCouncil.LastResult;
            if (council != null)
            {
                snapshot.RouteCouncilTopVote = council.WinningEngine;
                snapshot.RouteCouncilRecommendedDestination = council.RecommendedDestination;
                snapshot.RouteCouncilBlockedReason = council.BlockedReason;
            }
            snapshot.HorseAtlasEvidenceState = HorseMarketAtlasService.LastReport?.Verdict;
            snapshot.HerdLedgerPosture = HerdLedgerService.LastSnapshot?.RecommendedPosture;

            LastSnapshot = snapshot;
            return snapshot;
        }

        public static bool ShowNow()
        {
            var snapshot = BuildSnapshot(GameSessionState.LatestGameplaySurface);
            Write(snapshot);
            InGameNotice.Info(ModDisplay.CompactLine("Regent",
                $"{snapshot.StagnationClass} recovery={snapshot.RecommendedRecovery}"));
            return true;
        }

        public static void Write(CampaignRuntimeRegentSnapshot snapshot)
        {
            if (snapshot == null) return;
            File.WriteAllText(ReportPath, Serialize(snapshot), Encoding.UTF8);
        }

        private static string Serialize(CampaignRuntimeRegentSnapshot s)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            Str(sb, "generatedUtc", s.GeneratedUtc, true);
            Str(sb, "surface", s.Surface, true);
            Str(sb, "phase", s.Phase, true);
            Str(sb, "health", s.Health, true);
            Str(sb, "stagnationClass", s.StagnationClass, true);
            sb.AppendLine($"  \"sameSurfaceSeconds\": {s.SameSurfaceSeconds},");
            sb.AppendLine($"  \"sameDecisionCount\": {s.SameDecisionCount},");
            sb.AppendLine($"  \"sameBlockedClassCount\": {s.SameBlockedClassCount},");
            Str(sb, "lastGovernorBranch", s.LastGovernorBranch, true);
            Str(sb, "lastGovernorReason", s.LastGovernorReason, true);
            Str(sb, "lastActivityStatus", s.LastActivityStatus, true);
            Str(sb, "lastActivityFailureClass", s.LastActivityFailureClass, true);
            Str(sb, "lastActivityDetail", s.LastActivityDetail, true);
            Str(sb, "menuId", s.MenuId, true);
            sb.AppendLine($"  \"sessionTimePaused\": {B(s.SessionTimePaused)},");
            sb.AppendLine($"  \"operatorInterruptionObserved\": {B(s.OperatorInterruptionObserved)},");
            Str(sb, "operatorInterruptionReason", s.OperatorInterruptionReason, true);
            Str(sb, "recommendedRecovery", s.RecommendedRecovery, true);
            sb.AppendLine($"  \"canRunGovernorCycle\": {B(s.CanRunGovernorCycle)},");
            sb.AppendLine($"  \"requiresLauncherRecovery\": {B(s.RequiresLauncherRecovery)},");
            sb.AppendLine($"  \"requiresOperatorApproval\": {B(s.RequiresOperatorApproval)},");
            sb.AppendLine($"  \"mutationAllowed\": {B(s.MutationAllowed)},");
            sb.AppendLine($"  \"boundedExecutionEnabled\": {B(s.BoundedExecutionEnabled)},");
            sb.AppendLine($"  \"governorAutonomousEnabled\": {B(s.GovernorAutonomousEnabled)},");
            Str(sb, "routeCouncilTopVote", s.RouteCouncilTopVote, true);
            Str(sb, "routeCouncilRecommendedDestination", s.RouteCouncilRecommendedDestination, true);
            Str(sb, "routeCouncilBlockedReason", s.RouteCouncilBlockedReason, true);
            Str(sb, "horseAtlasEvidenceState", s.HorseAtlasEvidenceState, true);
            Str(sb, "herdLedgerPosture", s.HerdLedgerPosture, false);
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void Str(StringBuilder sb, string key, string value, bool comma)
        {
            sb.Append("  \"").Append(key).Append("\": ");
            sb.Append(value == null ? "null" : "\"" + Esc(value) + "\"");
            if (comma) sb.Append(",");
            sb.AppendLine();
        }

        private static string B(bool v) => v ? "true" : "false";
        private static string Esc(string v) => (v ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
