using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using BlacksmithGuild.ClanIntel;
using BlacksmithGuild.DevTools;
using BlacksmithGuild.DevTools.AutoCharacterBuild;
using BlacksmithGuild.DevTools.QuickStart;
using BlacksmithGuild.DevTools.Assistive;
using BlacksmithGuild.DevTools.Reporting;
using BlacksmithGuild.Forge;
using BlacksmithGuild.Market;
using BlacksmithGuild.Treasury;
using TaleWorlds.Library;

namespace BlacksmithGuild
{
    public static class ForgeStatus
    {
        private static readonly string StatusPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Status.json");

        private static readonly string ForgeLogPath =
            Path.Combine(BasePath.Name, "BlacksmithGuild_Forge.log");

        private static readonly Dictionary<string, string> TestStatuses =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        private static readonly Dictionary<string, string> TestMessages =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        private static bool _modLoaded = true;
        private static bool _campaignReady;
        private static bool _mainHeroReady;
        private static string _preflightVerdict;
        private static string _preflightReason;
        private static string _lastCommand;
        private static string _lastCommandSource;
        private static string _lastCommandResult;
        private static string _lastCommandDetail;
        private static int _lastCommandSequence = -1;
        private static DateTime? _lastCommandTime;
        private static GoldTestSnapshot _goldTest;
        private static ProgressionTestSnapshot _progressionTest;
        private static TreasuryWatchSummary _treasuryWatch;
        private static bool _treasuryWatchRecorded;
        private static ForgeRecommendationSummary _forgeRecommendations;
        private static bool _forgeRecommendationsRecorded;
        private static ForgeRecipeProbeSummary _recipeProbe;
        private static bool _recipeProbeRecorded;
        private static AutoCharacterBuildSummary _autoCharacterBuild;
        private static bool _autoCharacterBuildRecorded;
        private static SessionPhase _sessionPhase = SessionPhase.ModuleOnly;
        private static bool _sessionTimePaused;

        private struct GoldTestSnapshot
        {
            public bool Ran;
            public bool Passed;
            public int GoldBefore;
            public int GoldAfter;
            public int Delta;
        }

        private struct ProgressionTestSnapshot
        {
            public bool Ran;
            public bool Passed;
            public float SmithingXpBefore;
            public float SmithingXpAfter;
            public int SmithingFocusBefore;
            public int SmithingFocusAfter;
            public int EnduranceBefore;
            public int EnduranceAfter;
        }

        public static void Log(string message)
        {
            try
            {
                File.AppendAllText(
                    ForgeLogPath,
                    $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {message}{Environment.NewLine}"
                );
            }
            catch
            {
            }
        }

        public static void SetModLoaded(bool loaded)
        {
            _modLoaded = loaded;
            Flush();
        }

