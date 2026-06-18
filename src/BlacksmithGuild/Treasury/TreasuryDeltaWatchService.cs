using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.Reporting;
using TaleWorlds.CampaignSystem;
using TaleWorlds.Library;

namespace BlacksmithGuild.Treasury
{
    public static class TreasuryDeltaWatchService
    {
        public const string TreasurySnapshotNowCommand = "TreasurySnapshotNow";

        private const int MaxRecentDeltas = 50;
        private const int MaxLatestSnapshotsInReport = 10;
        private const int SuspiciousThreshold = 50_000;
        private const int CriticalThreshold = 150_000;

        private static readonly string ReportPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_TreasuryWatch.json");

        private static readonly Dictionary<string, TreasurySnapshot> PriorSnapshots =
            new Dictionary<string, TreasurySnapshot>(StringComparer.OrdinalIgnoreCase);

        private static readonly List<TreasuryDelta> RecentDeltas = new List<TreasuryDelta>();
        private static TreasuryWatchSummary _summary = new TreasuryWatchSummary { Enabled = true };
        private static TreasuryWatchReport _cachedReport = new TreasuryWatchReport();
        private static bool _initialized;
        private static bool _loggedCampaignDaySource;
        private static bool _pendingSnapshot;
        private static string _pendingSnapshotReason;
        private static int _snapshotCount;
        private static int _snapshotGeneration;

        public static TreasuryWatchSummary Summary => _summary;

        public static void OnCampaignMapReady()
        {
            if (_initialized)
            {
                return;
            }

            _initialized = true;
            _summary.Enabled = true;
            _summary.ReportPath = "BlacksmithGuild_TreasuryWatch.json";
            DebugLogger.Test("[TBG TREASURY] Treasury Delta Watch initialized.", showInGame: false);
            ScheduleSnapshot("map-ready");
        }

        public static void OnDailyTick()
        {
            if (!_summary.Enabled || Campaign.Current == null)
            {
                return;
            }

            ScheduleSnapshot("daily-tick");
        }

        public static void ProcessPendingSnapshot()
        {
            if (!_pendingSnapshot || Campaign.Current == null)
            {
                return;
            }

            if (!GameSessionState.IsCampaignMapReady)
            {
                return;
            }

            var reason = _pendingSnapshotReason ?? "deferred";
            _pendingSnapshot = false;
            _pendingSnapshotReason = null;
            TryTakeSnapshot(reason);
        }

        public static bool RunSnapshotNow()
        {
            if (Campaign.Current == null || Hero.MainHero == null)
            {
                DebugLogger.Test("[TBG TREASURY] TreasurySnapshotNow blocked: campaign not ready.", showInGame: false);
                CertificationReporter.WriteTreasuryRetestReport(
                    snapshotSucceeded: false,
                    snapshotGeneration: _summary.SnapshotGeneration,
                    deltaCount: _summary.DeltaCount,
                    suspiciousCount: _summary.SuspiciousCount,
                    criticalCount: _summary.CriticalCount);
                return false;
            }

            var generationBefore = _snapshotGeneration;
            TryTakeSnapshot("manual");
            WriteTreasuryReport("TreasurySnapshotNow");
            CertificationReporter.WriteTreasuryRetestReport(
                snapshotSucceeded: _snapshotGeneration > generationBefore || _snapshotCount > 0,
                snapshotGeneration: _summary.SnapshotGeneration,
                deltaCount: _summary.DeltaCount,
                suspiciousCount: _summary.SuspiciousCount,
                criticalCount: _summary.CriticalCount);
            return true;
        }

        public static void ScheduleSnapshot(string reason)
        {
            _pendingSnapshot = true;
            _pendingSnapshotReason = reason;
        }

