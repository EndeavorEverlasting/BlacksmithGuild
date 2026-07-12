using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.MapTrade;

namespace BlacksmithGuild.DevTools
{
    public enum EngineToggleMode
    {
        Manual,
        Hybrid,
        Automation
    }

    public enum EngineToggleKey
    {
        Governor,
        MapTrade,
        GuildLoop,
        Cohesion,
        HorseMarket,
        Smithing,
        Companion,
        Assistive
    }

    /// <summary>
    /// Central authority for runtime engine mode toggles.
    ///
    /// Manual: keep engines available for direct/read-only/manual use, but disable autonomous takeover.
    /// Hybrid: allow explicit user/file-inbox commands for visible mechanisms, but keep the Governor from ticking autonomously.
    /// Automation: allow higher-order automation to run and permit bounded execution through the same authority.
    ///
    /// This is intentionally small: existing DevToolsConfig flags remain the low-level switches, but callers should
    /// consult this authority instead of reading scattered booleans directly.
    /// </summary>
    public static class EngineToggleAuthority
    {
        public const string ShowEngineToggleStateCommand = "ShowEngineToggleState";
        public const string CycleEngineToggleModeCommand = "CycleEngineToggleMode";
        public const string SetEngineToggleManualCommand = "SetEngineToggleManual";
        public const string SetEngineToggleHybridCommand = "SetEngineToggleHybrid";
        public const string SetEngineToggleAutomationCommand = "SetEngineToggleAutomation";
        public const string SetMapTradeManualCommand = "SetMapTradeManual";
        public const string SetMapTradeHybridCommand = "SetMapTradeHybrid";
        public const string SetMapTradeAutomationCommand = "SetMapTradeAutomation";
        public const string EvidenceFileName = "BlacksmithGuild_EngineToggleAuthority.json";

        private static readonly EngineToggleKey[] KnownEngines =
        {
            EngineToggleKey.Governor,
            EngineToggleKey.MapTrade,
            EngineToggleKey.GuildLoop,
            EngineToggleKey.Cohesion,
            EngineToggleKey.HorseMarket,
            EngineToggleKey.Smithing,
            EngineToggleKey.Companion,
            EngineToggleKey.Assistive
        };

        private static readonly Dictionary<EngineToggleKey, EngineToggleMode> EngineModes =
            new Dictionary<EngineToggleKey, EngineToggleMode>();

        private static bool _initialized;
        private static EngineToggleMode _globalMode = EngineToggleMode.Hybrid;

        public static EngineToggleMode GlobalMode
        {
            get
            {
                EnsureInitialized();
                return _globalMode;
            }
        }

        public static bool ShowState(string source = ShowEngineToggleStateCommand)
        {
            EnsureInitialized();
            var summary = BuildSummary(source);
            DebugLogger.Test(summary, showInGame: false);
            WriteEvidence(source);
            InGameNotice.Info($"Engines: {ModeLabel(_globalMode)}");
            return true;
        }

        public static bool RunCommand(string commandName, string source = null)
        {
            if (commandName == ShowEngineToggleStateCommand)
            {
                return ShowState(source ?? commandName);
            }

            if (commandName == CycleEngineToggleModeCommand)
            {
                return SetGlobalMode(NextMode(GlobalMode), source ?? commandName);
            }

            if (commandName == SetEngineToggleManualCommand)
            {
                return SetGlobalMode(EngineToggleMode.Manual, source ?? commandName);
            }

            if (commandName == SetEngineToggleHybridCommand)
            {
                return SetGlobalMode(EngineToggleMode.Hybrid, source ?? commandName);
            }

            if (commandName == SetEngineToggleAutomationCommand)
            {
                return SetGlobalMode(EngineToggleMode.Automation, source ?? commandName);
            }

            if (commandName == SetMapTradeManualCommand)
            {
                return SetEngineMode(
                    EngineToggleKey.MapTrade,
                    EngineToggleMode.Manual,
                    source ?? commandName,
                    "targeted external operator command");
            }

            if (commandName == SetMapTradeHybridCommand)
            {
                return SetEngineMode(
                    EngineToggleKey.MapTrade,
                    EngineToggleMode.Hybrid,
                    source ?? commandName,
                    "targeted external operator command");
            }

            if (commandName == SetMapTradeAutomationCommand)
            {
                return SetEngineMode(
                    EngineToggleKey.MapTrade,
                    EngineToggleMode.Automation,
                    source ?? commandName,
                    "targeted external operator command");
            }

            return false;
        }

        public static bool SetGlobalMode(EngineToggleMode mode, string source = null)
        {
            EnsureInitialized();
            _globalMode = mode;
            foreach (var engine in KnownEngines)
            {
                EngineModes[engine] = mode;
                ApplyModeToConfig(engine, mode);
            }

            if (mode == EngineToggleMode.Manual)
            {
                RequestManualHold(source ?? "SetGlobalMode");
            }

            var detail = BuildSummary(source ?? "SetGlobalMode");
            DebugLogger.Test(detail, showInGame: false);
            WriteEvidence(source ?? "SetGlobalMode");
            InGameNotice.Success($"Engines: {ModeLabel(mode)}");
            return true;
        }