        public static void SetStep(string name, string status, string message = null)
        {
            Log($"STEP {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            Flush(overall: status == "FAIL" ? "FAIL" : null);
        }

        public static void SetPreflight(string verdict, string reason)
        {
            _preflightVerdict = verdict;
            _preflightReason = reason;
            Log($"PREFLIGHT {verdict} - {reason}");

            if (string.Equals(verdict, "Pass", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnPreflightPass();
            }
            else if (string.Equals(verdict, "Fail", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnPreflightFail(reason);
            }

            Flush(overall: verdict == "Fail" ? "FAIL" : null);
        }

        public static void SetTest(string name, string status, string message = null)
        {
            TestStatuses[name] = status;
            if (!string.IsNullOrEmpty(message))
            {
                TestMessages[name] = message;
            }

            if (string.Equals(name, "forge_lit", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(status, "PASS", StringComparison.OrdinalIgnoreCase))
            {
                CertificationTracker.OnForgeLit();
            }

            Log($"TEST {name} = {status}{(string.IsNullOrEmpty(message) ? "" : " - " + message)}");
            try
            {
                Flush(overall: status == "FAIL" ? "FAIL" : null);
            }
            catch
            {
            }
        }

        public static void RecordGoldTest(bool passed, int goldBefore, int goldAfter, int delta)
        {
            _goldTest = new GoldTestSnapshot
            {
                Ran = true,
                Passed = passed,
                GoldBefore = goldBefore,
                GoldAfter = goldAfter,
                Delta = delta
            };
            Flush();
        }

        public static void RecordProgressionTest(
            bool passed,
            float smithingXpBefore,
            float smithingXpAfter,
            int smithingFocusBefore,
            int smithingFocusAfter,
            int enduranceBefore,
            int enduranceAfter)
        {
            _progressionTest = new ProgressionTestSnapshot
            {
                Ran = true,
                Passed = passed,
                SmithingXpBefore = smithingXpBefore,
                SmithingXpAfter = smithingXpAfter,
                SmithingFocusBefore = smithingFocusBefore,
                SmithingFocusAfter = smithingFocusAfter,
                EnduranceBefore = enduranceBefore,
                EnduranceAfter = enduranceAfter
            };
            Flush();
        }

        public static void RecordTreasuryWatch(TreasuryWatchSummary summary)
        {
            _treasuryWatch = summary;
            _treasuryWatchRecorded = true;
            Flush();
        }

        public static void RecordForgeRecommendations(ForgeRecommendationSummary summary)
        {
            _forgeRecommendations = summary;
            _forgeRecommendationsRecorded = summary != null && summary.HasRankings;
            Flush();
        }

        public static void RecordRecipeProbe(ForgeRecipeProbeSummary summary)
        {
            _recipeProbe = summary;
            _recipeProbeRecorded = summary != null && summary.HasProbe;
            Flush();
        }

        public static void RecordAutoCharacterBuild(AutoCharacterBuildSummary summary)
        {
            _autoCharacterBuild = summary;
            _autoCharacterBuildRecorded = summary != null && summary.HasStatus;
            Flush();
        }

        /// <summary>
        /// Read-only verdict card: posts cached summary to the notice log. Does not scan or mutate campaign data.
        /// </summary>
        public static void DisplaySummaryInGame()
        {
            var version = PendingReloadWatcher.LoadedModuleVersion;
            var dllUtc = PendingReloadWatcher.LoadedDllWriteUtcIso;
            var devTools = DevToolsConfig.DevToolsEnabled ? "on" : "off";
            var reload = PendingReloadWatcher.IsReloadBlocked
                ? "blocked"
                : PendingReloadWatcher.IsReloadPending
                    ? "pending"
                    : "clear";
            var preflight = string.IsNullOrEmpty(_preflightVerdict) ? "unknown" : _preflightVerdict;
            var last = string.IsNullOrEmpty(_lastCommand)
                ? "none"
                : $"{_lastCommand} {_lastCommandResult ?? ""}".Trim();

            var certOverall = CertificationTracker.DeriveOverall(_campaignReady, _mainHeroReady);
            var certPassed = CertificationTracker.CountPassed();
            var certRequired = CertificationTracker.RequiredCheckNames.Count;
            var treasuryGen = _treasuryWatchRecorded ? _treasuryWatch.SnapshotGeneration : 0;

            AutoCharacterBuildService.RefreshStatusSnapshot();

            var report = ReportFormatter.BeginReport("FORGE STATUS", "F7", "forge-status");

            report.Section("Session");
            report.Line("phase", _sessionPhase.ToString());
            report.Line("ready", (_campaignReady && _mainHeroReady).ToString().ToLowerInvariant());
            report.Line("devTools", devTools);
            report.Line("preflight", preflight);
            report.Line("reload", reload);
            report.Line("loadedVersion", version);
            report.Line("dllUtc", dllUtc);

            report.Section("Last Command");
            report.Line("command", string.IsNullOrEmpty(_lastCommand) ? "none" : _lastCommand);
            report.Line("source", string.IsNullOrEmpty(_lastCommandSource) ? "none" : _lastCommandSource);
            report.Line("result", string.IsNullOrEmpty(_lastCommandResult) ? "none" : _lastCommandResult);
            if (!string.IsNullOrEmpty(_lastCommandDetail))
            {
                report.Line("detail", _lastCommandDetail);
            }

            if (DevToolsConfig.AutoSkipCharacterCreation)
            {
                report.Section("Quick Start");
                report.Line("phase", CampaignSetupStateTracker.Phase.ToString());
                report.Line("activeState", CampaignSetupStateTracker.ActiveStateName ?? "unknown");
            }

            if (certPassed > 0 || certOverall != "NOT_STARTED")
            {
                report.Section("Certification");
                report.Line("sprint001", $"{certOverall} ({certPassed}/{certRequired})");
                var cert002Overall = Sprint002CertificationTracker.DeriveOverall(_campaignReady, _mainHeroReady);
                var cert002Passed = Sprint002CertificationTracker.CountPassed();
                var cert002Required = Sprint002CertificationTracker.RequiredCheckNames.Count;
                if (cert002Passed > 0 || cert002Overall != "NOT_STARTED")
                {
                    report.Line("sprint002", $"{cert002Overall} ({cert002Passed}/{cert002Required})");
                }
            }

            TreasuryDeltaWatchService.AppendToReport(report);
            ForgeRecommendationService.AppendToReport(report);
            ForgeRecipeProbeService.AppendToReport(report);
            CharacterBuildProvenanceService.AppendToReport(report);
            CharacterDoctrineService.AppendToReport(report);
            AutoCharacterBuildService.AppendToReport(report);
            MarketIntelligenceService.AppendToReport(report);

            if (PendingReloadWatcher.IsReloadBlocked)
            {
                report.Verdict(ReportVerdict.Warn, "Reload blocked — close Bannerlord, run Forge.cmd");
            }
            else if (PendingReloadWatcher.IsReloadPending)
            {
                report.Verdict(ReportVerdict.Warn, "Reload pending — restart Bannerlord");
            }

            report.SummaryLine($"phase: {_sessionPhase} | reload: {reload} | treasury: gen={treasuryGen}");
            if (certPassed > 0 || certOverall != "NOT_STARTED")
            {
                report.SummaryLine($"cert: {certOverall} ({certPassed}/{certRequired})");
            }

            var forgeLine = ForgeRecommendationService.BuildCompactSummaryLine();
            if (!string.IsNullOrEmpty(forgeLine))
            {
                report.SummaryLine(forgeLine);
            }

            var marketLine = MarketIntelligenceService.BuildCompactSummaryLine();
            if (!string.IsNullOrEmpty(marketLine))
            {
                report.SummaryLine(marketLine);
            }

            report.EndReport();

            if (!string.IsNullOrEmpty(forgeLine))
            {
                InGameNotice.Info(forgeLine);
            }

            if (!string.IsNullOrEmpty(marketLine))
            {
                InGameNotice.Info(marketLine);
            }

            DebugLogger.Test("ShowForgeStatus displayed cached summary.", showInGame: false);
        }

        public static void UpdateReadiness(bool campaignReady, bool mainHeroReady)
        {
            _campaignReady = campaignReady;
            _mainHeroReady = mainHeroReady;
            try
            {
                if (CampaignMapReadyOrchestrator.ShouldDeferHeavyStatusFlush(out var reason))
                {
                    RuntimeTrace.LogSkipped(
                        "ForgeStatus",
                        "UpdateReadinessFlush",
                        reason);
                    FlushLightweight();
                    return;
                }

                Flush();
            }
            catch (Exception ex)
            {
                RuntimeTrace.LogFail("ForgeStatus", "UpdateReadinessFlush", ex);
            }
        }

        public static void UpdateSession(SessionPhase phase, bool timePaused, bool flush = true)
        {
            _sessionPhase = phase;
            _sessionTimePaused = timePaused;

            if (!flush)
            {
                return;
            }

            try
            {
                Flush();
            }
            catch (Exception ex)
            {
                RuntimeTrace.LogFail("ForgeStatus", "UpdateSessionFlush", ex);
                try
                {
                    FlushLightweight(error: ex.Message);
                }
                catch
                {
                }
            }
        }

        public static void RecordCommand(
            string commandName,
            string source,
            string result,
            string detail = null,
            int sequence = -1)
        {
            _lastCommand = commandName;
            _lastCommandSource = source;
            _lastCommandResult = result;
            _lastCommandDetail = detail;
            _lastCommandSequence = sequence;
            _lastCommandTime = DateTime.Now;
            Log($"COMMAND {commandName} source={source} result={result} seq={sequence}{(string.IsNullOrEmpty(detail) ? "" : " - " + detail)}");
            RuntimeLifecycleWriter.RecordCommandFinished(commandName, sequence, result, detail);
            Flush(overall: result == "FAIL" ? "FAIL" : null);
        }

        public static void RecordError(string message)
        {
            Log($"ERROR {message}");
            Flush(overall: "FAIL", error: message);
        }

        private static void Flush(
            string overall = null,
            string error = null)
        {
            try
            {
                if (CampaignMapReadyOrchestrator.ShouldDeferHeavyStatusFlush(out var deferReason))
                {
                    RuntimeTrace.LogSkipped(
                        "ForgeStatus",
                        "Flush",
                        deferReason);
                    FlushLightweight(overall, error);
                    return;
                }

                if (MapTransitionGuard.ShouldDeferHeavyCampaignTouch())
                {
                    RuntimeTrace.LogDeferOnce(
                        "flush_heavy",
                        "ForgeStatus",
                        "Flush",
                        MapTransitionGuard.GetDeferReason());
                    FlushLightweight(overall, error);
                    return;
                }

                FlushFull(overall, error);
            }
            catch (Exception ex)
            {
                RuntimeTrace.LogFail("ForgeStatus", "Flush", ex);
            }
        }

        private static void FlushLightweight(string overall = null, string error = null)
        {
            var topOverall = overall ?? "NOT_STARTED";
            var builder = new StringBuilder();
            builder.AppendLine("{");
            builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
            builder.AppendLine($"  \"modLoaded\": {_modLoaded.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"campaignReady\": {_campaignReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"mainHeroReady\": {_mainHeroReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"  \"overall\": \"{Escape(topOverall)}\",");
            builder.AppendLine("  \"session\": {");
            builder.AppendLine($"    \"phase\": \"{Escape(_sessionPhase.ToString())}\",");
            builder.AppendLine($"    \"timePaused\": {_sessionTimePaused.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"sessionReady\": {SafeSessionBool(() => GameSessionState.IsCampaignSessionReady).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"mapReady\": {SafeSessionBool(() => GameSessionState.IsCampaignMapReady).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"settlementReady\": {SafeSessionBool(() => GameSessionState.IsSettlementInteriorReady || GameSessionState.IsSettlementMenuReady).ToString().ToLowerInvariant()},");
            AppendSurfaceSessionFields(builder);
            builder.AppendLine("  },");
            AppendStateMachineBlock(builder);
            builder.AppendLine("  \"quickStart\": {");
            builder.AppendLine($"    \"enabled\": {DevToolsConfig.AutoSkipCharacterCreation.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"setupPhase\": \"{Escape(CampaignSetupStateTracker.Phase.ToString())}\",");
            builder.AppendLine($"    \"subStage\": \"{Escape(CampaignSetupStateTracker.SubStage ?? "")}\",");
            builder.AppendLine($"    \"activeState\": \"{Escape(CampaignSetupStateTracker.ActiveStateName ?? "")}\"");
            builder.AppendLine("  },");

            builder.AppendLine("  \"tests\": {");
            var first = true;
            foreach (var entry in TestStatuses)
            {
                if (!first)
                {
                    builder.AppendLine(",");
                }

                first = false;
                TestMessages.TryGetValue(entry.Key, out var testMessage);
                if (!string.IsNullOrEmpty(testMessage))
                {
                    builder.Append(
                        $"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\", \"message\": \"{Escape(testMessage)}\" }}"
                    );
                }
                else
                {
                    builder.Append($"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\" }}");
                }
            }

            builder.AppendLine();
            builder.AppendLine("  }");

            if (!string.IsNullOrEmpty(error))
            {
                builder.AppendLine(",");
                builder.AppendLine("  \"errors\": [");
                builder.AppendLine($"    {{ \"message\": \"{Escape(error)}\" }}");
                builder.AppendLine("  ]");
            }

            builder.AppendLine("}");
            RuntimeTrace.Run("ForgeStatus", "FlushWrite", () => File.WriteAllText(StatusPath, builder.ToString()));
        }

        private static void FlushFull(
            string overall = null,
            string error = null)
        {
            try
            {
                var certificationOverall = CertificationTracker.DeriveOverall(_campaignReady, _mainHeroReady);
                var topOverall = overall ?? certificationOverall;

                var builder = new StringBuilder();
                builder.AppendLine("{");
                builder.AppendLine($"  \"updatedAt\": \"{DateTime.Now:o}\",");
                builder.AppendLine($"  \"modLoaded\": {_modLoaded.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"campaignReady\": {_campaignReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"mainHeroReady\": {_mainHeroReady.ToString().ToLowerInvariant()},");
                builder.AppendLine($"  \"overall\": \"{Escape(topOverall)}\",");
                builder.AppendLine("  \"session\": {");
                builder.AppendLine($"    \"phase\": \"{Escape(_sessionPhase.ToString())}\",");
                builder.AppendLine($"    \"timePaused\": {_sessionTimePaused.ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"sessionReady\": {SafeSessionBool(() => GameSessionState.IsCampaignSessionReady).ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"mapReady\": {SafeSessionBool(() => GameSessionState.IsCampaignMapReady).ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"activeState\": \"{SafeSessionValue(() => GameSessionState.GetActiveStateName())}\",");
                builder.AppendLine($"    \"settlementReady\": {SafeSessionBool(() => GameSessionState.IsSettlementInteriorReady || GameSessionState.IsSettlementMenuReady).ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"tavernReady\": {SafeSessionBool(() => GameSessionState.IsTavernLocationReady).ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"settlementName\": \"{SafeSessionValue(() => GameSessionState.CurrentSettlementName)}\",");
                builder.AppendLine($"    \"locationId\": \"{SafeSessionValue(() => GameSessionState.CurrentLocationId)}\",");
                builder.AppendLine($"    \"canPollHotkeys\": {SafeSessionBool(() => GameSessionState.CanPollHotkeys).ToString().ToLowerInvariant()},");
                AppendSurfaceSessionFields(builder);
                builder.AppendLine("  },");
                AppendStateMachineBlock(builder);
                builder.AppendLine("  \"quickStart\": {");
                builder.AppendLine($"    \"enabled\": {DevToolsConfig.AutoSkipCharacterCreation.ToString().ToLowerInvariant()},");
                builder.AppendLine($"    \"setupPhase\": \"{Escape(CampaignSetupStateTracker.Phase.ToString())}\",");
                builder.AppendLine($"    \"subStage\": \"{Escape(CampaignSetupStateTracker.SubStage ?? "")}\",");
                builder.AppendLine($"    \"activeState\": \"{Escape(CampaignSetupStateTracker.ActiveStateName ?? "")}\"");
                builder.AppendLine("  },");

                builder.AppendLine("  \"certification\": {");
                builder.AppendLine($"    \"sprint\": \"{CertificationTracker.SprintId}\",");
                builder.AppendLine($"    \"overall\": \"{Escape(certificationOverall)}\",");
                builder.AppendLine($"    \"completed\": {CertificationTracker.CountPassed()},");
                builder.AppendLine($"    \"required\": {CertificationTracker.RequiredCheckNames.Count},");
                builder.AppendLine($"    \"nextCheck\": \"{Escape(CertificationTracker.GetNextCheck())}\",");
                builder.AppendLine("    \"checks\": {");

                var checkFirst = true;
                foreach (var checkName in CertificationTracker.RequiredCheckNames)
                {
                    CertificationTracker.TryGetCheck(checkName, out var status, out var at, out var message);
                    if (!checkFirst)
                    {
                        builder.AppendLine(",");
                    }

                    checkFirst = false;
                    if (!string.IsNullOrEmpty(at) && !string.IsNullOrEmpty(message))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\", \"message\": \"{Escape(message)}\" }}"
                        );
                    }
                    else if (!string.IsNullOrEmpty(at))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\" }}"
                        );
                    }
                    else
                    {
                        builder.Append($"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\" }}");
                    }
                }

                builder.AppendLine();
                builder.AppendLine("    }");
                builder.AppendLine("  },");

                var certification002Overall =
                    Sprint002CertificationTracker.DeriveOverall(_campaignReady, _mainHeroReady);
                builder.AppendLine("  \"certification002\": {");
                builder.AppendLine($"    \"sprint\": \"{Sprint002CertificationTracker.SprintId}\",");
                builder.AppendLine($"    \"overall\": \"{Escape(certification002Overall)}\",");
                builder.AppendLine($"    \"completed\": {Sprint002CertificationTracker.CountPassed()},");
                builder.AppendLine($"    \"required\": {Sprint002CertificationTracker.RequiredCheckNames.Count},");
                builder.AppendLine($"    \"nextCheck\": \"{Escape(Sprint002CertificationTracker.GetNextCheck())}\",");
                builder.AppendLine("    \"checks\": {");

                checkFirst = true;
                foreach (var checkName in Sprint002CertificationTracker.RequiredCheckNames)
                {
                    Sprint002CertificationTracker.TryGetCheck(checkName, out var status, out var at, out var message);
                    if (!checkFirst)
                    {
                        builder.AppendLine(",");
                    }

                    checkFirst = false;
                    if (!string.IsNullOrEmpty(at) && !string.IsNullOrEmpty(message))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\", \"message\": \"{Escape(message)}\" }}"
                        );
                    }
                    else if (!string.IsNullOrEmpty(at))
                    {
                        builder.Append(
                            $"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\", \"at\": \"{Escape(at)}\" }}"
                        );
                    }
                    else
                    {
                        builder.Append($"      \"{Escape(checkName)}\": {{ \"status\": \"{Escape(status)}\" }}");
                    }
                }