        public static void AppendToReport(ReportFormatter report)
        {
            report.Section("Treasury");
            if (!_summary.Enabled || _snapshotCount == 0)
            {
                report.Line("watch", "inactive (no snapshots yet)");
                return;
            }

            var severity = string.IsNullOrEmpty(_summary.MaxSeverity) ? "Observed" : _summary.MaxSeverity;
            report.Line("generation", _summary.SnapshotGeneration.ToString());
            report.Line("day", _summary.LastSnapshotDay.ToString());
            report.Line("kingdomsTracked", _summary.ActorsTracked.ToString());
            report.Line("maxDelta", _summary.MaxAbsDelta.ToString("N0"));
            report.Line("severity", severity);

            AppendDeltaVerdicts(report);

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_TreasuryWatch.json");
        }

        public static void WriteTreasuryReport(string source)
        {
            var report = ReportFormatter.BeginReport("TREASURY WATCH", source, "treasury-watch");

            report.Section("Snapshot");
            report.Line("generation", _summary.SnapshotGeneration.ToString());
            report.Line("day", _summary.LastSnapshotDay.ToString());
            report.Line("kingdomsTracked", _summary.ActorsTracked.ToString());
            report.Line("snapshotCount", _summary.SnapshotCount.ToString());

            report.Section("Deltas");
            AppendDeltaVerdicts(report);

            report.Section("Evidence");
            report.Line("json", "BlacksmithGuild_TreasuryWatch.json");

            var severity = string.IsNullOrEmpty(_summary.MaxSeverity) ? "Observed" : _summary.MaxSeverity;
            report.SummaryLine(
                $"treasury: gen={_summary.SnapshotGeneration} entities={_summary.ActorsTracked} severity={severity}");

            report.EndReport(emitInGame: source == TreasurySnapshotNowCommand, emitToFile: true);
        }

        private static void AppendDeltaVerdicts(ReportFormatter report)
        {
            if (_snapshotCount == 0)
            {
                report.Verdict(ReportVerdict.Info, "No snapshots taken yet");
                return;
            }

            if (RecentDeltas.Count == 0)
            {
                report.Verdict(ReportVerdict.Warn, "No treasury deltas detected");
                return;
            }

            var shown = 0;
            foreach (var delta in RecentDeltas.OrderByDescending(d => Math.Abs(d.Delta)))
            {
                if (shown >= 5)
                {
                    break;
                }

                var sign = delta.Delta >= 0 ? "+" : "";
                var label = FormatDeltaLabel(delta);
                var verdict = MapClassificationToVerdict(delta.Classification);
                report.Verdict(verdict, $"{delta.ActorName}: {sign}{delta.Delta:N0} {label}");
                shown++;
            }

            if (_summary.CriticalCount > 0)
            {
                report.Verdict(ReportVerdict.Warn, $"{_summary.CriticalCount} critical anomal{(_summary.CriticalCount == 1 ? "y" : "ies")} tracked");
            }
            else if (_summary.SuspiciousCount > 0)
            {
                report.Verdict(ReportVerdict.Warn, $"{_summary.SuspiciousCount} suspicious delta(s) tracked");
            }
            else
            {
                report.Verdict(ReportVerdict.Pass, "No critical anomalies");
            }
        }

        private static string FormatDeltaLabel(TreasuryDelta delta)
        {
            if (delta.Classification == TreasurySeverity.Critical.ToString())
            {
                return "critical anomaly";
            }

            if (delta.Classification == TreasurySeverity.Suspicious.ToString())
            {
                return "suspicious";
            }

            return "observed";
        }

        private static ReportVerdict MapClassificationToVerdict(string classification)
        {
            if (classification == TreasurySeverity.Critical.ToString())
            {
                return ReportVerdict.Warn;
            }

            if (classification == TreasurySeverity.Suspicious.ToString())
            {
                return ReportVerdict.Warn;
            }

            return ReportVerdict.Info;
        }

