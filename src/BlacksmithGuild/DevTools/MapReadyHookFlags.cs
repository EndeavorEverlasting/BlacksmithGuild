using System;

namespace BlacksmithGuild.DevTools
{
    [Flags]
    public enum MapReadyHookFlags
    {
        None = 0,
        StatusFlush = 1 << 0,
        NotifySetupTracker = 1 << 1,
        InGameNotices = 1 << 2,
        HotkeyTrace = 1 << 3,
        ForgeAdvisorSmoke = 1 << 4,
        TreasuryWatch = 1 << 5,
        AutoCharacterBuild = 1 << 6,
        CommandSurface = 1 << 7,
        AgentAutoLoop = 1 << 8,

        Immediate = StatusFlush | NotifySetupTracker | InGameNotices | HotkeyTrace,
        Deferred = ForgeAdvisorSmoke | TreasuryWatch | AutoCharacterBuild | CommandSurface | AgentAutoLoop,
        All = Immediate | Deferred
    }
}