                builder.AppendLine();
                builder.AppendLine("    }");
                builder.AppendLine("  },");

                if (!string.IsNullOrEmpty(_lastCommand))
                {
                    builder.AppendLine("  \"lastCommand\": {");
                    builder.AppendLine($"    \"name\": \"{Escape(_lastCommand)}\",");
                    builder.AppendLine($"    \"source\": \"{Escape(_lastCommandSource ?? "")}\",");
                    builder.AppendLine($"    \"sequence\": {_lastCommandSequence},");
                    builder.AppendLine($"    \"time\": \"{(_lastCommandTime ?? DateTime.Now):o}\",");
                    builder.AppendLine($"    \"result\": \"{Escape(_lastCommandResult ?? "")}\"");
                    if (!string.IsNullOrEmpty(_lastCommandDetail))
                    {
                        builder.AppendLine(",");
                        builder.AppendLine($"    \"detail\": \"{Escape(_lastCommandDetail)}\"");
                    }

                    builder.AppendLine("  },");
                }

                if (!string.IsNullOrEmpty(_preflightVerdict))
                {
                    builder.AppendLine("  \"preflight\": {");
                    builder.AppendLine($"    \"verdict\": \"{Escape(_preflightVerdict)}\",");
                    builder.AppendLine($"    \"reason\": \"{Escape(_preflightReason ?? "")}\"");
                    builder.AppendLine("  },");
                }

