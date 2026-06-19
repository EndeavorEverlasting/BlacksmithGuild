using System;
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

        public static void AnnounceSetupStalled(SetupPhase phase)
        {
            GuildLog.Display($"TBG QUICKSTART: setup stalled at {phase} — see Phase1.log");
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

        public static void Poll()
        {
            if (!IsTracking)
            {
                return;
            }

            var activeStateName = GameSessionState.GetActiveStateName();
            var nextPhase = ResolvePhase(activeStateName, out var subStage);

            if (nextPhase != _phase || subStage != _subStage || activeStateName != _lastActiveStateName)
            {
                LogTransition(_phase, _subStage, nextPhase, subStage, activeStateName);
                _phase = nextPhase;
                _subStage = subStage;
                _lastActiveStateName = activeStateName;
                _loggedWaiting = false;
            }

            if (_phase == SetupPhase.MapReady)
            {
                CompleteSetup();
            }
            else if (_phase is SetupPhase.IntroVideo or SetupPhase.SandboxVideo)
            {
                LogWaitingOnce("cutscene/video");
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
            }

            AnnounceCreationAdvance();
            HandleCharacterCreationStage(state, stageName);
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

        private static void HandleCharacterCreationStage(object state, string stageName)
        {
            try
            {
                if (stageName == "CharacterCreationCultureStage")
                {
                    CharacterCreationReflection.SkipCultureStage(state);
                }
                else if (stageName == "CharacterCreationFaceGeneratorStage")
                {
                    CharacterCreationReflection.NextStage(state);
                }
                else if (stageName == "CharacterCreationNarrativeStage" || stageName == "CharacterCreationGenericStage")
                {
                    CharacterCreationReflection.SkipNarrativeStage(state);
                }
                else if (stageName is "CharacterCreationReviewStage"
                    or "CharacterCreationOptionsStage"
                    or "CharacterCreationBannerEditorStage"
                    or "CharacterCreationClanNamingStage")
                {
                    CharacterCreationReflection.NextStage(state);
                }
            }
            catch (Exception ex)
            {
                GuildLog.Info(
                    $"[TBG QUICKSTART] stage handler failed at {stageName}: {ex.Message}",
                    showInGame: false
                );
            }
        }

        private static void CompleteSetup()
        {
            if (_setupComplete)
            {
                return;
            }

            _setupComplete = true;
            _phase = SetupPhase.Complete;

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
