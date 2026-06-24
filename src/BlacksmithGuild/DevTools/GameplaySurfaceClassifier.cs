using System;
using BlacksmithGuild.DevTools.Assistive;

namespace BlacksmithGuild.DevTools
{
    public static class GameplaySurfaceClassifier
    {
        private static string _lastStableSurface;
        private static DateTime? _stableSinceUtc;

        public static GameplaySurfaceSnapshot CaptureLive()
        {
            return Classify(new GameplaySurfaceInputs
            {
                ActiveStateName = GameSessionState.GetActiveStateName(),
                IsCampaignLoaded = GameSessionState.IsCampaignLoaded,
                IsMainHeroReady = GameSessionState.IsMainHeroReady,
                IsMapStateActive = GameSessionState.IsMapStateActive,
                IsMapMenuOpen = GameSessionState.IsMapMenuOpen,
                IsSettlementInteriorReady = GameSessionState.IsSettlementInteriorReady,
                IsMissionActive = GameSessionState.IsMissionActiveForTrace(),
                MenuId = GameSessionState.ActiveMenuId ?? GameSessionState.MapMenuId,
                LocationId = GameSessionState.CurrentLocationId,
                SettlementId = GameSessionState.CurrentSettlementStringId,
                SettlementName = GameSessionState.CurrentSettlementName,
                IsConversation = MissionSignalProbe.IsConversationActive(),
                IsTournament = MissionSignalProbe.IsTournamentActive(),
                IsBattle = MissionSignalProbe.IsBattleActive(),
                IsSmithing = MissionSignalProbe.IsSmithingSurface(
                    GameSessionState.ActiveMenuId,
                    GameSessionState.CurrentLocationId),
                IsTrading = MissionSignalProbe.IsTradingSurface(
                    GameSessionState.ActiveMenuId,
                    GameSessionState.CurrentLocationId),
                IsEscapeMenu = MissionSignalProbe.IsEscapeMenu(
                    GameSessionState.ActiveMenuId,
                    GameSessionState.GetActiveStateName()),
                CanPollFileInbox = GameSessionState.CanPollFileInbox,
                CanAcceptAssistiveCommand = AssistReadinessEvaluator.CanAcceptAssistiveCommand
            });
        }

        public static GameplaySurfaceSnapshot Classify(GameplaySurfaceInputs input)
        {
            input = input ?? new GameplaySurfaceInputs();
            var now = DateTime.UtcNow;
            var menuLocation = CombineSignals(input.MenuId, input.LocationId);
            var surface = ResolveGameplaySurface(input, menuLocation);
            var lifecycle = ResolveGameLifecycle(input, surface);
            var missionKind = ResolveMissionKind(input, surface);
            var gameplayMode = ResolveGameplayMode(input);
            UpdateStableSurface(surface, now);

            var snapshot = new GameplaySurfaceSnapshot
            {
                UpdatedAtUtc = now,
                HeartbeatUtc = now,
                ActiveStateName = input.ActiveStateName ?? "unknown",
                GameLifecycle = lifecycle,
                GameplayMode = gameplayMode,
                GameplaySurface = surface,
                MissionKind = missionKind,
                MenuId = input.MenuId,
                LocationId = input.LocationId,
                SettlementId = input.SettlementId,
                SettlementName = input.SettlementName,
                IsCampaignLoaded = input.IsCampaignLoaded,
                IsMainHeroReady = input.IsMainHeroReady,
                IsMapStateActive = input.IsMapStateActive,
                IsMapMenuOpen = input.IsMapMenuOpen,
                IsMissionActive = input.IsMissionActive,
                IsConversation = input.IsConversation,
                IsTournament = input.IsTournament,
                IsBattle = input.IsBattle,
                IsSmithing = input.IsSmithing || surface == GameplaySurfaceKinds.Blacksmithing,
                IsTrading = input.IsTrading || surface == GameplaySurfaceKinds.Trading,
                CanPollFileInbox = input.CanPollFileInbox,
                CanAcceptAssistiveCommand = input.CanAcceptAssistiveCommand,
                LastStableSurface = _lastStableSurface,
                StableSinceUtc = _stableSinceUtc
            };

            ApplySafetyRules(snapshot);
            return snapshot;
        }

        public static bool IsTravelExecuteSurface(string surface) =>
            surface == GameplaySurfaceKinds.SettlementMenu
            || surface == GameplaySurfaceKinds.CampaignMap;

        public static bool IsSmithingExecuteSurface(string surface) =>
            surface == GameplaySurfaceKinds.Blacksmithing;

        public static bool IsTradeExecuteSurface(string surface) =>
            surface == GameplaySurfaceKinds.Trading;

