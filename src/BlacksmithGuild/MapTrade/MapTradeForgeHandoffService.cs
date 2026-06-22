using System;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.Forge;

namespace BlacksmithGuild.MapTrade
{
    public static class MapTradeForgeHandoffService
    {
        public const string RunForgeHandoffAfterTradeNowCommand = "RunForgeHandoffAfterTradeNow";

        public static bool RunHandoffNow(string source = RunForgeHandoffAfterTradeNowCommand, bool allowAutomation = true)
        {
            GameSessionState.Refresh();
            var report = new MapTradeForgeHandoffReport
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                Source = source
            };

            if (!GameSessionState.IsCampaignMapReady)
            {
                report.BlockedReason = GameSessionState.GetCampaignMapBlockDetail();
                MapTradeEvidenceWriter.WriteForgeHandoff(report);
                InGameNotice.Blocked($"TBG MAP TRADE HANDOFF: {report.BlockedReason}");
                return false;
            }

            if (!allowAutomation || !DevToolsConfig.MapTradeAutoRunForgeHandoff)
            {
                report.ForgeHandoffResult = "SkippedByConfig";
                MapTradeEvidenceWriter.WriteForgeHandoff(report);
                InGameNotice.Info("TBG MAP TRADE HANDOFF: skipped by config.");
                return true;
            }

            if (BlacksmithAutomationService.RunAutomationNow(source))
            {
                report.ForgeHandoffRan = true;
                report.ForgeHandoffResult = "RunBlacksmithAutomationNow";
                MapTradeEvidenceWriter.WriteForgeHandoff(report);
                InGameNotice.Success("TBG MAP TRADE HANDOFF: forge automation ran.");
                return true;
            }

            report.BlockedReason = BlacksmithAutomationService.LastBlockedReason ?? "forge automation blocked";
            MapTradeEvidenceWriter.WriteForgeHandoff(report);
            InGameNotice.Blocked($"TBG MAP TRADE HANDOFF: {report.BlockedReason}");
            return false;
        }
    }
}
