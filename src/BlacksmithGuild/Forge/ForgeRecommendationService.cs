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
        public const string ProbeForgeRecipesCommand = ForgeRecipeProbeService.ProbeForgeRecipesCommand;

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
            InGameNotice.Info(ModDisplay.CompactLine("Forge", $"candidate source set to {kind}."));
            return true;
        }

        public static bool SetActiveDoctrine(ForgeDoctrine doctrine)
        {
            _activeDoctrine = doctrine;
            DebugLogger.Test($"[TBG FORGE] Doctrine set to {doctrine}.", showInGame: false);
            InGameNotice.Info(ModDisplay.CompactLine("Forge", $"doctrine set to {doctrine}."));
            return true;
        }

        public static bool ShowCandidateSource()
        {
            InGameNotice.Info(ModDisplay.CompactLine("Forge", $"requested source={_requestedSourceKind}"));
            return true;
        }

        public static bool ShowDoctrine()
        {
            InGameNotice.Info(ModDisplay.CompactLine("Forge", $"active doctrine={_activeDoctrine}"));
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
                var mapMeta = ForgeRealCandidateMapper.LastResult;

                _cachedReport = new ForgeRecommendationReport
                {
                    GeneratedUtc = DateTime.UtcNow.ToString("o"),
                    Source = resolution.SourceLabel,
                    SourceKind = resolution.SourceKind.ToString(),
                    SourceStatus = resolution.SourceStatus.ToString(),
                    FallbackUsed = resolution.FallbackUsed,
                    ResolutionDetail = resolution.Detail,
                    CandidateCount = resolution.Candidates.Count,
                    Doctrine = doctrine.ToString(),
                    EconomicsMode = resolution.FallbackUsed ? null : mapMeta?.EconomicsMode,
                    TemplateCount = resolution.FallbackUsed ? 0 : mapMeta?.TemplateCount ?? 0,
                    MappedCount = resolution.FallbackUsed ? 0 : mapMeta?.MappedCount ?? 0,
                    TopCandidate = ranked.FirstOrDefault(),
                    Ranked = ranked
                };

                PopulateAdvisoryFields(_cachedReport);

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
            if (_summary.FallbackUsed && !string.IsNullOrEmpty(_summary.ResolutionDetail))
            {
                report.Line("realDetail", _summary.ResolutionDetail);
            }
            if (!string.IsNullOrEmpty(_summary.EconomicsMode))
            {
                report.Line("economicsMode", _summary.EconomicsMode);
                report.Line("templateCount", _summary.TemplateCount.ToString());
                report.Line("mappedCount", _summary.MappedCount.ToString());
            }
            report.Line("ranked", _summary.RankedCount.ToString());
            report.Line("json", _summary.ReportPath);
        }

        public static string BuildCompactSummaryLine()
        {
            if (!_summaryRecorded || !_summary.HasRankings)
            {
                return null;
            }

            return ModDisplay.CompactLine(
                "Forge",
                $"top={_summary.TopCandidateName} score={_summary.TopFinalScore:0} doctrine={_summary.Doctrine} source={_summary.Source}");
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
                ResolutionDetail = report.ResolutionDetail,
                Doctrine = report.Doctrine,
                EconomicsMode = report.EconomicsMode,
                TemplateCount = report.TemplateCount,
                MappedCount = report.MappedCount,
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
            if (_cachedReport.FallbackUsed && !string.IsNullOrEmpty(_cachedReport.ResolutionDetail))
            {
                report.Line("realDetail", _cachedReport.ResolutionDetail);
            }
            if (!string.IsNullOrEmpty(_cachedReport.EconomicsMode))
            {
                report.Line("economicsMode", _cachedReport.EconomicsMode);
                report.Line("templateCount", _cachedReport.TemplateCount.ToString());
                report.Line("mappedCount", _cachedReport.MappedCount.ToString());
            }
            var honesty = _cachedReport.SourceHonesty
                ?? ForgeAdvisoryPlanner.BuildSourceHonesty(_requestedSourceKind, _cachedReport);
            report.Verdict(honesty.Verdict, honesty.VerdictMessage);

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

            AdvisoryReportSections.EmitSourceHonesty(report, _cachedReport.SourceHonesty);
            AdvisoryReportSections.EmitMaterialGaps(report, _cachedReport.MaterialGaps);
            AdvisoryReportSections.EmitActionPlan(report, _cachedReport.ActionPlan);
            AdvisoryReportSections.EmitCraftNext(
                report,
                ForgeAdvisoryPlanner.BuildCraftNextRows(_cachedReport.Ranked));

            if (top != null)
            {
                report.SummaryLine(
                    ModDisplay.CompactLine(
                        "Forge",
                        $"top={top.DesignName} score={top.FinalScore:0} doctrine={_cachedReport.Doctrine} source={_cachedReport.Source}"));
            }

            report.EndReport(emitInGame: string.Equals(source, RankForgeCandidatesCommand, StringComparison.Ordinal), emitToFile: true);
        }

        private static void PopulateAdvisoryFields(ForgeRecommendationReport report)
        {
            report.SourceHonesty = ForgeAdvisoryPlanner.BuildSourceHonesty(_requestedSourceKind, report);
            report.MaterialGaps = ForgeAdvisoryPlanner.BuildMaterialGaps(report.TopCandidate);
            var isStub = string.Equals(
                report.Source,
                StubForgeCandidateSource.SourceName,
                StringComparison.OrdinalIgnoreCase);
            report.ActionPlan = ForgeAdvisoryPlanner.BuildActionPlan(
                report.TopCandidate,
                report.MaterialGaps,
                isStub);
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
            builder.AppendLine(
                $"  \"realDetail\": {(string.IsNullOrEmpty(report.ResolutionDetail) ? "null" : $"\"{Escape(report.ResolutionDetail)}\"")},");
            builder.AppendLine($"  \"candidateCount\": {report.CandidateCount},");
            builder.AppendLine($"  \"doctrine\": \"{Escape(report.Doctrine)}\",");
            builder.AppendLine(
                $"  \"economicsMode\": {(string.IsNullOrEmpty(report.EconomicsMode) ? "null" : $"\"{Escape(report.EconomicsMode)}\"")},");
            builder.AppendLine($"  \"templateCount\": {report.TemplateCount},");
            builder.AppendLine($"  \"mappedCount\": {report.MappedCount},");

            AppendSourceHonestyJson(builder, report.SourceHonesty);
            AppendMaterialGapsJson(builder, report.MaterialGaps);
            AppendActionPlanJson(builder, report.ActionPlan);

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

        private static void AppendSourceHonestyJson(StringBuilder builder, SourceHonestyInfo info)
        {
            if (info == null)
            {
                builder.AppendLine("  \"sourceHonesty\": null,");
                return;
            }

            builder.AppendLine("  \"sourceHonesty\": {");
            builder.AppendLine($"    \"requested\": \"{Escape(info.Requested)}\",");
            builder.AppendLine($"    \"resolved\": \"{Escape(info.Resolved)}\",");
            builder.AppendLine($"    \"fallbackUsed\": {info.FallbackUsed.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"verdict\": \"{Escape(info.Verdict.ToString())}\",");
            builder.AppendLine($"    \"message\": \"{Escape(info.VerdictMessage)}\"");
            builder.AppendLine("  },");
        }

        private static void AppendMaterialGapsJson(StringBuilder builder, List<MaterialGapRow> gaps)
        {
            builder.AppendLine("  \"materialGaps\": [");
            if (gaps != null)
            {
                for (var i = 0; i < gaps.Count; i++)
                {
                    var gap = gaps[i];
                    builder.AppendLine("    {");
                    builder.AppendLine($"      \"itemId\": {(string.IsNullOrEmpty(gap.ItemId) ? "null" : $"\"{Escape(gap.ItemId)}\"")},");
                    builder.AppendLine($"      \"itemName\": \"{Escape(gap.ItemName)}\",");
                    builder.AppendLine($"      \"need\": {gap.Need},");
                    builder.AppendLine($"      \"have\": {gap.Have},");
                    builder.AppendLine($"      \"buyTown\": {(string.IsNullOrEmpty(gap.BuyTown) ? "null" : $"\"{Escape(gap.BuyTown)}\"")},");
                    builder.AppendLine($"      \"buyPrice\": {(gap.BuyPrice.HasValue ? gap.BuyPrice.Value.ToString() : "null")},");
                    builder.AppendLine($"      \"stock\": {(gap.Stock.HasValue ? gap.Stock.Value.ToString() : "null")},");
                    builder.AppendLine($"      \"buyHint\": {(string.IsNullOrEmpty(gap.BuyHint) ? "null" : $"\"{Escape(gap.BuyHint)}\"")}");
                    builder.Append(i < gaps.Count - 1 ? "    }," : "    }");
                    builder.AppendLine();
                }
            }

            builder.AppendLine("  ],");
        }

        private static void AppendActionPlanJson(StringBuilder builder, List<ActionPlanStep> steps)
        {
            builder.AppendLine("  \"actionPlan\": [");
            if (steps != null)
            {
                for (var i = 0; i < steps.Count; i++)
                {
                    var step = steps[i];
                    builder.AppendLine("    {");
                    builder.AppendLine($"      \"step\": {step.Step},");
                    builder.AppendLine($"      \"text\": \"{Escape(step.Text)}\"");
                    builder.Append(i < steps.Count - 1 ? "    }," : "    }");
                    builder.AppendLine();
                }
            }

            builder.AppendLine("  ],");
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
