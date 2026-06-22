using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.Cohesion;
using BlacksmithGuild.Forge;
using BlacksmithGuild.GuildLoop;
using BlacksmithGuild.MapTrade;
using BlacksmithGuild.Market;
using BlacksmithGuild.TavernHeroes;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools
{
    /// <summary>
    /// Keep hotkey bindings in sync with DevHotkeyHandler.cs.
    /// </summary>
    public static class CommandSurfaceService
    {
        public const string ReportFileName = "BlacksmithGuild_CommandSurface.json";

        private static readonly string ReportPath = Path.Combine(BasePath.Name, ReportFileName);

        private static readonly HashSet<string> MutationCommands = new HashSet<string>
        {
            EconomyTestScenarios.RichPlayerEconomyTestName,
            CharacterProgressionTestScenarios.RichSmithingProgressionTestName,
            CharacterProgressionTestScenarios.AddSmithingXpCommand,
            CharacterProgressionTestScenarios.AddSmithingFocusCommand,
            CharacterProgressionTestScenarios.AddEnduranceAttributeCommand,
            AutoCharacterBuild.AutoCharacterBuildService.ApplyAutoCharacterBuildCommand,
            SmithingSafeActionService.RunSmithingSafeActionNowCommand,
            BlacksmithAutomationService.RunBlacksmithAutomationNowCommand,
            TavernHeroRecruitmentService.RecruitTavernHeroVisibleNowCommand,
            CohesionExecutionDriver.RunVisibleCohesionMoveNowCommand,
            MapTradeAutonomousService.RunAutonomousVisibleTradeRouteNowCommand,
            AutonomousGuildLoopService.RunAutonomousGuildLoopNowCommand
        };

        public static void WriteCommandSurface(string source)
        {
            try
            {
                WriteCommandSurfaceCore(source);
            }
            catch (Exception ex)
            {
                DebugLogger.Test(
                    $"[TBG COMMANDS] WriteCommandSurface failed source={source}: {ex.Message}",
                    showInGame: false);
            }
        }

        private static void WriteCommandSurfaceCore(string source)
        {
            var sb = new StringBuilder();
            var hotkeys = BuildHotkeys();
            var inbox = DevCommandRegistry.RegisteredCommandNames.OrderBy(name => name).ToList();
            var stageDExposed = DevCommandRegistry.IsRegistered(SmithingRestPlanService.RunSmithingRestPlanNowCommand);

            sb.AppendLine("{");
            sb.AppendLine($"  \"generatedUtc\": \"{Escape(DateTime.UtcNow.ToString("o"))}\",");
            sb.AppendLine($"  \"source\": \"{Escape(source)}\",");
            sb.AppendLine("  \"hotkeys\": [");
            for (var i = 0; i < hotkeys.Count; i++)
            {
                var row = hotkeys[i];
                sb.AppendLine("    {");
                sb.AppendLine($"      \"input\": \"{Escape(row.Input)}\",");
                sb.AppendLine($"      \"command\": \"{Escape(row.Command)}\",");
                sb.AppendLine($"      \"description\": \"{Escape(row.Description)}\"");
                sb.Append(i < hotkeys.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"inboxCommands\": [");
            for (var i = 0; i < inbox.Count; i++)
            {
                var name = inbox[i];
                var mutation = MutationCommands.Contains(name);
                sb.AppendLine("    {");
                sb.AppendLine($"      \"command\": \"{Escape(name)}\",");
                sb.AppendLine($"      \"mutation\": {mutation.ToString().ToLowerInvariant()}");
                sb.Append(i < inbox.Count - 1 ? "    }," : "    }");
                sb.AppendLine();
            }

            sb.AppendLine("  ],");
            sb.AppendLine("  \"stageD\": {");
            sb.AppendLine($"    \"exposed\": {stageDExposed.ToString().ToLowerInvariant()},");
            sb.AppendLine($"    \"command\": {(stageDExposed ? $"\"{SmithingRestPlanService.RunSmithingRestPlanNowCommand}\"" : "null")},");
            sb.AppendLine("    \"hotkey\": null,");
            sb.AppendLine($"    \"reason\": \"{(stageDExposed ? "Read-only rest plan via forge.ps1 inbox" : "No rest optimizer command currently registered")}\"");
            sb.AppendLine("  }");
            sb.AppendLine("}");

            File.WriteAllText(ReportPath, sb.ToString(), Encoding.UTF8);
        }

        private static List<HotkeyBinding> BuildHotkeys()
        {
            return new List<HotkeyBinding>
            {
                new HotkeyBinding("F7", DevCommandRegistry.ShowForgeStatusCommand, "Status snapshot"),
                new HotkeyBinding("F8", DevCommandRegistry.ListScenariosCommand, "Command list"),
                new HotkeyBinding("F9", DevCommandRegistry.AdvanceOneDayCommand, "Advance one day"),
                new HotkeyBinding("F10", DevCommandRegistry.ToggleFastForwardCommand, "Toggle fast-forward"),
                new HotkeyBinding("F11", EconomyTestScenarios.RichPlayerEconomyTestName, "Gold test (+100k)"),
                new HotkeyBinding("Ctrl+Alt+M", MarketIntelligenceService.MarketSnapshotNowCommand, "Market intel"),
                new HotkeyBinding("Ctrl+Alt+R", ForgeRecommendationService.RankForgeCandidatesCommand, "Rank forge candidates"),
                new HotkeyBinding("Ctrl+Alt+G", GuildLoopService.RunGuildLoopNowCommand, "Guild loop (market + forge + crew)"),
                new HotkeyBinding("Ctrl+Alt+B", AutonomousGuildLoopService.AbortAutonomousGuildLoopNowCommand, "Abort all movement automation"),
                new HotkeyBinding("Ctrl+Alt+S", CharacterProgressionTestScenarios.RichSmithingProgressionTestName, "Rich smithing progression"),
                new HotkeyBinding("Ctrl+Alt+D", DevCommandRegistry.AdvanceOneDayCommand, "Daily tick (fallback)"),
                new HotkeyBinding("Ctrl+Alt+7", DevCommandRegistry.ShowForgeStatusCommand, "Status (fallback)"),
                new HotkeyBinding("Ctrl+Alt+8", DevCommandRegistry.ListScenariosCommand, "Commands (fallback)")
            };
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }

        private sealed class HotkeyBinding
        {
            public HotkeyBinding(string input, string command, string description)
            {
                Input = input;
                Command = command;
                Description = description;
            }

            public string Input { get; }
            public string Command { get; }
            public string Description { get; }
        }
    }
}