        private static void TryTakeSnapshot(string reason)
        {
            try
            {
                if (Campaign.Current == null || Hero.MainHero == null)
                {
                    return;
                }

                var currentDay = GetCampaignDay(out var daySource);
                LogCampaignDaySourceOnce(daySource);

                var snapshots = CollectSnapshots(currentDay);
                if (snapshots.Count == 0)
                {
                    _cachedReport.Warnings.Add($"No treasury actors readable at day {currentDay} ({reason}).");
                    WriteReport(currentDay);
                    return;
                }

                var newDeltas = new List<TreasuryDelta>();
                foreach (var snap in snapshots)
                {
                    if (PriorSnapshots.TryGetValue(snap.ActorId, out var prior))
                    {
                        var delta = snap.Gold - prior.Gold;
                        if (delta != 0)
                        {
                            var record = BuildDelta(prior, snap, delta);
                            newDeltas.Add(record);
                            RecentDeltas.Add(record);
                            MaybeNotify(record);
                        }
                    }

                    PriorSnapshots[snap.ActorId] = snap;
                }

                TrimRecentDeltas();
                _snapshotCount++;
                _snapshotGeneration++;
                UpdateSummary(snapshots, currentDay, newDeltas);
                WriteReport(currentDay, snapshots);
                ForgeStatus.RecordTreasuryWatch(_summary);

                DebugLogger.Test(
                    $"[TBG TREASURY] Snapshot #{_snapshotCount} gen={_snapshotGeneration} day={currentDay} actors={snapshots.Count} newDeltas={newDeltas.Count} ({reason})",
                    showInGame: false
                );
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG TREASURY] Snapshot failed: {ex.Message}", showInGame: false);
                _cachedReport.Warnings.Add(ex.Message);
            }
        }

        private static void LogCampaignDaySourceOnce(string daySource)
        {
            if (_loggedCampaignDaySource)
            {
                return;
            }

            _loggedCampaignDaySource = true;
            DebugLogger.Test($"[TBG TREASURY] Campaign day source: {daySource}", showInGame: false);
        }

        private static List<TreasurySnapshot> CollectSnapshots(int currentDay)
        {
            var results = new List<TreasurySnapshot>();
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            TryAddClanSnapshot(results, seen, Clan.PlayerClan, currentDay);

            foreach (var kingdom in Kingdom.All)
            {
                if (kingdom == null || kingdom.IsEliminated)
                {
                    continue;
                }

                var rulerClan = kingdom.RulingClan;
                if (rulerClan == null)
                {
                    continue;
                }

                var gold = ReadClanGold(rulerClan);
                if (gold < 0)
                {
                    continue;
                }

                var actorId = "kingdom:" + kingdom.StringId;
                if (!seen.Add(actorId))
                {
                    continue;
                }

                results.Add(new TreasurySnapshot
                {
                    ActorId = actorId,
                    ActorName = kingdom.StringId,
                    ActorType = "Kingdom",
                    Gold = gold,
                    Day = currentDay,
                    WarStateAgainstPlayer = GetWarState(kingdom)
                });
            }

            foreach (var clan in Clan.All)
            {
                if (clan == null || clan.IsBanditFaction || clan.IsEliminated)
                {
                    continue;
                }

                if (clan == Clan.PlayerClan)
                {
                    continue;
                }

                if (clan.Tier < 3)
                {
                    continue;
                }

                TryAddClanSnapshot(results, seen, clan, currentDay);
            }

            return results;
        }

        private static void TryAddClanSnapshot(
            List<TreasurySnapshot> results,
            HashSet<string> seen,
            Clan clan,
            int currentDay)
        {
            if (clan == null)
            {
                return;
            }

            var actorId = "clan:" + clan.StringId;
            if (!seen.Add(actorId))
            {
                return;
            }

            var gold = ReadClanGold(clan);
            if (gold < 0)
            {
                return;
            }

            results.Add(new TreasurySnapshot
            {
                ActorId = actorId,
                ActorName = clan.StringId,
                ActorType = clan == Clan.PlayerClan ? "PlayerClan" : "Clan",
                Gold = gold,
                Day = currentDay,
                WarStateAgainstPlayer = GetWarState(clan.Kingdom)
            });
        }

        private static int ReadClanGold(Clan clan)
        {
            try
            {
                return clan.Gold;
            }
            catch
            {
            }

            try
            {
                return clan.Leader?.Gold ?? -1;
            }
            catch
            {
                return -1;
            }
        }