                if (_goldTest.Ran)
                {
                    builder.AppendLine("  \"goldTest\": {");
                    builder.AppendLine("    \"ran\": true,");
                    builder.AppendLine($"    \"passed\": {_goldTest.Passed.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"goldBefore\": {_goldTest.GoldBefore},");
                    builder.AppendLine($"    \"goldAfter\": {_goldTest.GoldAfter},");
                    builder.AppendLine($"    \"delta\": {_goldTest.Delta}");
                    builder.AppendLine("  },");
                }

                if (_progressionTest.Ran)
                {
                    builder.AppendLine("  \"progressionTest\": {");
                    builder.AppendLine("    \"ran\": true,");
                    builder.AppendLine($"    \"passed\": {_progressionTest.Passed.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"smithingXpBefore\": {_progressionTest.SmithingXpBefore},");
                    builder.AppendLine($"    \"smithingXpAfter\": {_progressionTest.SmithingXpAfter},");
                    builder.AppendLine($"    \"smithingFocusBefore\": {_progressionTest.SmithingFocusBefore},");
                    builder.AppendLine($"    \"smithingFocusAfter\": {_progressionTest.SmithingFocusAfter},");
                    builder.AppendLine($"    \"enduranceBefore\": {_progressionTest.EnduranceBefore},");
                    builder.AppendLine($"    \"enduranceAfter\": {_progressionTest.EnduranceAfter}");
                    builder.AppendLine("  },");
                }

