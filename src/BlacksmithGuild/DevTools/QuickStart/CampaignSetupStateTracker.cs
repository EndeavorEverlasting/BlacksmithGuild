using System;
using BlacksmithGuild.Behaviors;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Core;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public enum SetupPhase
    {
        Idle,
        MainMenu,
        IntroVideo,
        SandboxVideo,
        CharacterCreation,
        MapTransition,
        MapReady,
        Complete
    }

    public static class CampaignSetupStateTracker
    {
        private static SetupPhase _phase = SetupPhase.Idle;
        private static string _subStage;
        private static string _lastActiveStateName;
        private static bool _setupComplete;
        private static bool _loggedWaiting;
        private static bool _loggedQuickStartNotice;
        private static bool _hasAnnouncedCutsceneNotice;
        private static bool _hasAnnouncedCreationNotice;
        private static bool _bootstrapArmed;
        private static bool _bootstrapUsed;
        private static bool _devSaveLoadUsed;
        private static string _devSaveName;
        private static string _simpleStagePendingAdvance;
        private static float _creationStageStalledSeconds;
        private static string _creationStallSubStage;
        private static bool _hasAnnouncedCreationStall;
        private static bool _bootstrapCompletedThisProcess;
        private static bool _forwardLaunchCompletedThisProcess;
        private static bool _campaignLoadedThisProcess;
        private static bool _sessionEndDisarmed;
        private static float _gameLoadingStateStalledSeconds;
        private static bool _hasAnnouncedGameLoadingStall;

        private const float CreationStageStallThresholdSeconds = 5f;
        private const float GameLoadingStallThresholdSeconds = 180f;

        public static bool BootstrapCompletedThisProcess => _bootstrapCompletedThisProcess;

        public static bool ForwardLaunchCompletedThisProcess => _forwardLaunchCompletedThisProcess;

        public static SetupPhase Phase => _phase;

        public static string SubStage => _subStage;

        public static string ActiveStateName => _lastActiveStateName;

        public static bool IsBootstrapArmed =>
            _bootstrapArmed && DevToolsConfig.AutoSkipCharacterCreation && !_setupComplete;

        public static bool IsTracking =>
            DevToolsConfig.AutoSkipCharacterCreation && !_setupComplete && (_bootstrapArmed || _bootstrapUsed);

        public static bool BootstrapUsed => _bootstrapUsed;

        public static bool DevSaveLoadUsed => _devSaveLoadUsed;

        public static bool UsedDisposableQuickStartPath => _bootstrapUsed || _devSaveLoadUsed;

        public static void ResetForNewSession()
        {
            _phase = SetupPhase.Idle;
            _subStage = null;
            _lastActiveStateName = null;
            _setupComplete = false;
            _loggedWaiting = false;
            _loggedQuickStartNotice = false;
            _hasAnnouncedCutsceneNotice = false;
            _hasAnnouncedCreationNotice = false;
            _bootstrapArmed = DevToolsConfig.AutoSkipCharacterCreation;
            _bootstrapUsed = false;
            _devSaveLoadUsed = false;
            _devSaveName = null;
            _simpleStagePendingAdvance = null;
            _creationStageStalledSeconds = 0f;
            _creationStallSubStage = null;
            _hasAnnouncedCreationStall = false;
            _bootstrapCompletedThisProcess = false;
            _forwardLaunchCompletedThisProcess = false;
            _campaignLoadedThisProcess = false;
            _sessionEndDisarmed = false;
            _gameLoadingStateStalledSeconds = 0f;
            _hasAnnouncedGameLoadingStall = false;
            CharacterCreationReflection.ResetNarrativeSession();
            MainMenuAutoLauncher.ResetForNewSession();
            ModuleMismatchAutoConfirmService.ResetForNewSession();
        }

        public static void AnnounceCutsceneSkip()
        {
            if (_hasAnnouncedCutsceneNotice || !DevToolsConfig.AutoSkipCharacterCreation)
            {
                return;
            }

            _hasAnnouncedCutsceneNotice = true;
            GuildLog.Display("TBG QUICKSTART: SandBox intro cutscene detected — auto-skipping.");
        }

        public static void AnnounceCreationAdvance()
        {
            if (_hasAnnouncedCreationNotice || !DevToolsConfig.AutoSkipCharacterCreation)
            {
                return;
            }

            _hasAnnouncedCreationNotice = true;
            GuildLog.Display("TBG QUICKSTART: auto-advancing character creation.");
        }

        public static void AnnounceSetupStalled(string stageLabel)
        {
            GuildLog.Display($"TBG QUICKSTART: setup stalled at {stageLabel} — see Phase1.log");
        }

        public static void MarkSandboxBootstrapStarted()
        {
            _bootstrapUsed = true;
            MarkSandboxSetupStarted();
        }

        public static void MarkDevSaveLoadStarted(string saveName)
        {
            _devSaveLoadUsed = true;
            _devSaveName = saveName;
            _setupComplete = false;
            _phase = SetupPhase.MapTransition;
            _subStage = saveName;
            GuildLog.Info($"[TBG QUICKSTART] dev save load started: {saveName}", showInGame: false);
        }

        public static void MarkDevSaveLoadIfApplicable()
        {
            if (!DevToolsConfig.AutoLoadDevSave)
            {
                return;
            }

            if (DevSaveResolver.TryGetLatest(out var saveInfo) && saveInfo?.Name != null)
            {
                _devSaveLoadUsed = true;
                _devSaveName = saveInfo.Name;
            }
        }

        public static void DisarmBootstrap(string reason)
        {
            if (_setupComplete && !_bootstrapArmed)
            {
                return;
            }

            var wasActive = _bootstrapArmed || !_setupComplete;
            _bootstrapArmed = false;
            _setupComplete = true;
            _phase = SetupPhase.Complete;

            if (wasActive)
            {
                GuildLog.Info($"[TBG QUICKSTART] bootstrap disarmed: {reason}", showInGame: false);
            }

            if (_bootstrapUsed
                && (string.Equals(reason, "campaign map ready", StringComparison.Ordinal)
                    || string.Equals(reason, "setup complete", StringComparison.Ordinal)))
            {
                MarkBootstrapCompleted(reason);
            }
        }

        internal static void DisarmForGameEnd()
        {
            _sessionEndDisarmed = true;
            DisarmBootstrap("game end");
        }

        public static void MarkForwardLaunchCompleted(string reason)
        {
            if (_forwardLaunchCompletedThisProcess)
            {
                return;
            }

            _forwardLaunchCompletedThisProcess = true;
            _bootstrapCompletedThisProcess = true;
            GuildLog.Info(
                "[TBG QUICKSTART] forward launch complete: disarming forward launch state and intro skip hooks " +
                $"reason={reason}",
                showInGame: false);
            MainMenuAutoLauncher.EnsureIntentFilesCleared("forward launch complete");
            MainMenuAutoLauncher.LogLaunchIntentFileStatus("forward launch complete");
            QuickStartDiagnostics.LogStateStack("forward launch complete");
        }

        private static void MarkBootstrapCompleted(string reason)
        {
            if (_bootstrapCompletedThisProcess)
            {
                return;
            }

            _bootstrapCompletedThisProcess = true;
            GuildLog.Info(
                "[TBG QUICKSTART] bootstrap complete: disarming forward launch state and intro skip hooks " +
                $"reason={reason}",
                showInGame: false);
            MainMenuAutoLauncher.EnsureIntentFilesCleared("bootstrap complete");
            MainMenuAutoLauncher.LogLaunchIntentFileStatus("bootstrap complete");
            QuickStartDiagnostics.LogStateStack("bootstrap complete");
        }

        public static void NotifyCampaignMapReady()
        {
            _campaignLoadedThisProcess = true;
            MarkForwardLaunchCompleted("campaign map ready");
            DisarmBootstrap("campaign map ready");
        }

        public static void Poll(float dt = 0f)
        {
            MainMenuAutoLauncher.Poll(dt);
            ModuleMismatchAutoConfirmService.Poll(dt);

            var activeStateName = GameSessionState.GetActiveStateName();
            if (MainMenuAutoLauncher.IsForwardLaunchInProgress
                && !string.Equals(activeStateName, "InitialState", StringComparison.OrdinalIgnoreCase))
            {
                MainMenuAutoLauncher.ClearForwardLaunchInProgress();
            }

            TryDisarmOnMainMenuReturn();

            TryDetectGameLoadingStall(activeStateName, dt);

            if (!IsTracking)
            {
                return;
            }

            var nextPhase = ResolvePhase(activeStateName, out var subStage);

            if (nextPhase != _phase || subStage != _subStage || activeStateName != _lastActiveStateName)
            {
                LogTransition(_phase, _subStage, nextPhase, subStage, activeStateName);
                _phase = nextPhase;
                _subStage = subStage;
                _lastActiveStateName = activeStateName;
                _loggedWaiting = false;
                if (nextPhase == SetupPhase.CharacterCreation)
                {
                    _simpleStagePendingAdvance = null;
                    _creationStageStalledSeconds = 0f;
                    _creationStallSubStage = subStage;
                    _hasAnnouncedCreationStall = false;
                    CharacterCreationReflection.ResetNarrativeSession();
                }
            }

            if (_phase == SetupPhase.MapReady)
            {
                CompleteSetup();
            }
            else if (_phase is SetupPhase.IntroVideo or SetupPhase.SandboxVideo)
            {
                LogWaitingOnce("cutscene/video");
            }
            else if (_phase == SetupPhase.CharacterCreation)
            {
                TryAdvanceCurrentCreationStage(dt);
            }
        }

        public static void OnCharacterCreationStage(object state)
        {
            if (!IsTracking || state == null)
            {
                return;
            }

            var stageName = CharacterCreationReflection.GetCurrentStageName(state);
            var nextPhase = SetupPhase.CharacterCreation;

            if (_phase != nextPhase || _subStage != stageName)
            {
                LogTransition(_phase, _subStage, nextPhase, stageName, _lastActiveStateName);
                _phase = nextPhase;
                _subStage = stageName;
                _loggedWaiting = false;
                _simpleStagePendingAdvance = null;
                _creationStageStalledSeconds = 0f;
                _creationStallSubStage = stageName;
                _hasAnnouncedCreationStall = false;
                CharacterCreationReflection.ResetNarrativeSession();
            }

            TryAdvanceCurrentCreationStage(0f);
        }

        public static void MarkSandboxSetupStarted()
        {
            if (!IsTracking)
            {
                return;
            }

            LogTransition(_phase, _subStage, SetupPhase.CharacterCreation, "bootstrap", _lastActiveStateName);
            _phase = SetupPhase.CharacterCreation;
            _subStage = "bootstrap";
            _loggedWaiting = false;
            _simpleStagePendingAdvance = null;
        }

        private static void TryAdvanceCurrentCreationStage(float dt)
        {
            var stateType = CharacterCreationReflection.StateType;
            var activeState = GameStateManager.Current?.ActiveState;
            if (stateType == null || activeState == null || activeState.GetType() != stateType)
            {
                return;
            }

            if (!_bootstrapUsed)
            {
                _bootstrapUsed = true;
            }

            var stageName = CharacterCreationReflection.GetCurrentStageName(activeState);
            if (_subStage != stageName)
            {
                _subStage = stageName;
                _simpleStagePendingAdvance = null;
                _creationStageStalledSeconds = 0f;
                _creationStallSubStage = stageName;
                _hasAnnouncedCreationStall = false;
                CharacterCreationReflection.ResetNarrativeSession();
            }

            var advanced = TryAdvanceCreationStage(activeState, stageName);

            if (advanced)
            {
                AnnounceCreationAdvance();
                _creationStageStalledSeconds = 0f;
                _hasAnnouncedCreationStall = false;
                return;
            }

            if (dt <= 0f || stageName != _creationStallSubStage)
            {
                return;
            }

            _creationStageStalledSeconds += dt;
            if (_creationStageStalledSeconds < CreationStageStallThresholdSeconds || _hasAnnouncedCreationStall)
            {
                return;
            }

            _hasAnnouncedCreationStall = true;
            AnnounceSetupStalled($"CharacterCreation/{stageName}");
            if (stageName is "CharacterCreationNarrativeStage" or "CharacterCreationGenericStage")
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] narrative stall detail: {CharacterCreationReflection.GetNarrativeStallDiagnostics()}",
                    showInGame: false);
            }

            GuildLog.Info(
                $"[TBG QUICKSTART] stage stalled for {CreationStageStallThresholdSeconds:0}s at {stageName}.",
                showInGame: false);
        }

        private static bool TryAdvanceCreationStage(object state, string stageName)
        {
            if (stageName == "CharacterCreationCultureStage")
            {
                return CharacterCreationReflection.TrySkipCultureStage(state);
            }

            if (stageName is "CharacterCreationNarrativeStage" or "CharacterCreationGenericStage")
            {
                return CharacterCreationReflection.TryAdvanceNarrativeMenu(state);
            }

            if (!IsSimpleNextStage(stageName))
            {
                return false;
            }

            if (string.Equals(_simpleStagePendingAdvance, stageName, StringComparison.Ordinal))
            {
                return false;
            }

            if (!CharacterCreationReflection.TryNextStage(state))
            {
                return false;
            }

            _simpleStagePendingAdvance = stageName;
            return true;
        }

        private static bool IsSimpleNextStage(string stageName)
        {
            return stageName is "CharacterCreationFaceGeneratorStage"
                or "CharacterCreationReviewStage"
                or "CharacterCreationOptionsStage"
                or "CharacterCreationBannerEditorStage"
                or "CharacterCreationClanNamingStage";
        }

        public static void MarkStoryModeBlocked()
        {
            if (!IsTracking)
            {
                return;
            }

            GuildLog.Info("[TBG QUICKSTART] blocked: story mode — automation disabled.", showInGame: false);
            _setupComplete = true;
            _phase = SetupPhase.Complete;
        }

        private static SetupPhase ResolvePhase(string activeStateName, out string subStage)
        {
            subStage = null;
            var creationStateName = CharacterCreationReflection.StateType?.Name ?? "CharacterCreationState";

            if (string.IsNullOrEmpty(activeStateName) || activeStateName == "null")
            {
                return SetupPhase.MainMenu;
            }

            if (activeStateName.IndexOf("Video", StringComparison.OrdinalIgnoreCase) >= 0
                || activeStateName.IndexOf("Splash", StringComparison.OrdinalIgnoreCase) >= 0)
            {
                return SetupPhase.IntroVideo;
            }

            if (activeStateName == creationStateName)
            {
                subStage = TryGetCharacterCreationSubStage();
                return SetupPhase.CharacterCreation;
            }

            if (activeStateName == "MapState")
            {
                GameSessionState.Refresh();
                return GameSessionState.IsCampaignMapReady ? SetupPhase.MapReady : SetupPhase.MapTransition;
            }

            if (Campaign.Current != null)
            {
                return SetupPhase.MapTransition;
            }

            if (Game.Current == null)
            {
                return SetupPhase.MainMenu;
            }

            return SetupPhase.SandboxVideo;
        }

        private static string TryGetCharacterCreationSubStage()
        {
            try
            {
                var stateType = CharacterCreationReflection.StateType;
                if (stateType == null || GameStateManager.Current?.ActiveState?.GetType() != stateType)
                {
                    return "unknown";
                }

                return CharacterCreationReflection.GetCurrentStageName(GameStateManager.Current.ActiveState);
            }
            catch
            {
            }

            return "unknown";
        }

        private static void TryDetectGameLoadingStall(string activeStateName, float dt)
        {
            if (!string.Equals(activeStateName, "GameLoadingState", StringComparison.OrdinalIgnoreCase))
            {
                _gameLoadingStateStalledSeconds = 0f;
                return;
            }

            if (dt <= 0f)
            {
                return;
            }

            _gameLoadingStateStalledSeconds += dt;
            if (_gameLoadingStateStalledSeconds < GameLoadingStallThresholdSeconds || _hasAnnouncedGameLoadingStall)
            {
                return;
            }

            _hasAnnouncedGameLoadingStall = true;
            GuildLog.Info(
                $"[TBG QUICKSTART] load stall: GameLoadingState exceeded {GameLoadingStallThresholdSeconds:0}s",
                showInGame: false);
            QuickStartDiagnostics.LogStateStack("GameLoadingState stall");
            AnnounceSetupStalled("GameLoadingState");
        }

        private static void TryDisarmOnMainMenuReturn()
        {
            var activeStateName = GameSessionState.GetActiveStateName();
            if (!string.Equals(activeStateName, "InitialState", StringComparison.OrdinalIgnoreCase))
            {
                return;
            }

            if (!_campaignLoadedThisProcess
                && !_bootstrapUsed
                && !_devSaveLoadUsed
                && !MainMenuAutoLauncher.ForwardLaunchCompletedThisProcess
                && _phase is SetupPhase.Idle or SetupPhase.MainMenu)
            {
                return;
            }

            if (_sessionEndDisarmed)
            {
                return;
            }

            if (MainMenuAutoLauncher.IsForwardLaunchInProgress)
            {
                return;
            }

            _sessionEndDisarmed = true;
            MainMenuAutoLauncher.DisarmForSessionEnd("returned to main menu");
            BlacksmithGuildCampaignBehavior.ResetCampaignMapReadyAnnouncement();
            MainMenuAutoLauncher.LogLaunchIntentFileStatus("returned to main menu");
            QuickStartDiagnostics.LogStateStack("returned to main menu");
            DisarmBootstrap("returned to main menu");
        }

        private static void CompleteSetup()
        {
            if (_setupComplete)
            {
                return;
            }

            DisarmBootstrap("setup complete");

            GuildLog.Info("[TBG QUICKSTART] setup complete; handing off to map readiness gate.", showInGame: false);

            if (_loggedQuickStartNotice)
            {
                return;
            }

            _loggedQuickStartNotice = true;

            if (_devSaveLoadUsed)
            {
                GuildLog.Display($"TBG DEVSAVE: map ready ({_devSaveName ?? "dev save"}).");
                return;
            }

            if (_bootstrapUsed)
            {
                GuildLog.Display("TBG QUICKSTART: sandbox character auto-applied.");
            }
        }

        private static void LogTransition(
            SetupPhase fromPhase,
            string fromSubStage,
            SetupPhase toPhase,
            string toSubStage,
            string activeStateName)
        {
            if (!AutoCharacterCreationConfig.TraceTransitions)
            {
                return;
            }

            var from = FormatPhase(fromPhase, fromSubStage);
            var to = FormatPhase(toPhase, toSubStage);
            GuildLog.Info(
                $"[TBG QUICKSTART] transition: {from} -> {to} (activeState={activeStateName})",
                showInGame: false
            );
        }

        private static void LogWaitingOnce(string reason)
        {
            if (_loggedWaiting)
            {
                return;
            }

            _loggedWaiting = true;

            if (_phase is SetupPhase.IntroVideo or SetupPhase.SandboxVideo)
            {
                AnnounceCutsceneSkip();
            }

            if (AutoCharacterCreationConfig.TraceTransitions)
            {
                GuildLog.Info($"[TBG QUICKSTART] waiting at {_phase} ({reason}).", showInGame: false);
            }
        }

        private static string FormatPhase(SetupPhase phase, string subStage)
        {
            if (phase == SetupPhase.CharacterCreation && !string.IsNullOrEmpty(subStage))
            {
                return $"{phase}({subStage})";
            }

            return phase.ToString();
        }
    }
}