        public static bool SetEngineMode(
            EngineToggleKey engine,
            EngineToggleMode mode,
            string requestedBy,
            string reason = null,
            bool showNotice = false)
        {
            EnsureInitialized();
            EngineModes[engine] = mode;
            ApplyModeToConfig(engine, mode);
            _globalMode = InferGlobalMode();
            if (mode == EngineToggleMode.Manual)
            {
                RequestManualHold(engine, requestedBy ?? "SetEngineMode");
            }

            DebugLogger.Test(
                $"[TBG ENGINES] {requestedBy ?? "unknown"} set {engine}={mode} reason={reason ?? "none"}",
                showInGame: false);
            WriteEvidence(requestedBy ?? "SetEngineMode");
            if (showNotice)
            {
                InGameNotice.Info($"Engines: {engine} {ModeLabel(mode)}");
            }

            return true;
        }

        public static void ResetForNewCampaign()
        {
            EngineModes.Clear();
            _initialized = true;
            _globalMode = EngineToggleMode.Manual;
            foreach (var engine in KnownEngines)
            {
                EngineModes[engine] = EngineToggleMode.Manual;
                ApplyModeToConfig(engine, EngineToggleMode.Manual);
            }

            WriteEvidence("campaign_generation_reset");
        }

        public static void WriteEvidence(string source)
        {
            EnsureInitialized();
            try
            {
                var sb = new StringBuilder();
                sb.AppendLine("{");
                sb.AppendLine("  \"schemaVersion\": \"TbgEngineToggleAuthority.v1\",");
                sb.AppendLine("  \"updatedAtUtc\": \"" + DateTime.UtcNow.ToString("o") + "\",");
                sb.AppendLine("  \"source\": \"" + Escape(source) + "\",");
                sb.AppendLine("  \"runtimeSessionId\": \"" + Escape(RuntimeProofContext.RuntimeSessionId) + "\",");
                sb.AppendLine("  \"runId\": " + NullableString(RuntimeProofContext.RunId) + ",");
                sb.AppendLine("  \"headSha\": " + NullableString(RuntimeProofContext.ExpectedHeadSha) + ",");
                sb.AppendLine("  \"activeSaveSlotName\": " + NullableString(RuntimeProofContext.ActiveSaveSlotName) + ",");
                sb.AppendLine("  \"globalMode\": \"" + _globalMode + "\",");
                sb.AppendLine("  \"engines\": {");
                for (var index = 0; index < KnownEngines.Length; index++)
                {
                    var engine = KnownEngines[index];
                    var mode = GetMode(engine);
                    sb.Append("    \"").Append(engine).Append("\": { \"mode\": \"").Append(mode).Append("\" }");
                    sb.AppendLine(index < KnownEngines.Length - 1 ? "," : string.Empty);
                }

                sb.AppendLine("  },");
                sb.AppendLine("  \"mapTrade\": {");
                sb.AppendLine("    \"isRunning\": " + Boolean(MapTradeAutonomousService.IsRunning) + ",");
                sb.AppendLine("    \"lastTerminalState\": \"" + MapTradeAutonomousService.LastTerminalState + "\",");
                sb.AppendLine("    \"lastTerminalVerdict\": " + NullableString(MapTradeAutonomousService.LastTerminalVerdict));
                sb.AppendLine("  }");
                sb.AppendLine("}");

                RuntimeProofContext.WriteAllTextAtomic(
                    Path.Combine(TaleWorlds.Library.BasePath.Name, EvidenceFileName),
                    sb.ToString());
            }
            catch (Exception ex)
            {
                DebugLogger.Test("[TBG ENGINES] authority evidence failed: " + ex.Message, showInGame: false);
            }
        }

        public static EngineToggleMode GetMode(EngineToggleKey engine)
        {
            EnsureInitialized();
            return EngineModes.ContainsKey(engine) ? EngineModes[engine] : _globalMode;
        }

        public static bool IsEngineEnabled(EngineToggleKey engine)
        {
            var mode = GetMode(engine);
            return mode != EngineToggleMode.Manual;
        }

        public static bool IsAutomationEnabled(EngineToggleKey engine)
        {
            return GetMode(engine) == EngineToggleMode.Automation;
        }

        public static bool IsBoundedExecutionAllowed(EngineToggleKey engine)
        {
            return engine == EngineToggleKey.Governor
                   && GetMode(EngineToggleKey.Governor) == EngineToggleMode.Automation
                   && DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution;
        }