                if (_treasuryWatchRecorded)
                {
                    builder.AppendLine("  \"treasuryWatch\": {");
                    builder.AppendLine($"    \"enabled\": {_treasuryWatch.Enabled.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"lastSnapshotDay\": {_treasuryWatch.LastSnapshotDay},");
                    builder.AppendLine($"    \"actorsTracked\": {_treasuryWatch.ActorsTracked},");
                    builder.AppendLine($"    \"snapshotCount\": {_treasuryWatch.SnapshotCount},");
                    builder.AppendLine($"    \"snapshotGeneration\": {_treasuryWatch.SnapshotGeneration},");
                    builder.AppendLine($"    \"deltaCount\": {_treasuryWatch.DeltaCount},");
                    builder.AppendLine($"    \"observedCount\": {_treasuryWatch.ObservedCount},");
                    builder.AppendLine($"    \"suspiciousCount\": {_treasuryWatch.SuspiciousCount},");
                    builder.AppendLine($"    \"criticalCount\": {_treasuryWatch.CriticalCount},");
                    builder.AppendLine($"    \"maxAbsDelta\": {_treasuryWatch.MaxAbsDelta},");
                    builder.AppendLine($"    \"maxSeverity\": \"{Escape(_treasuryWatch.MaxSeverity ?? "")}\",");
                    builder.AppendLine($"    \"lastCriticalActor\": \"{Escape(_treasuryWatch.LastCriticalActor ?? "")}\",");
                    builder.AppendLine($"    \"lastCriticalDelta\": {_treasuryWatch.LastCriticalDelta},");
                    builder.AppendLine($"    \"lastReportPath\": \"{Escape(_treasuryWatch.ReportPath ?? "")}\"");
                    builder.AppendLine("  },");
                }

