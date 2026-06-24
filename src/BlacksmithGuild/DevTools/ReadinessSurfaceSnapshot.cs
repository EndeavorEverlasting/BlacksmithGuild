namespace BlacksmithGuild.DevTools
{
    public static class ReadinessSurfaceKinds
    {
        public const string Loading = "loading";
        public const string MainMenu = "main_menu";
        public const string SettlementMenu = "settlement_menu";
        public const string SettlementInterior = "settlement_interior";
        public const string MapSurface = "map_surface";
        public const string Unknown = "unknown";
    }

    /// <summary>Primitive readiness surface DTO — no live Bannerlord object references.</summary>
    public struct ReadinessSurfaceSnapshot
    {
        public bool MapStateActive;
        public bool SettlementMenuOpen;
        public string SettlementMenuId;
        public string SettlementName;
        public bool CampaignMapSurfaceOpen;
        public bool SettlementInteriorReady;
        public string ReadinessSurface;
    }
}
