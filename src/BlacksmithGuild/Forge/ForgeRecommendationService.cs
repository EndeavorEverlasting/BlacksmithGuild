using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.Library;

namespace BlacksmithGuild.Forge
{
    public static class ForgeRecommendationService
    {
        public const string RankForgeCandidatesCommand = "RankForgeCandidates";
        public const string SetForgeCandidateSourceStubCommand = "SetForgeCandidateSourceStub";
        public const string SetForgeCandidateSourceRealCommand = "SetForgeCandidateSourceReal";
        public const string ShowForgeCandidateSourceCommand = "ShowForgeCandidateSource";
        public const string SetForgeDoctrineProfitForgeCommand = "SetForgeDoctrineProfitForge";
        public const string SetForgeDoctrineRareMetalConservationCommand = "SetForgeDoctrineRareMetalConservation";
        public const string SetForgeDoctrineCashCrisisCommand = "SetForgeDoctrineCashCrisis";
        public const string ShowForgeDoctrineCommand = "ShowForgeDoctrine";

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_ForgeRecommendations.json");

        private static readonly StubForgeCandidateSource StubSource = new StubForgeCandidateSource();
        private static readonly RealForgeCandidateSource RealSource = new RealForgeCandidateSource();

        private static ForgeCandidateSourceKind _requestedSourceKind = ForgeCandidateSourceKind.Stub;
        private static ForgeDoctrine _activeDoctrine = ForgeDoctrine.ProfitForge;
        private static ForgeRecommendationSummary _summary = new ForgeRecommendationSummary();
        private static ForgeRecommendationReport _cachedReport = new ForgeRecommendationReport();
        private static bool _summaryRecorded;

        public static ForgeRecommendationSummary Summary => _summary;
        public static ForgeCandidateSourceKind RequestedSourceKind => _requestedSourceKind;
        public static ForgeDoctrine ActiveDoctrine => _activeDoctrine;

        public static bool SetRequestedSourceKind(ForgeCandidateSourceKind kind)
        {
            _requestedSourceKind = kind;
            DebugLogger.Test($"[TBG FORGE] Candidate source set to {kind}.", showInGame: false);
            InGameNotice.Info($"TBG FORGE: candidate source set to {kind}.");
            return true;
        }

        public static bool SetActiveDoctrine(ForgeDoctrine doctrine)
        {
            _activeDoctrine = doctrine;
            DebugLogger.Test($"[TBG FORGE] Doctrine set to {doctrine}.", showInGame: false);
            InGameNotice.Info($"TBG FORGE: doctrine set to {doctrine}.");
            return true;
        }

        public static bool ShowCandidateSource()
        {
            InGameNotice.Info($"TBG FORGE: requested source={_requestedSourceKind}");
            return true;
        }

        public static bool ShowDoctrine()
        {
            InGameNotice.Info($"TBG FORGE: active doctrine={_activeDoctrine}");
            return true;
        }

        public static bool RunRankNow(ForgeDoctrine? doctrineOverride = null, string source = RankForgeCandidatesCommand)
        {
            try
            {
                var doctrine = doctrineOverride ?? _activeDoctrine;
                var resolution = ResolveCandidates(_requestedSourceKind);
                if (resolution.Candidates.Count == 0)
                {
                    DebugLogger.Test("[TBG FORGE] RankForgeCandidates failed: no candidates after source resolution.", showInGame: false);
                    return false;
                }

                var advisor = new ForgeAdvisor(new MaterialReservePolicy());
                var ranked = advisor.RankCandidates(resolution.Candidates, doctrine).ToList();

                _cachedReport = new ForgeRecommendationReport
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = resolution.SourceLabel,
                    SourceKind = resolution.SourceKind.ToString(),
                    SourceStatus = resolution.SourceStatus.ToString(),
                    FallbackUsed = resolution.FallbackUsed,
                    CandidateCount = resolution.Candidates.Count,
                    Doctrine = doctrine.ToString(),
                    TopCandidate = ranked.FirstOrDefault(),
                    Ranked = ranked
                };

                WriteJsonReport(_cachedReport);
                UpdateSummary(_cachedReport);
                WriteStructuredReport(source);
                ForgeStatus.RecordForgeRecommendations(_summary);

                DebugLogger.Test(
                    $"[TBG FORGE] RankForgeCandidates complete source={_cachedReport.Source} kind={_cachedReport.SourceKind} doctrine={_cachedReport.Doctrine} top={_summary.TopCandidateName} score={_summary.TopFinalScore:0}",
                    showInGame: false);

                return ranked.Count > 0;
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] RankForgeCandidates failed: {ex.Message}", showInGame: false);
                return false;
            }
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Forge Recommendations");
            if (!_summaryRecorded || !_summary.HasRankings)
            {
                report.Line("status", "no rankings cached (run RankForgeCandidates)");
                report.Line("requestedSource", _requestedSourceKind.ToString());
                report.Line("activeDoctrine", _activeDoctrine.ToString());
                report.Verdict(ReportVerdict.Info, "Run RankForgeCandidates to cache ranked candidates");
                return;
            }