        public static string BuildSummary(string source = null)
        {
            EnsureInitialized();
            var sb = new StringBuilder();
            sb.Append("[TBG ENGINES] mode=").Append(_globalMode);
            if (!string.IsNullOrWhiteSpace(source))
            {
                sb.Append(" source=").Append(source);
            }

            foreach (var engine in KnownEngines)
            {
                sb.Append(' ').Append(engine).Append('=').Append(GetMode(engine));
            }

            sb.Append(" governorAuto=").Append(DevToolsConfig.CampaignRuntimeGovernorAutonomousMode);
            sb.Append(" bounded=").Append(DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution);
            sb.Append(" mapTradeAuto=").Append(DevToolsConfig.MapTradeAutonomousMode);
            sb.Append(" guildLoopAuto=").Append(DevToolsConfig.GuildLoopAutonomousMode);
            return sb.ToString();
        }

        private static void EnsureInitialized()
        {
            if (_initialized)
            {
                return;
            }

            _initialized = true;

            EngineModes[EngineToggleKey.Governor] = DevToolsConfig.CampaignRuntimeGovernorAutonomousMode
                ? EngineToggleMode.Automation
                : EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.MapTrade] = DevToolsConfig.MapTradeAutonomousMode
                ? EngineToggleMode.Hybrid
                : EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.GuildLoop] = DevToolsConfig.GuildLoopAutonomousMode
                ? EngineToggleMode.Hybrid
                : EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.Cohesion] = EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.HorseMarket] = EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.Smithing] = EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.Companion] = EngineToggleMode.Manual;
            EngineModes[EngineToggleKey.Assistive] = DevToolsConfig.AssistiveMode
                ? EngineToggleMode.Hybrid
                : EngineToggleMode.Manual;

            _globalMode = InferGlobalMode();
        }

        private static EngineToggleMode InferGlobalMode()
        {
            var allManual = true;
            var allAutomation = true;
            foreach (var engine in KnownEngines)
            {
                var mode = EngineModes.ContainsKey(engine) ? EngineModes[engine] : EngineToggleMode.Manual;
                if (mode != EngineToggleMode.Manual)
                {
                    allManual = false;
                }

                if (mode != EngineToggleMode.Automation)
                {
                    allAutomation = false;
                }
            }

            if (allManual)
            {
                return EngineToggleMode.Manual;
            }

            return allAutomation ? EngineToggleMode.Automation : EngineToggleMode.Hybrid;
        }

        private static EngineToggleMode NextMode(EngineToggleMode mode)
        {
            switch (mode)
            {
                case EngineToggleMode.Manual:
                    return EngineToggleMode.Hybrid;
                case EngineToggleMode.Hybrid:
                    return EngineToggleMode.Automation;
                default:
                    return EngineToggleMode.Manual;
            }
        }

        private static void ApplyModeToConfig(EngineToggleKey engine, EngineToggleMode mode)
        {
            switch (engine)
            {
                case EngineToggleKey.Governor:
                    DevToolsConfig.CampaignRuntimeGovernorAutonomousMode = mode == EngineToggleMode.Automation;
                    DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution = mode == EngineToggleMode.Automation;
                    break;
                case EngineToggleKey.MapTrade:
                    DevToolsConfig.MapTradeAutonomousMode = mode != EngineToggleMode.Manual;
                    break;
                case EngineToggleKey.GuildLoop:
                    DevToolsConfig.GuildLoopAutonomousMode = mode != EngineToggleMode.Manual;
                    break;
                case EngineToggleKey.Assistive:
                    DevToolsConfig.AssistiveMode = mode != EngineToggleMode.Manual;
                    break;
                case EngineToggleKey.Cohesion:
                case EngineToggleKey.HorseMarket:
                case EngineToggleKey.Smithing:
                case EngineToggleKey.Companion:
                default:
                    break;
            }
        }

        private static void RequestManualHold(string source)
        {
            foreach (var engine in KnownEngines)
            {
                RequestManualHold(engine, source);
            }
        }

        private static void RequestManualHold(EngineToggleKey engine, string source)
        {
            switch (engine)
            {
                case EngineToggleKey.MapTrade:
                    if (MapTradeAutonomousService.IsRunning)
                    {
                        DebugLogger.Test(
                            $"[TBG ENGINES] {source ?? "unknown"} manual hold aborting MapTrade route",
                            showInGame: false);
                        MapTradeAutonomousService.AbortNow();
                    }

                    break;
                case EngineToggleKey.GuildLoop:
                    if (AutonomousGuildLoopService.IsRunning)
                    {
                        DebugLogger.Test(
                            $"[TBG ENGINES] {source ?? "unknown"} manual hold aborting GuildLoop route",
                            showInGame: false);
                        AutonomousGuildLoopService.AbortNow();
                    }

                    break;
            }
        }

        private static string ModeLabel(EngineToggleMode mode)
        {
            switch (mode)
            {
                case EngineToggleMode.Manual:
                    return "Manual";
                case EngineToggleMode.Automation:
                    return "Automation";
                default:
                    return "Hybrid";
            }
        }

        private static string Boolean(bool value) => value ? "true" : "false";
        private static string NullableString(string value) => value == null ? "null" : "\"" + Escape(value) + "\"";
        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
    }
}