        private static string ResolveGameplaySurface(GameplaySurfaceInputs input, string menuLocation)
        {
            var activeState = input.ActiveStateName ?? "unknown";

            if (input.IsEscapeMenu || ContainsAny(menuLocation, "escape"))
            {
                return GameplaySurfaceKinds.EscapeMenu;
            }

            if (string.Equals(activeState, "MainMenuState", StringComparison.Ordinal))
            {
                return ContainsAny(menuLocation, "multiplayer")
                    ? GameplaySurfaceKinds.Multiplayer
                    : GameplaySurfaceKinds.MainMenu;
            }

            if (string.Equals(activeState, "GameLoadingState", StringComparison.Ordinal)
                || !input.IsCampaignLoaded
                || !input.IsMainHeroReady)
            {
                return GameplaySurfaceKinds.Loading;
            }

            if (ContainsAny(activeState, "multiplayer"))
            {
                return GameplaySurfaceKinds.Multiplayer;
            }

            if (input.IsConversation)
            {
                return GameplaySurfaceKinds.Conversation;
            }

            if (input.IsTournament || ContainsAny(menuLocation, "tournament"))
            {
                return GameplaySurfaceKinds.Tournament;
            }

            if (input.IsBattle)
            {
                return GameplaySurfaceKinds.Battle;
            }

            if (input.IsSmithing || ContainsAny(menuLocation, "smith", "smithy", "craft", "forge"))
            {
                return GameplaySurfaceKinds.Blacksmithing;
            }

            if (input.IsTrading || ContainsAny(menuLocation, "trade", "market", "shop", "merchant"))
            {
                return GameplaySurfaceKinds.Trading;
            }

            if (ContainsAny(menuLocation, "inventory", "stash"))
            {
                return GameplaySurfaceKinds.Inventory;
            }

            if (ContainsAny(menuLocation, "party"))
            {
                return GameplaySurfaceKinds.Party;
            }

            if (ContainsAny(menuLocation, "character", "hero"))
            {
                return GameplaySurfaceKinds.Character;
            }

            if (ContainsAny(menuLocation, "kingdom"))
            {
                return GameplaySurfaceKinds.Kingdom;
            }

            if (ContainsAny(menuLocation, "clan"))
            {
                return GameplaySurfaceKinds.Clan;
            }

            if (ContainsAny(menuLocation, "arena"))
            {
                return GameplaySurfaceKinds.Arena;
            }

            if (ContainsAny(menuLocation, "hideout"))
            {
                return GameplaySurfaceKinds.Hideout;
            }

            if (input.IsMissionActive)
            {
                return GameplaySurfaceKinds.Unknown;
            }

            if (input.IsMapStateActive && input.IsMapMenuOpen)
            {
                return GameplaySurfaceKinds.SettlementMenu;
            }

            if (input.IsSettlementInteriorReady)
            {
                return ContainsAny(menuLocation, "center", "town", "city")
                    ? GameplaySurfaceKinds.SettlementCity
                    : GameplaySurfaceKinds.SettlementInterior;
            }

            if (input.IsMapStateActive && !input.IsMapMenuOpen)
            {
                return GameplaySurfaceKinds.CampaignMap;
            }

            return GameplaySurfaceKinds.Unknown;
        }

        private static string ResolveGameLifecycle(GameplaySurfaceInputs input, string surface)
        {
            if (surface == GameplaySurfaceKinds.MainMenu)
            {
                return GameLifecycleKinds.MainMenu;
            }

            if (surface == GameplaySurfaceKinds.Multiplayer)
            {
                return GameLifecycleKinds.MultiplayerMenu;
            }

            if (surface == GameplaySurfaceKinds.Loading)
            {
                return GameLifecycleKinds.CampaignLoading;
            }

            if (input.IsMissionActive || IsMissionSurface(surface))
            {
                return GameLifecycleKinds.MissionActive;
            }

            if (input.IsCampaignLoaded && input.IsMainHeroReady)
            {
                return GameLifecycleKinds.CampaignLoaded;
            }

            return GameLifecycleKinds.Unknown;
        }

        private static string ResolveGameplayMode(GameplaySurfaceInputs input)
        {
            if (ContainsAny(input.ActiveStateName, "multiplayer")
                || ContainsAny(CombineSignals(input.MenuId, input.LocationId), "multiplayer"))
            {
                return "multiplayer";
            }

            return input.IsCampaignLoaded ? "campaign" : "unknown";
        }

        private static string ResolveMissionKind(GameplaySurfaceInputs input, string surface)
        {
            if (!input.IsMissionActive && !IsMissionSurface(surface))
            {
                return null;
            }

            if (input.IsBattle || surface == GameplaySurfaceKinds.Battle)
            {
                return "mission_active:battle";
            }

            if (input.IsTournament || surface == GameplaySurfaceKinds.Tournament)
            {
                return "mission_active:tournament";
            }

            if (input.IsConversation || surface == GameplaySurfaceKinds.Conversation)
            {
                return "mission_active:conversation";
            }

            if (surface == GameplaySurfaceKinds.Arena)
            {
                return "mission_active:arena";
            }

            if (surface == GameplaySurfaceKinds.Hideout)
            {
                return "mission_active:hideout";
            }

            return "mission_active:unknown";
        }

