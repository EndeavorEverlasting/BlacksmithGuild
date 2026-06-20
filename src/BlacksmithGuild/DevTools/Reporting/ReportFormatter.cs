using System;
using System.Collections.Generic;
using System.Text;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Reporting
{
    public sealed class ReportFormatter
    {
        private readonly List<string> _sectionLines = new List<string>();
        private readonly List<string> _summaryLines = new List<string>();
        private readonly List<string> _verdictLines = new List<string>();
        private bool _ended;

        private ReportFormatter(string title, string source, string reportIdSlug, bool isCert)
        {
            Title = title;
            Source = source;
            IsCert = isCert;
            Time = DateTime.Now;
            ReportId = $"{reportIdSlug}-{Time:yyyyMMdd-HHmmss}";
        }

        public string ReportId { get; }

        public string Title { get; }

        public string Source { get; }

        public DateTime Time { get; }

        public bool IsCert { get; }

        public static ReportFormatter BeginReport(string title, string source, string reportIdSlug)
        {
            return new ReportFormatter(title, source, reportIdSlug, isCert: false);
        }

        public static ReportFormatter BeginCertReport(string title, string source, string reportIdSlug)
        {
            return new ReportFormatter(title, source, reportIdSlug, isCert: true);
        }

        public ReportFormatter Section(string title)
        {
            EnsureOpen();
            _sectionLines.Add($"--- {title} ---");
            return this;
        }

        public ReportFormatter Line(string label, string value)
        {
            EnsureOpen();
            _sectionLines.Add($"{label}: {value ?? ""}");
            return this;
        }

        public ReportFormatter TableLine(string line)
        {
            EnsureOpen();
            _sectionLines.Add(line ?? string.Empty);
            return this;
        }

        public ReportFormatter Verdict(ReportVerdict verdict, string message)
        {
            EnsureOpen();
            _verdictLines.Add($"{AdvisoryReportText.FormatVerdictMarker(verdict)} {message}");
            return this;
        }

        public ReportFormatter SummaryLine(string line)
        {
            EnsureOpen();
            if (!string.IsNullOrEmpty(line))
            {
                _summaryLines.Add(line);
            }

            return this;
        }

        public void EndReport(bool emitInGame = true, bool emitToFile = true)
        {
            if (_ended)
            {
                return;
            }

            _ended = true;

            if (emitToFile)
            {
                WriteToFile(BuildFullReport());
            }

            if (emitInGame)
            {
                EmitInGame(BuildSummaryReport());
            }
        }

        public string BuildFullReport()
        {
            var builder = new StringBuilder();
            AppendHeader(builder);
            AppendLines(builder, _sectionLines);
            AppendLines(builder, _verdictLines);
            AppendEndMarker(builder);
            return builder.ToString();
        }

        public string BuildSummaryReport()
        {
            var builder = new StringBuilder();
            AppendHeader(builder);
            AppendLines(builder, _summaryLines);
            AppendEndMarker(builder);
            return builder.ToString();
        }

        private void AppendHeader(StringBuilder builder)
        {
            builder.AppendLine(IsCert ? ModDisplay.CertReportHeader(Title) : ModDisplay.ReportHeader(Title));
            builder.AppendLine($"reportId: {ReportId}");
            if (!string.IsNullOrEmpty(Source))
            {
                builder.AppendLine($"source: {Source}");
            }

            builder.AppendLine($"time: {Time:yyyy-MM-dd HH:mm:ss}");
        }

        private void AppendEndMarker(StringBuilder builder)
        {
            builder.AppendLine(IsCert ? ModDisplay.CertReportEnd : ModDisplay.ReportEnd);
        }

        private static void AppendLines(StringBuilder builder, IEnumerable<string> lines)
        {
            foreach (var line in lines)
            {
                builder.AppendLine(line);
            }
        }

        private static void WriteToFile(string report)
        {
            foreach (var line in report.Split(new[] { Environment.NewLine }, StringSplitOptions.None))
            {
                if (string.IsNullOrEmpty(line))
                {
                    continue;
                }

                GuildLog.Info(line, showInGame: false);
            }
        }

        private static void EmitInGame(string report)
        {
            foreach (var line in report.Split(new[] { Environment.NewLine }, StringSplitOptions.None))
            {
                if (string.IsNullOrEmpty(line))
                {
                    continue;
                }

                var kind = ReportLineClassifier.Classify(line);
                GuildLog.Display(line, showInGame: true, color: ReportLineClassifier.ColorFor(kind));
            }
        }

        private void EnsureOpen()
        {
            if (_ended)
            {
                throw new InvalidOperationException("Report already ended.");
            }
        }
    }
}