                if (_forgeRecommendationsRecorded)
                {
                    builder.AppendLine("  \"forgeRecommendations\": {");
                    builder.AppendLine($"    \"source\": \"{Escape(_forgeRecommendations.Source ?? "")}\",");
                    builder.AppendLine($"    \"sourceKind\": \"{Escape(_forgeRecommendations.SourceKind ?? "")}\",");
                    builder.AppendLine($"    \"sourceStatus\": \"{Escape(_forgeRecommendations.SourceStatus ?? "")}\",");
                    builder.AppendLine($"    \"fallbackUsed\": {_forgeRecommendations.FallbackUsed.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"doctrine\": \"{Escape(_forgeRecommendations.Doctrine ?? "")}\",");
                    builder.AppendLine($"    \"topCandidateId\": \"{Escape(_forgeRecommendations.TopCandidateId ?? "")}\",");
                    builder.AppendLine($"    \"topCandidateName\": \"{Escape(_forgeRecommendations.TopCandidateName ?? "")}\",");
                    builder.AppendLine($"    \"topFinalScore\": {_forgeRecommendations.TopFinalScore},");
                    builder.AppendLine($"    \"rankedCount\": {_forgeRecommendations.RankedCount},");
                    builder.AppendLine($"    \"candidateCount\": {_forgeRecommendations.CandidateCount},");
                    builder.AppendLine($"    \"reportPath\": \"{Escape(_forgeRecommendations.ReportPath ?? "")}\",");
                    builder.AppendLine($"    \"generatedAt\": \"{(_forgeRecommendations.GeneratedAt ?? DateTime.Now):o}\"");
                    builder.AppendLine("  },");
                }