        private static string GetWarState(Kingdom kingdom)
        {
            if (kingdom == null)
            {
                return "none";
            }

            try
            {
                var playerKingdom = Hero.MainHero?.Clan?.Kingdom;
                if (playerKingdom == null)
                {
                    return "unknown";
                }

                if (playerKingdom == kingdom)
                {
                    return "player";
                }

                var stance = playerKingdom.GetStanceWith(kingdom);
                if (stance == null)
                {
                    return "neutral";
                }

                if (stance.IsAtWar)
                {
                    return "atWar";
                }

                return "atPeace";
            }
            catch
            {
                return "unknown";
            }
        }

        private static TreasuryDelta BuildDelta(TreasurySnapshot prior, TreasurySnapshot current, int delta)
        {
            var absDelta = Math.Abs(delta);
            var score = ScoreDelta(absDelta, current.WarStateAgainstPlayer, delta);
            var classification = Classify(absDelta, score);

            return new TreasuryDelta
            {
                ActorId = current.ActorId,
                ActorName = current.ActorName,
                ActorType = current.ActorType,
                PreviousGold = prior.Gold,
                CurrentGold = current.Gold,
                Delta = delta,
                PreviousDay = prior.Day,
                CurrentDay = current.Day,
                Classification = classification,
                SuspicionScore = score,
                Explanation = BuildExplanation(classification, current.WarStateAgainstPlayer, absDelta)
            };
        }

        private static int ScoreDelta(int absDelta, string warState, int delta)
        {
            var score = 0;
            if (absDelta >= 50_000)
            {
                score += 20;
            }

            if (absDelta >= 100_000)
            {
                score += 20;
            }

            if (absDelta >= 250_000)
            {
                score += 30;
            }

            if (delta > 0 && warState == "atWar")
            {
                score += 15;
            }

            return score;
        }

        private static string Classify(int absDelta, int score)
        {
            if (absDelta >= CriticalThreshold || score >= 75)
            {
                return TreasurySeverity.Critical.ToString();
            }

            if (absDelta >= SuspiciousThreshold || score >= 50)
            {
                return TreasurySeverity.Suspicious.ToString();
            }

            return TreasurySeverity.Observed.ToString();
        }

        private static string BuildExplanation(string classification, string warState, int absDelta)
        {
            if (classification == TreasurySeverity.Observed.ToString())
            {
                return "Routine treasury movement within observed thresholds.";
            }

            if (warState == "atWar" && absDelta >= SuspiciousThreshold)
            {
                return "Large treasury change for a faction at war with the player; no matching event recorded in MVP.";
            }

            return "Treasury delta exceeded MVP suspicion thresholds; no matching event recorded.";
        }

        private static void MaybeNotify(TreasuryDelta delta)
        {
            if (delta.Classification == TreasurySeverity.Observed.ToString())
            {
                return;
            }

            var sign = delta.Delta >= 0 ? "+" : "";
            var label = delta.Classification == TreasurySeverity.Critical.ToString()
                ? "Critical"
                : "Suspicious";

            InGameNotice.Warn(
                $"TBG TREASURY: {label} treasury delta observed: {delta.ActorName} {sign}{delta.Delta:N0} gold"
            );
        }

        private static void TrimRecentDeltas()
        {
            while (RecentDeltas.Count > MaxRecentDeltas)
            {
                RecentDeltas.RemoveAt(0);
            }
        }

