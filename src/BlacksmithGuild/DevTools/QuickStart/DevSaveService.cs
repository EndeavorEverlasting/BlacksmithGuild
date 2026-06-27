using System;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.DevTools.QuickStart
{
    public static class DevSaveService
    {
        public const string SaveDevStartSaveNowCommand = "SaveDevStartSaveNow";

        public static string LastFailReason { get; private set; }

        public static bool SaveDevStartNow(string source = SaveDevStartSaveNowCommand)
        {
            LastFailReason = null;
            GameSessionState.Refresh();
            GuildLog.Info($"[TBG DEVSAVE] save requested (source={source}).", showInGame: false);

            if (Campaign.Current == null)
            {
                return Fail("campaign_not_loaded");
            }

            if (!GameSessionState.IsCampaignSessionReady)
            {
                return Fail("campaign_session_not_ready: " + GameSessionState.GetCommandReadyBlockDetail());
            }

            if (Campaign.Current.SaveHandler.IsSaving)
            {
                return Fail("save_in_progress");
            }

            var targetName = DevSaveResolver.DevSavePrefix;
            if (!targetName.StartsWith(DevSaveResolver.DevSavePrefix, StringComparison.OrdinalIgnoreCase))
            {
                return Fail("target_name_not_disposable_prefix");
            }

            try
            {
                Campaign.Current.SaveHandler.SaveAs(targetName);
                if (!DevSaveResolver.TryGetLatest(out var saveInfo) || saveInfo?.Name == null)
                {
                    return Fail("dev_save_not_found_after_save");
                }

                if (!saveInfo.Name.StartsWith(DevSaveResolver.DevSavePrefix, StringComparison.OrdinalIgnoreCase))
                {
                    return Fail("saved_name_not_disposable_prefix: " + saveInfo.Name);
                }

                GuildLog.Info(
                    $"[TBG DEVSAVE] saved disposable dev save '{saveInfo.Name}' (source={source}).",
                    showInGame: false);
                InGameNotice.Info(ModDisplay.CompactLine("DevSave", $"saved {saveInfo.Name}"));
                return true;
            }
            catch (Exception ex)
            {
                return Fail(ex.Message);
            }
        }

        private static bool Fail(string reason)
        {
            LastFailReason = reason;
            GuildLog.Info($"[TBG DEVSAVE] refused/failed: {reason}", showInGame: false);
            return false;
        }
    }
}