                if (_recipeProbeRecorded)
                {
                    builder.AppendLine("  \"recipeProbe\": {");
                    builder.AppendLine($"    \"probeStatus\": \"{Escape(_recipeProbe.ProbeStatus ?? "")}\",");
                    builder.AppendLine($"    \"detail\": \"{Escape(_recipeProbe.Detail ?? "")}\",");
                    builder.AppendLine($"    \"matchedTypeCount\": {_recipeProbe.MatchedTypeCount},");
                    builder.AppendLine($"    \"templateCount\": {_recipeProbe.TemplateCount},");
                    builder.AppendLine(
                        $"    \"craftingOrderCount\": {(_recipeProbe.CraftingOrderCount.HasValue ? _recipeProbe.CraftingOrderCount.Value.ToString() : "null")},");
                    builder.AppendLine(
                        $"    \"smithingSkillLevel\": {(_recipeProbe.SmithingSkillLevel.HasValue ? _recipeProbe.SmithingSkillLevel.Value.ToString() : "null")},");
                    builder.AppendLine($"    \"reportPath\": \"{Escape(_recipeProbe.ReportPath ?? "")}\",");
                    builder.AppendLine($"    \"generatedAt\": \"{(_recipeProbe.GeneratedAt ?? DateTime.Now):o}\"");
                    builder.AppendLine("  },");
                }

                if (_autoCharacterBuildRecorded)
                {
                    builder.AppendLine("  \"autoCharacterBuild\": {");
                    builder.AppendLine($"    \"selectedProfile\": \"{Escape(_autoCharacterBuild.SelectedProfileId ?? "")}\",");
                    builder.AppendLine($"    \"defaultProfile\": \"{Escape(_autoCharacterBuild.DefaultProfileId ?? "")}\",");
                    builder.AppendLine($"    \"autoApplyNewGame\": {_autoCharacterBuild.AutoApplyNewGame.ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"continueAutoApply\": {_autoCharacterBuild.ContinueAutoApply.ToString().ToLowerInvariant()},");
                    builder.AppendLine(
                        $"    \"lastApplied\": {(string.IsNullOrEmpty(_autoCharacterBuild.LastAppliedProfileId) ? "null" : $"\"{Escape(_autoCharacterBuild.LastAppliedProfileId)} ({Escape(_autoCharacterBuild.LastAppliedTrigger ?? "")})\"")},");
                    builder.AppendLine($"    \"availableProfiles\": \"{Escape(_autoCharacterBuild.AvailableProfilesCsv ?? "")}\",");
                    builder.AppendLine($"    \"profile\": \"{Escape(_autoCharacterBuild.Profile ?? "")}\",");
                    builder.AppendLine($"    \"applied\": {(_autoCharacterBuild.LastApplied ?? false).ToString().ToLowerInvariant()},");
                    builder.AppendLine($"    \"trigger\": \"{Escape(_autoCharacterBuild.LastAppliedTrigger ?? "")}\",");
                    builder.AppendLine($"    \"reportPath\": \"{Escape(_autoCharacterBuild.ReportPath ?? "")}\",");
                    builder.AppendLine($"    \"generatedAt\": \"{(_autoCharacterBuild.GeneratedAt ?? DateTime.Now):o}\"");
                    builder.AppendLine("  },");
                }

                if (GameSessionState.IsCampaignMapReady
                    && _mainHeroReady
                    && !CampaignMapReadyOrchestrator.ShouldDeferHeavyStatusFlush(out _))
                {
                    AppendFactionPowerPosture(builder);
                }

                builder.AppendLine("  \"tests\": {");
                var first = true;
                foreach (var entry in TestStatuses)
                {
                    if (!first)
                    {
                        builder.AppendLine(",");
                    }

                    first = false;
                    TestMessages.TryGetValue(entry.Key, out var testMessage);
                    if (!string.IsNullOrEmpty(testMessage))
                    {
                        builder.Append(
                            $"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\", \"message\": \"{Escape(testMessage)}\" }}"
                        );
                    }
                    else
                    {
                        builder.Append($"    \"{Escape(entry.Key)}\": {{ \"status\": \"{Escape(entry.Value)}\" }}");
                    }
                }

                builder.AppendLine();
                builder.AppendLine("  }");

                if (!string.IsNullOrEmpty(error))
                {
                    builder.AppendLine(",");
                    builder.AppendLine("  \"errors\": [");
                    builder.AppendLine($"    {{ \"message\": \"{Escape(error)}\" }}");
                    builder.AppendLine("  ]");
                }