            report.Line("top", _summary.TopCandidateName);
            report.Line("score", _summary.TopFinalScore.ToString("0"));
            report.Line("doctrine", _summary.Doctrine);
            report.Line("source", _summary.Source);
            report.Line("sourceKind", _summary.SourceKind);
            report.Line("sourceStatus", _summary.SourceStatus);
            report.Line("fallbackUsed", _summary.FallbackUsed.ToString().ToLowerInvariant());
            report.Line("ranked", _summary.RankedCount.ToString());
            report.Line("json", _summary.ReportPath);
        }

        public static string BuildCompactSummaryLine()
        {
            if (!_summaryRecorded || !_summary.HasRankings)
            {
                return null;
            }

            return
                $"TBG FORGE: top={_summary.TopCandidateName} score={_summary.TopFinalScore:0} doctrine={_summary.Doctrine} source={_summary.Source}";
        }

        private static CandidateResolution ResolveCandidates(ForgeCandidateSourceKind requestedKind)
        {
            if (requestedKind == ForgeCandidateSourceKind.Real)
            {
                if (RealSource.TryGetCandidates(out var realCandidates, out var realStatus, out var realDetail))
                {
                    return new CandidateResolution
                    {
                        Candidates = realCandidates,
                        SourceKind = ForgeCandidateSourceKind.Real,
                        SourceLabel = "real",
                        SourceStatus = realStatus,
                        FallbackUsed = false,
                        Detail = realDetail
                    };
                }

                DebugLogger.Test($"[TBG FORGE] [WARN] real forge candidate source unavailable: {realDetail}", showInGame: false);
                if (StubSource.TryGetCandidates(out var fallbackCandidates, out var stubStatus, out var stubDetail))
                {
                    return new CandidateResolution
                    {
                        Candidates = fallbackCandidates,
                        SourceKind = ForgeCandidateSourceKind.StubFallback,
                        SourceLabel = "stub-fallback",
                        SourceStatus = stubStatus,
                        FallbackUsed = true,
                        Detail = $"real failed ({realStatus}: {realDetail}); {stubDetail}"
                    };
                }
            }

            if (StubSource.TryGetCandidates(out var stubOnly, out var status, out var detail))
            {
                return new CandidateResolution
                {
                    Candidates = stubOnly,
                    SourceKind = ForgeCandidateSourceKind.Stub,
                    SourceLabel = StubForgeCandidateSource.SourceName,
                    SourceStatus = status,
                    FallbackUsed = false,
                    Detail = detail
                };
            }

            return new CandidateResolution
            {
                Candidates = Array.Empty<ForgeCandidate>(),
                SourceKind = ForgeCandidateSourceKind.Stub,
                SourceLabel = StubForgeCandidateSource.SourceName,
                SourceStatus = ForgeCandidateSourceStatus.Empty,
                FallbackUsed = false,
                Detail = detail ?? "stub source returned no candidates"
            };
        }

        private static void UpdateSummary(ForgeRecommendationReport report)
        {
            var top = report.TopCandidate;
            _summary = new ForgeRecommendationSummary
            {
                HasRankings = report.Ranked != null && report.Ranked.Count > 0,
                Source = report.Source,
                SourceKind = report.SourceKind,
                SourceStatus = report.SourceStatus,
                FallbackUsed = report.FallbackUsed,
                Doctrine = report.Doctrine,
                TopCandidateId = top?.Id,
                TopCandidateName = top?.DesignName,
                TopFinalScore = top?.FinalScore ?? 0,
                RankedCount = report.Ranked?.Count ?? 0,
                CandidateCount = report.CandidateCount,
                ReportPath = "BlacksmithGuild_ForgeRecommendations.json",
                GeneratedAt = DateTime.Now
            };
            _summaryRecorded = _summary.HasRankings;
        }

        private static void WriteStructuredReport(string source)
        {
            var report = ReportFormatter.BeginReport("FORGE RECOMMENDATIONS", source, "forge-recommendations");
            var top = _cachedReport.TopCandidate;

            report.Section("Source");
            report.Line("requested", _requestedSourceKind.ToString());
            report.Line("resolved", _cachedReport.Source);
            report.Line("sourceKind", _cachedReport.SourceKind);
            report.Line("sourceStatus", _cachedReport.SourceStatus);
            report.Line("fallbackUsed", _cachedReport.FallbackUsed.ToString().ToLowerInvariant());
            report.Line("candidateCount", _cachedReport.CandidateCount.ToString());
            if (_cachedReport.FallbackUsed)
            {
                report.Verdict(ReportVerdict.Warn, "Real source unavailable — fell back to stub oracle");
            }
            else
            {
                report.Verdict(ReportVerdict.Pass, "Candidate source resolved");
            }

            report.Section("Doctrine");
            report.Line("active", _cachedReport.Doctrine);

            if (top != null)
            {
                report.Section("Top Candidate");
                report.Line("id", top.Id);
                report.Line("name", top.DesignName);
                report.Line("class", top.WeaponClass);
                report.Line("netProfit", top.EstimatedNetProfit.ToString());
                report.Line("doctrineScore", top.DoctrineScore.ToString());
                report.Line("finalScore", top.FinalScore.ToString("0"));
            }

            report.Section("Top 3");
            var index = 1;
            foreach (var candidate in _cachedReport.Ranked.Take(3))
            {
                report.Line(
                    index.ToString(),
                    $"{candidate.DesignName} | score {candidate.FinalScore:0}");
                index++;
            }

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_ForgeRecommendations.json");

            if (top != null)
            {
                report.SummaryLine(
                    $"top={top.DesignName} score={top.FinalScore:0} doctrine={_cachedReport.Doctrine} source={_cachedReport.Source}");
            }

            report.EndReport(emitInGame: string.Equals(source, RankForgeCandidatesCommand, StringComparison.Ordinal), emitToFile: true);
        }

        private static void WriteJsonReport(ForgeRecommendationReport report)
        {
            try
            {
                File.WriteAllText(ReportPath, SerializeReport(report));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG FORGE] Failed to write recommendations JSON: {ex.Message}", showInGame: false);
            }
        }

        private static string SerializeReport(ForgeRecommendationReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"source\": \"{Escape(report.Source)}\",");
            builder.AppendLine($"  \"sourceKind\": \"{Escape(report.SourceKind)}\",");
            builder.AppendLine($"  \"sourceStatus\": \"{Escape(report.SourceStatus)}\",");
            builder.AppendLine($"  \"fallbackUsed\": {report.FallbackUsed.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"candidateCount\": {report.CandidateCount},");
            builder.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");

            if (report.TopCandidate != null)
            {
                AppendCandidateJson(builder, "topCandidate", report.TopCandidate, trailingComma: true);
            }

            builder.AppendLine("  \"ranked\": [");
            for (var i = 0; i < report.Ranked.Count; i++)
            {
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                builder.Append("    ");
                AppendCandidateObject(builder, report.Ranked[i]);
            }

            builder.AppendLine();
            builder.AppendLine("  ]");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static void AppendCandidateJson(
            StringBuilder builder,
            string propertyName,
            ForgeCandidate candidate,
            bool trailingComma)
        {
            builder.Append($"  \"{propertyName}\": ");
            AppendCandidateObject(builder, candidate);
            builder.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static void AppendCandidateObject(StringBuilder builder, ForgeCandidate candidate)
        {
            builder.AppendLine("{");
            builder.AppendLine($"    \"id\": \"{Escape(candidate.Id)}\",");
            builder.AppendLine($"    \"name\": \"{Escape(candidate.DesignName)}\",");
            builder.AppendLine($"    \"class\": \"{Escape(candidate.WeaponClass)}\",");
            builder.AppendLine($"    \"source\": \"{Escape(candidate.Source)}\",");
            builder.AppendLine($"    \"estimatedValue\": {candidate.EstimatedValue},");
            builder.AppendLine($"    \"estimatedMaterialCost\": {candidate.EstimatedMaterialCost},");
            builder.AppendLine($"    \"rareMaterialPenalty\": {candidate.RareMaterialPenalty},");
            builder.AppendLine($"    \"netProfit\": {candidate.EstimatedNetProfit},");
            builder.AppendLine($"    \"doctrineScore\": {candidate.DoctrineScore},");
            builder.AppendLine($"    \"finalScore\": {candidate.FinalScore},");
            builder.AppendLine($"    \"reason\": \"{Escape(candidate.Reason)}\"");
            builder.Append("  }");
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private sealed class CandidateResolution
        {
            public IReadOnlyList<ForgeCandidate> Candidates { get; set; } = Array.Empty<ForgeCandidate>();
            public ForgeCandidateSourceKind SourceKind { get; set; }
            public string SourceLabel { get; set; }
            public ForgeCandidateSourceStatus SourceStatus { get; set; }
            public bool FallbackUsed { get; set; }
            public string Detail { get; set; }
        }
    }
}
