using System;

namespace BlacksmithGuild.DevTools.Automation
{
    public sealed class AutomationCheckpointEvent
    {
        public const int SchemaVersion = 1;
        public const string FileName = "BlacksmithGuild_AutomationEvents.jsonl";

        public const string EventCheckpointReached = "checkpoint_reached";
        public const string EventCheckpointBlocked = "checkpoint_blocked";
        public const string EventCycleCompleted = "cycle_completed";
        public const string EventStopRequested = "stop_requested";
        public const string EventUnsafeSurface = "unsafe_surface";
        public const string EventFinalizationStarted = "finalization_started";
        public const string EventFinalizedPass = "finalized_pass";
        public const string EventFinalizedFail = "finalized_fail";
        public const string EventFinalizedAbort = "finalized_abort";

        public const string SessionStarted = "session_started";
        public const string LauncherOpen = "launcher_open";
        public const string ContinueVisible = "continue_visible";
        public const string ContinueClicked = "continue_clicked";
        public const string GameSpawned = "game_spawned";
        public const string AttachReady = "attach_ready";
        public const string StateMachineConsumed = "state_machine_consumed";
        public const string RuntimeLifecycleConsumed = "runtime_lifecycle_consumed";
        public const string TravelGateReady = "travel_gate_ready";
        public const string ProbeAck = "probe_ack";
        public const string ExecuteAck = "execute_ack";
        public const string PartyMovementObserved = "party_movement_observed";
        public const string MarketEvaluated = "market_evaluated";
        public const string SmithingRefineCompleted = "smithing_refine_completed";
        public const string TavernCompanionScanCompleted = "tavern_companion_scan_completed";
        public const string CompanionRosterDecisionRecorded = "companion_roster_decision_recorded";
        public const string CycleCompleted = "cycle_completed";
        public const string NextActionPlanned = "next_action_planned";
        public const string UnsafeSurface = "unsafe_surface";
        public const string StopRequested = "stop_requested";
        public const string ToggleReceived = "toggle_received";
        public const string AssistLoopStarted = "assist_loop_started";
        public const string SummaryWritten = "summary_written";
        public const string AutomationNotRunning = "automation_not_running";
        public const string PreviousRunTerminalNotice = "previous_run_terminal_notice";

        public string EventId { get; set; } = Guid.NewGuid().ToString();
        public string SessionId { get; set; }
        public string RunId { get; set; }
        public DateTime AtUtc { get; set; } = DateTime.UtcNow;
        public string EventType { get; set; } = EventCheckpointReached;
        public string CheckpointName { get; set; }
        public bool IsTerminal { get; set; }
        public string TerminalState { get; set; }
        public string Phase { get; set; }
        public string Source { get; set; } = "mod";
        public string Reason { get; set; }
        public bool MessageShownInGame { get; set; }
        public string MessageText { get; set; }
        public string RelatedEventId { get; set; }
        public string DetailsJson { get; set; }
    }
}