                builder.AppendLine("}");
                RuntimeTrace.Run("ForgeStatus", "FlushWrite", () => File.WriteAllText(StatusPath, builder.ToString()));
            }
            catch (Exception ex)
            {
                RuntimeTrace.LogFail("ForgeStatus", "FlushFull", ex);
            }
        }

        private static void AppendSurfaceSessionFields(StringBuilder builder)
        {
            ReadinessSurfaceSnapshot snap;
            try
            {
                snap = GameSessionState.CaptureReadinessSurfaceSnapshot();
            }
            catch
            {
                snap = new ReadinessSurfaceSnapshot { ReadinessSurface = ReadinessSurfaceKinds.Unknown };
            }

            builder.AppendLine($"    \"mapStateActive\": {snap.MapStateActive.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"settlementMenuOpen\": {snap.SettlementMenuOpen.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"settlementMenuId\": \"{Escape(snap.SettlementMenuId ?? "")}\",");
            builder.AppendLine($"    \"campaignMapSurfaceOpen\": {snap.CampaignMapSurfaceOpen.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"settlementInteriorReady\": {snap.SettlementInteriorReady.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"readinessSurface\": \"{Escape(snap.ReadinessSurface ?? ReadinessSurfaceKinds.Unknown)}\",");
            AppendAssistReadinessFields(builder);
        }

        private static void AppendAssistReadinessFields(StringBuilder builder)
        {
            builder.AppendLine($"    \"canPollFileInbox\": {SafeSessionBool(() => GameSessionState.CanPollFileInbox).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"openMapReady\": {SafeSessionBool(() => AssistReadinessEvaluator.IsOpenMapReady).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"townMenuReady\": {SafeSessionBool(() => AssistReadinessEvaluator.IsTownMenuReady).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"inGameAssistReady\": {SafeSessionBool(() => AssistReadinessEvaluator.IsInGameAssistReady).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"canAcceptAssistiveCommand\": {SafeSessionBool(() => AssistReadinessEvaluator.CanAcceptAssistiveCommand).ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"assistiveCertReady\": {SafeSessionBool(() => AssistReadinessEvaluator.IsInGameAssistReady).ToString().ToLowerInvariant()}");
        }

        private static void AppendStateMachineBlock(StringBuilder builder)
        {
            GameplaySurfaceSnapshot snapshot;
            try
            {
                snapshot = GameSessionState.LatestGameplaySurface ?? GameplaySurfaceClassifier.CaptureLive();
            }
            catch
            {
                snapshot = new GameplaySurfaceSnapshot();
            }

            RuntimeLifecycleWriter.AppendStateMachine(builder, snapshot);
        }

        private static void AppendFactionPowerPosture(StringBuilder builder)
        {
            if (!RuntimeTrace.RunSafe(
                    "ForgeStatus",
                    "FactionPowerPostureScan",
                    () => FactionPowerPostureScanner.Scan(),
                    out FactionPowerPostureBlock block))
            {
                return;
            }

            builder.AppendLine("  \"clanPosture\": {");
            builder.AppendLine($"    \"allegianceMode\": \"{Escape(block.AllegianceMode ?? "")}\",");
            builder.AppendLine($"    \"kingdomName\": {(block.KingdomName == null ? "null" : $"\"{Escape(block.KingdomName)}\"")},");
            builder.AppendLine($"    \"mapFactionName\": {(block.MapFactionName == null ? "null" : $"\"{Escape(block.MapFactionName)}\"")},");
            builder.AppendLine($"    \"isAtWar\": {block.IsAtWar.ToString().ToLowerInvariant()},");
            builder.AppendLine($"    \"playerPartyStrength\": {(block.PlayerPartyStrength.HasValue ? block.PlayerPartyStrength.Value.ToString() : "null")},");
            builder.AppendLine($"    \"powerVerdict\": \"{Escape(block.PowerVerdict ?? "")}\",");
            builder.AppendLine($"    \"hostileCountInRadius\": {block.HostileCountInRadius},");
            builder.AppendLine(
                $"    \"strengthRatioVsNearestHostile\": {(block.StrengthRatioVsNearestHostile.HasValue ? block.StrengthRatioVsNearestHostile.Value.ToString("0.##") : "null")}");
            builder.AppendLine("  },");
        }

        private static string SafeSessionValue(Func<string> getter, string fallback = "")
        {
            try
            {
                return Escape(getter() ?? fallback);
            }
            catch
            {
                return Escape(fallback);
            }
        }

        private static bool SafeSessionBool(Func<bool> getter, bool fallback = false)
        {
            try
            {
                return getter();
            }
            catch
            {
                return fallback;
            }
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}
