using System;

namespace BlacksmithGuild.DevTools
{
    public static class GameLifecycleKinds
    {
        public const string NotStarted = "not_started";
        public const string ModuleLoaded = "module_loaded";
        public const string MainMenu = "main_menu";
        public const string MultiplayerMenu = "multiplayer_menu";
        public const string CampaignLoading = "campaign_loading";
        public const string CampaignLoaded = "campaign_loaded";
        public const string MissionActive = "mission_active";
        public const string Terminated = "terminated";
        public const string Unknown = "unknown";
    }

    public static class GameplaySurfaceKinds
    {
        public const string Loading = "loading";
        public const string MainMenu = "main_menu";
        public const string Multiplayer = "multiplayer";
        public const string CampaignMap = "campaign_map";
        public const string SettlementMenu = "settlement_menu";
        public const string SettlementCity = "settlement_city";
        public const string SettlementInterior = "settlement_interior";
        public const string Conversation = "conversation";
        public const string Battle = "battle";
        public const string Tournament = "tournament";
        public const string Arena = "arena";
        public const string Hideout = "hideout";
        public const string Blacksmithing = "blacksmithing";
        public const string Trading = "trading";
        public const string Inventory = "inventory";
        public const string Party = "party";
        public const string Character = "character";
        public const string Kingdom = "kingdom";
        public const string Clan = "clan";
        public const string EscapeMenu = "escape_menu";
        public const string Unknown = "unknown";
    }

    public sealed class GameplaySurfaceInputs
    {
        public string ActiveStateName { get; set; } = "unknown";
        public bool IsCampaignLoaded { get; set; }
        public bool IsMainHeroReady { get; set; }
        public bool IsMapStateActive { get; set; }
        public bool IsMapMenuOpen { get; set; }
        public bool IsSettlementInteriorReady { get; set; }
        public bool IsMissionActive { get; set; }
        public string MenuId { get; set; }
        public string LocationId { get; set; }
        public string SettlementId { get; set; }
        public string SettlementName { get; set; }
        public bool IsConversation { get; set; }
        public bool IsTournament { get; set; }
        public bool IsBattle { get; set; }
        public bool IsSmithing { get; set; }
        public bool IsTrading { get; set; }
        public bool IsEscapeMenu { get; set; }
        public bool CanPollFileInbox { get; set; }
        public bool CanAcceptAssistiveCommand { get; set; }
    }

    public sealed class GameplaySurfaceSnapshot
    {
        public const int SchemaVersion = 1;

        public DateTime UpdatedAtUtc { get; set; } = DateTime.UtcNow;
        public DateTime HeartbeatUtc { get; set; } = DateTime.UtcNow;
        public string ActiveStateName { get; set; } = "unknown";
        public string GameLifecycle { get; set; } = GameLifecycleKinds.Unknown;
        public string GameplayMode { get; set; } = "unknown";
        public string GameplaySurface { get; set; } = GameplaySurfaceKinds.Unknown;
        public string MissionKind { get; set; }
        public string MenuId { get; set; }
        public string LocationId { get; set; }
        public string SettlementId { get; set; }
        public string SettlementName { get; set; }
        public bool IsCampaignLoaded { get; set; }
        public bool IsMainHeroReady { get; set; }
        public bool IsMapStateActive { get; set; }
        public bool IsMapMenuOpen { get; set; }
        public bool IsMissionActive { get; set; }
        public bool IsConversation { get; set; }
        public bool IsTournament { get; set; }
        public bool IsBattle { get; set; }
        public bool IsSmithing { get; set; }
        public bool IsTrading { get; set; }
        public bool CanPollFileInbox { get; set; }
        public bool CanAcceptAssistiveCommand { get; set; }
        public bool SafeToWait { get; set; }
        public bool SafeToCancel { get; set; }
        public bool SafeToExecuteTravel { get; set; }
        public bool SafeToExecuteSmithing { get; set; }
        public bool SafeToExecuteTrade { get; set; }
        public string BlockReason { get; set; }
        public string LastStableSurface { get; set; }
        public DateTime? StableSinceUtc { get; set; }
    }
}