        private static void UpdateSummary(
            List<TreasurySnapshot> snapshots,
            int currentDay,
            List<TreasuryDelta> newDeltas)
        {
            _summary.Enabled = true;
            _summary.LastSnapshotDay = currentDay;
            _summary.ActorsTracked = snapshots.Count;
            _summary.SnapshotCount = _snapshotCount;
            _summary.SnapshotGeneration = _snapshotGeneration;
            _summary.DeltaCount = RecentDeltas.Count;
            _summary.ObservedCount = 0;
            _summary.SuspiciousCount = 0;
            _summary.CriticalCount = 0;
            _summary.MaxAbsDelta = 0;
            _summary.MaxSeverity = TreasurySeverity.Observed.ToString();
            _summary.ReportPath = "BlacksmithGuild_TreasuryWatch.json";

            foreach (var delta in RecentDeltas)
            {
                var abs = Math.Abs(delta.Delta);
                if (abs > _summary.MaxAbsDelta)
                {
                    _summary.MaxAbsDelta = abs;
                }

                switch (delta.Classification)
                {
                    case "Suspicious":
                        _summary.SuspiciousCount++;
                        if (_summary.MaxSeverity != TreasurySeverity.Critical.ToString())
                        {
                            _summary.MaxSeverity = TreasurySeverity.Suspicious.ToString();
                        }

                        break;
                    case "Critical":
                        _summary.CriticalCount++;
                        _summary.MaxSeverity = TreasurySeverity.Critical.ToString();
                        _summary.LastCriticalActor = delta.ActorName;
                        _summary.LastCriticalDelta = delta.Delta;
                        break;
                    default:
                        _summary.ObservedCount++;
                        break;
                }
            }

            foreach (var delta in newDeltas)
            {
                if (delta.Classification == TreasurySeverity.Critical.ToString())
                {
                    _summary.LastCriticalActor = delta.ActorName;
                    _summary.LastCriticalDelta = delta.Delta;
                }
            }
        }