        private static void ApplySafetyRules(GameplaySurfaceSnapshot snapshot)
        {
            snapshot.SafeToExecuteTravel = IsTravelExecuteSurface(snapshot.GameplaySurface)
                && !snapshot.IsMissionActive
                && snapshot.MissionKind == null;
            snapshot.SafeToExecuteSmithing = IsSmithingExecuteSurface(snapshot.GameplaySurface);
            snapshot.SafeToExecuteTrade = IsTradeExecuteSurface(snapshot.GameplaySurface);
            snapshot.SafeToWait = snapshot.GameLifecycle == GameLifecycleKinds.CampaignLoaded
                || snapshot.GameLifecycle == GameLifecycleKinds.CampaignLoading
                || snapshot.GameLifecycle == GameLifecycleKinds.MainMenu
                || snapshot.GameLifecycle == GameLifecycleKinds.ModuleLoaded;
            snapshot.SafeToCancel = snapshot.IsMissionActive
                || snapshot.GameplaySurface == GameplaySurfaceKinds.Conversation
                || snapshot.GameplaySurface == GameplaySurfaceKinds.EscapeMenu
                || snapshot.GameplaySurface == GameplaySurfaceKinds.Loading;

            if (snapshot.SafeToExecuteTravel)
            {
                snapshot.BlockReason = null;
                return;
            }

            if (!string.IsNullOrEmpty(snapshot.MissionKind))
            {
                snapshot.BlockReason = snapshot.MissionKind;
                return;
            }

            if (snapshot.GameplaySurface == GameplaySurfaceKinds.Loading)
            {
                snapshot.BlockReason = "loading";
                return;
            }

            if (snapshot.GameplaySurface == GameplaySurfaceKinds.Unknown)
            {
                snapshot.BlockReason = "unknown_surface";
                return;
            }

            snapshot.BlockReason = $"surface_blocked:{snapshot.GameplaySurface}";
        }

        private static void UpdateStableSurface(string surface, DateTime now)
        {
            if (surface == GameplaySurfaceKinds.Loading || surface == GameplaySurfaceKinds.Unknown)
            {
                return;
            }

            if (!string.Equals(surface, _lastStableSurface, StringComparison.Ordinal))
            {
                _lastStableSurface = surface;
                _stableSinceUtc = now;
            }
        }

        private static bool IsMissionSurface(string surface)
        {
            return surface == GameplaySurfaceKinds.Battle
                || surface == GameplaySurfaceKinds.Tournament
                || surface == GameplaySurfaceKinds.Conversation
                || surface == GameplaySurfaceKinds.Arena
                || surface == GameplaySurfaceKinds.Hideout;
        }

        private static string CombineSignals(params string[] values) =>
            string.Join("|", values ?? Array.Empty<string>()).ToLowerInvariant();

        private static bool ContainsAny(string haystack, params string[] needles)
        {
            if (string.IsNullOrWhiteSpace(haystack))
            {
                return false;
            }

            foreach (var needle in needles)
            {
                if (haystack.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }

            return false;
        }
    }

    internal static class MissionSignalProbe
    {
        public static bool IsConversationActive()
        {
            try
            {
                var campaign = TaleWorlds.CampaignSystem.Campaign.Current;
                var manager = campaign?.GetType().GetProperty("ConversationManager")?.GetValue(campaign);
                if (manager == null)
                {
                    return false;
                }

                return manager.GetType().GetProperty("IsConversationInProgress")?.GetValue(manager) is bool b && b;
            }
            catch
            {
                return false;
            }
        }

        public static bool IsTournamentActive() => ProbeMissionSceneContains("tournament");
        public static bool IsBattleActive() => ProbeMissionSceneContains("battle", "siege");

        public static bool IsSmithingSurface(string menuId, string locationId) =>
            Contains(menuId, locationId, "smith", "smithy", "craft", "forge");

        public static bool IsTradingSurface(string menuId, string locationId) =>
            Contains(menuId, locationId, "trade", "market", "shop", "merchant");

        public static bool IsEscapeMenu(string menuId, string activeState) =>
            Contains(menuId, activeState, "escape");

        private static bool Contains(string a, string b, params string[] needles)
        {
            var haystack = $"{a}|{b}".ToLowerInvariant();
            foreach (var needle in needles)
            {
                if (haystack.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }

            return false;
        }

        private static bool ProbeMissionSceneContains(params string[] needles)
        {
            try
            {
                var missionType = Type.GetType("TaleWorlds.MountAndBlade.Mission, TaleWorlds.MountAndBlade");
                var current = missionType?.GetProperty("Current")?.GetValue(null);
                if (current == null)
                {
                    return false;
                }

                var scene = current.GetType().GetProperty("SceneName")?.GetValue(current)?.ToString()
                    ?? current.GetType().Name;
                foreach (var needle in needles)
                {
                    if (scene.IndexOf(needle, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return true;
                    }
                }
            }
            catch
            {
            }

            return false;
        }
    }
}
