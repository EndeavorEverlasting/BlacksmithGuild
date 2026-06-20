namespace BlacksmithGuild.DevTools.Reporting
{
    public enum ModNoticeKind
    {
        Info,
        Success,
        Warn,
        Blocked,
        Fail,
        Ready
    }

    /// <summary>
    /// Player-facing mod branding. Dev file logs keep [TBG …] prefixes elsewhere.
    /// </summary>
    public static class ModDisplay
    {
        public const string Name = "Blacksmith Guild";

        public static string ReportHeader(string title) =>
            $"========== {Name} — {title} ==========";

        public const string ReportEnd = "========== End of report ==========";

        public static string CertReportHeader(string title) =>
            $"========== {Name} — Cert: {title} ==========";

        public const string CertReportEnd = "========== End of cert ==========";

        public static string NoticePrefix(ModNoticeKind kind)
        {
            switch (kind)
            {
                case ModNoticeKind.Success:
                    return $"{Name} — Success:";
                case ModNoticeKind.Warn:
                    return $"{Name} — Warn:";
                case ModNoticeKind.Blocked:
                    return $"{Name} — Blocked:";
                case ModNoticeKind.Fail:
                    return $"{Name} — Failed:";
                case ModNoticeKind.Ready:
                    return $"{Name} — Ready:";
                default:
                    return $"{Name}:";
            }
        }

        public static string CompactLine(string domain, string detail) =>
            $"{Name} — {domain}: {detail}";
    }
}