        private static void WriteReport(int currentDay, List<TreasurySnapshot> latestSnapshots = null)
        {
            _cachedReport.GeneratedUtc = DateTime.UtcNow.ToString("o");
            _cachedReport.CampaignDay = currentDay;
            _cachedReport.WatchEnabled = _summary.Enabled;
            _cachedReport.LastSnapshotDay = _summary.LastSnapshotDay;
            _cachedReport.ActorsTracked = _summary.ActorsTracked;
            _cachedReport.SnapshotCount = _summary.SnapshotCount;
            _cachedReport.SnapshotGeneration = _summary.SnapshotGeneration;
            _cachedReport.Summary = _summary;
            _cachedReport.RecentDeltas = new List<TreasuryDelta>(RecentDeltas);
            _cachedReport.LatestSnapshots = latestSnapshots ?? _cachedReport.LatestSnapshots;

            try
            {
                File.WriteAllText(ReportPath, SerializeReport(_cachedReport));
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG TREASURY] Failed to write report: {ex.Message}", showInGame: false);
            }
        }

        private static string SerializeReport(TreasuryWatchReport report)
        {
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"generatedUtc\": \"{Escape(report.GeneratedUtc)}\",");
            builder.AppendLine($"  \"campaignDay\": {report.CampaignDay},");
            builder.AppendLine($"  \"snapshotGeneration\": {report.SnapshotGeneration},");
            builder.AppendLine($"  \"watchEnabled\": {report.WatchEnabled.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"lastSnapshotDay\": {report.LastSnapshotDay},");
            builder.AppendLine($"  \"actorsTracked\": {report.ActorsTracked},");
            builder.AppendLine($"  \"snapshotCount\": {report.SnapshotCount},");
            builder.AppendLine("  \"summary\": {");
            builder.AppendLine($"    \"enabled\": {report.Summary.Enabled.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"lastSnapshotDay\": {report.Summary.LastSnapshotDay},");
            builder.AppendLine($"    \"actorsTracked\": {report.Summary.ActorsTracked},");
            builder.AppendLine($"    \"snapshotCount\": {report.Summary.SnapshotCount},");
            builder.AppendLine($"    \"snapshotGeneration\": {report.Summary.SnapshotGeneration},");
            builder.AppendLine($"    \"deltaCount\": {report.Summary.DeltaCount},");
            builder.AppendLine($"    \"observedCount\": {report.Summary.ObservedCount},");
            builder.AppendLine($"    \"suspiciousCount\": {report.Summary.SuspiciousCount},");
            builder.AppendLine($"    \"criticalCount\": {report.Summary.CriticalCount},");
            builder.AppendLine($"    \"maxAbsDelta\": {report.Summary.MaxAbsDelta},");
            builder.AppendLine($"    \"maxSeverity\": \"{Escape(report.Summary.MaxSeverity)}\",");
            builder.AppendLine($"    \"lastCriticalActor\": \"{Escape(report.Summary.LastCriticalActor ?? "")}\",");
            builder.AppendLine($"    \"lastCriticalDelta\": {report.Summary.LastCriticalDelta},");
            builder.AppendLine($"    \"reportPath\": \"{Escape(report.Summary.ReportPath ?? "")}\"");
            builder.AppendLine("  },");
            builder.AppendLine("  \"latestSnapshots\": [");

            var latest = report.LatestSnapshots ?? new List<TreasurySnapshot>();
            var capped = latest.Take(MaxLatestSnapshotsInReport).ToList();
            for (var i = 0; i < capped.Count; i++)
            {
                var snap = capped[i];
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                builder.AppendLine("    {");
                builder.AppendLine($"      \"actorId\": \"{Escape(snap.ActorId)}\",");
                builder.AppendLine($"      \"actorName\": \"{Escape(snap.ActorName)}\",");
                builder.AppendLine($"      \"actorType\": \"{Escape(snap.ActorType)}\",");
                builder.AppendLine($"      \"gold\": {snap.Gold},");
                builder.AppendLine($"      \"day\": {snap.Day},");
                builder.AppendLine($"      \"warStateAgainstPlayer\": \"{Escape(snap.WarStateAgainstPlayer ?? "")}\"");
                builder.Append("    }");
            }

            builder.AppendLine();
            builder.AppendLine("  ],");
            builder.AppendLine("  \"recentDeltas\": [");

            for (var i = 0; i < report.RecentDeltas.Count; i++)
            {
                var delta = report.RecentDeltas[i];
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                builder.AppendLine("    {");
                builder.AppendLine($"      \"actorId\": \"{Escape(delta.ActorId)}\",");
                builder.AppendLine($"      \"actorName\": \"{Escape(delta.ActorName)}\",");
                builder.AppendLine($"      \"actorType\": \"{Escape(delta.ActorType)}\",");
                builder.AppendLine($"      \"previousGold\": {delta.PreviousGold},");
                builder.AppendLine($"      \"currentGold\": {delta.CurrentGold},");
                builder.AppendLine($"      \"delta\": {delta.Delta},");
                builder.AppendLine($"      \"previousDay\": {delta.PreviousDay},");
                builder.AppendLine($"      \"currentDay\": {delta.CurrentDay},");
                builder.AppendLine($"      \"classification\": \"{Escape(delta.Classification)}\",");
                builder.AppendLine($"      \"suspicionScore\": {delta.SuspicionScore},");
                builder.AppendLine($"      \"explanation\": \"{Escape(delta.Explanation)}\"");
                builder.Append("    }");
            }

            builder.AppendLine();
            builder.AppendLine("  ],");

            builder.AppendLine("  \"warnings\": [");
            for (var i = 0; i < report.Warnings.Count; i++)
            {
                if (i > 0)
                {
                    builder.AppendLine(",");
                }

                builder.Append($"    \"{Escape(report.Warnings[i])}\"");
            }

            builder.AppendLine();
            builder.AppendLine("  ]");
            builder.AppendLine("}");
            return builder.ToString();
        }

        private static int GetCampaignDay(out string source)
        {
            source = "unknown";

            try
            {
                var days = (int)CampaignTime.Now.ToDays;
                source = "CampaignTime.Now.ToDays";
                return days;
            }
            catch
            {
            }

            try
            {
                if (Campaign.Current != null)
                {
                    var days = (int)CampaignTime.Now.ToYears * 360 + (int)CampaignTime.Now.GetDayOfSeason;
                    source = "CampaignTime.Now.GetDayOfSeason";
                    return days;
                }
            }
            catch
            {
            }

            source = "fallback-zero";
            return 0;
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
